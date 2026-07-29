# Phase 1 Implementation Plan — Conservation Layer

**Status:** **APPROVED for execution** (2026-07-29) — follow Exact Execution Order only  
**Date:** 2026-07-29  
**Parent study:** [`CONSERVATION_LAYER_TECHNICAL_PLAN.md`](./CONSERVATION_LAYER_TECHNICAL_PLAN.md)  
**Branch:** `feature/conservation-management`  
**Environment:** Staging only (`iqcxgtpcfhoapnklxdyl`)  
**Architecture:** Additive · Feature Flags default **OFF** · Read-only derived metrics  

### Approval addenda (binding)

1. **P1A:** do **not** create `conservation_data_quality_snapshots` — quality is in-memory/service-only until a later reviewed migration.  
2. Pre-migration gates are strict: Git + tag + branch + backup + restore drill + runbook + regression baseline + existing tests **all green** before `063`.  
3. Automated regression compare after each sub-phase; unexpected count drift = **STOP**.  
4. Flags stay **OFF** after every migration; no auto-enable; report before any manual enable.  
5. Existing platform semantics frozen (consumption, charts, normalization, reports, entry, photos, corrections, offline, alerts, COP).  
6. Conservation never writes `meter_readings`.  
7. **P1B:** insufficient history → show **Insufficient Data** (never `0%` / `0 saving`).  
8. **P1C:** Actual vs Target gap is **Below/Above Target**, never Saving (Saving = Phase 4).  
9. **P1D:** Approved baseline immutable (`baseline_value`, reference period, method); changes = new version.  
10. **P1E:** physical meters remain fully enterable when referenced by virtual hierarchy; residual naming = Residual / Balance Difference only (no Leak).  
11. Sub-phase completion report required; do not auto-start next sub-phase on failure.  
12. After P1E → `PHASE_1_COMPLETION_REPORT.md` then **stop** for Phase 2 approval.

---

## 0. Binding constraints (confirmed)

These conditions are **mandatory** for all Phase 1 work:

| # | Constraint |
|---|------------|
| 1 | **Restore-verified backup** — dump alone is insufficient; restore procedure must be documented and smoke-tested before first migration |
| 2 | **Regression Baseline Report** before any change; re-run after every sub-phase |
| 3 | **Rollback order:** Disable flags → Revert app code → **Preserve conservation tables/data** → DB rollback only if necessary, after backup + explicit approval (no default DROP of data-bearing tables) |
| 4 | **Do not change** existing consumption formulas or existing report behavior in Phase 1 |
| 5 | Conservation metrics are **read-only derived** from current data — never mutate `meter_readings` or stored consumption |
| 6 | Every important metric carries **calculation metadata** (method, period, completeness, confidence, baseline/target version, calculated_at) |
| 7 | Phase 1 is **P1A → P1E** only; full regression after each; stop on any regression |
| 8 | Virtual meter **safety tests** listed in §P1E are mandatory before enabling that flag |
| 9 | All feature flags **OFF by default** after migration |
| 10 | No Night Flow / Peak / Hourly / Real-time / Pressure / BMS / Auto-FDD (Future Ready only) |

### Consumption lock (Phase 1)

- `dashboard_repository` consumption paths, `chart_period.periodConsumptionFromEndpoints`, and existing report exporters: **read/call only, no semantic edits**.
- Conservation services may **call** existing helpers or re-implement **equivalent** derived math in a separate module, but must not alter dashboard/report outputs for users with conservation flags OFF.

### Metric metadata contract (all Conservation results)

Every card/API result for a key metric must include (fields or nested `CalculationMeta`):

```
calculation_method
period_start
period_end
data_completeness        -- e.g. 0.0–1.0 or %
confidence_score         -- 0–100 or enum + numeric
baseline_version         -- nullable
target_version           -- nullable
calculated_at            -- timestamptz / DateTime
```

---

