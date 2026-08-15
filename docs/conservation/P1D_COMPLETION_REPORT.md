# P1D Completion Report — Versioned Baselines

**Status: P1D PASS**  
**Date (UTC):** 2026-07-29  
**Branch:** `feature/conservation-management`  
**Environment:** Staging (`iqcxgtpcfhoapnklxdyl`)  
**Git commit SHA (P1D implementation):** `54e6ca88307c6f89fb7dfef161dcd7702f41696c`

**Next:** Stop for approval before **P1E**. Do **not** start P1E until this report is approved.

---

## 1. Migration 065 — summary

**File:** `supabase/migrations/065_conservation_baselines.sql`

**Applied how:** Direct `supabase db query --linked -f …` (not `db push`) so **056–062 were not executed**. Version row `065` / `conservation_baselines` inserted into `schema_migrations` only.

### Schema `conservation_baselines`

| Column | Notes |
|--------|-------|
| `id` | uuid PK |
| `site_id` | FK → sites |
| `scope_type` / `scope_id` | site \| category \| meter |
| `utility_code` | optional utility/category context |
| `version_number` | int ≥ 1 |
| `label` | text |
| `reference_period_start` / `end` | dates |
| `calculation_method` | `total_period` \| `average_daily` \| `custom_fixed` |
| `baseline_value` | numeric ≥ 0 |
| `unit_code` | text |
| `status` | `draft` \| `approved` \| `superseded` \| `archived` |
| `valid_from` / `valid_to` | operational validity |
| `created_by`, `created_at`, `updated_at` | |
| `approved_by`, `approved_at` | |
| `notes` | |
| `data_completeness`, `confidence_score`, `boundary_quality` | quality snapshot |
| `calculation_meta` | jsonb |

**Not created:** Savings, Opportunities, Actions, Balance, Tariffs, ROI, Conservation Reports.

### Indexes / constraints

| Object | Purpose |
|--------|---------|
| `conservation_baselines_version_uq` | Unique `(site, scope, unit, version_number)` — concurrent-safe |
| `conservation_baselines_one_approved_uq` | At most one **approved** per operational key |
| `conservation_baselines_approved_lookup_idx` | Dashboard approved-only lookup |
| Immutability trigger | Blocks core-field edits after leave-draft |
| `conservation_baselines_next_version()` | Advisory-lock version allocator |

### Self-review

| Check | Result |
|-------|--------|
| Additive only | PASS |
| No DROP of existing objects | PASS |
| No `meter_readings` mutation | PASS |
| 056–062 backlog untouched | PASS |
| `conservation_targets` unchanged | PASS (count 0) |

---

## 2. RLS

| Op | Who |
|----|-----|
| SELECT | `is_super_admin()` OR `is_platform_owner()` OR `has_site_access` |
| INSERT | draft only; site_admin+`can_manage_site` / super / owner |
| UPDATE | same writers (Edit Draft + Approve + Supersede) |
| DELETE | drafts only; same writers |

Explicit super_admin / platform_owner (062 gap). Technicians cannot write.

**Script:** `scripts/conservation/p1d_rls_validate.sql` → **`P1D_RLS_RESULT=PASS`**

Covers: viewer select-in-scope / no write; tech no write; site_admin in-scope draft + approve/supersede; site_admin out-of-scope rejected; super select; immutability; duplicate version rejected; targets unchanged; flags OFF.

---

## 3. Lifecycle & permissions

```
draft ──approve──► approved ──new approve──► superseded
  │                   │
  └──archive──► archived ◄──archive─────────┘
```

| Action | Roles |
|--------|-------|
| Create Draft | site_admin (+can_manage_site), super_admin, platform_owner |
| Edit Draft | same |
| Approve | same — **explicit** action (never auto on create) |
| Archive | same |
| Viewer / Technician | SELECT only |

Approve is a separate service call (`BaselineApprovalService.approve`) with quality gates — creating a draft does not approve it.

---

