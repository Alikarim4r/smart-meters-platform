# Phase 2 Completion Report — Balance / Benchmarking / Periodic Anomalies

**Status: PHASE 2 COMPLETE — PASS (pending user approval before Phase 3)**  
**PHASE_2_FINAL_GATE: PASS**  
**Date (UTC):** 2026-07-29  
**Branch:** `feature/conservation-management`  
**Environment:** Staging (`iqcxgtpcfhoapnklxdyl`)  
**Tag (unchanged):** `pre-conservation-stable`  
**Git commit SHA (Phase 2 implementation):** `78632dcedfbe7de18ab3165de7be7e9cea32a6d6`

**Do not start Phase 3 until this report is explicitly approved.**

---

## Executive Summary

Phase 2 productizes **Water/Energy Balance Difference**, **mechanical reading alignment**, **human Balance classification** (with minimum audit), **site conservation profiles**, **benchmarking / intensity**, and **periodic consumption anomalies** (including a read-only COP deterioration trend hook).

All capabilities sit behind new feature flags (**OFF by default**) plus master `conservation_module`. Phase 1 protections hold: no `meter_readings` mutation, no consumption-helper rewrite, no Entry/Photos/Offline/Corrections/Reports/COP formula changes, and Default Overview unchanged when flags are OFF.

Balance Difference reuses the **P1E `VirtualMeterCalculator`** (`parent_minus_children`) — no second calculator.

---

## Migrations (additive only)

| Version | Name | Content |
|---------|------|---------|
| **067** | `conservation_site_profiles` | `site_conservation_profiles` (m², occupancy, peer_group) — does **not** alter `sites` |
| **068** | `conservation_balance_groups` | Balance groups + members + validate trigger |
| **069** | `conservation_balance_classifications` | Human classification + audit table/triggers |
| **070** | `conservation_balance_group_validate_fix` | REPLACE validate fn (meters has `unit_id`, not `unit_code`) |
| **071** | `conservation_classification_audit_definer` | Audit trigger fns `SECURITY DEFINER` (SELECT-only audit for clients) |

**Apply method:** `npx supabase db query --linked -f …` + insert into `schema_migrations`. **Not** `db push`.  
**056–062:** untouched (`MIGRATION_HISTORY_RECONCILIATION_056_062` remains Open/Deferred).

Staging `migration_max` after Phase 2: **071**.

---

## New tables / columns

| Object | Purpose |
|--------|---------|
| `site_conservation_profiles` | Additive site metadata for benchmarking |
| `conservation_balance_groups` | Main + utility + unit + optional virtual link |
| `conservation_balance_group_members` | Submeter contributors |
| `conservation_balance_classifications` | Human-reviewed classification per group/period |
| `conservation_balance_classification_audit` | who/when/previous/new/notes/evidence |

**Indexes / triggers / functions:** updated_at triggers; group/member validate; classification audit insert/update (definer); RLS with explicit `is_super_admin()` / `is_platform_owner()`.

**Not created:** Opportunities, Savings, Cost/ROI, Conservation PDF/Excel, real-time anomaly tables.

---

## RLS

| Role | Profiles / Balance groups / Classification | Audit |
|------|--------------------------------------------|-------|
| viewer | SELECT in-scope | SELECT in-scope |
| technician | SELECT; **no write** | SELECT |
| site_admin | WRITE on managed sites | via parent write + definer insert |
| super_admin / platform_owner | full | SELECT (+ definer writes) |

Script: `scripts/conservation/p2_rls_validate.sql` → **P2_RLS_RESULT=PASS** (viewer/tech denied writes; site_admin update + audit trail; readings/flags unchanged; fixtures cleaned).

---

## Balance architecture

```
Balance group (main + members) [optional link to P1E virtual parent_minus_children]
  → VirtualMeterCalculator.contributorsFromSeries (existing endpoints)
  → ReadingAlignmentAnalyzer
  → BalanceService.evaluate → BalanceResult
```

Formula:

`Balance Difference = Main Consumption − Σ Submeter Consumption`

Labels only: **Balance Difference** / **Unaccounted Consumption** / **Residual**.  
Never auto: Leak, Leakage, Water Loss, Waste, Saving.

Energy Balance uses the same engine when `utility_code=electricity` and units/hierarchy are compatible; otherwise **Insufficient Data**.

---

## Mechanical reading alignment

`ReadingAlignmentStatus`: **Aligned** | **PartiallyAligned** | **Misaligned** | **InsufficientData**

Compares main/child reading spans within the analysis period (tolerance days). Misaligned / insufficient alignment applies confidence penalties and warnings; Balance is not treated as fully trustworthy when periods are incompatible.

---

