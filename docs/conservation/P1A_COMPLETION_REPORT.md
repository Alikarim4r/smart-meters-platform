# P1A Completion Report — Conservation Safety Foundation

**Status: P1A PASS**  
**Date (UTC):** 2026-07-29  
**Branch:** `feature/conservation-management`  
**Environment:** Staging (`iqcxgtpcfhoapnklxdyl`)  
**Git commit SHA:** `acd05e1ff2c205c52998f7ab114c1f27e233da4f`  

**Next:** Stop for approval before **P1B**.

---

## 1. Migration 063 — final SQL summary

**File:** `supabase/migrations/063_conservation_feature_flags.sql`

**Applied how:** Direct `supabase db query --linked -f …` (not `db push`) so **056–062 were not executed**. Version row `063` / `conservation_feature_flags` inserted into `schema_migrations` only.

### Self-review checklist (passed)

| Check | Result |
|-------|--------|
| Additive only | PASS |
| No DROP of existing objects | PASS |
| No destructive ALTER | PASS |
| No changes to existing RLS policies | PASS |
| No `meter_readings` / `meters` / `profiles` mutation | PASS |
| No replace of existing helpers | PASS |
| `enabled` default **false** | PASS |
| No quality snapshot table | PASS |
| Explicit `is_super_admin()` / `is_platform_owner()` on policies | PASS |

### Objects created

**Table:** `public.conservation_feature_flags`

| Column | Notes |
|--------|--------|
| `id` | uuid PK |
| `organization_id` | FK → organizations |
| `site_id` | nullable FK → sites (null = org-wide) |
| `flag_key` | text |
| `enabled` | boolean **default false** |
| `created_at` / `updated_at` | timestamptz; updated_at via existing `set_updated_at` trigger |

**Indexes:** org-wide unique `(organization_id, flag_key) WHERE site_id IS NULL`; site unique `(organization_id, site_id, flag_key) WHERE site_id IS NOT NULL`; supporting org/site/key indexes.

**RLS policies (new table only):**

| Policy | Intent |
|--------|--------|
| `conservation_feature_flags_select` | `is_super_admin()` OR `is_platform_owner()` OR `has_site_access(site_id)` OR org-wide if any accessible site in org |
| `conservation_feature_flags_insert/update/delete` | `is_super_admin()` OR `is_platform_owner()` OR (`current_user_role() = site_admin` AND manage helpers) |

**Write-policy note:** Staging technicians can satisfy `can_manage_site` via scopes; write policies therefore **also require** `current_user_role() = site_admin` so technicians cannot manage flags.

**Not created:** `conservation_data_quality_snapshots`, targets/baselines/opportunities/savings/balance/report tables.

**056–062:** not re-run; not backfilled. See backlog note.

---

## 2. Feature flag status (post-apply)

| Flag key (app constant) | DB rows | Enabled |
|-------------------------|---------|---------|
| `conservation_module` | none | **OFF** (default) |
| `data_quality` | none | **OFF** |
| `period_compare` | none | **OFF** |
| `targets` / `baseline` / `virtual_meters` | none | **OFF** |

Live check: `flag_rows = 0`, `any_enabled = false`.

---

## 3. Files created

| Path |
|------|
| `supabase/migrations/063_conservation_feature_flags.sql` |
| `packages/smart_meters_core/lib/conservation/conservation.dart` |
| `packages/smart_meters_core/lib/conservation/flags/feature_flag_keys.dart` |
| `packages/smart_meters_core/lib/conservation/flags/feature_flag_repository.dart` |
| `packages/smart_meters_core/lib/conservation/models/calculation_meta.dart` |
| `packages/smart_meters_core/lib/conservation/models/data_quality_result.dart` |
| `packages/smart_meters_core/lib/conservation/domain/data_quality_rules.dart` |
| `packages/smart_meters_core/lib/conservation/services/confidence_score.dart` |
| `packages/smart_meters_core/lib/conservation/services/data_quality_service.dart` |
| `packages/smart_meters_core/test/conservation/data_quality_service_test.dart` |
| `packages/smart_meters_core/test/conservation/confidence_score_test.dart` |
| `scripts/conservation/p1a_rls_validate.sql` |
| `docs/backlog/MIGRATION_HISTORY_RECONCILIATION_056_062.md` |
| `docs/conservation/P1A_COMPLETION_REPORT.md` *(this file)* |
| `docs/regression/snapshot_POST_P1A_*.json` / `REGRESSION_POST_P1A_*.md` / `COMPARE_POST_P1A.md` |

## 4. Existing files modified

| Path | Change |
|------|--------|
| `packages/smart_meters_core/lib/smart_meters_core.dart` | Export `conservation/conservation.dart` (no behavior change for existing apps) |