## 1. Pre-flight (before P1A code)

### 1.1 Git hygiene (documented; execute only after plan approval)

1. Inventory / commit or stash current dirty working tree on `main` (icons, docs, etc.)  
2. Tag: `pre-conservation-stable` on agreed commit  
3. Create branch: `feature/conservation-management` from that tag  
4. No conservation work on `main`

### 1.2 Backup + **Restore verification** (gate)

| Step | Action | Pass criteria |
|------|--------|---------------|
| B1 | Schema dump (`db dump --schema-only`) timestamped | File exists, non-empty |
| B2 | Data dump (`db dump --data-only` or full) timestamped | File exists; size plausible vs row counts |
| B3 | Record `supabase_migrations.schema_migrations` versions | List saved with dumps |
| B4 | Document Storage buckets (`meter-images`, `report-logos`) + sample path counts if feasible | Written in baseline report |
| B5 | **Restore drill** on a **throwaway** target (local Supabase Docker **or** temporary DB) | Restore completes; spot-check org/site/meter/reading counts match dump snapshot |
| B6 | Write `docs/STAGING_RESTORE_RUNBOOK.md` (during pre-flight execution) with exact commands | Runbook reviewed |

**Stop rule:** If B5 fails, **no migrations**. Fix backup/restore first.

> Note: Restoring *over* live Staging is destructive and requires explicit approval. The drill proves capability on an isolated target; live Staging restore remains a last-resort approved operation.

### 1.3 Regression Baseline Report (gate)

Script/report artifact (to be created at execution time):  
`docs/regression/REGRESSION_BASELINE_YYYYMMDD.md` (+ optional JSON snapshot)

**Must include at least:**

| Check | Query / method (conceptual) |
|-------|-----------------------------|
| Organizations count | `count(*)` from `organizations` |
| Zones count | `zones` |
| Sites count | `sites` |
| Meters count | `meters` (+ breakdown physical/virtual if any) |
| Meter readings count | `meter_readings` |
| Reading photos | count where `image_url is not null` (+ optional Storage object count) |
| Last reading per meter | `max(reading_date)` grouped by `meter_id` (sample or full export) |
| Users / roles | `profiles` by `role` + `approval_status`; sample `user_site_access` counts |
| COP groups | count `cop_groups` + membership counts |
| Virtual meters | `meters where meter_kind = 'virtual'` |
| Dashboard smoke | Manual: open Overview / Water / Electricity / BTU / Alerts / Reports on one known site; note KPI totals shown |

**After every sub-phase:** re-run same checks → `REGRESSION_POST_<subphase>_YYYYMMDD.md`  
**Pass:** counts unchanged (unless sub-phase intentionally adds *new empty* conservation tables only); dashboard smoke identical with flags OFF; entry/correction/photo paths still work.

---

## 2. Shared Phase 1 packaging (all sub-phases)

### 2.1 New package layout (created progressively)

```
packages/smart_meters_core/lib/conservation/
  conservation.dart                 # export barrel
  models/
  domain/
  repositories/
  services/
  flags/
```

Optional later split to `packages/smart_meters_conservation` — **not required in P1** if kept namespaced under `conservation/`.

### 2.2 Apps touch pattern

- **dashboard_app / admin_app:** add gated routes/sections only; default navigation unchanged when flags OFF  
- **entry_app:** **no functional change in P1A–P1D**; P1E no entry changes  
- **Existing files:** prefer additive imports/providers; avoid editing consumption/report cores

### 2.3 Default feature flags (all OFF after migration)

| Flag key | Introduced in |
|----------|----------------|
| `conservation_module` | P1A |
| `data_quality` | P1A |
| `period_compare` | P1B |
| `targets` | P1C |
| `baseline` | P1D |
| `virtual_meters` | P1E |

Master: if `conservation_module=false`, all conservation UI hidden regardless of child flags.

---

## 3. P1A — Safety Foundation

