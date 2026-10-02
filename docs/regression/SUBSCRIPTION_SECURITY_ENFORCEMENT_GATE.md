# Subscription Security & Enforcement Gate — PR #2

- PR: #2 `feature/subscriptions-v1` — "Add server-authoritative subscription entitlements"
- Subject migration: `supabase/migrations/20261002170000_subscription_entitlements.sql`
- Gate fix migration: `supabase/migrations/20261002171000_subscription_security_gate_hardening.sql`
- Date: 2026-10-02
- **Final verdict: PASS**. The verdict only holds if the uncommitted gate changes listed under "Fixes made" ship with PR #2. Without the fix migration, PR #2 is **FAIL**.

## 1. Environment and safety boundaries

| Item | Value |
|---|---|
| Target | Disposable isolated Supabase stack `smgate-subsec-20261002`: API `127.0.0.1:55421`, DB `127.0.0.1:55422` |
| Schema state | Replayed through `20261002170000` (previous session, with replay-only shims for historical drift), then `20261002171000` applied by this gate |
| Not touched | Production, staging, the TAMARHUL local stack (`54322`), and the unrelated icon/branding working-tree changes |
| Disposable-only changes | `create extension pgtap` (schema `extensions`) on the disposable DB, to run the pgTAP suites |
| Data hygiene | pgTAP suites run in one transaction and roll back. The race and API scripts commit fixtures and delete them on exit; residue was verified as 0 rows after every run |
| Not done | No commit, no push, no merge, no Google Play Billing work |

The race and API scripts refuse any non-`127.0.0.1`/`localhost` target and the reserved local ports `54321`/`54322`.

## 2. How to reproduce

```bash
DB=postgresql://postgres:postgres@127.0.0.1:55422/postgres
# pgTAP adversarial suite (113 assertions)
PGOPTIONS='--search_path=public,extensions' psql "$DB" -X -At -f supabase/tests/subscription_security_gate_test.sql
# Concurrency/race (N parallel creators vs max_sites=1 / max_meters=1)
SUBSCRIPTION_GATE_DB_URL=$DB RACE_WORKERS=12 supabase/tests/subscription_quota_race_test.sh
# API path through Kong -> PostgREST with signed/forged JWTs
SUBSCRIPTION_GATE_DB_URL=$DB SUBSCRIPTION_GATE_API_URL=http://127.0.0.1:55421 \
SUBSCRIPTION_GATE_JWT_SECRET=<local stack JWT secret> supabase/tests/subscription_api_smoke_test.sh
# Existing suites (regression)
for t in production_security_hardening_test platform_owner_authority_test meter_rollover_consumption_test subscription_entitlements_test; do
  PGOPTIONS='--search_path=public,extensions' psql "$DB" -X -At -v ON_ERROR_STOP=1 -f supabase/tests/$t.sql; done
```

Stored evidence is in `docs/regression/evidence/`:

- `subscription_gate_prepatch.tap`: 25 of 113 failing, which is the exploit proof.
- `subscription_gate_postpatch.tap`: 113 of 113 passing.
- `subscription_quota_race_prepatch.txt`: 8 of 1 sites and 8 of 1 meters created.
- `subscription_quota_race_postpatch.txt`: 1 of 1 sites and 1 of 1 meters, across 3 runs of 12 workers.
- `subscription_api_smoke_postpatch.tap`: 15 of 15 passing.

## 3. Role model under test (actual schema)

| Gate role | Fixture representation |
|---|---|
| Viewer | `profiles.role=viewer`, scope `viewer` on site A1, legacy `user_site_access(can_read)` |
| Technician | `profiles.role=technician`, scope `reading_entry` on A1, legacy `user_site_access(technician, can_write)` |
| Site Admin (scope) | scope `site_admin` on site A1 |
| Site Admin (legacy) | `user_site_access(site_admin, can_manage_meters)` on A1 |
| Org Admin A / B | scope `org_admin` at organization A / B |

Fixture entitlements:

- Org A: `starter/active`, max_sites=2, max_meters=3.
- Org B: `professional/active`, max_sites=3, max_meters=2.

Real `subscription_status` enum values: `trialing, active, past_due, grace_period, canceled, expired`. No states were invented.

## 4. Attack matrix

"Pre" is the result on PR #2 as submitted; "Post" is the result after the gate fix. IDs are assertion labels in `subscription_security_gate_test.sql` (SQL) or numbered checks in `subscription_api_smoke_test.sh` (API).

### A. Role / scope

