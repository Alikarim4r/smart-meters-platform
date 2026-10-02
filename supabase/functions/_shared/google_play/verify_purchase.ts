// Google Play purchase verification/sync orchestration. All I/O is injected so
// this runs under Node tests with deterministic fixtures.
//
// Flow (client_verify):
//   1. caller JWT -> billing_google_play_authorize(org) (DB decides; 403 otherwise)
//   2. subscriptionsv2.get(token) with the server-configured package
//   3. interpretSubscriptionV2 (pure, fail-closed)
//   4. billing_apply_google_play_verification (service_role; DB maps state,
//      checks mapping/binding/token ownership, writes entitlement + audit)
//   5. if the DB applied an entitling, unacknowledged purchase: single-flight
//      server acknowledgement (claim -> acknowledge -> succeeded/failed)
// syncPurchase (steps 2-5) is reusable for server-triggered resync/RTDN.

import type { FetchFn, PlayPublisherClient } from './google_play_api.ts';
import {
  interpretSubscriptionV2,
  mapGoogleState,
  parseVerifyRequest,
  tokenSha256,
  type PurchaseEvidence,
} from './play_subscription.ts';

export type SyncSource = 'client_verify' | 'server_resync' | 'rtdn';

export interface ApplyParams {
  organizationId: string;
  purchaseToken: string;
  evidence: PurchaseEvidence;
  actorId: string | null;
  source: SyncSource;
}

export interface ApplyResult {
  outcome: 'applied' | 'recorded' | 'rejected' | 'conflict';
  reason: string | null;
  mapped_status?: string | null;
  plan?: string | null;
  entitlement_applied: boolean;
  has_access?: boolean;
  acknowledgement_required: boolean;
}

export interface BillingRpc {
  /** Returns the caller's uid if they may manage billing for the org, else null. */
  authorize(callerJwt: string, organizationId: string): Promise<string | null>;
  apply(params: ApplyParams): Promise<ApplyResult>;
  ackTransition(purchaseToken: string, event: 'claim' | 'succeeded' | 'failed'): Promise<boolean>;
}

export type Acknowledgement =
  | 'server_acknowledged'
  | 'already_acknowledged'
  | 'server_ack_failed'
  | 'in_progress'
  | 'not_required';

export interface SyncOutcome {
  httpStatus: number;
  body: {
    ok: boolean;
    outcome: string;
    reason: string | null;
    status: string | null;
    plan: string | null;
    has_access: boolean;
    entitlement_applied: boolean;
    acknowledgement: Acknowledgement;
  };
}

export interface Logger {
  info(event: Record<string, unknown>): void;
  error(event: Record<string, unknown>): void;
}

export interface SyncDeps {
  rpc: BillingRpc;
  publisher: PlayPublisherClient;
  packageName: string;
  allowTestPurchases: boolean;
  now: () => Date;
  logger: Logger;
}

function failure(httpStatus: number, outcome: string, reason: string): SyncOutcome {
  return {
    httpStatus,
    body: {
      ok: false,
      outcome,
      reason,
      status: null,
      plan: null,
      has_access: false,
      entitlement_applied: false,
      acknowledgement: 'not_required',
    },
  };
}

