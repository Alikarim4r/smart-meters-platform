# Preflight Gate Report — Conservation Phase 1

**Status: PRE-FLIGHT: PASS**  
**Date (UTC):** 2026-07-29  
**Branch:** `feature/conservation-management`  
**Tag:** `pre-conservation-stable`  
**Test-fix commit:** `cf9f5c22751ff9b54719385d94e25fe6b6c104d0`  
**Docs commit (this update):** *(pending)*  

---

## Decision

All approved preflight gates are green. **Migration 063 / P1A may proceed** under the approved Phase 1 plan (flags default OFF; no `conservation_data_quality_snapshots`).

---

## Exact Execution Order

| Step | Status |
|------|--------|
| [1] Git hygiene + tag | PASS |
| [2] Branch `feature/conservation-management` | PASS |
| [3] Staging backup | PASS (`backups/staging_20260729T172256Z/`) |
| [4] Restore drill + runbook | PASS |
| [5a] Regression baseline | PASS |
| [5b] Fix 2 stale tests (test-only) | PASS — commit `cf9f5c2` |
| [5c] Full test suites green | PASS |
| [5d] Regression re-check after test fix | PASS — no protected-metric drift |
| [6] P1A / Migration 063 | **NEXT** (not started in this report) |

---

## Test-fix summary (no production behavior change)

### 1) `utility_network_canvas_layout_test.dart`
- **Cause:** Expectations assumed legacy meter card size **170×86**. Production uses circular meters via `kUtilityNetworkMeterSize = **112**`.
- **Math:** `right = 400+112+20 = 532`, `bottom = 500+112+20 = 632`.
- **Fix:** Updated expectations + comment. **No production layout change.**

### 2) `chart_type_test.dart`
- **Cause:** Stale assertions on `UtilityChartType.cop`, which is **not** in the current enum.
- **Current design:** utility charts = `chartTypesForUtility`; COP/EER charts = `chartTypesForEfficiency()` (separate).
- **Fix:** Replaced cop assertions with efficiency-helper checks. **Did not restore `cop` on the production enum.**

### Suite results after fix
| Suite | Result |
|-------|--------|
| smart_meters_core | PASS (~119) |
| dashboard_app | PASS (~75) |
| entry_app | PASS (~13) |
| admin_app | PASS (~21) |

---

## Regression after test fix

Compared `REGRESSION_BASELINE_LATEST.json` → `snapshot_POST_TESTFIX_*`:

All protected metrics **unchanged** (orgs/zones/sites/meters/readings/photos/profiles/access/COP).  
`RESULT: PASS`

---

## Migrations 056–062 tracking gap (documented only — no repair)

**`schema_migrations` on Staging:** max **055** (55 rows). **No rows** for 056–062.

**Files present on this branch:**

| File | In repo | `schema_migrations` | Live object probe (best-effort) |
|------|---------|---------------------|----------------------------------|
| `056_harden_scope_assignment_hierarchy.sql` | Yes | Missing | `user_may_write_scope_assignment` **not found** → likely **not applied** |
| `057_technician_scope_enter_readings.sql` | Yes | Missing | `is_technician_only_for_site` **present** → applied outside tracker |
| `058_ensure_own_pending_profile.sql` | **Not on branch** (was untracked/stashed earlier) | Missing | not inventoried here |
| `059_report_logos.sql` | **Not on branch** | Missing | `report-logos` bucket + `policy_settings.report_logo_secondary_path` **present** |
| `060_scoped_report_logos.sql` | Yes | Missing | `sites.report_logo_path` / `zones.report_logo_path` **present** |
| `061_atomic_approve_require_sites.sql` | Yes | Missing | `admin_approve_user(uuid,user_role,uuid[],text)` **present** |
| `062_super_admin_visibility_and_list_readings.sql` | Yes | Missing | `admin_list_site_readings` **present**; but `has_site_access` **does not** include `is_super_admin()` → **partial / incomplete apply** vs file |

**Conclusion:** This is **mixed**: primarily **migration history tracking drift** (objects applied via SQL/hotfix without version rows), plus at least one **possible schema drift** (`has_site_access` missing super_admin clause from 062).  

**No manual backfill of migration versions and no re-run of 056–062** without a separate approved report.

---

## Rollback readiness (unchanged)

- Tag `pre-conservation-stable`
- Staging dump + verified restore runbook
- Feature flags will remain OFF after 063

---

*PRE-FLIGHT: PASS — ready for P1A / Migration 063 per approved plan.*