## Water balance / Energy balance

| Flag | Gate |
|------|------|
| `water_balance` | module ∧ water_balance |
| `energy_balance` | module ∧ energy_balance |

Dashboard: Balance Difference cards + lightweight hierarchy tree (Source → Main → Submeters → Balance Difference) with missing / low-confidence / misaligned / normal chips.

Admin: `BalanceGroupsAdminScreen` (create/members/classify).

---

## Classification

Allowed human values: Confirmed Leak, Suspected Leak, Meter Error, Reading Error, Unmetered Consumption, Operational Usage, Timing/Alignment Difference, Unknown.

**Confirmed Leak is never auto-assigned** by services; repository `assertHumanReviewed` documents/enforces human review intent for that value.

Minimum audit: previous classification, new classification, who, when, notes, evidence_refs.

---

## Network visualization

Lightweight Conservation tree only (not a rewrite of Utility Network). Existing Utility Network remains the platform graph editor; Balance view shows derived hierarchy status chips.

---

## Benchmarking / intensity / peer groups

| Flag | Role |
|------|------|
| `benchmarking` | Site snapshot + peer warnings |
| `intensity` | kWh/m², m³/m², optional /person |

Missing m²/occupancy → **Normalization Data Missing** (never invent).  
Peer groups: school / office / administrative / large_site / small_site / other.  
Without peer metadata: warning **Not normalized / Different site characteristics**.  
Ranking does **not** treat lowest absolute consumption as “best” without normalization.

---

## Site conservation profile

Admin screen: floor area, occupancy, peer group, notes. Additive table only.

---

## Periodic anomaly engine

Flag: `periodic_anomalies`.

Kinds: unusual increase/decrease, repeated high/low, sudden change, above target, far above baseline, COP declining (via separate flag).

Severity: Info / Low / Medium / High / Critical.  
Low confidence (<60) caps severity at Medium; Critical requires confidence ≥70 else warning: *Low confidence — not a confirmed fault*.  
Labels: **Unusual Consumption** / **Requires Review** — never Confirmed Fault.

---

## COP trend integration

Flag: `cop_conservation`.

`CopConservationTrendService` consumes **already-computed** COP series from existing dashboard COP APIs — **does not change** COP/EER formulas. Detects N consecutive declining valid periods + investigation hints (flow, heat exchanger, condenser, setpoint, data accuracy).

---

## Data Quality / Target / Baseline / Virtual Meter integration

- Reuses P1A completeness/confidence patterns on Balance/Anomaly results.
- Targets (P1C) and Baselines (P1D) feed anomaly variance hooks without reimplementation.
- Virtual Meter calculator (P1E) is the Balance numeric engine.

---

## Feature flags (all OFF on Staging)

| Key | Phase |
|-----|-------|
| `conservation_module` | master (P1) |
| `data_quality` | P1 |
| `period_compare` | P1 |
| `targets` | P1 |
| `baseline` | P1 |
| `virtual_meters` | P1 |
| `water_balance` | P2 |
| `energy_balance` | P2 |
| `benchmarking` | P2 |
| `intensity` | P2 |
| `periodic_anomalies` | P2 |
| `cop_conservation` | P2 |

Live FINAL_GATE: `flags_enabled=0`.

---

## Screens / UI

### Dashboard Conservation (flags OFF → section hidden)

When ON (examples):
- Water / Energy Balance Difference cards (Main, Submeters, Difference, %, Confidence, Alignment, Requires Review)
- Hierarchy status tree
- Benchmark / intensity card
- Anomaly cards
- Existing P1 period / target / baseline / virtual preview sections retained

Default Overview: **unchanged**.

### Admin

- Balance Groups (+ human classification dialog)
- Site Conservation Profile
- Existing Targets / Baselines / Virtual meters links retained

### Entry / Reports

No Conservation functional changes. No new Conservation PDF/Excel.

---

## Tests

| Suite | Result |
|-------|--------|
| Conservation (all, incl. P2) | **133 PASS** |
| `smart_meters_core` | **252 PASS** |
| `dashboard_app` | **77 PASS** |
| `entry_app` | **13 PASS** |
| `admin_app` | **21 PASS** |
| `p2_rls_validate.sql` | **PASS** |
| Dashboard flags-OFF nav smoke | **PASS** (`site_navigation_test`) |

---

## Regression / protected DB comparison

Baseline → `PHASE_2_FINAL_GATE` (`snapshot_PHASE_2_FINAL_GATE_20260729T215421Z.json`):