export async function syncPurchase(
  deps: SyncDeps,
  input: {
    organizationId: string;
    purchaseToken: string;
    actorId: string | null;
    source: SyncSource;
    productIdHint?: string | null;
    basePlanIdHint?: string | null;
  },
  depth = 0,
): Promise<SyncOutcome> {
  const tokenRef = (await tokenSha256(input.purchaseToken)).slice(0, 16);
  const log = (fields: Record<string, unknown>) =>
    deps.logger.info({
      event: 'google_play_sync',
      source: input.source,
      organization_id: input.organizationId,
      token_sha256_prefix: tokenRef,
      ...fields,
    });

  const got = await deps.publisher.getSubscriptionV2(input.purchaseToken);
  if (got.kind === 'not_found') {
    log({ outcome: 'rejected', reason: 'PURCHASE_NOT_FOUND' });
    return failure(422, 'rejected', 'PURCHASE_NOT_FOUND');
  }
  if (got.kind === 'error') {
    log({ outcome: 'error', reason: 'PROVIDER_UNAVAILABLE', provider_status: got.status });
    return failure(502, 'error', 'PROVIDER_UNAVAILABLE');
  }

  const interpreted = interpretSubscriptionV2(got.body, {
    packageName: deps.packageName,
    productIdHint: input.productIdHint ?? null,
    basePlanIdHint: input.basePlanIdHint ?? null,
    allowTestPurchases: deps.allowTestPurchases,
  });
  if (!interpreted.ok) {
    log({ outcome: 'rejected', reason: interpreted.reason });
    return failure(422, 'rejected', interpreted.reason);
  }
  const evidence = interpreted.value;

  const applied = await deps.rpc.apply({
    organizationId: input.organizationId,
    purchaseToken: input.purchaseToken,
    evidence,
    actorId: input.actorId,
    source: input.source,
  });

  // A canceled pending upgrade grants nothing; the linked (old) subscription
  // stays authoritative, so refresh it from Google (one level only).
  if (
    evidence.subscriptionState === 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED' &&
    evidence.linkedPurchaseToken &&
    depth === 0
  ) {
    try {
      await syncPurchase(
        deps,
        {
          organizationId: input.organizationId,
          purchaseToken: evidence.linkedPurchaseToken,
          actorId: input.actorId,
          source: 'server_resync',
        },
        depth + 1,
      );
    } catch (err) {
      // Best effort: the primary (non-entitling) result stands either way.
      log({ outcome: 'error', reason: 'LINKED_RESYNC_FAILED', error: err instanceof Error ? err.message.slice(0, 120) : 'unknown' });
    }
  }

  const entitlingNow = mapGoogleState(evidence.subscriptionState, evidence.expiryTime, deps.now()).entitling;
  let acknowledgement: Acknowledgement = 'not_required';
  if (applied.outcome === 'applied' && entitlingNow) {
    if (
      applied.acknowledgement_required &&
      evidence.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING'
    ) {
      if (!(await deps.rpc.ackTransition(input.purchaseToken, 'claim'))) {
        acknowledgement = 'in_progress';
      } else {
        let acked = false;
        try {
          acked = (await deps.publisher.acknowledgeSubscription(evidence.productId, input.purchaseToken)).ok;
        } catch {
          acked = false;
        }
        await deps.rpc.ackTransition(input.purchaseToken, acked ? 'succeeded' : 'failed');
        acknowledgement = acked ? 'server_acknowledged' : 'server_ack_failed';
      }
    } else {
      acknowledgement = 'already_acknowledged';
    }
  }

  log({
    outcome: applied.outcome,
    reason: applied.reason,
    google_state: evidence.subscriptionState,
    mapped_status: applied.mapped_status ?? null,
    acknowledgement,
    test_purchase: evidence.isTestPurchase,
  });

  const httpStatus = applied.outcome === 'rejected' ? 422 : applied.outcome === 'conflict' ? 409 : 200;
  return {
    httpStatus,
    body: {
      ok: applied.outcome === 'applied' || applied.outcome === 'recorded',
      outcome: applied.outcome,
      reason: applied.reason,
      status: applied.mapped_status ?? null,
      plan: applied.plan ?? null,
      has_access: applied.has_access === true,
      entitlement_applied: applied.entitlement_applied === true,
      acknowledgement,
    },
  };
}

// ---------------------------------------------------------------------------
// PostgREST RPC adapter (no SDK dependency)
// ---------------------------------------------------------------------------
export function createBillingRpc(opts: {
  supabaseUrl: string;
  anonKey: string;
  serviceRoleKey: string;
  fetchFn: FetchFn;
}): BillingRpc {
  const call = (fn: string, bearer: string, apikey: string, args: Record<string, unknown>) =>
    opts.fetchFn(`${opts.supabaseUrl.replace(/\/+$/, '')}/rest/v1/rpc/${fn}`, {
      method: 'POST',
      headers: {
        apikey,
        authorization: `Bearer ${bearer}`,
        'content-type': 'application/json',
        accept: 'application/json',
      },
      body: JSON.stringify(args),
      signal: AbortSignal.timeout(10_000),
    });
  const service = (fn: string, args: Record<string, unknown>) =>
    call(fn, opts.serviceRoleKey, opts.serviceRoleKey, args);

  return {
    async authorize(callerJwt, organizationId) {
      const res = await call('billing_google_play_authorize', callerJwt, opts.anonKey, {
        p_organization_id: organizationId,
      });
      if (!res.ok) {
        await res.body?.cancel();
        return null;
      }
      const uid = await res.json();
      return typeof uid === 'string' && uid.length > 0 ? uid : null;
    },
    async apply(p) {
      const e = p.evidence;
      const res = await service('billing_apply_google_play_verification', {
        p_organization_id: p.organizationId,
        p_purchase_token: p.purchaseToken,
        p_package_name: e.packageName,
        p_product_id: e.productId,
        p_base_plan_id: e.basePlanId,
        p_offer_id: e.offerId,
        p_subscription_state: e.subscriptionState,
        p_acknowledgement_state: e.acknowledgementState,
        p_expiry_time: e.expiryTime ? e.expiryTime.toISOString() : null,
        p_linked_purchase_token: e.linkedPurchaseToken,
        p_latest_order_id: e.latestOrderId,
        p_obfuscated_account_id: e.obfuscatedAccountId,
        p_is_test_purchase: e.isTestPurchase,
        p_actor_id: p.actorId,
        p_source: p.source,
      });
      if (!res.ok) {
        await res.body?.cancel();
        throw new Error(`billing_apply_failed:${res.status}`);
      }
      return (await res.json()) as ApplyResult;
    },
    async ackTransition(purchaseToken, event) {
      const res = await service('billing_google_play_ack_transition', {
        p_purchase_token: purchaseToken,
        p_event: event,
      });
      if (!res.ok) {
        await res.body?.cancel();
        return false;
      }
      return (await res.json()) === true;
    },
  };
}