**Risk level:** Low  
**Expected effect on current platform:** None visible (flags OFF). New empty tables only.

### Goal

Feature flags store + Data Quality / Completeness / Confidence / Photo checks as **derived read-only** services + unit tests. Optional admin-only debug panel behind flags (still OFF by default).

### Migration (proposed)

`063_conservation_flags_and_quality.sql`

**Tables:**

| Table | Columns (summary) |
|-------|-------------------|
| `conservation_feature_flags` | `id`, `organization_id`, `site_id` null=org-wide, `flag_key`, `enabled` default **false**, timestamps, unique `(organization_id, site_id, flag_key)` |
| `conservation_data_quality_snapshots` *(optional persist)* | `id`, `site_id`, `period_start`, `period_end`, `completeness`, `confidence_score`, `findings_json`, `calculated_at`, `calculation_method` — **or** skip persist in P1A and keep in-memory only |

**Recommendation P1A:** start **without** persisting findings (service-only) to minimize DB surface; add snapshot table only if needed for audits. Flags table is mandatory.

**RLS (new tables only):**

- SELECT: `has_site_access(site_id)` or org-level via site membership / super_admin / platform_owner  
- INSERT/UPDATE flags: `can_manage_site` or super_admin / platform_owner  
- No changes to existing table policies

### Files to create

| Path |
|------|
| `supabase/migrations/063_conservation_flags_and_quality.sql` |
| `packages/smart_meters_core/lib/conservation/flags/feature_flag_keys.dart` |
| `packages/smart_meters_core/lib/conservation/flags/feature_flag_repository.dart` |
| `packages/smart_meters_core/lib/conservation/models/calculation_meta.dart` |
| `packages/smart_meters_core/lib/conservation/models/data_quality_result.dart` |
| `packages/smart_meters_core/lib/conservation/domain/data_quality_rules.dart` |
| `packages/smart_meters_core/lib/conservation/services/data_quality_service.dart` |
| `packages/smart_meters_core/lib/conservation/services/confidence_score.dart` |
| `packages/smart_meters_core/test/conservation/data_quality_service_test.dart` |
| `packages/smart_meters_core/test/conservation/confidence_score_test.dart` |
| `scripts/conservation/regression_baseline.sh` *(or `.dart`/sql)* |
| `docs/regression/` (baseline + post-P1A reports) |
| `docs/STAGING_RESTORE_RUNBOOK.md` |

### Files that may be modified (minimal)

| File | Change |
|------|--------|
| `packages/smart_meters_core/lib/smart_meters_core.dart` | Export conservation barrel (no behavior) |
| `apps/admin_app/...` *(optional)* | Hidden “Conservation flags” screen — only if `conservation_module` ON (still default OFF) |
| `apps/dashboard_app` | **Prefer none** in P1A |

**Must not modify:** `dashboard_repository` consumption logic, report exporters, `meter_reading_repository` writes, RLS on existing tables, `alert_detection` semantics (may *read* patterns for parallel quality rules in conservation module).

### Models / services

- `CalculationMeta`
- `DataQualityFinding` (missing reading, lower than previous, unreasonable jump, missing photo, correction in window, incomplete group…)
- `DataQualityService.evaluate(siteId, period)` → findings + completeness + confidence + meta  
- **Read-only:** SELECT `meter_readings`, `meters`, `policy_settings`; never UPDATE readings

### UI

- None required for end users in P1A  
- Optional: Admin flags toggles (staging only), behind module flag

### Tests

- Unit: each quality rule; confidence aggregation; photo_required cases  
- Flag repository: default false  
- No write-side reading tests broken

### Regression checks (after P1A)

Full baseline re-run + entry photo upload + login roles + dashboard smoke with flags OFF.

### Rollback procedure (P1A)