## 4. Versioning & immutability

- New drafts get `version_number` via `conservation_baselines_next_version` (advisory xact lock + unique index).
- Approving vN sets previous approved → **superseded** with `valid_to`, then draft → **approved** with `valid_from`.
- History is **never deleted** on supersede.
- DB trigger blocks changing `baseline_value`, reference period, method, unit, scope, version after leave-draft.
- Changes require a **new version**.

**Target ≠ Baseline** — no auto-wiring between them.

---

## 5. Boundary handling (Mechanical Meter Period Boundary)

More conservative than P1C for **approval**:

| Case | Draft calc | Formal approve |
|------|------------|----------------|
| Exact reading strictly before `reference_period_start` | OK · `exact_pre_period` | Allowed (if completeness/confidence OK) |
| first-in-period fallback only | Preview OK · labeled + confidence −25 | **Blocked** |
| No valid endpoints | Insufficient Data draft | **Blocked** |
| Invent `periodStart−1` | **Never** | **Never** |

Fallback appears in `CalculationMeta.notes` and `boundary_quality`.

---

## 6. Calculation methods (P1D)

| Method | Behavior |
|--------|----------|
| `total_period` | Sum of period consumption via existing endpoints helper |
| `average_daily` | `total / inclusiveDayCount(start,end)` — calendar-aware (Jan=31, not 30) |
| `custom_fixed` | Admin-specified value; `boundary_quality=not_applicable` |

**Not in P1D:** Weather / Occupancy normalization.

---

## 7. Approval quality gates

Config: `BaselineApprovalGates.standard` (not buried in UI):

- `minCompleteness = 0.80`
- `minConfidence = 70`
- `requireExactPrePeriodBoundary = true`

Also blocks: unit mismatch, cross-site scope, invalid period, missing scope_id, critical DQ findings, non-draft status, non-computable value.

Insufficient / low-confidence drafts **may be saved**; they **cannot** be approved.

---

## 8. Actual vs Baseline

Labels only: **Above Baseline / Below Baseline / On Baseline / Insufficient Data**.  
**Forbidden:** Saving, Verified Saving, Cost Avoided.

Carries: absolute variance, percentage variance (N/A if baseline=0), completeness, confidence, baseline version, method, period, calculated_at.

**Combined confidence = min(baseline, actual)** — strong baseline does not rescue weak actual.

---

## 9. Feature flags

UI requires `conservation_module` **AND** `baseline`.  
Staging: all flags **OFF** (`any_flag=false`). Default nav unchanged.

---

## 10. Screens / UI

| Surface | Behavior |
|---------|----------|
| Admin `BaselinesAdminScreen` | List/history, create draft, method, preview, completeness, confidence, warnings, Approve (gated), status badges |
| Admin site detail | Link only when flags ON |
| Dashboard `ActualVsBaselineCard` | Inside Conservation only |
| Dashboard provider | Loads **approved only** (not full history) |

**Not modified:** Overview / Water / Electricity / BTU / Fuel panels, PDF/Excel reports, COP logic, entry_app.

---

## 11. Files created

| Path |
|------|
| `supabase/migrations/065_conservation_baselines.sql` |
| `packages/smart_meters_core/lib/conservation/models/conservation_baseline.dart` |
| `packages/smart_meters_core/lib/conservation/models/actual_vs_baseline_result.dart` |
| `packages/smart_meters_core/lib/conservation/domain/baseline_approval_gates.dart` |
| `packages/smart_meters_core/lib/conservation/services/baseline_calculation_service.dart` |
| `packages/smart_meters_core/lib/conservation/services/baseline_approval_service.dart` |
| `packages/smart_meters_core/lib/conservation/services/actual_vs_baseline_service.dart` |
| `packages/smart_meters_core/lib/conservation/repositories/baseline_repository.dart` |
| `packages/smart_meters_core/test/conservation/baseline_p1d_test.dart` |
| `apps/admin_app/lib/screens/baselines_admin_screen.dart` |
| `apps/dashboard_app/lib/widgets/conservation/actual_vs_baseline_card.dart` |
| `scripts/conservation/p1d_rls_validate.sql` |
| `docs/conservation/P1D_COMPLETION_REPORT.md` |
| `docs/regression/snapshot_POST_P1D_*` / `COMPARE_POST_P1D.md` |

