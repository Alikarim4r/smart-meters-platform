// Pure interpretation of Google Play subscriptionsv2 responses and client
// verification requests. No I/O. Runs under Deno (Edge) and Node (tests).
//
// The database (billing_apply_google_play_verification) is the entitlement
// authority; mapGoogleState mirrors billing_google_play_map_state so the Edge
// Function can fail fast and never acknowledge a non-entitling purchase.

export type SubscriptionStatus =
  | 'trialing'
  | 'active'
  | 'past_due'
  | 'grace_period'
  | 'canceled'
  | 'expired';

export interface MappedState {
  status: SubscriptionStatus;
  cancelAtPeriodEnd: boolean;
  entitling: boolean;
}

/** Fail-closed Google subscriptionState -> server status (mirror of SQL). */
export function mapGoogleState(
  state: string | null | undefined,
  expiry: Date | null,
  now: Date,
): MappedState {
  const future = expiry !== null && expiry.getTime() > now.getTime();
  switch (state) {
    case 'SUBSCRIPTION_STATE_ACTIVE':
      return future
        ? { status: 'active', cancelAtPeriodEnd: false, entitling: true }
        : { status: 'expired', cancelAtPeriodEnd: false, entitling: false };
    case 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD':
      return future
        ? { status: 'grace_period', cancelAtPeriodEnd: false, entitling: true }
        : { status: 'past_due', cancelAtPeriodEnd: false, entitling: false };
    case 'SUBSCRIPTION_STATE_CANCELED':
      // Canceled but not yet expired keeps access until expiry.
      return future
        ? { status: 'active', cancelAtPeriodEnd: true, entitling: true }
        : { status: 'expired', cancelAtPeriodEnd: false, entitling: false };
    case 'SUBSCRIPTION_STATE_ON_HOLD':
    case 'SUBSCRIPTION_STATE_PAUSED':
    case 'SUBSCRIPTION_STATE_PENDING':
      return { status: 'past_due', cancelAtPeriodEnd: false, entitling: false };
    default:
      // EXPIRED, PENDING_PURCHASE_CANCELED, UNSPECIFIED, missing or unknown.
      return { status: 'expired', cancelAtPeriodEnd: false, entitling: false };
  }
}

// ---------------------------------------------------------------------------
// Client request validation
// ---------------------------------------------------------------------------
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
// Play purchase tokens are URL-safe opaque strings.
const TOKEN_RE = /^[A-Za-z0-9._\-]{16,4096}$/;
const PRODUCT_RE = /^[a-z0-9][a-z0-9_.]{0,139}$/;
const BASE_PLAN_RE = /^[a-z0-9][a-z0-9-]{0,62}$/;

export interface VerifyRequest {
  organizationId: string;
  purchaseToken: string;
  productIdHint: string | null;
  basePlanIdHint: string | null;
}

export type Result<T> = { ok: true; value: T } | { ok: false; reason: string };

export function parseVerifyRequest(body: unknown): Result<VerifyRequest> {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    return { ok: false, reason: 'INVALID_REQUEST' };
  }
  const b = body as Record<string, unknown>;
  const org = b.organization_id;
  const token = b.purchase_token;
  const product = b.product_id ?? null;
  const basePlan = b.base_plan_id ?? null;
  if (typeof org !== 'string' || !UUID_RE.test(org)) {
    return { ok: false, reason: 'INVALID_ORGANIZATION_ID' };
  }
  if (typeof token !== 'string' || !TOKEN_RE.test(token)) {
    return { ok: false, reason: 'INVALID_PURCHASE_TOKEN' };
  }
  if (product !== null && (typeof product !== 'string' || !PRODUCT_RE.test(product))) {
    return { ok: false, reason: 'INVALID_PRODUCT_HINT' };
  }
  if (basePlan !== null && (typeof basePlan !== 'string' || !BASE_PLAN_RE.test(basePlan))) {
    return { ok: false, reason: 'INVALID_BASE_PLAN_HINT' };
  }
  return {
    ok: true,
    value: {
      organizationId: org.toLowerCase(),
      purchaseToken: token,
      productIdHint: product as string | null,
      basePlanIdHint: basePlan as string | null,
    },
  };
}