1. Ensure all flags OFF (or leave defaults)  
2. Revert app commits for P1A UI/exports if any  
3. **Keep** `conservation_feature_flags` table (empty/disabled)  
4. DB DROP only if migration fatally broken — requires backup + explicit approval  

### Stop conditions

- Restore drill failed  
- Regression counts drift unexpectedly  
- Any existing test suite failure introduced  

---

## 4. P1B — Period Comparisons

**Risk level:** Low  
**Expected effect:** None while `period_compare` OFF; with flag ON, new cards only.

### Goal

Previous Period and Same Period Last Year comparison cards — derived only — with full `CalculationMeta`.

### Migration

Usually **none** if P1A flags already include `period_compare`.  
If not: tiny seed row migration only (still `enabled=false`).

### Files to create

| Path |
|------|
| `.../conservation/services/period_comparison_service.dart` |
| `.../conservation/models/period_comparison_result.dart` |
| `.../test/conservation/period_comparison_service_test.dart` |
| `apps/dashboard_app/lib/.../conservation/period_comparison_cards.dart` *(new)* |
| Wire into site dashboard **behind flag only** |

### Files that may be modified

| File | Change |
|------|--------|
| Site dashboard shell / section enum | Add optional `Conservation` subsection **gated** |
| Providers | New Riverpod providers reading flag + service |

**Must not modify:** existing chart series semantics, report PDF/Excel layouts/outputs.

### Calculation notes

- Reuse **existing** consumption helpers via import/call, or duplicate formula in conservation module for isolation — **do not edit** helper behavior  
- Missing history → meta.completeness low; show “insufficient data”, not fake zeros as savings  

### Tests

- YoY / prev period with fixtures  
- Metadata always present  
- Flag OFF → widget not in tree / provider short-circuits  

### Regression

Full baseline + dashboard charts unchanged with flags OFF.

### Rollback

Disable `period_compare` (+ module if needed) → revert UI commits → preserve DB flags table.

---

## 5. P1C — Targets

**Risk level:** Low–Medium  
**Expected effect:** New admin CRUD; dashboard Actual vs Target only when `targets` ON.

### Goal

Monthly & Annual targets; Actual vs Target; target administration.

### Migration

`064_conservation_targets.sql`

**Table `conservation_targets`:**

| Column | Notes |
|--------|-------|
| `id` | uuid PK |
| `site_id` | FK sites |
| `scope_type` | `site` \| `category` \| `meter` |
| `scope_id` | nullable uuid |
| `period_type` | `monthly` \| `annual` |
| `period_start` / `period_end` | dates |
| `target_value` | numeric |
| `unit_code` | text |
| `version` | int (target version for meta) |
| `status` | `draft` \| `active` \| `archived` |
| `created_by`, timestamps | |

**RLS:** SELECT `has_site_access`; write `can_manage_site` / super_admin / owner.  
**No** triggers that write to `meter_readings`.

### Files to create

| Path |
|------|
| migration `064_...` |
| `models/conservation_target.dart` |
| `repositories/target_repository.dart` |
| `services/actual_vs_target_service.dart` |
| Admin: `targets_admin_screen.dart` |
| Dashboard: `actual_vs_target_card.dart` |
| tests for repo rules + actual vs target |

### Files that may be modified

| File | Change |
|------|--------|
| Admin navigation | Link under Structure/Settings — gated |
| Dashboard conservation section | Card when flags ON |

### Tests

- CRUD isolation by site RLS (documented manual + unit where possible)  
- Actual vs Target uses derived consumption only  
- Meta includes `target_version`  

### Regression

Baseline counts; existing reports; entry flow.

### Rollback

Flags OFF → revert UI → **retain** `conservation_targets` data → no DROP unless approved.

---

## 6. P1D — Versioned Baselines

**Risk level:** Medium  
**Expected effect:** Admin baseline workflow; Actual vs Baseline when `baseline` ON.

### Goal

Versioned baselines; draft / approved / superseded; no overwrite of history; Actual vs Baseline.

