# P1C Completion Report — Targets & Actual vs Target

**Status: P1C PASS**  
**Date (UTC):** 2026-07-29  
**Branch:** `feature/conservation-management`  
**Environment:** Staging (`iqcxgtpcfhoapnklxdyl`)  
**Git commit SHA (P1C implementation):** `3c03a56097b4a24401d8eb268403a099c79aa410`

**Next:** Stop for approval before **P1D**. Do **not** start P1D until this report is approved.

---

## 1. Migration 064 — summary

**File:** `supabase/migrations/064_conservation_targets.sql`

**Applied how:** Direct `supabase db query --linked -f …` (not `db push`) so **056–062 were not executed**. Version row `064` / `conservation_targets` inserted into `schema_migrations` only.

### Table `conservation_targets` (additive only)

| Column | Notes |
|--------|-------|
| `id` | uuid PK |
| `site_id` | FK → sites |
| `scope_type` | `site` \| `category` \| `meter` |
| `scope_id` | nullable; required for category/meter |
| `period_type` | `monthly` \| `annual` |
| `period_start` / `period_end` | dates |
| `target_value` | numeric > 0 |
| `unit_code` | text |
| `version` | int ≥ 1 |
| `status` | `draft` \| `active` \| `archived` |
| `created_by`, timestamps | |

**Unique:** one **active** row per `(site, scope, period_type, period_start, unit)`.

**Not created:** baselines, savings, opportunities, quality snapshots, report tables.

### Self-review checklist

| Check | Result |
|-------|--------|
| Additive only | PASS |
| No DROP / destructive ALTER of existing objects | PASS |
| No changes to existing RLS on other tables | PASS |
| No `meter_readings` / consumption helper mutation | PASS |
| 056–062 backlog untouched | PASS |

---

## 2. RLS (full roles)

Policies on `conservation_targets`:

| Op | Who |
|----|-----|
| SELECT | `is_super_admin()` OR `is_platform_owner()` OR `has_site_access(site_id)` |
| INSERT / UPDATE | super_admin / platform_owner **or** `current_user_role() = site_admin` **and** `can_manage_site` |
| DELETE | same as write; site_admin may delete **drafts only** |

Explicit `is_super_admin()` / `is_platform_owner()` retained (Staging `has_site_access` gap from 062).

**Script:** `scripts/conservation/p1c_rls_validate.sql` → **`P1C_RLS_RESULT=PASS`** (viewer site isolation; tech cannot write; site_admin can insert on managed site; flags remain OFF).

---

## 3. Versioning (no history overwrite)

`ConservationTargetRepository`:

- Drafts may be updated in place.
- **Activate:** archives previous **active** for the same key, then sets draft → active.
- Does **not** UPDATE `target_value` on archived/active history rows to “edit” them.
- New drafts get `version = max(existing) + 1`.

**Target ≠ Baseline** — baselines deferred to P1D; models/services note the separation.

---

## 4. Actual vs Target service

**File:** `packages/smart_meters_core/lib/conservation/services/actual_vs_target_service.dart`

- Consumption via existing `periodConsumptionFromEndpoints` + `extractEndpoints` (no semantics change).
- Labels: **Above Target / Below Target / On Target / Insufficient Data** only.
- **Forbidden:** Energy/Water/Verified Saving (gap is never called Saving).
- **Monthly + Annual** `period_type` supported.
- **MTD / YTD:** when `analysisAsOf < periodEnd`, compares actual-to-date vs **prorated** target (`elapsedDays / periodDays`). Does **not** compare a partial actual to the full-period target in a misleading way.
- Every result carries **Data Completeness** + **Confidence** (+ `CalculationMeta` with `target_version`).
- Completeness &lt; 50% or missing valid endpoints → **Insufficient Data**.

### Mechanical Meter Period Boundary (carry into P1D)

Manual / mechanical meters often **lack** a reading on `periodStart − 1 day`.

| Rule | Behavior |
|------|----------|
| Do **not** invent a reading on `periodStart - 1` | PASS |
| Use latest reading **strictly before** period when present | PASS |
| Else fall back to **first-in-period** (existing helper semantics) | PASS |
| If neither boundary exists | **Insufficient Data** |
| Fetch window may include `periodStart - 1` for query bounds only | Not an invented reading |

This note applies equally to **P1D Baselines**.

---

## 5. Feature flags

