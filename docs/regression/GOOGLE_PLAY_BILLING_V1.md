# Google Play Billing v1 — Server-Verified Entitlements

- Date: 2026-10-02
- Branch: `feature/google-play-billing-v1`
- Base: `9379c96` (`feature/subscriptions-v1` Security Gate PASS)
- Android billing surface: Admin app only (`com.smartmeters.admin_app`)
- Entitlement authority: Supabase server-side state only
- **Local implementation verdict: PASS, operator configuration/deployment still required.**

## Architecture

Google Play is payment evidence, not entitlement authority. The Android Admin app can list configured products and start/restore a purchase, but `PurchaseStatus` never unlocks a feature. Purchased/restored tokens are sent to `google-play-verify`; the Edge Function verifies the token with Android Publisher, then a service-role-only database function maps the verified product/base plan to the server plan catalog and updates `organization_subscriptions`. The client re-reads the resulting server entitlement before showing access.

`entry_app` and `dashboard_app` contain no billing SDK or provider-specific code.

## Database changes

`20261002180000_subscription_max_users_enforcement.sql` closes the pre-billing `max_users` residual risk. A seat is a distinct user with active organization/zone/site scope or legacy site access. Duplicate grants for one user consume one seat. Quota decisions serialize on the organization subscription row, so concurrent grants cannot exceed the limit.

`20261002181000_google_play_billing_v1.sql` adds:

- `billing_google_play_products`: operator-owned mapping of Play package/product/base plan to Smart Meters plan and billing period. It is deliberately empty by default.
- `billing_google_play_purchases`: service-only verified purchase evidence and token state.
- `billing_events`: append-only audit without raw purchase tokens.
- scoped catalog/authorization RPCs for authenticated organization managers.
- service-role-only verification apply and acknowledgement state transitions.
- fail-closed Google subscription-state mapping.

No client can write subscription, product mapping, verified purchase, or billing audit state.

## Verification flow

1. Admin app receives a Play purchase/restore event.
2. It sends only organization id, purchase token and optional consistency hints to `google-play-verify`.
3. The Edge Function re-authorizes the caller against the organization.
4. It calls Android Publisher `subscriptionsv2.get` using a service-account credential held only in environment secrets.
5. Package/product/base plan/account binding/state/expiry are interpreted fail-closed.
6. The service-only DB apply function resolves plan, limits and features from server tables; client claims never decide entitlement.
7. Entitling purchases are acknowledged server-side through a single-flight claim. Client `completePurchase` is only a fallback after server application if server acknowledgement failed.
8. Admin app re-reads the server entitlement. Only that state controls access.

A canceled subscription with future expiry stays active until its period end with `cancel_at_period_end=true`. Expired/unknown/pending-hold states do not grant new access. A canceled pending replacement does not replace the old entitlement and can trigger a linked-token resync.

## Required secrets / environment

Never commit these values:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` — Google service-account JSON with Android Publisher access.
- `GOOGLE_PLAY_PACKAGE_NAME` — optional; defaults to `com.smartmeters.admin_app`.
- `GOOGLE_PLAY_ALLOW_TEST_PURCHASES` — set `true` only in a non-production testing environment.
- Supabase-provided `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.

If the Play credential is absent, verification fails closed with `BILLING_NOT_CONFIGURED`.

## Play Console prerequisites

Before live testing, the operator must:

1. Ensure the Google Play application package is `com.smartmeters.admin_app`.
2. Create the intended subscription products and monthly/annual base plans in Play Console.
3. Grant the verifier service account the required Android Publisher permissions.
4. Configure an Internal testing track and license-test accounts before production purchase testing.
5. Insert the exact live product/base-plan mappings into `billing_google_play_products` and set only intended rows `active=true`.

No fake product IDs are seeded by this implementation. An empty mapping intentionally produces no purchasable plans.

Example mapping template (replace every placeholder with the exact Play Console values):

```sql
insert into public.billing_google_play_products
  (package_name, product_id, base_plan_id, plan, billing_period, active, display_order)
values
  ('com.smartmeters.admin_app', '<PLAY_PRODUCT_ID>', '<PLAY_BASE_PLAN_ID>',
   'professional', 'monthly', true, 20);
```

Do not insert a row until the corresponding Play product/base plan actually exists.

## Admin app behavior

The Admin settings drawer contains **Subscription & billing**. The screen shows server plan/status, access, renewal/end/grace dates, user/site/meter usage, configured Play products, localized Play prices, monthly/annual offers, purchase state, and restore action.

Purchasing is disabled when the caller lacks organization billing authority, Google Play is unavailable, the server catalog is empty, or an active Google Play/external contract already owns the entitlement. Store-only status never changes the entitlement card.

## Security / threat model

Covered controls include forged client plan/limits/features, unauthorized organization billing, wrong package/token/product/base plan, account-binding mismatch, cross-organization token reuse, linked-token reuse, expired/non-entitling provider states, duplicate acknowledgement, raw-token log leakage, inactive/empty product configuration, and concurrent user-seat creation.

Raw purchase tokens remain in the service-only evidence table for resync; logs/audit use hashes instead. Provider reference fields remain hidden from normal API roles by the Subscription Security Gate.

## Local verification evidence

- Subscription Security Gate after billing migrations: **113/113**.
- Google Play Billing pgTAP suite: **120/120**.
- Edge verifier tests: **29/29 Node**, **29/29 Deno**; Deno type-check/lint clean.
- `max_users` race: **1 seat of max 1 with 12 concurrent workers**.
- Admin billing pure tests: **6/6**.
- Admin full Flutter tests: **34/34**.
- `smart_meters_core` Flutter tests: **433/433**.
- Admin analyzer: no billing-owned issue; 6 pre-existing repository warnings/info remain elsewhere.
- Core analyzer: 41 pre-existing warnings/info remain elsewhere; no billing/core source was changed in this phase.

## RTDN readiness

The shared `syncPurchase` path accepts `client_verify`, `server_resync`, and `rtdn` sources, so an RTDN worker can later resolve the purchase token and reuse the same verifier/apply path. Pub/Sub topic/subscription setup, Google Play RTDN registration, retry/dead-letter policy, and production event monitoring are not configured in this phase.

## Rollback

Before production use, rollback is operationally simple: deactivate all `billing_google_play_products` rows and disable/remove the Edge Function route. That prevents new purchases from being offered/verified while preserving audit/evidence and existing server entitlement data. Database migrations are additive and are not rewritten or deleted.

## Remaining operator actions

- Create/confirm real Play subscription products/base plans and pricing.
- Supply the Play service-account secret to the target Supabase environment.
- Insert exact product/base-plan mapping rows.
- Deploy the two new migrations and `google-play-verify` only after migration-history review on the target environment.
- Run an Internal-track end-to-end purchase/restore/cancel/grace/expiry test with license testers.
- Configure RTDN before production-scale billing.
- Resolve the GitHub Actions account billing lock and rerun CI before merging protected branches.
- PR #2 must be merged first; this branch is stacked on its Security Gate commit.

No Production, Staging, TAMARHUL, Google Play Console configuration, live credentials, or protected branch merge was performed during this implementation.
