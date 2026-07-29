# Preflight Gate Report — Conservation Phase 1

**Date (UTC):** 2026-07-29  
**Branch:** `feature/conservation-management`  
**Tag:** `pre-conservation-stable`  
**Commit:** `74e4449155494991824d7b0eed9f1e36162ce9d0`  
**Decision:** **STOP before Migration 063 / P1A code** — existing automated tests are not fully green.

---

## Exact Execution Order progress

| Step | Status | Notes |
|------|--------|-------|
| [1] Git hygiene + tag `pre-conservation-stable` | **PASS** | Unrelated WIP stashed as `wip-non-conservation-before-pre-conservation-stable`. Plans committed on `74e4449`. |
| [2] Branch `feature/conservation-management` | **PASS** | Created from tag. |
| [3] Full Staging backup | **PASS** | `backups/staging_20260729T172256Z/` — schema.sql (~523KB), data.sql (~95MB), roles.sql |
| [4] Restore drill + runbook | **PASS** | Throwaway Docker `postgres:17` on :5433; protected counts matched Staging exactly. Runbook: `docs/STAGING_RESTORE_RUNBOOK.md` |
| [5] Regression Baseline + existing tests | **PARTIAL / STOP** | Baseline captured; **2 pre-existing test failures** block Migration 063 per approved gates |

**Migration 063 / Conservation code:** **NOT STARTED** (correct per gates).

---

## Backup + Restore

| Item | Result |
|------|--------|
| Schema dump | OK |
| Data dump | OK (circular FK warnings only) |
| Restore target | Docker `conservation-restore-drill` (`postgres:17`, port 5433) |
| Restore verification | **PASS** — orgs/zones/sites/meters/readings/photos/profiles/access/COP counts identical to Staging |
| Live Staging overwrite | Not performed (correct) |

---

## Regression Baseline (Staging)

Source: `docs/regression/REGRESSION_BASELINE_LATEST.json`

| Metric | Count |
|--------|------:|
| organizations | 1 |
| zones | 8 |
| sites | 4 |
| meters | 35 |
| meters_physical | 35 |
| meters_virtual | 0 |
| meter_readings | 43845 |
| reading_photos | 4 |
| profiles | 14 |
| user_site_access | 18 |
| cop_groups | 1 |
| cop_btu_links | 3 |
| cop_elec_links | 3 |
| migration_count (schema_migrations) | 55 |
| migration_max | 055 |

**Profiles by role:** super_admin 2, site_admin 1, technician 6, technician_request 1, viewer 4  
**Approval:** approved 12, rejected 1, suspended 1  

**Storage buckets:** `meter-images`, `profile-avatars`, `report-logos`  

**Last readings (sample):** newest `2026-07-28` on several meters; some meters last at `2026-05-31`.

**Note — migrations tracking gap:** repo contains SQL files through `062_*`, but Staging `schema_migrations` lists only through **055**. Functions from later hotfixes may exist without version rows. Documented for awareness; not changed in this preflight.

**Compare tooling:**  
- `scripts/conservation/capture_regression_snapshot.sh`  
- `scripts/conservation/compare_regression_snapshot.sh`

---

## Existing automated tests

| Suite | Result |
|-------|--------|
| `smart_meters_core` | **118 passed, 1 failed** — `utility_network_canvas_layout_test.dart` (`fit bounds…` expected 590 vs actual 532.0) |
| `dashboard_app` | **Fail to load** `chart_type_test.dart` — `UtilityChartType.cop` member not found (stale test vs current enum) |
| `entry_app` | **All passed** |
| `admin_app` | **All passed** |

These failures are **pre-existing on the stable tag** (no Conservation code yet). Per approved plan, Migration 063 must not start until tests are green **or** you explicitly waive/fix these two failures as an accepted baseline exception.

---

## Feature flags

N/A yet — no Conservation migration applied. All future flags remain planned **OFF by default**.

---

## Rollback readiness

| Asset | Location |
|-------|----------|
| Git tag | `pre-conservation-stable` |
| Stash of unrelated WIP | `stash@{0}: wip-non-conservation-before-pre-conservation-stable` |
| DB backup | `backups/staging_20260729T172256Z/` (gitignored) |
| Restore procedure | `docs/STAGING_RESTORE_RUNBOOK.md` (verified) |

---

## Required decision before continuing

Choose one:

1. **Fix the 2 failing tests** on this branch (layout expectation + remove/update stale `UtilityChartType.cop` assertions), re-run suites to green, then start **P1A** (flags + read-only Data Quality services; **no** `conservation_data_quality_snapshots` table).  
2. **Explicitly waive** the 2 failures as known baseline debt and authorize P1A start anyway.  
3. **Pause** until you review.

**Recommendation:** Option 1 — small, contained test fixes that do not change production consumption/report semantics; keeps the approved gate honest.

---

*No Conservation application code and no Migration 063 were applied.*
