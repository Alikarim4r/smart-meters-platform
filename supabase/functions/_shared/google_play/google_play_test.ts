// deno-lint-ignore-file require-await -- async mocks mirror the async interfaces.
// Deterministic tests for the Google Play verifier. No network, no live Play
// credentials. Runs with `node --test` (Node >= 23 strips TS types) or `deno test`.
import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  interpretSubscriptionV2,
  mapGoogleState,
  parseVerifyRequest,
  tokenSha256,
} from './play_subscription.ts';
import {
  buildServiceAccountAssertion,
  createAccessTokenProvider,
  createPlayPublisherClient,
  parseServiceAccount,
  type PlayPublisherClient,
} from './google_play_api.ts';
import {
  createBillingRpc,
  createVerifyHandler,
  type ApplyParams,
  type ApplyResult,
  type BillingRpc,
  type Logger,
} from './verify_purchase.ts';

const NOW = new Date('2030-01-01T00:00:00Z');
const FUTURE = '2030-02-01T00:00:00Z';
const PAST = '2029-12-01T00:00:00Z';
const ORG = '11111111-2222-4333-8444-555555555555';
const TOKEN = 'opaque-token.AO-J1Oz_abcdefghijklmnopqrstuvwxyz0123456789';
const PKG = 'com.smartmeters.admin_app';