// ---------------------------------------------------------------------------
// HTTP handler for the client-facing verify endpoint
// ---------------------------------------------------------------------------
const MAX_BODY_BYTES = 16 * 1024;

export interface HandlerConfig {
  rpc: BillingRpc;
  /** null when the Play credential is not configured: fail closed with 503. */
  publisher: PlayPublisherClient | null;
  packageName: string;
  allowTestPurchases: boolean;
  now?: () => Date;
  logger?: Logger;
}

const jsonResponse = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
  });

export const consoleLogger: Logger = {
  info: (e) => console.log(JSON.stringify(e)),
  error: (e) => console.error(JSON.stringify(e)),
};

export function createVerifyHandler(cfg: HandlerConfig): (req: Request) => Promise<Response> {
  const logger = cfg.logger ?? consoleLogger;
  const now = cfg.now ?? (() => new Date());
  return async (req) => {
    if (req.method !== 'POST') return jsonResponse(405, { ok: false, reason: 'METHOD_NOT_ALLOWED' });
    const authz = req.headers.get('authorization') ?? '';
    const jwt = authz.startsWith('Bearer ') ? authz.slice(7).trim() : '';
    if (!jwt) return jsonResponse(401, { ok: false, reason: 'UNAUTHENTICATED' });

    const text = await req.text();
    if (new TextEncoder().encode(text).length > MAX_BODY_BYTES) {
      return jsonResponse(413, { ok: false, reason: 'PAYLOAD_TOO_LARGE' });
    }
    let body: unknown;
    try {
      body = JSON.parse(text);
    } catch {
      return jsonResponse(400, { ok: false, reason: 'INVALID_REQUEST' });
    }
    const parsed = parseVerifyRequest(body);
    if (!parsed.ok) return jsonResponse(400, { ok: false, reason: parsed.reason });
    const input = parsed.value;

    try {
      const actorId = await cfg.rpc.authorize(jwt, input.organizationId);
      if (!actorId) return jsonResponse(403, { ok: false, reason: 'FORBIDDEN' });
      if (!cfg.publisher) {
        logger.error({ event: 'google_play_verify', reason: 'BILLING_NOT_CONFIGURED' });
        return jsonResponse(503, { ok: false, reason: 'BILLING_NOT_CONFIGURED' });
      }
      const outcome = await syncPurchase(
        {
          rpc: cfg.rpc,
          publisher: cfg.publisher,
          packageName: cfg.packageName,
          allowTestPurchases: cfg.allowTestPurchases,
          now,
          logger,
        },
        {
          organizationId: input.organizationId,
          purchaseToken: input.purchaseToken,
          actorId,
          source: 'client_verify',
          productIdHint: input.productIdHint,
          basePlanIdHint: input.basePlanIdHint,
        },
      );
      return jsonResponse(outcome.httpStatus, outcome.body);
    } catch (err) {
      // Error messages here never include tokens or credentials.
      logger.error({
        event: 'google_play_verify',
        reason: 'INTERNAL_ERROR',
        error: err instanceof Error ? err.message.slice(0, 120) : 'unknown',
      });
      return jsonResponse(500, { ok: false, reason: 'INTERNAL_ERROR' });
    }
  };
}
