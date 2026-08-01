# Phase 5 Completion Report — Advanced Normalization / Persistence / Carbon / Portfolio

**Status: PHASE 5 CLOSED — PASS (pending user approval before Phase 6)**  
**PHASE_5_FINAL_GATE: PASS**  
**PHASE_5_COMMITTED_FINAL_GATE: PASS**  
**Date (UTC):** 2026-08-01  
**Branch:** `feature/conservation-management`  
**Environment:** Staging (`iqcxgtpcfhoapnklxdyl`)  
**Tag (unchanged):** `pre-conservation-stable`  

| Artifact | SHA |
|----------|-----|
| **Phase 5 implementation** | `70b7f948824926de8762ba8700fd874a3c5f9e33` |
| **Phase 5 closure/docs** | `db56f8f3dbde746c914d34f7725aceb7fe924bdf` |
| **Git HEAD after closure** | `db56f8f3dbde746c914d34f7725aceb7fe924bdf` |

**Do not start Phase 6 until this report is explicitly approved.**

---

## Executive Summary

Phase 5 adds an **optional, flag-gated** advanced analytics layer on top of Phase 4 M&V:

**Normalize (weather/occupancy) → Persist savings → Carbon (optional) → Portfolio / Forecast / Recommendations**

Capability levels A/B/C are modeled so Level C (interval/smart) is never required for mechanical periodic meters.

All Phase 5 feature flags remain **OFF** by default. Protected platform metrics unchanged (`meter_readings=43845`, physical meters=35). Migration backlog **056–062** remains Open / Deferred outside Conservation.

**Git closure:** Implementation committed at `70b7f94…`. Local/generated Podfiles and Flutter registrant/xcconfig noise were excluded from commits.

---

## Negative-performance preservation check/fix

### Finding
Phase 4 already kept a **signed** delta in `estimated_saving_quantity` and in `calculation_meta` (`verified_from_estimated`, `negative_outcome_clamped`), while clamping `verified_saving_quantity` to `≥ 0`.

### Forward hardening (additive) — committed in `70b7f94`
| Item | Detail |
|------|--------|
| **Migration 081** | Column `performance_change_quantity` (signed, reportable) |
| **Model** | `MeasurementVerification.performanceChangeQuantity` + `resolvedPerformanceChangeQuantity` / `isIncreasedConsumptionOutcome` |
| **Services** | Estimation meta includes `performance_change_quantity`; verify writes column + meta; Verified totals still ignore negatives |
| **UI** | M&V card shows Performance change; increased consumption labeled |
| **Tests** | `mv_p4_test` + Example I in `phase5_advanced_test` (committed gate re-run PASS) |

**Example I (committed):** Reference 900 / Post 1050 → `performance_change_quantity = −150`, `verified_saving_quantity = 0`, status display “No Saving — Consumption Increased”. Verified Savings Total excludes the negative; signed value remains on the record/meta.
---

## Migrations (additive only)

| Version | Name | Content |
|---------|------|---------|
| **081** | `mv_performance_change_quantity` | Signed performance change column |
| **082** | `conservation_phase5_feature_flag_docs` | Document P5 flag keys (no auto-enable) |
| **083** | `conservation_weather_datasets` | Weather datasets + observations + approval trigger |
| **084** | `conservation_normalization_models` | Models + normalized results; M&V methods weather/occupancy adjusted |
| **085** | `site_operating_calendar` | Operating calendar + occupancy profiles |
| **086** | `conservation_saving_persistence` | Persistence follow-up + reopen suggestion dedupe index |
| **087** | `emission_factors_carbon` | Emission factors + carbon results (version binding) |
| **088** | `conservation_portfolio_forecast_reco` | Portfolio cache, forecasts, recommendations |
| **089** | `weather_approval_authority_tighten` | Weather approve/write = site_admin/super/owner (not org-update tech) |
| **090** | `emission_factor_admin_authority` | Factor activation = Conservation admin helper |

**Apply:** `db query --linked` + `schema_migrations`. **Not** `db push`.  
**056–062:** untouched.  
Staging `migration_max`: **090**.

### Migration 082 review

`082_conservation_phase5_feature_flag_docs` is a **documentation-only** migration:

- Updates `COMMENT ON TABLE conservation_feature_flags` to list Phase 5 flag key names.
- **No** `INSERT` of flag rows.
- **No** `enabled=true`.
- **No** operational data.
- **No** semantic change to helpers/RLS.

Why a DB migration: keeps Staging migration history aligned with the Phase sequence (081–090) and documents intended keys next to the live flags table.  

**Future recommendation:** prefer Dart-only key docs when no schema change is required; do **not** rewrite/delete 082 historically now that it is applied.

### Git ↔ Staging migration match