// ---------------------------------------------------------------------------
// subscriptionsv2 response interpretation
// ---------------------------------------------------------------------------
export interface PurchaseEvidence {
  packageName: string;
  productId: string;
  basePlanId: string;
  offerId: string | null;
  subscriptionState: string;
  acknowledgementState: string | null;
  expiryTime: Date | null;
  linkedPurchaseToken: string | null;
  latestOrderId: string | null;
  obfuscatedAccountId: string | null;
  isTestPurchase: boolean;
}

export interface InterpretOptions {
  /** Package the token was verified against (server configuration). */
  packageName: string;
  productIdHint?: string | null;
  basePlanIdHint?: string | null;
  allowTestPurchases: boolean;
}

function str(v: unknown): string | null {
  return typeof v === 'string' && v.length > 0 ? v : null;
}

/**
 * Extracts verified evidence from a SubscriptionPurchaseV2 JSON body.
 * subscriptionsv2.get is scoped to the package in the request URL, so the
 * package is the server-configured one. Anything ambiguous is rejected.
 */
export function interpretSubscriptionV2(
  raw: unknown,
  opts: InterpretOptions,
): Result<PurchaseEvidence> {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    return { ok: false, reason: 'MALFORMED_PROVIDER_RESPONSE' };
  }
  const r = raw as Record<string, unknown>;
  const state = str(r.subscriptionState);
  if (state === null) return { ok: false, reason: 'MALFORMED_PROVIDER_RESPONSE' };

  const lineItems = Array.isArray(r.lineItems) ? r.lineItems : [];
  if (lineItems.length === 0) return { ok: false, reason: 'MALFORMED_PROVIDER_RESPONSE' };
  // v1 sells single-item subscriptions only; add-on bundles are not mapped.
  if (lineItems.length > 1) return { ok: false, reason: 'MULTI_LINE_ITEM_UNSUPPORTED' };

  const item = lineItems[0];
  if (item === null || typeof item !== 'object') {
    return { ok: false, reason: 'MALFORMED_PROVIDER_RESPONSE' };
  }
  const li = item as Record<string, unknown>;
  const productId = str(li.productId);
  const offer = (li.offerDetails ?? null) as Record<string, unknown> | null;
  const basePlanId = offer && typeof offer === 'object' ? str(offer.basePlanId) : null;
  if (productId === null || basePlanId === null) {
    return { ok: false, reason: 'MALFORMED_PROVIDER_RESPONSE' };
  }
  if (opts.productIdHint && opts.productIdHint !== productId) {
    return { ok: false, reason: 'PRODUCT_HINT_MISMATCH' };
  }
  if (opts.basePlanIdHint && opts.basePlanIdHint !== basePlanId) {
    return { ok: false, reason: 'BASE_PLAN_HINT_MISMATCH' };
  }

  let expiryTime: Date | null = null;
  const expiryRaw = str(li.expiryTime);
  if (expiryRaw !== null) {
    const d = new Date(expiryRaw);
    if (Number.isNaN(d.getTime())) return { ok: false, reason: 'MALFORMED_PROVIDER_RESPONSE' };
    expiryTime = d;
  }

  const isTestPurchase = r.testPurchase !== undefined && r.testPurchase !== null;
  if (isTestPurchase && !opts.allowTestPurchases) {
    return { ok: false, reason: 'TEST_PURCHASE_NOT_ALLOWED' };
  }

  const ext = (r.externalAccountIdentifiers ?? null) as Record<string, unknown> | null;
  return {
    ok: true,
    value: {
      packageName: opts.packageName,
      productId,
      basePlanId,
      offerId: offer ? str(offer.offerId) : null,
      subscriptionState: state,
      acknowledgementState: str(r.acknowledgementState),
      expiryTime,
      linkedPurchaseToken: str(r.linkedPurchaseToken),
      latestOrderId: str(li.latestSuccessfulOrderId) ?? str(r.latestOrderId),
      obfuscatedAccountId: ext && typeof ext === 'object' ? str(ext.obfuscatedExternalAccountId) : null,
      isTestPurchase,
    },
  };
}

/** sha256 hex of a token, for logs and correlation. Never log raw tokens. */
export async function tokenSha256(token: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}