### Migration

`065_conservation_baselines.sql`

**Table `conservation_baselines`:** as in technical plan (version_number, reference period, calculation_method, baseline_value, status, valid_from/to, approved_by/at, …).

**Rules in DB or service (service preferred for Phase 1 clarity):**

- Approving vN sets previous approved to `superseded` + `valid_to`  
- DELETE restricted if referenced later (P4 savings) — for P1D soft-archive only  
- Never UPDATE `baseline_value` in place for approved rows — amend via new version  

**RLS:** same pattern as targets.

### Files to create

| Path |
|------|
| migration `065_...` |
| `models/conservation_baseline.dart` |
| `repositories/baseline_repository.dart` |
| `services/actual_vs_baseline_service.dart` |
| `services/baseline_approval_service.dart` |
| Admin baseline screens |
| Dashboard Actual vs Baseline card |
| tests: versioning, no overwrite, meta.baseline_version |

### Files that may be modified

Gated navigation only.

### Tests

- Cannot mutate approved baseline value  
- Supersede chain  
- Actual vs Baseline metadata  

### Regression

Full suite + flags OFF platform unchanged.

### Rollback

Flags OFF → revert code → **preserve baselines** → DROP only with approval.

---

## 7. P1E — Virtual Meters (last step of Phase 1)

**Risk level:** Medium–High (hierarchy mistakes)  
**Expected effect:** Admin can define/configure virtual meters when flag ON; **no** Balance Difference product yet (Phase 2). Calculator returns derived values + meta only.

### Goal

`VirtualMeterCalculator` for `sum_children` and `parent_minus_children`; limited Admin UI; strong validation.

### Migration

Prefer **no schema change** if existing `meters.meter_kind` / `calculation_type` / `parent_meter_id` suffice.

Optional `066_conservation_virtual_meter_constraints.sql` **only if** additive CHECKs/triggers are needed — must not break existing physical meters.

Possible additive helpers:

- Trigger/function: reject `parent_meter_id = id`  
- Trigger: reject cycles  
- Keep existing reading rejection for virtual meters  

### Files to create

| Path |
|------|
| `domain/virtual_meter_validation.dart` |
| `services/virtual_meter_calculator.dart` |
| Admin limited UI: create/edit virtual meter + children selection |
| Extensive tests listed below |

### Files that may be modified

| File | Change |
|------|--------|
| `meter_repository.dart` / admin meter forms | **Careful additive paths** for virtual kind — must not change default physical create path behavior |
| Catalog filters | Allow listing virtuals in admin when flag ON |

**Must not:** change how physical reading consumption is shown on existing dashboard tabs; must not label `parent_minus_children` result as “leak”.

### Calculator behavior (derived)

- `sum_children`: Σ child period consumption (each child via **existing** consumption semantics)  
- `parent_minus_children`: parent consumption − Σ children → expose as **Balance Difference / Unaccounted** numeric only (naming in UI for P1E: “Virtual result” / “Residual”; full Water Balance UX in P2)  
- Negative residual → show value + quality note; **never** auto-classify as leak  
- Missing child readings → lower completeness/confidence; optionally exclude or mark incomplete per meta  
- Nested virtuals: evaluate leaves first; forbid double-counting via validation (a meter cannot appear twice in expansion)

### Mandatory virtual-meter protection tests

| Test |
|------|
| Meter cannot be parent of itself |
| Circular parent relationships rejected |
| Duplicate children rejected |
| Child from incompatible org/site rejected |
| Unit compatibility enforced (or explicit conversion factors only if already platform-supported) |
| Multiplier handled consistently with existing normalization |
| Missing readings → incomplete meta, not silent invent |
| Negative difference not auto-labeled leak |
| Nested virtual meters: no double counting |

### UI

- Admin only, flag `virtual_meters` + module  
- No Phase 2 Balance dashboard yet  

### Regression