| Version | In Git (`70b7f94`) | In Staging `schema_migrations` | Objects smoke |
|---------|:------------------:|:------------------------------:|:-------------:|
| 081–090 | Present | Present (names aligned) | PASS (`performance_change_quantity` + P5 tables exist) |

**Migration-to-Git matching result: PASS** — no STOP condition.

---

## Weather normalization

- Eligible only via `WeatherSensitiveUtilities` (cooling; electricity only with cooling/HVAC/CHW tags).
- Sources: imported monthly / manual approved / API-future — **no hard-coded values**.
- Method v1: explainable **degree-day** (`DegreeDayNormalizationService`).
- Quality gates: samples, completeness, fit, outliers, units, approved weather → else **Normalization Not Reliable**.
- Actual vs normalized kept separate (`actual_consumption` never replaced).

---

## Occupancy / calendar normalization

- `site_operating_calendar` + `conservation_occupancy_profiles`.
- Missing data → **Occupancy Normalization = Not Available**.
- Intensities (per m² / occupied day / person) only when inputs complete.

---

## Model quality gates

`NormalizationQualityGates` + `NormalizationModelService.evaluateDraft` → metadata: method, training period, variables, sample count, goodness-of-fit, confidence, version, warnings. DB refuses approve when `quality_gate_passed = false`.

---

## Saving persistence

Windows `1m/3m/6m/12m` only when follow-up days support them. Statuses: sustained / partially_sustained / declining / not_sustained / insufficient_follow_up. Original Verified MV never deleted. Reopen suggestion keyed + deduped; **not** auto-opened.

---

## Carbon factors / accounting

- Versioned `emission_factors` (grid electricity, diesel/fuel, optional water-related).
- Missing/expired/inactive → **Carbon Avoided = Not Available** (null, never invent).
- Official total = **Verified Saving × bound factor snapshot** only (`CarbonAccountingService.verifiedCarbonTotal`).

---

## Portfolio optimization

- Org / zone / site aggregates; verified-only totals; bounded `limit`.
- Ranking methods: absolute, intensity, cost, target variance, opportunity risk, confidence-adjusted priority — each with **+/- explanations**.

---

## Forecasting

Explainable: run-rate, seasonal average, rolling average, simple/normalized trend. Insufficient history → **no invented number**. Budget impact N/A without tariff.

---

## Recommendation engine

Rule-based only (verification backlog, overdue actions, meter alignment, missing weather/occupancy, repeated anomaly, tariff/baseline, persistence). No BMS commands. No AI cause/saving confirmation.

---

## Data lineage

Normalized / forecast / carbon / portfolio / persistence results carry `lineage` JSON (readings/baseline/tariff/weather/occupancy/emission/model version as applicable).

---

## Feature flags (all OFF by default)

`weather_normalization`, `occupancy_normalization`, `saving_persistence`, `carbon_accounting`, `portfolio_optimization`, `forecasting`, `recommendation_engine`

---

## UI

- **Site:** Advanced tabs (lazy) — Normalized / Persistence / Carbon / Forecast / Recommendations; Simple by default.
- **Admin:** Portfolio executive cards (gated by `portfolio_optimization`).
- Model regression details not shown on first viewport.

---

## UX complexity controls

Simple by default; Advanced on demand; tabs + lazy FutureBuilders; no full-portfolio recompute on every render (cached `conservation_portfolio_summaries`).

### Empty-state behavior (flags ON, no stored results)

| Surface | Behavior |
|---------|----------|
| Advanced tabs | Clear empty copy; no invented numbers |
| Carbon | Not Available / missing factor message |
| Forecast | Insufficient History / no stored forecasts |
| Persistence | No follow-up rows; original Verified MV preserved |
| Portfolio | Explicit “No portfolio summary cached” — **no fake zero totals** |
| Cost/Carbon N/A | `N/A`, never invented 0 |

Flags OFF hide Advanced entirely (`advancedOn`). FutureBuilders settle; no loading loops.

---

## RLS

`scripts/conservation/p5_rls_validate.sql` — PASS:

- Tech cannot approve weather / activate emission factors  
- Site admin can approve weather  
- Failed quality gates block model approval  
- Viewer can select weather; cannot write  
- meter_readings / physical meters / flags_on unchanged  

Roles covered in design: viewer, technician, site_admin, super_admin, platform_owner.

---

## Tests

| Suite | Result |
|-------|--------|
| Conservation unit (`test/conservation/`) | **224 PASS** |
| `smart_meters_core` full | **343 PASS** |
| `dashboard_app` | **77 PASS** |
| `entry_app` | **13 PASS** |
| `admin_app` | **21 PASS** |
| Phase 5 RLS | **PASS** |
| Phase 4 RLS (recheck) | **PASS** |

---

## Regression