## 12. Files modified

| Path | Change |
|------|--------|
| `conservation.dart` | Export P1D symbols |
| `conservation_providers.dart` | baseline gate + approved-only AvB provider + section visibility |
| `site_conservation_panel.dart` | Actual vs Baseline section |
| `site_detail_screen.dart` | Flag-gated baselines link |

---

## 13. Tests

| Suite | Result |
|-------|--------|
| Conservation (incl. P1D) | **76 PASS** |
| `smart_meters_core` | **195 PASS** |
| `dashboard_app` | **77 PASS** |
| `entry_app` | **13 PASS** |
| `admin_app` | **21 PASS** |
| `p1d_rls_validate.sql` | **PASS** |

P1D unit coverage includes: exact boundary, fallback, low completeness/confidence blocks, total_period, average_daily, custom_fixed, unit mismatch, cross-site, scope validation, Above/Below/On, baseline=0 → % N/A, missing actual, combined confidence, draft not usable, permissions exclude tech/viewer.

DB script covers: V1 approve → V2 supersede, immutability, duplicate version protection, RLS roles.

---

## 14. Regression POST_P1D

**RESULT: PASS — protected metrics unchanged**

| Metric | Baseline | POST_P1D | Δ |
|--------|---------:|---------:|--:|
| organizations | 1 | 1 | 0 |
| zones / sites / meters | unchanged | unchanged | 0 |
| meter_readings | 43845 | 43845 | 0 |
| reading_photos | 4 | 4 | 0 |
| profiles / COP | unchanged | unchanged | 0 |

INFO (expected): `migration_count` 55 → 58; `migration_max` `055` → **`065`**.  
`conservation_baselines` = **0** rows; `conservation_targets` = **0**; flags OFF.

---

## 15. Performance

Dashboard `listApprovedForSite` / provider loads **current approved only**.  
Full version history loaded only on admin baselines screen.

---

## 16. Numeric examples

### A — Approved baseline with good boundaries
Reference Jan 2026; pre-period reading 100, end 200 → `total_period` baseline **100**; `exact_pre_period`; confidence ≥ 70 → **approvable**.

### B — Actual above baseline
Baseline 50; actual Feb consumption 80 → **Above Baseline**; absolute +30; % = +60%.

### C — Actual below baseline
Baseline 100; actual 40 → **Below Baseline** (not Saving).

### D — Insufficient / cannot approve
No pre-period reading; first-in-period fallback → draft preview OK but gate: **blocked** (“fallback is not acceptable for formal approval”). Empty readings → Insufficient Data draft.

### E — V1 superseded by V2
Approve V1 → approve V2 draft → V1 `superseded` + `valid_to`; V2 `approved` + `valid_from`; V1 row retained.

---

## 17. Known limitations

- Category/meter scopes modeled; dashboard AvB evaluates **site** scope in P1D UI.
- Weather/occupancy normalization deferred.
- Saving / Verified Saving deferred to Phase 4.
- Approve uses same RLS writer roles as draft edit; separation is **service/action** level (documented), not a separate DB role.
- Concurrent version races handled by unique index + advisory lock (insert may need retry on rare conflict).

---

## 18. Rollback readiness

1. Keep flags **OFF**.
2. Revert UI/services on branch.
3. **Retain** `conservation_baselines` data/schema unless DROP approved.
4. Do **not** run 056–062.

---

## 19. Stop condition

**P1D complete. Awaiting explicit approval before P1E (Virtual Meters).**

`MIGRATION_HISTORY_RECONCILIATION_056_062` remains outside P1D (not a blocker).