| # | Attack | Pre | Post | Evidence |
|---|---|---|---|---|
| A1–A6 | Viewer creates, updates or deletes sites/meters | blocked | PASS | SQL A1–A6; API 9 |
| A7, A18 | Viewer/Technician self-escalate `profiles.role` | blocked | PASS | SQL A7, A18 |
| A8, A9, A17 | Viewer/Technician grant self org_admin / site_admin / legacy site_admin | blocked | PASS | SQL A8, A9, A17 |
| A10, A16, A29 | Cross-org reads (sites/meters) | blocked | PASS | SQL A10, A16, A29 |
| A11–A15 | Technician creates sites/meters, writes meters, IDOR meter in org B | blocked | PASS | SQL A11–A15 |
| A19 | Technician mutates subscription | blocked | PASS | SQL A19 |
| A20–A24 | Site Admin creates sites (own/other org), IDOR meter, moves meter cross-org | blocked | PASS | SQL A20–A24; API 10 |
| **A25, A33** | **Site Admin (scope and legacy) moves own site into another org** | **EXPLOITED** | PASS | SQL A25, A33; API 11 |
| **A26** | **Site Admin attaches own site to another org's zone** | **EXPLOITED** | PASS | SQL A26; API 12 |
| **A36** | **Org Admin A pushes own site into org B** | **EXPLOITED** | PASS | SQL A36 |
| **A37** | **Org Admin B plants a site in org A by supplying B's zone_id** | **EXPLOITED** | PASS | SQL A37; API 13 |
| A27, A28 | Site Admin grants self org_admin / other-org site_admin | blocked | PASS | SQL A27, A28 |
| A30, A31 | Site Admin cannot delete a site; can still rename own site (legit) | as expected | PASS | SQL A30, A31 |
| A32, A34, A35 | Legacy Site Admin / Org Admin IDOR on org B | blocked (A32's error leaked quota, see C18b) | PASS | SQL A32, A34, A35 |

### B. Entitlement / subscription tampering

| # | Attack | Pre | Post | Evidence |
|---|---|---|---|---|
| B1–B4 | anon reads table or calls RPCs | blocked | PASS | SQL B1–B4; API 1–2 |
| B5–B10 | Viewer/Org Admin insert/update/delete subscription; rewrite plan catalog | blocked | PASS | SQL B5–B10; API 3–4 |
| **B11, B12** | **Site Admin `TRUNCATE organization_subscriptions` / `subscription_plan_catalog`** (bypasses RLS; wiped all tenants in the first pre-patch run) | **EXPLOITED** | PASS | SQL B11, B12, B12b, D6, D7 |
| **B13** | **Viewer reads billing `provider_*_ref`** | **EXPLOITED** | PASS | SQL B13, D8; API 5 |
| B14–B16, B18 | Own-org read OK; other-org entitlement/usage/row IDOR | blocked | PASS | SQL B14–B16, B18; API 7 |
| **B17** | **Viewer probes other org's features via SECURITY DEFINER `subscription_has_feature`** | **EXPLOITED** | PASS | SQL B17; API 8 |
| B19 | Non-boolean feature value (`"yes"`) | no error, not granted | PASS | SQL B19 |
| B21–B25 | Forged JWT claims (`plan`, `max_sites`, `max_meters`, `features`, `subscription_status`, `organization_id`, `user_role`, `app_metadata.role`) | ignored | PASS | SQL B21–B25, C14; API 6, 10 |

### C. Quota enforcement

| # | Attack | Pre | Post | Evidence |
|---|---|---|---|---|
| C1/C2, C12/C13 | Exact boundary N allowed, N+1 rejected (sites/meters) | enforced | PASS | SQL C1, C2, C12, C13; API 14–15 |
| C3–C9, C15–C16 | Inactive insert, then reactivate past the limit; deactivate, delete, recreate | enforced | PASS | SQL C3–C9, C15, C16 |
| C10 | Multi-row insert across the limit | enforced | PASS | SQL C10 |
| **Race** | **8 concurrent creators vs max=1** | **EXPLOITED: 8 sites, 8 meters** | PASS: 1/1 (3 runs × 12 workers) | `subscription_quota_race_test.sh` |
| C17–C18 | Org-scoped counting; org B unaffected by org A | enforced | PASS | SQL C17, C18 |
| **C18b** | **Unauthorized cross-tenant insert returns the victim org's quota state instead of 42501** | **EXPLOITED (info leak)** | PASS | SQL C18b |
| C19 | Meter moved into a full org | enforced | PASS | SQL C19 |
| **C20** | **Site moved between orgs carries meters past the target max_meters** | **EXPLOITED** | PASS | SQL C20 |
| C21–C27, C33 | past_due, canceled, expired, lapsed grace, missing row: blocked; open grace: allowed | enforced | PASS | SQL C21–C27, C33 |
| **C28–C31** | **trialing/active past `current_period_end` still entitled (creates, has_access, features)** | **EXPLOITED** | PASS | SQL C28–C31; C32 open-ended contract still allowed |
| C34–C35 | New org gets a server-provisioned trial from the catalog | **missing** (all creates failed) | PASS | SQL C34, C35; `meter_rollover_consumption_test` |

### D. Function / RLS security

| # | Control | Pre | Post | Evidence |
|---|---|---|---|---|
| **D1–D3, D5** | Quota trigger functions SECURITY DEFINER and executable by anon, PUBLIC and authenticated | **FAIL** (also broke the existing `production_security_hardening_test`) | PASS | SQL D1–D3, D5 |
| D4 | Every subscription function pins `search_path` | PASS | PASS (new functions use `search_path=''`) | SQL D4 |
| D6–D8 | Table/column least privilege | **FAIL** | PASS | SQL D6–D8 |
| D9 | RLS enabled on both tables | PASS | PASS | SQL D9 |
| — | Profile self-update cannot elevate | PASS | PASS | SQL A7, A18; `platform_owner_authority_test` |

### E. Regression (post-patch)

| Suite | Result |
|---|---|
| `subscription_security_gate_test.sql` (new) | 113/113 |
| `subscription_quota_race_test.sh` (new) | 2/2 × 3 runs |
| `subscription_api_smoke_test.sh` (new) | 15/15 |
| `production_security_hardening_test.sql` | PASS. It **failed on PR #2 as submitted**: "anon can execute 2 SECURITY DEFINER functions" |
| `platform_owner_authority_test.sql` | 20/20 |
| `meter_rollover_consumption_test.sql` | 29/29. It **failed on PR #2 as submitted** with `SUBSCRIPTION_REQUIRED` |
| `subscription_entitlements_test.sql` | PASS |
| `packages/smart_meters_core/test/subscription_test.dart` | 2/2 |
| Legit flows: Viewer/Technician reads, Site Admin rename + meter create within quota, Org Admin site create within quota, service_role subscription write | PASS (SQL A31, C11, C17, E1–E5; API 14) |

## 5. Vulnerabilities found

| ID | Severity | Exploit | Root cause |
|---|---|---|---|
| SUB-GATE-03 | **High** | 8 parallel inserts against max_sites=1 / max_meters=1 all committed | Count-then-insert in a BEFORE trigger with no per-org serialization |
| SUB-GATE-04 | **High** | Site Admin (scope or legacy) and Org Admin move a site to another org. A Site Admin attaches the site to a foreign zone. Org Admin B plants a site in org A via B's zone. This escapes or poisons per-org quotas and crosses tenants | `sites_update` WITH CHECK `can_manage_site(id)` evaluates the *old* row's org. `sites_insert` accepts `user_can_manage_zone(zone_id)` with no zone/org consistency check. Pre-existing RLS gaps that the quota model depends on |
| SUB-GATE-01 | Medium | `TRUNCATE` as `authenticated` wiped every tenant's subscriptions and the plan catalog. No direct REST verb exists for it, but it is reachable from any SQL execution path running as `authenticated` | Supabase default privileges kept TRUNCATE/REFERENCES/TRIGGER, and the migration revoked only INSERT/UPDATE/DELETE |
| SUB-GATE-05 | Medium | Any authenticated user learns any org's feature flags and active status | `subscription_has_feature` was SECURITY DEFINER with no caller scoping |
| SUB-GATE-07 | Medium | An ended trial (or ended paid period) kept full entitlement and creation rights indefinitely | Access was computed from `status` only; `current_period_end` was ignored and nothing transitions statuses |
| SUB-GATE-08 | Medium | Moving a site with meters into another org bypassed the target's max_meters | Meter quota is only checked on meter writes; site org changes did not recount meters |
| SUB-GATE-02 | Low | Viewer/Technician read `provider_customer_ref` / `provider_subscription_ref` | Table-wide SELECT grant |
| SUB-GATE-06 | Low | A cross-tenant insert returned `SUBSCRIPTION_METER_LIMIT_REACHED:<n>` for the victim org (quota oracle; masks 42501) | BEFORE triggers run before RLS WITH CHECK |
| SUB-GATE-10 | Low | `enforce_subscription_*` callable by anon/PUBLIC; broke the existing hardening suite | Default PUBLIC EXECUTE on new SECURITY DEFINER functions |
| SUB-GATE-09 | Functional regression | Any organization created after the migration could not create sites or meters; broke `meter_rollover_consumption_test` | No subscription is provisioned for new organizations |

## 6. Fixes made

All fixes are in `20261002171000_subscription_security_gate_hardening.sql`. The PR migration is not rewritten.

1. **Grants (01, 02):** `revoke all` from public/anon/authenticated on both tables. Authenticated keeps catalog `SELECT` and column-level `SELECT` on `organization_subscriptions`, excluding the provider refs. `service_role` is unaffected.
2. **Single entitlement predicate (07):** `subscription_row_has_access(status, current_period_end, grace_period_end)`:
   - trialing/active require the period not to have ended; null means open-ended.
   - grace_period requires the grace window not to have ended.
   - Every other status has no access.

   `subscription_access_state`, `subscription_has_feature` and the quota lock all use it.
3. **Feature probe (05):** `subscription_has_feature` is now SECURITY INVOKER with `search_path=''`. It is scoped by RLS and grants a feature only on a JSON `true`.
4. **Atomic quotas (03):** `subscription_lock_for_quota(org)` takes `SELECT … FOR UPDATE` on the org's subscription row and validates state. It is SECURITY DEFINER and not executable by any API role. Concurrent creators serialize per org and recount after the winner commits.
5. **Trigger placement (06, 08):** the site and meter quota triggers are now AFTER ROW triggers, so RLS rejects unauthorized writers first. A site moved between orgs re-checks the target org's meter quota. Updates that don't change the active count are skipped.
6. **Tenant boundary (04):** a new BEFORE trigger, `sites_guard_tenant_scope`, enforces two rules:
   - Only the platform owner, or a JWT-less service/DB session, may change `sites.organization_id`.
   - `zone_id` must belong to the site's organization. Violations raise 42501.

   The app's site update never sends `organization_id` (`site_repository.dart` `updateSite`), so no legitimate flow is affected.
7. **Provisioning (09):** an `organizations` AFTER INSERT trigger creates a `trial/trialing` row from `subscription_plan_catalog`, with the period ending after `trial_days`.
8. **EXECUTE least privilege (10):** all trigger/internal SECURITY DEFINER functions are revoked from public, anon and authenticated.

## 7. Regression tests added

- `supabase/tests/subscription_security_gate_test.sql`: pgTAP, 113 assertions covering matrix A–E. It uses an always-rollback probe helper so a successful exploit cannot cascade into later assertions.
- `supabase/tests/subscription_quota_race_test.sh`: parallel-transaction race for sites and meters.
- `supabase/tests/subscription_api_smoke_test.sh`: HTTP/JWT path through Kong → PostgREST, including forged claims.

## 8. Residual risks: subscription gate (accepted or for review)

1. **Isolation level:** the per-org lock guarantees atomicity under READ COMMITTED, which PostgREST uses. A direct DB session in REPEATABLE READ/SERIALIZABLE could count from a stale snapshot. API clients cannot choose the isolation level.
2. **`max_users` is not enforced server-side.** `subscription_usage` only reports it. It was not in the mandatory matrix and needs a decision before billing.
3. **Period-end enforcement is a business decision:** the PR backfill gives existing orgs `active` until now()+365 days. After that, site/meter creation stops unless the period is renewed or set to null (open-ended). Reads are unaffected. No job transitions statuses yet; billing sync must own that.
4. **Downgrades are not retroactive.** Existing over-quota rows remain; only new creates and reactivations are blocked.
5. **Platform-owner subscription management** is only possible through service_role (no app write path), so it fails closed.
6. **Pre-existing, not introduced by PR #2:** `INSERT … RETURNING` on `sites` by scope-model (non-owner) admins is rejected by `sites_select` visibility. This affects `SiteRepository.createSite`'s `.select()` for org/zone admins. It was verified identical with the gate triggers disabled. The API smoke uses `return=minimal`. It needs a separate fix.
7. The gate covered `sites`, `meters` and the subscription objects. Other site-scoped tables were not re-audited for tenant moves.

## 9. Migration-history residual risks (separate from the gate findings)

- The disposable DB reached `20261002170000` only with replay-only shims for historical drift around migrations 056–062/059 and duplicate 118 objects. That drift was **not repaired** here.
- The fix migration was applied on top of that replayed state. A clean from-zero `supabase db reset` replay was **not** possible because of that drift.
- Staging/production migration history was not inspected or modified, by design.

## 10. Final verdict

**PASS.** Every mandatory control has executed adversarial evidence against the isolated DB:

- Pre-patch: 25 assertions failed and the race was exploited.
- Post-patch: 113/113, race 1/1 in each of 3 runs, API 15/15, and all existing suites green.

This holds only with `20261002171000_subscription_security_gate_hardening.sql` and the new tests included in PR #2. PR #2 as currently pushed is **FAIL**.