`COMPARE_PHASE_5_FINAL_GATE.md` → **RESULT: PASS — protected metrics unchanged**

| Metric | Value |
|--------|------:|
| meter_readings | 43845 |
| meters_physical | 35 |
| flags_on | 0 |
| migration_max | 090 |

---

## Performance

- Portfolio/forecast/normalized lists are **bounded** (limit/pagination).  
- Advanced UI loads per-tab only.  
- No “compute all sites/models/forecasts on every dashboard open”.

---

## Protected metrics

Unchanged vs `REGRESSION_BASELINE_LATEST.json` for all protected counts.

---

## Known limitations

- Degree-day is the primary weather method; full IPMVP Option C not claimed.  
- AI summarization not shipped (rules only).  
- Persistence/carbon/forecast need on-demand compute + storage fill — UI shows empty states when flags ON but no rows.  
- Org-wide weather (`site_id` null) write path restricted to super/owner after 089.  
- Mobile install skipped if no Android device connected (gate run: macOS only; no phone).

---

## Rollback

1. Disable all Phase 5 flags (already OFF).  
2. Optionally drop new tables (083–088) / columns (081) via forward reverse migration if ever required — do **not** rewrite 077–080.  
3. Tag `pre-conservation-stable` remains valid restore point for pre-Conservation platform.

---

## Numeric examples

| ID | Scenario | Result |
|----|----------|--------|
| **A** | Cooling 1200 kWh / 300 CDD → ref 250 CDD | Normalized **1000** kWh; actual preserved **1200** |
| **B** | sample_count=2 | **Normalization Not Reliable**; normalized null |
| **C** | Verified 100; follow-up sustained 90 | Status **sustained** (90%) |
| **D** | Verified 100; sustained 10 | Status **not_sustained**; reopen suggested |
| **E** | Verified 100 kWh × factor 0.5 | Carbon Avoided **50** kgCO2e; factor snapshot bound |
| **F** | Missing factor | **Carbon Avoided = Not Available** |
| **G** | Sites A 100/1000 m² vs B 80/200 m² | Intensity ranking prefers **B** |
| **H** | Monthly 100×3; annual target 1000 | Expected **1200**; exceedance **200**; budget with tariff |
| **I** | Ref 900 / Post 1050 | Performance **−150**; Verified **0**; total ignores negative |

---

## PHASE_5_FINAL_GATE

| Check | Status |
|-------|--------|
| Full Conservation + core tests | PASS |
| App tests (dashboard/entry/admin) | PASS |
| RLS Phase 5 + Phase 4 recheck | PASS |
| Regression protected metrics | PASS |
| Flags live / enabled count | **0 (OFF)** |
| meter_readings | **43845** |
| physical meters | **35** |
| Phase 4 M&V / reports intact | PASS |
| Phase 3 workflow intact | PASS (suite) |
| Phase 2 analytics intact | PASS (suite) |
| Performance smoke (bounded queries / lazy tabs) | PASS |
| Flags-OFF UX (advanced hidden) | PASS by design |
| MIGRATION_HISTORY_RECONCILIATION_056_062 | Still Open / Deferred |

**PHASE_5_FINAL_GATE = PASS** (pre-commit working-tree gate)

---

## PHASE_5_COMMITTED_FINAL_GATE

Re-run **from committed code** at implementation SHA `70b7f948824926de8762ba8700fd874a3c5f9e33` (not the pre-commit gate).

| Check | Status |
|-------|--------|
| Conservation tests | **224 PASS** |
| smart_meters_core | **343 PASS** |
| dashboard_app | **77 PASS** |
| entry_app | **13 PASS** |
| admin_app | **21 PASS** |
| P5 RLS | **PASS** |
| P4 RLS recheck | **PASS** |
| Regression (`COMPARE_PHASE_5_COMMITTED_FINAL_GATE`) | **PASS** |
| Flags live (`enabled=true`) | **0** |
| meter_readings | **43845** |
| physical meters | **35** |
| Phase 4 M&V suite / report paths | **PASS** (`mv_p4_test` + Example I) |
| Phase 3 workflow smoke | **PASS** (`opportunity_p3_test` in conservation suite) |
| Phase 2 analytics smoke | **PASS** (`balance_p2_test` in conservation suite) |
| Flags-OFF UX smoke | **PASS** (Advanced gated by `advancedOn`; missing flags ⇒ OFF) |
| Empty-state / no fake zeros | **PASS** |
| Git ↔ Staging migrations 081–090 | **PASS** |
| MIGRATION_HISTORY_RECONCILIATION_056_062 | Still Open / Deferred |

**PHASE_5_COMMITTED_FINAL_GATE = PASS**

---

## Stop

Phase 5 is closed in Git. **Phase 6 will not start** until you explicitly approve this report.