**Not modified:** `dashboard_repository` consumption, report exporters, `meter_reading_repository` writes, existing RLS on core tables, alert detection production semantics.

---

## 5. Data Quality rules implemented (read-only)

| Rule | Behavior |
|------|----------|
| Completeness | Only when explicit `expectedIntervalDays` **or** inferable median gap (≥3 historical readings). **No invented daily expectation.** |
| Missing / incomplete expected readings | Findings when known interval + large gaps / empty period |
| Unusual consumption change | Jump vs recent average × policy multiplier — title **Unusual Consumption Change** / review language (not Leak/Waste/Fault) |
| Reading lower than previous | Checks replacement/reset flag, correction history, rollover heuristic → **Reading Requires Review** / possible rollover — **not** auto Invalid |
| Missing required photo | Only if `photoRequired=true` |
| Correction in analysis period | Info finding |
| Incomplete meter group | Optional COP/group member counts |

**Persistence:** none. No writes to `meter_readings`, `meters`, `reading_audit_logs`, `policy_settings`.

**Source retention:** `DataQualityResult.sourceReadings` always keeps original reading values / photo path refs even when confidence is low.

---

## 6. Confidence formula (deterministic)

```
Base confidence: 100
Missing required photo: -20   (deduped per reading)
Correction in analysis period: -10 (deduped per meter)
Incomplete expected readings: -15 (once)
Unusual consumption change: -15 (per finding)
Reading requires review: -10 (per finding)
Possible rollover or reset: -5 (per finding)
Incomplete meter group: -10 (once)
Final confidence: clamp(0, 100)
```

Exposed via `ConfidenceBreakdown.explanationLines` (e.g. Base 100 / Missing required photo -20 / … / Final 55).

Photo not required ⇒ missing photo does **not** reduce confidence.

---

## 7. Test results

| Suite | Result |
|-------|--------|
| Conservation unit (DQ + confidence) | PASS (15) |
| `smart_meters_core` | PASS (134) |
| `dashboard_app` | PASS (75) |
| `entry_app` | PASS (13) |
| `admin_app` | PASS (21) |

### RLS role tests (Staging SQL impersonation)

Script: `scripts/conservation/p1a_rls_validate.sql` → **`P1A_RLS_RESULT=PASS`**

| Role | SELECT | WRITE flags |
|------|--------|-------------|
| viewer | In-scope only (HQ yes / Ali no) | Denied |
| technician | In-scope (Osman) | Denied (even if `can_manage_site` true) |
| site_admin | Manage HQ update OK | Arwa out-of-scope denied |
| super_admin | All probe rows (≥5) | N/A in probe (select focus; explicit OR unblocks 062 gap) |
| platform_owner | Policy includes `is_platform_owner()`; no dedicated profile role in Staging user_role enum | Covered in policy text |

Probe rows deleted afterward; flags table empty / OFF.

### Regression

Compared baseline → `snapshot_POST_P1A_*`:

**RESULT: PASS — protected metrics unchanged**  
(orgs/zones/sites/meters/readings/photos/profiles/access/COP unchanged)

Expected INFO only: `migration_count` 55→56, `migration_max` 055→063.

### Platform smoke (flags OFF)

| Check | Result |
|-------|--------|
| Entry reading (unit suite) | PASS |
| Photo policy helpers (existing + DQ photo tests) | PASS |
| Corrections (existing core/admin suites; no conservation writes) | PASS |
| Dashboard smoke (suite + no UI gate changes) | PASS |
| Existing reports / COP | PASS (suites; COP counts unchanged in regression) |
| `meter_readings` count | **43845 unchanged** — Conservation did not mutate readings |

---

## 8. Performance observations

- DQ evaluation is in-memory over caller-supplied snapshots (no new DB round-trips in P1A service).  
- Flags table empty; SELECT cost negligible.  
- No dashboard query path changes while flags OFF.

---

## 9. Known limitations

1. Completeness inference from median gaps needs ≥3 readings; otherwise completeness is skipped (by design).  
2. Rollover uses heuristic / optional `meterMaxValue` — meters have no capacity column yet.  
3. Flag repository `setEnabled` is unused in UI (no admin screen in P1A); RLS still enforced when called.  
4. Migration history 056–062 still drifted — **backlog only**.  
5. No end-user Conservation UI in P1A (intentional).

---

## 10. Rollback readiness

1. Keep all flags OFF (current state).  
2. Revert app/code commit exporting conservation module if needed.  
3. **Preserve** `conservation_feature_flags` table (empty).  
4. DROP table only with backup + explicit approval.

Tag `pre-conservation-stable` + Staging restore runbook remain valid.

---

## 11. Confirmation

- Conservation **never mutated** `meter_readings` (count stable; services are read-only).  
- Flags remain **OFF**.  
- **P1B not started.**

---

## Git commit SHA

*(set on commit)*