Full baseline; physical meter CRUD unchanged; entry still rejects/ignores virtual writes as today; dashboard physical analytics unchanged with flags OFF.

### Rollback

Flags OFF → revert admin virtual UI → preserve any virtual meter rows created in Staging test → no DROP of `meters` → never delete physical data  

---

## 8. Exact execution order

```
[0] Plan approved by product owner (this document)
        │
        ▼
[1] Git: stabilize main / tag pre-conservation-stable
        │     Test: clean status; tag points to agreed SHA
        │     STOP if dirty tree unresolved
        ▼
[2] Create branch feature/conservation-management
        │
        ▼
[3] Backup Staging (schema + data) + record migration versions
        │
        ▼
[4] Restore drill on throwaway target + write STAGING_RESTORE_RUNBOOK.md
        │     Test: counts match snapshot
        │     STOP if restore fails
        ▼
[5] Regression Baseline Report (REGRESSION_BASELINE_*.md)
        │     Test: document org/zone/site/meter/reading/photo/users/COP/virtual/dashboard smoke
        │     Also: run existing automated test suites — must pass
        │     STOP if baseline incomplete or tests fail
        ▼
[6] P1A — implement flags + data quality/completeness/confidence/photo (code + migration 063)
        │     Test: unit tests P1A; flags default OFF; existing suites pass
        ▼
[7] Regression POST-P1A
        │     STOP on any count drift / functional regression
        ▼
[8] P1B — period comparisons service + gated cards
        │     Test: unit + flag OFF invisible
        ▼
[9] Regression POST-P1B → STOP if fail
        ▼
[10] P1C — targets migration 064 + admin + Actual vs Target
        │     Test: unit + RLS manual; no reading mutations
        ▼
[11] Regression POST-P1C → STOP if fail
        ▼
[12] P1D — baselines migration 065 + versioning + Actual vs Baseline
        │     Test: no overwrite; supersede chain
        ▼
[13] Regression POST-P1D → STOP if fail
        ▼
[14] P1E — VirtualMeterCalculator + validation + limited admin UI (+ optional 066)
        │     Test: full virtual protection suite
        ▼
[15] Regression POST-P1E → STOP if fail
        ▼
[16] Phase 1 complete checkpoint — request approval before Phase 2 (Balance)
```

### First concrete step after approval

**Step [1] Git hygiene + tag** — no conservation code yet.  
Then **[3]–[5] backup/restore/baseline**.  
**First code/migration** is only at **[6] P1A**.

### When to stop

Stop and report immediately if:

- Restore drill fails  
- Regression Baseline cannot be produced  
- Any existing automated test fails after a sub-phase  
- Org/zone/site/meter/reading/photo counts change unexpectedly  
- Entry/photo/offline/corrections/reports/dashboard (flags OFF) behave differently  
- Any code path writes to `meter_readings` from conservation services  
- Consumption/report outputs change with flags OFF  

---

## 9. Out of scope for Phase 1 (reminder)

- Water/Energy Balance product UI & classification (Phase 2)  
- Benchmarking / Intensity (needs m² profile — Phase 2+)  
- Opportunities / Action workflow (Phase 3)  
- Estimated/Verified Saving / Cost / ROI / Conservation monthly reports productization (Phase 4)  
- Weather/occupancy normalization (Phase 5)  
- All 🔵 Smart Meter / BMS / hourly / real-time features  

---

## 10. Approval checklist

- [ ] Constraints §0 accepted  
- [ ] Restore-verified backup approach accepted  
- [ ] Regression Baseline contents accepted  
- [ ] Rollback order (preserve conservation data) accepted  
- [ ] Consumption/report freeze accepted  
- [ ] P1A–P1E split + exact order accepted  
- [ ] Virtual meter test list accepted  
- [ ] Flags default OFF accepted  

**Signature:** ______________________  **Date:** __________

---

*No implementation will start until this file is explicitly approved.*
