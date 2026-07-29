# Phase 3 Completion Report — Opportunities / Investigation / Actions / Evidence / Close

**Status: PHASE 3 COMPLETE — PASS (pending user approval before Phase 4)**  
**PHASE_3_FINAL_GATE: PASS**  
**Date (UTC):** 2026-07-29  
**Branch:** `feature/conservation-management`  
**Environment:** Staging (`iqcxgtpcfhoapnklxdyl`)  
**Tag (unchanged):** `pre-conservation-stable`  
**Git commit SHA (Phase 3 implementation):** `b99506fa9b7b01db474bff353266735b8d338cd7`

**Do not start Phase 4 until this report is explicitly approved.**

---

## Executive Summary

Phase 3 delivers an end-to-end **Conservation workflow**:

**Signal → Opportunity → Investigation → Action → Evidence → Monitoring / Resolve / Dismiss**

Opportunities represent **potential issues requiring investigation**, not confirmed causes and not savings. Automatic generation is **explicit + idempotent** (fingerprint dedupe); opening the Dashboard does **not** insert rows. Technician writes are **assignment-scoped**. Feature flags stay **OFF by default**. Phase 1/2 analytics remain independent when workflow flags are OFF.

---

## Migrations

| Version | Name | Content |
|---------|------|---------|
| **072** | `conservation_opportunities` | Opportunities + open fingerprint unique index + RLS |
| **073** | `conservation_investigations_actions` | Investigations, Actions, transition guards, RLS |
| **074** | `conservation_evidence_and_audit` | Evidence + append-only `conservation_workflow_audit` + definer append RPC |
| **075** | `conservation_evidence_storage` | Private `conservation-evidence` bucket + storage policies |
| **076** | `conservation_workflow_rls_tighten` | `conservation_site_admin_manages()` — explicit USA site_admin manage (not org-wide scope alone) |

**Apply:** `db query --linked -f` + `schema_migrations` insert. **Not** `db push`.  
**056–062:** untouched (**Open / Deferred**).

Staging `migration_max`: **076**.

---

## Schema

| Table | Role |
|-------|------|
| `conservation_opportunities` | Suggested/manual opportunities; source snapshot; potential excess qty |
| `conservation_investigations` | Assign / findings / **human** confirmed cause |
| `conservation_actions` | Corrective workflow actions (not BMS control) |
| `conservation_evidence` | Photo/note/refs; before/after/general phases (M&V-ready later) |
| `conservation_workflow_audit` | Append-only who/when/from/to/notes |

**Not created:** `conservation_savings`, tariffs, ROI, M&V tables.

---

## RLS

| Role | Opportunities | Investigation / Action | Evidence | Audit |
|------|---------------|------------------------|----------|-------|
| viewer | SELECT in-scope | SELECT | SELECT | SELECT |
| technician | SELECT; no resolve/dismiss | UPDATE if assigned/owner | INSERT if assigned | SELECT |
| site_admin | WRITE via **explicit USA manage** | WRITE in managed sites | manage | SELECT |
| super / platform_owner | full intended | full | full | SELECT (+ definer append) |

Script: `scripts/conservation/p3_rls_validate.sql` → **P3_RLS_RESULT=PASS**.

---

## Storage

- New private bucket: **`conservation-evidence`** (jpeg/png/webp/pdf, 10MB).
- Path: `{org}/{site}/opportunities/{opportunity_id}/…`
- Does **not** mix with `meter-images` reading photos.
- No public access. Storage policies: site access / site_admin manage / tech upload with site access.

---

## Opportunity architecture

| Field | Notes |
|-------|-------|
| origin | `automatic` \| `manual` |
| source_type | anomaly / balance / target / baseline / COP / manual / DQ-conservation |
| source_fingerprint | site + type + entity + period + rule_version |
| source_snapshot | Frozen detection context (versions/values) |
| estimated_waste_quantity | **Potential Excess / Quantity at Risk** — never Saving |
| status | detected → triaged → under_investigation → action_required → monitoring → resolved \| dismissed |

**Signal vs Data Quality:** Missing photo / reading-requires-review are **Data Quality Issues**, not automatic Opportunities (`OpportunitySignalRules`).

---

## Deduplication

Unique index on `(site_id, source_fingerprint)` where status ∉ (`resolved`,`dismissed`).  
`OpportunityGenerationService.refreshForSite`: same open fingerprint → **refresh metadata**; else **create**. No duplicate opens.

---

## Lifecycle

**Opportunity:** detected → triaged → under_investigation → action_required → monitoring → resolved; dismiss with reason; reopen supported (history kept).  
**Investigation:** open → assigned → in_progress → completed \| cancelled.  
**Action:** open → assigned → in_progress → completed \| verification_pending \| cancelled. **DB+Dart block `open → completed`.**

---

## Investigation / Confirmed cause

- Separate investigation records (not a text field on Opportunity).
- `confirmed_cause` requires `confirmed_by` + `confirmed_at` (DB constraint + app rules).
- Never auto-set by anomaly/balance engines.

---

## Actions

Typed list: Inspect Meter, Inspect Pipe/Network, Repair Leak, Correct Reading/Setup, Adjust Schedule, HVAC Maintenance, Adjust Setpoint, Inspect Irrigation, Meter Calibration, Investigate COP, Other.  
Workflow management only — does not change operational systems.

---

## Evidence

Kinds: photo, note, meter reading reference, balance reference, anomaly reference, document link.  
Phases: before / after / general (Phase 4 M&V can consume later — **no Verified Saving now**).

---

## Audit trail

`conservation_workflow_audit` append-only via `conservation_workflow_audit_append` (SECURITY DEFINER). Clients cannot UPDATE/DELETE audit rows.

---

## Technician permissions

