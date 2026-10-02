// Google Play Developer API client (Android Publisher v3) with service-account
// OAuth. The credential is supplied by the caller from an environment secret;
// nothing here reads env or logs secrets/tokens. fetch/clock are injectable.

import type { Result } from './play_subscription.ts';

export type FetchFn = (input: string, init?: RequestInit) => Promise<Response>;

const GOOGLE_TOKEN_URI = 'https://oauth2.googleapis.com/token';
const PUBLISHER_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const TIMEOUT_MS = 10_000;

export interface ServiceAccount {
  clientEmail: string;
  privateKeyPem: string;
}

/** Parses the service-account JSON secret. The token endpoint is pinned. */
export function parseServiceAccount(json: string | undefined | null): Result<ServiceAccount> {
  if (!json) return { ok: false, reason: 'BILLING_NOT_CONFIGURED' };
  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch {
    return { ok: false, reason: 'BILLING_NOT_CONFIGURED' };
  }
  const p = parsed as Record<string, unknown>;
  if (
    typeof p?.client_email !== 'string' ||
    typeof p?.private_key !== 'string' ||
    !p.private_key.includes('BEGIN PRIVATE KEY') ||
    (p.token_uri !== undefined && p.token_uri !== GOOGLE_TOKEN_URI)
  ) {
    return { ok: false, reason: 'BILLING_NOT_CONFIGURED' };
  }
  return { ok: true, value: { clientEmail: p.client_email, privateKeyPem: p.private_key } };
}

function base64url(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const b64 = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replace(/\s+/g, '');
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** Builds an RS256-signed JWT bearer assertion (RFC 7523) for Google OAuth. */
export async function buildServiceAccountAssertion(sa: ServiceAccount, nowSeconds: number): Promise<string> {
  const enc = new TextEncoder();
  const header = base64url(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = base64url(
    enc.encode(
      JSON.stringify({
        iss: sa.clientEmail,
        scope: SCOPE,
        aud: GOOGLE_TOKEN_URI,
        iat: nowSeconds,
        exp: nowSeconds + 3600,
      }),
    ),
  );
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.privateKeyPem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signingInput = `${header}.${claims}`;
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(signingInput));
  return `${signingInput}.${base64url(new Uint8Array(sig))}`;
}

/** Returns a cached access-token getter (refreshed 60s before expiry). */
export function createAccessTokenProvider(
  sa: ServiceAccount,
  fetchFn: FetchFn,
  now: () => number = () => Date.now(),
): () => Promise<string> {
  let cached: { token: string; expiresAtMs: number } | null = null;
  return async () => {
    if (cached && cached.expiresAtMs - 60_000 > now()) return cached.token;
    const assertion = await buildServiceAccountAssertion(sa, Math.floor(now() / 1000));
    const res = await fetchFn(GOOGLE_TOKEN_URI, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }).toString(),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!res.ok) throw new Error(`google_oauth_failed:${res.status}`);
    const body = (await res.json()) as { access_token?: string; expires_in?: number };
    if (typeof body.access_token !== 'string') throw new Error('google_oauth_malformed');
    cached = { token: body.access_token, expiresAtMs: now() + (body.expires_in ?? 3600) * 1000 };
    return cached.token;
  };
}

export type GetSubscriptionResult =
  | { kind: 'ok'; body: unknown }
  | { kind: 'not_found' }
  | { kind: 'error'; status: number };

export interface PlayPublisherClient {
  getSubscriptionV2(purchaseToken: string): Promise<GetSubscriptionResult>;
  acknowledgeSubscription(productId: string, purchaseToken: string): Promise<{ ok: boolean; status: number }>;
}

export function createPlayPublisherClient(opts: {
  packageName: string;
  fetchFn: FetchFn;
  getAccessToken: () => Promise<string>;
}): PlayPublisherClient {
  const pkg = encodeURIComponent(opts.packageName);
  const auth = async () => ({ authorization: `Bearer ${await opts.getAccessToken()}` });
  return {
    // purchases.subscriptionsv2.get
    async getSubscriptionV2(purchaseToken) {
      const res = await opts.fetchFn(
        `${PUBLISHER_BASE}/${pkg}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
        { method: 'GET', headers: await auth(), signal: AbortSignal.timeout(TIMEOUT_MS) },
      );
      // 400/404/410: token unknown for this package (wrong app, forged or purged).
      if (res.status === 400 || res.status === 404 || res.status === 410) {
        await res.body?.cancel();
        return { kind: 'not_found' };
      }
      if (!res.ok) {
        await res.body?.cancel();
        return { kind: 'error', status: res.status };
      }
      return { kind: 'ok', body: await res.json() };
    },
    // purchases.subscriptions.acknowledge (the supported subscription ack endpoint).
    async acknowledgeSubscription(productId, purchaseToken) {
      const res = await opts.fetchFn(
        `${PUBLISHER_BASE}/${pkg}/purchases/subscriptions/${encodeURIComponent(productId)}` +
          `/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
        {
          method: 'POST',
          headers: { ...(await auth()), 'content-type': 'application/json' },
          body: '{}',
          signal: AbortSignal.timeout(TIMEOUT_MS),
        },
      );
      await res.body?.cancel();
      return { ok: res.ok, status: res.status };
    },
  };
}
