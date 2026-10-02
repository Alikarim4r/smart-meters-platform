// Supabase Edge Function: verify/sync a Google Play subscription purchase for
// an organization. See docs/regression/GOOGLE_PLAY_BILLING_V1.md.
//
// Secrets (set with `supabase secrets set`, never committed):
//   GOOGLE_PLAY_SERVICE_ACCOUNT_JSON  service-account key JSON (Android Publisher access)
// Optional configuration:
//   GOOGLE_PLAY_PACKAGE_NAME          default com.smartmeters.admin_app
//   GOOGLE_PLAY_ALLOW_TEST_PURCHASES  'true' only on non-production projects
// Provided by the platform: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.
//
// Missing credential => every request fails closed with 503 BILLING_NOT_CONFIGURED.

import {
  createAccessTokenProvider,
  createPlayPublisherClient,
  parseServiceAccount,
} from '../_shared/google_play/google_play_api.ts';
import { createBillingRpc, createVerifyHandler } from '../_shared/google_play/verify_purchase.ts';

const env = (name: string) => Deno.env.get(name) ?? '';

const packageName = env('GOOGLE_PLAY_PACKAGE_NAME') || 'com.smartmeters.admin_app';
const serviceAccount = parseServiceAccount(Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));

const publisher = serviceAccount.ok
  ? createPlayPublisherClient({
      packageName,
      fetchFn: fetch,
      getAccessToken: createAccessTokenProvider(serviceAccount.value, fetch),
    })
  : null;

const handler = createVerifyHandler({
  rpc: createBillingRpc({
    supabaseUrl: env('SUPABASE_URL'),
    anonKey: env('SUPABASE_ANON_KEY'),
    serviceRoleKey: env('SUPABASE_SERVICE_ROLE_KEY'),
    fetchFn: fetch,
  }),
  publisher,
  packageName,
  allowTestPurchases: env('GOOGLE_PLAY_ALLOW_TEST_PURCHASES') === 'true',
});

Deno.serve(handler);