**May:** view in-scope; update assigned investigation; progress owned actions; add evidence when assigned.  
**May NOT:** resolve/dismiss opportunities; configure targets/baselines/balance groups/profiles/flags; admin conservation config.

---

## Feature flags (all OFF on Staging)

| Key | Role |
|-----|------|
| `opportunities` | Opportunity list + generate/refresh |
| `investigations` | Investigation UI |
| `actions` | Action dashboard |
| `evidence` | Evidence attach |
| + master `conservation_module` | always required |

Phase 2 analytics flags remain independent.

---

## UI

**Dashboard:** Opportunities section + status chips + cards (Potential Excess) + **manual Refresh opportunities** (never on load).  
**Admin:** Opportunities list/detail (triage, assign, confirm cause, actions, evidence, resolve/dismiss/reopen); Actions screen. Linked from site detail when flags ON.

Default Overview / Entry / Reports / COP formulas: unchanged.

---

## Phase 1/2 integration

Reuses Balance / Anomaly / Actual vs Target / Actual vs Baseline / COP trend results as **signals** only. Does not rewrite P1/P2 engines. Generation bounded to selected analysis period (no historical mass backfill).

---

## Tests

| Suite | Result |
|-------|--------|
| Conservation (all) | **153 PASS** |
| `smart_meters_core` | **272 PASS** |
| `dashboard_app` | **77 PASS** |
| `entry_app` | **13 PASS** |
| `admin_app` | **21 PASS** |
| `p3_rls_validate.sql` | **PASS** |
| Flags-OFF nav smoke | **PASS** |

---

## Regression / protected DB

Baseline → `PHASE_3_FINAL_GATE`:

| Metric | Baseline | Gate | Δ |
|--------|---------:|-----:|---|
| meter_readings | **43845** | **43845** | **0** |
| meters_physical | 35 | 35 | 0 |
| meters_virtual | 0 | 0 | 0 |
| orgs/zones/sites/profiles/COP | unchanged | unchanged | 0 |
| migration_max | 055 | **076** | expected |
| flags_enabled | 0 | **0** | OK |
| opportunities rows | — | **0** | clean |

**RESULT: PASS** (`COMPARE_PHASE_3_FINAL_GATE.md`).

---

## Performance

- Opportunity list bounded (`limit` 50 / pagination support).
- Evidence/audit loaded on detail, not list.
- No auto generate on Overview render.
- No portfolio-wide opportunity backfill.

---

## Known limitations

- No external WhatsApp/email notifications (notification-ready audit/events only).
- No Conservation PDF/Excel export (Phase 4).
- No Estimated/Verified Saving, Cost Avoided, ROI, Payback (Phase 4).
- Admin refresh uses current-period balance/target/baseline signals (not full historical anomaly backfill).
- No Android device connected at gate — mobile install skipped.
- Technician may set confirmed_cause via RLS if assigned; app UX treats confirm as human-reviewed (site_admin primary path).

---

## Rollback

1. Keep workflow flags OFF (current).  
2. Revert Phase 3 app commit.  
3. Preserve tables by default; DROP only with explicit approval.  
4. Never delete physical readings/meters.  
5. Tag + restore runbook remain valid.  
6. Do not repair 056–062.

---

## Workflow examples

### A — Anomaly → suggested Opportunity
`farAboveBaseline` + high confidence → candidate `periodic_anomaly` with Potential Excess = current − baseline; origin automatic.

### B — Duplicate prevention
Same fingerprint while open → refresh snapshot/confidence; **no second row**.

### C — Balance residual → Investigation
Balance Requires Review → Opportunity → site_admin starts Investigation.

### D — Technician assigned → evidence → finding
Assign tech → tech updates finding_summary + inserts note evidence.

### E — Human confirms cause
`confirmed_cause=operational_usage` with `confirmed_by` + `confirmed_at` (not engine).

### F — Corrective action completed
Action open → assigned → in_progress → completed (open→completed blocked).

### G — Monitoring / Resolved
Action done → Opportunity `monitoring` with follow_up window → later `resolved` with resolution reason.

### H — False positive dismissed
Dismiss reason `false_positive` + dismissed_by/at/notes; fingerprint slot freed.

### I — Reopen
Resolved/dismissed → reopen to `detected`/`triaged` without deleting history; new open fingerprint uniqueness applies.

---

## PHASE_3_FINAL_GATE

| Check | Result |
|-------|--------|
| Conservation 153 | PASS |
| smart_meters_core 272 | PASS |
| dashboard / entry / admin | PASS |
| P3 RLS + evidence bucket | PASS |
| Regression vs pre-conservation baseline | PASS |
| Flags OFF | PASS |
| meter_readings 43845 | PASS |
| physical meters 35 | PASS |
| Flags-OFF dashboard smoke | PASS |
| Phase 2 analytics suites still in conservation PASS | PASS |

**PHASE_3_FINAL_GATE = PASS**

Artifacts:
- `docs/regression/snapshot_PHASE_3_FINAL_GATE_20260729T223215Z.json`
- `docs/regression/REGRESSION_PHASE_3_FINAL_GATE_20260729T223215Z.md`
- `docs/regression/COMPARE_PHASE_3_FINAL_GATE.md`

---

## MIGRATION_HISTORY_RECONCILIATION_056_062

**Status: Open / Deferred** — not repaired in Phase 3.

---

## Phase 4 readiness (suggestion only — do not start)

Suggested Phase 4 after approval: Estimated/Verified Saving, Cost/ROI, M&V using before/after evidence + follow-up windows, Conservation reports.

---

## Stop

**Phase 3 implementation + FINAL_GATE complete.**  
**Awaiting your review.**  
**Do not start Phase 4 until you give explicit approval.**