| Metric | Baseline | Final Gate | Δ |
|--------|---------:|-----------:|---|
| organizations | 1 | 1 | 0 |
| zones | 8 | 8 | 0 |
| sites | 4 | 4 | 0 |
| meters physical | 35 | 35 | 0 |
| meters virtual | 0 | 0 | 0 |
| meter_readings | **43845** | **43845** | **0** |
| reading_photos | 4 | 4 | 0 |
| profiles | 14 | 14 | 0 |
| COP groups/links | unchanged | unchanged | 0 |
| migration_max | 055 | **071** | expected (+063…071) |
| flags enabled | 0 | **0** | OK |

**RESULT: PASS — protected metrics unchanged** (`COMPARE_PHASE_2_FINAL_GATE.md`).

---

## Performance

- Flags OFF → providers short-circuit (no Balance/Benchmark/Anomaly queries).
- Balance: bounded to selected period + group meter IDs only.
- Benchmark: single-site snapshot; peer list bounded (no portfolio-wide query every Overview render).
- Anomalies: bounded history (~6 periods for COP / historical lists).
- Virtual recursion still max depth 8.

**Concerns:** none blocking. Full org peer medians deferred (intentional) to avoid heavy dashboard reads.

---

## Known limitations

- No Opportunity / Investigation / Action workflow (Phase 3).
- No Estimated/Verified Saving, Cost, ROI (Phase 4).
- No Conservation export pack (Phase 4).
- No Night Flow / Hourly / Peak / real-time leak / BMS FDD.
- Peer median across all org sites not fully computed in dashboard (count + warning only).
- Classification evidence is free-form JSON refs (minimum audit — not a full evidence vault).
- Energy Balance only when hierarchy/units suitable.
- `manual_adjustment` still not exposed.
- Mobile Android deploy not run (no device connected at gate time).

---

## Rollback

1. Keep all Conservation flags OFF (current Staging state).
2. Revert app commit `78632dc` if needed.
3. Preserve new tables by default; DROP only with explicit approval.
4. Never delete physical meter/reading data.
5. Tag `pre-conservation-stable` + `docs/STAGING_RESTORE_RUNBOOK.md` remain valid.
6. Do not “fix” 056–062 as part of rollback.

---

## Numeric examples

### A — Valid Water Balance
Main 100 m³ − children (40+30) = **30 m³** Balance Difference / Unaccounted · **30%** · aligned · no Leak label.

### B — Negative Balance Difference
Main 50 − children 80 = **−30** shown as-is + *Negative Balance Difference* investigation warnings (misalignment / hierarchy / multiplier / correction / accuracy). Not Leak.

### C — Misaligned readings
Main span early-month vs child late-month → **Misaligned** (or PartiallyAligned) + confidence penalty + Requires Review; not treated as high-trust Balance.

### D — Benchmark between two valid comparable sites
Both have `floor_area_m2` + same `peer_group` → intensity m³/m² (or kWh/m²) comparable; ranking may use intensity for Best Performing.

### E — Benchmark blocked (missing normalization)
Site without m² → **Normalization Data Missing**; no invented intensity number.

### F — High consumption anomaly
Current 1240 vs baseline 980 → **+26.5%** · farAboveBaseline / unusual increase · High (if confidence adequate) · Requires Review — not Confirmed Fault.

### G — COP deterioration trend
COP series declining for 3 consecutive valid periods → anomaly kind COP declining + investigation hints; COP formula unchanged.

---

## PHASE_2_FINAL_GATE

| Check | Result |
|-------|--------|
| Conservation 133 | PASS |
| smart_meters_core 252 | PASS |
| dashboard_app 77 | PASS |
| entry_app 13 | PASS |
| admin_app 21 | PASS |
| P2 RLS | PASS |
| Regression vs pre-conservation baseline | PASS |
| Flags all OFF | PASS |
| meter_readings = 43845 | PASS |
| physical meters = 35 | PASS |
| Dashboard flags-OFF smoke | PASS |

**PHASE_2_FINAL_GATE = PASS**

Artifacts:
- `docs/regression/snapshot_PHASE_2_FINAL_GATE_20260729T215421Z.json`
- `docs/regression/REGRESSION_PHASE_2_FINAL_GATE_20260729T215421Z.md`
- `docs/regression/COMPARE_PHASE_2_FINAL_GATE.md`

---

## MIGRATION_HISTORY_RECONCILIATION_056_062

**Status: Open / Deferred** — not repaired in Phase 2.

---

## Phase 3 readiness (suggestion only — do not start)

Suggested Phase 3 scope after approval: Opportunity → Investigation → Action → Evidence → Close.  
Do **not** implement until this report is approved.

---

## Stop

**Phase 2 implementation + FINAL_GATE complete.**  
**Awaiting your review of this report.**  
**Do not start Phase 3 until you give explicit approval.**