| Flag | Default |
|------|---------|
| `conservation_module` | OFF (missing row) |
| `targets` | OFF |
| `period_compare` / others | unchanged OFF |

Staging check: `flag_rows=0`, `any_enabled=false`.  
Dashboard Conservation section visible only when module + (`period_compare` **or** `targets`).  
Admin targets link on site detail only when module + `targets`.  
**Default navigation unchanged while flags OFF.**

---

## 6. Files created

| Path |
|------|
| `supabase/migrations/064_conservation_targets.sql` |
| `packages/smart_meters_core/lib/conservation/models/conservation_target.dart` |
| `packages/smart_meters_core/lib/conservation/models/actual_vs_target_result.dart` |
| `packages/smart_meters_core/lib/conservation/repositories/target_repository.dart` |
| `packages/smart_meters_core/lib/conservation/services/actual_vs_target_service.dart` |
| `packages/smart_meters_core/test/conservation/actual_vs_target_service_test.dart` |
| `apps/dashboard_app/lib/widgets/conservation/actual_vs_target_card.dart` |
| `apps/admin_app/lib/screens/targets_admin_screen.dart` |
| `scripts/conservation/p1c_rls_validate.sql` |
| `docs/conservation/P1C_COMPLETION_REPORT.md` |
| `docs/regression/snapshot_POST_P1C_*.json` / `REGRESSION_POST_P1C_*.md` / `COMPARE_POST_P1C.md` |

## 7. Existing files modified

| Path | Change |
|------|--------|
| `packages/smart_meters_core/lib/conservation/conservation.dart` | Export P1C symbols |
| `apps/dashboard_app/lib/providers/conservation_providers.dart` | Targets gate + ActualVsTarget provider |
| `apps/dashboard_app/lib/widgets/system/site_conservation_panel.dart` | Period + Targets sections |
| `apps/dashboard_app/lib/screens/site_dashboard_screen.dart` | Section visibility via combined gate |
| `apps/dashboard_app/lib/widgets/shell/dashboard_sidebar.dart` | Same combined gate |
| `apps/admin_app/lib/screens/site_detail_screen.dart` | Flag-gated link to targets admin |

**Not modified:** report exporters, `meter_readings` schema/logic, entry_app business logic, 056–062 migrations/backlog docs content, existing consumption semantics.

---

## 8. Tests

| Suite | Result |
|-------|--------|
| `smart_meters_core` | **166 PASS** (includes 9 ActualVsTarget tests) |
| `dashboard_app` | **77 PASS** |
| `entry_app` | **13 PASS** |
| `admin_app` | **21 PASS** |
| `p1c_rls_validate.sql` | **PASS** |

AvT coverage includes: Above/Below, MTD proration, YTD proration, annual, unit mismatch, empty boundaries → Insufficient Data, first-in-period fallback (mechanical), no “Saving” label.

---

## 9. Regression POST_P1C

Compared to `docs/regression/REGRESSION_BASELINE_LATEST.json`:

**RESULT: PASS — protected metrics unchanged**

| Metric | Baseline | POST_P1C | Δ |
|--------|---------:|---------:|--:|
| organizations | 1 | 1 | 0 |
| zones | 8 | 8 | 0 |
| sites | 4 | 4 | 0 |
| meters | 35 | 35 | 0 |
| meter_readings | 43845 | 43845 | 0 |
| reading_photos | 4 | 4 | 0 |
| profiles | 14 | 14 | 0 |
| COP groups / links | unchanged | unchanged | 0 |

INFO (expected additive): `migration_count` 55 → 57; `migration_max` `055` → `064` (063+064).  
`conservation_targets` row count = **0** (empty; no production data writes).

Artifacts:

- `docs/regression/snapshot_POST_P1C_20260729T201801Z.json`
- `docs/regression/REGRESSION_POST_P1C_20260729T201801Z.md`
- `docs/regression/COMPARE_POST_P1C.md`

---

## 10. Rollback (if needed)

1. Keep feature flags **OFF** (already default).
2. Revert UI/providers/services on branch.
3. **Retain** `conservation_targets` data/schema unless approved DROP.
4. Do **not** run 056–062.

---

## 11. Stop condition

**P1C complete. Awaiting explicit approval before P1D (Versioned Baselines).**

Carry-forward note for P1D: **Mechanical Meter Period Boundary** — same valid-boundary / Insufficient Data policy; no invented `periodStart - 1` reading; Target and Baseline remain separate concepts.