function subscription(overrides: Record<string, unknown> = {}, item: Record<string, unknown> = {}) {
  return {
    kind: 'androidpublisher#subscriptionPurchaseV2',
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
    externalAccountIdentifiers: { obfuscatedExternalAccountId: 'binding-abc' },
    lineItems: [
      {
        productId: 'smartmeters_professional',
        expiryTime: FUTURE,
        latestSuccessfulOrderId: 'GPA.1234-5678-9012-34567',
        offerDetails: { basePlanId: 'professional-monthly', offerId: 'intro' },
        autoRenewingPlan: { autoRenewEnabled: true },
        ...item,
      },
    ],
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// mapGoogleState (mirrors SQL billing_google_play_map_state; same matrix as G90/G91)
// ---------------------------------------------------------------------------
test('state mapping matrix with future expiry matches the SQL mapping', () => {
  const expiry = new Date(FUTURE);
  const rows: Array<[string, string, boolean, boolean]> = [
    ['SUBSCRIPTION_STATE_ACTIVE', 'active', false, true],
    ['SUBSCRIPTION_STATE_IN_GRACE_PERIOD', 'grace_period', false, true],
    ['SUBSCRIPTION_STATE_CANCELED', 'active', true, true],
    ['SUBSCRIPTION_STATE_EXPIRED', 'expired', false, false],
    ['SUBSCRIPTION_STATE_ON_HOLD', 'past_due', false, false],
    ['SUBSCRIPTION_STATE_PAUSED', 'past_due', false, false],
    ['SUBSCRIPTION_STATE_PENDING', 'past_due', false, false],
    ['SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED', 'expired', false, false],
    ['SUBSCRIPTION_STATE_UNSPECIFIED', 'expired', false, false],
    ['SOMETHING_NEW', 'expired', false, false],
  ];
  for (const [state, status, cancel, entitling] of rows) {
    assert.deepEqual(mapGoogleState(state, expiry, NOW), { status, cancelAtPeriodEnd: cancel, entitling }, state);
  }
});

test('expired, missing or equal-to-now expiry never entitles', () => {
  for (const expiry of [new Date(PAST), null, NOW]) {
    for (const s of ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', 'SUBSCRIPTION_STATE_CANCELED']) {
      assert.equal(mapGoogleState(s, expiry, NOW).entitling, false, `${s} @ ${expiry}`);
    }
  }
  assert.equal(mapGoogleState('SUBSCRIPTION_STATE_IN_GRACE_PERIOD', new Date(PAST), NOW).status, 'past_due');
  assert.equal(mapGoogleState(undefined, new Date(FUTURE), NOW).status, 'expired');
});

// ---------------------------------------------------------------------------
// parseVerifyRequest
// ---------------------------------------------------------------------------
test('verify request validation is strict', () => {
  assert.equal(parseVerifyRequest({ organization_id: ORG, purchase_token: TOKEN }).ok, true);
  const bad: Array<[unknown, string]> = [
    [null, 'INVALID_REQUEST'],
    [[], 'INVALID_REQUEST'],
    [{ organization_id: 'not-a-uuid', purchase_token: TOKEN }, 'INVALID_ORGANIZATION_ID'],
    [{ organization_id: ORG }, 'INVALID_PURCHASE_TOKEN'],
    [{ organization_id: ORG, purchase_token: 'short' }, 'INVALID_PURCHASE_TOKEN'],
    [{ organization_id: ORG, purchase_token: `${TOKEN}/../x` }, 'INVALID_PURCHASE_TOKEN'],
    [{ organization_id: ORG, purchase_token: 'a'.repeat(4097) }, 'INVALID_PURCHASE_TOKEN'],
    [{ organization_id: ORG, purchase_token: TOKEN, product_id: 'Bad Id' }, 'INVALID_PRODUCT_HINT'],
    [{ organization_id: ORG, purchase_token: TOKEN, base_plan_id: 'x_y' }, 'INVALID_BASE_PLAN_HINT'],
  ];
  for (const [body, reason] of bad) {
    const r = parseVerifyRequest(body);
    assert.equal(r.ok, false);
    if (!r.ok) assert.equal(r.reason, reason);
  }
});

test('client-supplied plan/limits/features are ignored by the request parser', () => {
  const r = parseVerifyRequest({
    organization_id: ORG,
    purchase_token: TOKEN,
    plan: 'enterprise',
    max_users: 1_000_000,
    features: { automation: true },
    status: 'active',
  });
  assert.equal(r.ok, true);
  if (r.ok) assert.deepEqual(Object.keys(r.value).sort(), ['basePlanIdHint', 'organizationId', 'productIdHint', 'purchaseToken']);
});

// ---------------------------------------------------------------------------
// interpretSubscriptionV2
// ---------------------------------------------------------------------------
const OPTS = { packageName: PKG, allowTestPurchases: false };

test('interprets a single-line ACTIVE subscription', () => {
  const r = interpretSubscriptionV2(subscription({ linkedPurchaseToken: 'old-token-0123456789' }), OPTS);
  assert.equal(r.ok, true);
  if (!r.ok) return;
  assert.deepEqual(
    { ...r.value, expiryTime: r.value.expiryTime?.toISOString() },
    {
      packageName: PKG,
      productId: 'smartmeters_professional',
      basePlanId: 'professional-monthly',
      offerId: 'intro',
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
      expiryTime: '2030-02-01T00:00:00.000Z',
      linkedPurchaseToken: 'old-token-0123456789',
      latestOrderId: 'GPA.1234-5678-9012-34567',
      obfuscatedAccountId: 'binding-abc',
      isTestPurchase: false,
    },
  );
});

test('ambiguous or malformed provider responses are rejected', () => {
  const cases: Array<[unknown, string]> = [
    [null, 'MALFORMED_PROVIDER_RESPONSE'],
    [subscription({ subscriptionState: undefined }), 'MALFORMED_PROVIDER_RESPONSE'],
    [subscription({ lineItems: [] }), 'MALFORMED_PROVIDER_RESPONSE'],
    [subscription({}, { productId: undefined }), 'MALFORMED_PROVIDER_RESPONSE'],
    [subscription({}, { offerDetails: {} }), 'MALFORMED_PROVIDER_RESPONSE'],
    [subscription({}, { expiryTime: 'yesterday' }), 'MALFORMED_PROVIDER_RESPONSE'],
    [
      subscription({ lineItems: [subscription().lineItems[0], subscription().lineItems[0]] }),
      'MULTI_LINE_ITEM_UNSUPPORTED',
    ],
  ];
  for (const [raw, reason] of cases) {
    const r = interpretSubscriptionV2(raw, OPTS);
    assert.equal(r.ok, false);
    if (!r.ok) assert.equal(r.reason, reason);
  }
});

test('product/base plan hints must match the verified purchase', () => {
  const p = interpretSubscriptionV2(subscription(), { ...OPTS, productIdHint: 'smartmeters_business' });
  assert.equal(!p.ok && p.reason, 'PRODUCT_HINT_MISMATCH');
  const b = interpretSubscriptionV2(subscription(), { ...OPTS, basePlanIdHint: 'professional-annual' });
  assert.equal(!b.ok && b.reason, 'BASE_PLAN_HINT_MISMATCH');
});

test('test purchases are rejected unless explicitly allowed', () => {
  const raw = subscription({ testPurchase: {} });
  const denied = interpretSubscriptionV2(raw, OPTS);
  assert.equal(!denied.ok && denied.reason, 'TEST_PURCHASE_NOT_ALLOWED');
  const allowed = interpretSubscriptionV2(raw, { ...OPTS, allowTestPurchases: true });
  assert.equal(allowed.ok && allowed.value.isTestPurchase, true);
});

test('missing account binding is surfaced as null for the DB to reject', () => {
  const r = interpretSubscriptionV2(subscription({ externalAccountIdentifiers: undefined }), OPTS);
  assert.equal(r.ok && r.value.obfuscatedAccountId, null);
});

// ---------------------------------------------------------------------------
// Google OAuth / publisher client
// ---------------------------------------------------------------------------
async function testServiceAccount() {
  const kp = (await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  )) as CryptoKeyPair;
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', kp.privateKey));
  let bin = '';
  for (const b of der) bin += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(bin).replace(/(.{64})/g, '$1\n')}\n-----END PRIVATE KEY-----\n`;
  return {
    kp,
    json: JSON.stringify({
      client_email: 'verifier@example.iam.gserviceaccount.com',
      private_key: pem,
      token_uri: 'https://oauth2.googleapis.com/token',
    }),
  };
}

test('service account config fails closed and pins the token endpoint', async () => {
  for (const bad of [undefined, '', 'not json', '{}', JSON.stringify({ client_email: 'x', private_key: 'nope' })]) {
    assert.equal(parseServiceAccount(bad).ok, false);
  }
  const { json } = await testServiceAccount();
  assert.equal(parseServiceAccount(json).ok, true);
  const evil = JSON.parse(json);
  evil.token_uri = 'https://attacker.example/token';
  assert.equal(parseServiceAccount(JSON.stringify(evil)).ok, false);
});

test('JWT assertion is RS256-signed with the androidpublisher scope', async () => {
  const { kp, json } = await testServiceAccount();
  const sa = parseServiceAccount(json);
  assert.ok(sa.ok);
  if (!sa.ok) return;
  const jwt = await buildServiceAccountAssertion(sa.value, 1_900_000_000);
  const [h, c, s] = jwt.split('.');
  const dec = (x: string) => JSON.parse(atob(x.replace(/-/g, '+').replace(/_/g, '/')));
  assert.deepEqual(dec(h), { alg: 'RS256', typ: 'JWT' });
  assert.deepEqual(dec(c), {
    iss: 'verifier@example.iam.gserviceaccount.com',
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: 1_900_000_000,
    exp: 1_900_003_600,
  });
  const sig = Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (ch) => ch.charCodeAt(0));
  assert.equal(
    await crypto.subtle.verify('RSASSA-PKCS1-v1_5', kp.publicKey, sig, new TextEncoder().encode(`${h}.${c}`)),
    true,
  );
});

test('access token is cached and the publisher uses subscriptionsv2 + acknowledge endpoints', async () => {
  const { json } = await testServiceAccount();
  const sa = parseServiceAccount(json);
  if (!sa.ok) throw new Error('fixture');
  const calls: Array<{ url: string; method: string; auth: string | null }> = [];
  const fetchFn = async (url: string, init?: RequestInit) => {
    const headers = new Headers(init?.headers);
    calls.push({ url, method: init?.method ?? 'GET', auth: headers.get('authorization') });
    if (url.startsWith('https://oauth2.googleapis.com/token')) {
      return Response.json({ access_token: 'ya29.test', expires_in: 3600 });
    }
    if (url.includes('/subscriptionsv2/tokens/')) {
      return url.includes('unknown') ? new Response('{}', { status: 404 }) : Response.json(subscription());
    }
    return new Response('', { status: 200 });
  };
  const client = createPlayPublisherClient({
    packageName: PKG,
    fetchFn,
    getAccessToken: createAccessTokenProvider(sa.value, fetchFn, () => NOW.getTime()),
  });
  assert.equal((await client.getSubscriptionV2(TOKEN)).kind, 'ok');
  assert.equal((await client.getSubscriptionV2('unknown-token-123456')).kind, 'not_found');
  assert.equal((await client.acknowledgeSubscription('smartmeters_professional', TOKEN)).ok, true);
  assert.equal(calls.filter((c) => c.url.includes('oauth2')).length, 1, 'token cached');
  assert.equal(
    calls[1].url,
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}/purchases/subscriptionsv2/tokens/${TOKEN}`,
  );
  assert.equal(
    calls[3].url,
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}/purchases/subscriptions/smartmeters_professional/tokens/${TOKEN}:acknowledge`,
  );
  assert.equal(calls[3].method, 'POST');
  assert.equal(calls[1].auth, 'Bearer ya29.test');
});

// ---------------------------------------------------------------------------
// Handler / orchestration with mocked RPC + publisher
// ---------------------------------------------------------------------------
interface Harness {
  rpc: BillingRpc & { applied: ApplyParams[]; ackEvents: string[] };
  publisher: PlayPublisherClient & { acks: number; gets: string[] };
  logs: string[];
  handler: (req: Request) => Promise<Response>;
}

function harness(opts: {
  authorizedUid?: string | null;
  google?: Record<string, unknown> | 'not_found' | 'error';
  applyResult?: Partial<ApplyResult>;
  claim?: boolean;
  ackOk?: boolean;
  configured?: boolean;
} = {}): Harness {
  const logs: string[] = [];
  const logger: Logger = { info: (e) => logs.push(JSON.stringify(e)), error: (e) => logs.push(JSON.stringify(e)) };
  const rpc = {
    applied: [] as ApplyParams[],
    ackEvents: [] as string[],
    async authorize(jwt: string, org: string) {
      assert.equal(jwt, 'user.jwt.value');
      assert.equal(org, ORG);
      return opts.authorizedUid === undefined ? 'actor-uid' : opts.authorizedUid;
    },
    async apply(p: ApplyParams): Promise<ApplyResult> {
      rpc.applied.push(p);
      return {
        outcome: 'applied',
        reason: null,
        mapped_status: 'active',
        plan: 'professional',
        entitlement_applied: true,
        has_access: true,
        acknowledgement_required: true,
        ...opts.applyResult,
      };
    },
    async ackTransition(_t: string, event: 'claim' | 'succeeded' | 'failed') {
      rpc.ackEvents.push(event);
      return event === 'claim' ? opts.claim ?? true : true;
    },
  };
  const publisher = {
    acks: 0,
    gets: [] as string[],
    async getSubscriptionV2(token: string) {
      publisher.gets.push(token);
      const g = opts.google ?? subscription();
      if (g === 'not_found') return { kind: 'not_found' as const };
      if (g === 'error') return { kind: 'error' as const, status: 503 };
      return { kind: 'ok' as const, body: token === TOKEN ? g : subscription() };
    },
    async acknowledgeSubscription() {
      publisher.acks++;
      return { ok: opts.ackOk ?? true, status: opts.ackOk === false ? 500 : 200 };
    },
  };
  const handler = createVerifyHandler({
    rpc,
    publisher: opts.configured === false ? null : publisher,
    packageName: PKG,
    allowTestPurchases: false,
    now: () => NOW,
    logger,
  });
  return { rpc, publisher, logs, handler };
}

const post = (body: unknown, auth = 'Bearer user.jwt.value') =>
  new Request('https://edge.local/google-play-verify', {
    method: 'POST',
    headers: { authorization: auth, 'content-type': 'application/json' },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
const BODY = {
  organization_id: ORG,
  purchase_token: TOKEN,
  product_id: 'smartmeters_professional',
  base_plan_id: 'professional-monthly',
};

test('happy path: verify, apply via service RPC, server acknowledges exactly once', async () => {
  const h = harness();
  const res = await h.handler(post(BODY));
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), {
    ok: true,
    outcome: 'applied',
    reason: null,
    status: 'active',
    plan: 'professional',
    has_access: true,
    entitlement_applied: true,
    acknowledgement: 'server_acknowledged',
  });
  assert.equal(h.rpc.applied.length, 1);
  assert.equal(h.rpc.applied[0].actorId, 'actor-uid');
  assert.equal(h.rpc.applied[0].source, 'client_verify');
  assert.equal(h.rpc.applied[0].evidence.packageName, PKG);
  assert.deepEqual(h.rpc.ackEvents, ['claim', 'succeeded']);
  assert.equal(h.publisher.acks, 1);
});

test('tokens and JWTs never appear in responses or logs', async () => {
  const scenarios = [
    {},
    { google: 'not_found' as const },
    { applyResult: { outcome: 'rejected' as const, reason: 'PRODUCT_NOT_CONFIGURED', entitlement_applied: false } },
  ];
  for (const opts of scenarios) {
    const h = harness(opts);
    const text = await (await h.handler(post(BODY))).text();
    assert.ok(!text.includes(TOKEN), 'response leaks token');
    assert.ok(h.logs.length > 0);
    for (const line of h.logs) {
      assert.ok(!line.includes(TOKEN), 'log leaks token');
      assert.ok(!line.includes('user.jwt.value'), 'log leaks JWT');
    }
  }
});

test('token hash prefix is logged for correlation', async () => {
  const h = harness();
  await h.handler(post(BODY));
  const prefix = (await tokenSha256(TOKEN)).slice(0, 16);
  assert.ok(h.logs.some((l) => JSON.parse(l).token_sha256_prefix === prefix));
});

test('unauthenticated, non-POST, oversized and malformed requests are rejected before any I/O', async () => {
  const h = harness();
  assert.equal((await h.handler(post(BODY, ''))).status, 401);
  assert.equal((await h.handler(new Request('https://edge.local/x', { method: 'GET' }))).status, 405);
  assert.equal((await h.handler(post('x'.repeat(17 * 1024)))).status, 413);
  assert.equal((await h.handler(post('{not json'))).status, 400);
  assert.equal((await h.handler(post({ organization_id: 'x', purchase_token: TOKEN }))).status, 400);
  assert.equal(h.publisher.gets.length, 0);
  assert.equal(h.rpc.applied.length, 0);
});

test('caller who cannot manage the org gets 403 and no Google/DB writes', async () => {
  const h = harness({ authorizedUid: null });
  assert.equal((await h.handler(post(BODY))).status, 403);
  assert.equal(h.publisher.gets.length, 0);
  assert.equal(h.rpc.applied.length, 0);
});

test('missing Play credential fails closed with 503 (after authorization)', async () => {
  const h = harness({ configured: false });
  const res = await h.handler(post(BODY));
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), { ok: false, reason: 'BILLING_NOT_CONFIGURED' });
  assert.equal(h.rpc.applied.length, 0);
});

test('unknown token (wrong package / forged) is rejected without DB writes', async () => {
  const h = harness({ google: 'not_found' });
  const res = await h.handler(post(BODY));
  assert.equal(res.status, 422);
  assert.equal((await res.json()).reason, 'PURCHASE_NOT_FOUND');
  assert.equal(h.rpc.applied.length, 0);
});

test('provider outage returns 502 and changes nothing', async () => {
  const h = harness({ google: 'error' });
  assert.equal((await h.handler(post(BODY))).status, 502);
  assert.equal(h.rpc.applied.length, 0);
});

test('hint mismatch / test purchase are rejected before apply', async () => {
  const h1 = harness();
  const r1 = await h1.handler(post({ ...BODY, base_plan_id: 'professional-annual' }));
  assert.equal(r1.status, 422);
  assert.equal((await r1.json()).reason, 'BASE_PLAN_HINT_MISMATCH');
  const h2 = harness({ google: subscription({ testPurchase: {} }) });
  assert.equal((await (await h2.handler(post(BODY))).json()).reason, 'TEST_PURCHASE_NOT_ALLOWED');
  assert.equal(h1.rpc.applied.length + h2.rpc.applied.length, 0);
});

test('DB rejection/conflict is surfaced and never acknowledged', async () => {
  const rejected = harness({
    applyResult: { outcome: 'rejected', reason: 'ACCOUNT_BINDING_MISMATCH', entitlement_applied: false, acknowledgement_required: false },
  });
  const r1 = await rejected.handler(post(BODY));
  assert.equal(r1.status, 422);
  assert.equal((await r1.json()).acknowledgement, 'not_required');
  const conflict = harness({
    applyResult: { outcome: 'conflict', reason: 'ACTIVE_GOOGLE_PLAY_SUBSCRIPTION', entitlement_applied: false, acknowledgement_required: false },
  });
  assert.equal((await conflict.handler(post(BODY))).status, 409);
  assert.equal(rejected.publisher.acks + conflict.publisher.acks, 0);
  assert.equal(rejected.rpc.ackEvents.length + conflict.rpc.ackEvents.length, 0);
});

test('lost ack claim (concurrent verify) does not acknowledge again', async () => {
  const h = harness({ claim: false });
  assert.equal((await (await h.handler(post(BODY))).json()).acknowledgement, 'in_progress');
  assert.equal(h.publisher.acks, 0);
});

test('already acknowledged purchase is not re-acknowledged', async () => {
  const h = harness({
    google: subscription({ acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' }),
    applyResult: { acknowledgement_required: false },
  });
  assert.equal((await (await h.handler(post(BODY))).json()).acknowledgement, 'already_acknowledged');
  assert.equal(h.publisher.acks, 0);
  assert.deepEqual(h.rpc.ackEvents, []);
});

test('failed server ack releases the claim and tells the client', async () => {
  const h = harness({ ackOk: false });
  assert.equal((await (await h.handler(post(BODY))).json()).acknowledgement, 'server_ack_failed');
  assert.deepEqual(h.rpc.ackEvents, ['claim', 'failed']);
});

test('non-entitling Google state is never acknowledged even if the DB asked', async () => {
  const h = harness({
    google: subscription({ subscriptionState: 'SUBSCRIPTION_STATE_PENDING' }),
    applyResult: { mapped_status: 'past_due', has_access: false, acknowledgement_required: true },
  });
  assert.equal((await (await h.handler(post(BODY))).json()).acknowledgement, 'not_required');
  assert.equal(h.publisher.acks, 0);
});

test('PENDING_PURCHASE_CANCELED resyncs the linked token server-side (one level)', async () => {
  const h = harness({
    google: subscription({
      subscriptionState: 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED',
      linkedPurchaseToken: 'linked-old-token-0123456789',
    }),
    applyResult: { outcome: 'recorded', reason: 'NOT_ENTITLING', mapped_status: 'expired', entitlement_applied: false, acknowledgement_required: false },
  });
  assert.equal((await h.handler(post(BODY))).status, 200);
  assert.deepEqual(h.publisher.gets, [TOKEN, 'linked-old-token-0123456789']);
  assert.deepEqual(h.rpc.applied.map((a) => a.source), ['client_verify', 'server_resync']);
});

test('internal errors return 500 without details', async () => {
  const h = harness();
  h.rpc.apply = async () => {
    throw new Error('billing_apply_failed:500');
  };
  const res = await h.handler(post(BODY));
  assert.equal(res.status, 500);
  assert.deepEqual(await res.json(), { ok: false, reason: 'INTERNAL_ERROR' });
});

test('PostgREST adapter: caller JWT for authorize, service key for apply/ack', async () => {
  const seen: Array<{ url: string; apikey: string | null; auth: string | null; body: Record<string, unknown> }> = [];
  const fetchFn = async (url: string, init?: RequestInit) => {
    const h = new Headers(init?.headers);
    seen.push({ url, apikey: h.get('apikey'), auth: h.get('authorization'), body: JSON.parse(String(init?.body)) });
    if (url.endsWith('billing_google_play_authorize')) return Response.json('actor-uid');
    if (url.endsWith('billing_google_play_ack_transition')) return Response.json(true);
    return Response.json({ outcome: 'applied', reason: null, entitlement_applied: true, acknowledgement_required: false });
  };
  const rpc = createBillingRpc({
    supabaseUrl: 'http://127.0.0.1:54321/',
    anonKey: 'anon-key',
    serviceRoleKey: 'service-key',
    fetchFn,
  });
  assert.equal(await rpc.authorize('user.jwt.value', ORG), 'actor-uid');
  const ev = interpretSubscriptionV2(subscription(), OPTS);
  if (!ev.ok) throw new Error('fixture');
  await rpc.apply({ organizationId: ORG, purchaseToken: TOKEN, evidence: ev.value, actorId: 'actor-uid', source: 'client_verify' });
  assert.equal(await rpc.ackTransition(TOKEN, 'claim'), true);
  assert.equal(seen[0].url, 'http://127.0.0.1:54321/rest/v1/rpc/billing_google_play_authorize');
  assert.deepEqual([seen[0].apikey, seen[0].auth], ['anon-key', 'Bearer user.jwt.value']);
  assert.deepEqual([seen[1].apikey, seen[1].auth], ['service-key', 'Bearer service-key']);
  assert.equal(seen[1].body.p_expiry_time, '2030-02-01T00:00:00.000Z');
  assert.equal(seen[1].body.p_package_name, PKG);
  assert.deepEqual(
    Object.keys(seen[1].body).filter((k) => /^p_(plan|max_|features|status)/.test(k)),
    [],
    'no client plan/limits/status sent',
  );
  const denied = createBillingRpc({
    supabaseUrl: 'http://x',
    anonKey: 'a',
    serviceRoleKey: 's',
    fetchFn: async () => new Response('{}', { status: 400 }),
  });
  assert.equal(await denied.authorize('jwt', ORG), null);
});
