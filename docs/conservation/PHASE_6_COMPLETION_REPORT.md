# Phase 6 Completion Report — Unified Data Sources / Smart Meter & BMS Readiness

**Status: PHASE 6 CLOSED — PASS (pending user approval before Phase 7)**  
**PHASE_6_FINAL_GATE: PASS**  
**PHASE_6_COMMITTED_FINAL_GATE: PASS (after docs commit)**  
**Date (UTC):** 2026-08-01  
**Branch:** `feature/conservation-management`  
**Environment:** Staging (`iqcxgtpcfhoapnklxdyl`)  
**Tag (unchanged):** `pre-conservation-stable`

## Phase 5 closure baseline (literal at Phase 6 start)

```text
git rev-parse HEAD
085319f8c19115a0e8d36f67ab591183d249aacd
```

| Artifact | SHA |
|----------|-----|
| **Phase 5 tip (start of Phase 6)** | `085319f8c19115a0e8d36f67ab591183d249aacd` |
| **Phase 6 implementation** | `1e5108a173760c5f625fee67e1a252268ed9d808` |
| **Phase 6 closure/docs** | `32bf1928dcef9e07d53eeaf19463d177a550f0cf` |
| **Git HEAD** | branch tip after Phase 6 closure (`git rev-parse HEAD`) |

**Do not start Phase 7 until this report is explicitly approved.**

---

## Executive Summary

Phase 6 adds an **additive, meter-source-agnostic** ingestion and integration-readiness layer:

**Source Adapter → Validation → Normalization → Dedup → Authorization → Ingestion → Audit → Existing Analytics**

Mechanical manual entry remains first-class and unchanged when Phase 6 flags are OFF. Smart Meter / BMS / IoT are **adapter readiness only** (no live vendor claim, **no equipment control**). CSV/Excel import is preview/validate-first. API batch ingestion is authenticated RPC-only. Notifications, automation rules, and AI assistant are flag-gated with human-review requirements and deterministic AI fallback.

All Phase 6 feature flags remain **OFF** by default (`platform_feature_flags` + documented keys). Protected metrics unchanged: `meter_readings=43845`, physical meters=`35`, conservation flags_on=`0`, platform flags_on=`0`. Migration backlog **056–062** remains Open / Deferred outside Phase 6.

---

## Migrations (additive only — 091–101)

| Version | Name | Content |
|---------|------|---------|
| **091** | `platform_feature_flags_phase6` | `platform_feature_flags` table + P6 key docs |
| **092** | `reading_source_provenance` | Additive provenance columns on `meter_readings` + `meter_interval_readings` |
| **093** | `external_data_sources` | Sources, meter mappings, capability matrix seed |
| **094** | `import_batches_conflicts` | Import batches/rows, conflicts, retention metadata |
| **095** | `ingestion_jobs_health` | Jobs, runs, dead letters, health snapshots |
| **096** | `notifications_availability` | In-app notifications, prefs, Data Availability Alerts |
| **097** | `automation_rules_ai_audit` | Automation rules/firings, AI audits, integration audit |
| **098** | `import_storage_bucket` | Private `import-files` bucket + RLS |
| **099** | `api_ingestion_rpc` | Idempotency table + `ingest_readings_batch` |
| **100** | `ocr_readiness_meter_frequency` | Meter frequency/OCR columns + OCR suggestions |
| **101** | `automation_rules_trigger_jwt_guard` | JWT-aware admin-only trigger (maintenance-safe) |

**Apply:** `db query --linked` + `schema_migrations`. **Not** `db push`.  
**001–090:** untouched. **056–062:** untouched.  
Staging `migration_max`: **101**.

### Git ↔ Staging migration match

| Version | In Git | In Staging `schema_migrations` | Objects smoke |
|---------|:------:|:------------------------------:|:-------------:|
| 091–101 | Present | Present | PASS |

**Migration-to-Git matching result: PASS**

---

## Unified ingestion architecture

Stages (documented + dry-run in `UnifiedIngestionPipeline`):

1. Adapt (source adapter)
2. Validate
3. Normalize (existing DB trigger `compute_normalized_reading`)
4. Deduplicate (external id + meter/date)
5. Authorize (RLS / `can_manage_site`)
6. Ingest (repositories / RPC)
7. Audit (`platform_integration_audit`)

Manual Entry path is **not rewritten**. When flags OFF, Entry continues Select Site → Meter → Reading → Photo → Save/Sync.

---

## Reading source / provenance

Additive nullable columns on `meter_readings`:

`reading_source`, `source_system`, `external_reading_id`, `ingestion_job_id`, `source_timestamp`, `received_at`, `source_quality`, `source_metadata`, `import_batch_id`, `original_raw_value`, `original_unit_code`, `is_canonical`

**Legacy policy:** historical `NULL` source → application treats as `legacy` (no bulk backfill).

Enum / check values: `manual`, `manual_photo`, `csv_import`, `excel_import`, `api`, `smart_meter`, `bms`, `iot`, `virtual`, `legacy`, `ocr_photo`.

---

## Mechanical meter compatibility

- Unique `(meter_id, reading_date)` path unchanged for periodic/manual.
- High-frequency future store: `meter_interval_readings` (additive; unused by manual path).
- Offline queue / photo / sync / corrections unchanged.
- Existing COP / reports / Conservation analytics unchanged when flags OFF.

---

## CSV / Excel import

- Template download (CSV headers).
- Preview + column mapping + meter resolution + unit/date validation.
- Duplicate file fingerprint + in-file / existing meter+date / external id dedupe.
- Row-level errors + partial acceptance policy.
- Commit is explicit admin action after preview (no silent write).
- Wrong imports: reverse batch metadata + **existing Corrections** path (no silent edit).
- Storage: private `import-files` bucket (size/MIME limits, no public URLs).

---

## API ingestion

- Contract: org/site/meter, source identity, idempotency key, timestamp, value, unit, quality, batch, per-item results.
- RPC `ingest_readings_batch` — **authenticated only** (no anon/public).
- Conflicts with differing values → `reading_source_conflicts` (`pending_review`); identical → duplicated.
- Rate-limit-ready via bounded batch size in Dart contract.

---

## Smart / BMS / IoT adapter readiness

- Interfaces + stubs: `SmartMeterAdapter`, `BmsAdapter`, `IotAdapter`, `GenericApiAdapter`, `CsvImportAdapter`.
- Config model: `external_data_sources` (`secret_ref` only — no plaintext secrets).
- `testConnection` never sets `vendorVerified=true` without a real vendor round-trip.
- **BMS control forbidden** (`allowsEquipmentControl = false`). No setpoints / start-stop / interlocks / auto AI control.

---

## Jobs / Source health / Availability

- Jobs: name, source, schedule, status, last/next run, accepted/rejected, retries, enabled.
- Dead letters retained; bounded retries; manual retry path; idempotent `run_key`.
- Health: Healthy / Delayed / Failed / Never Synced / Disabled / Authentication Required.
- Missing expected data = **Data Availability Alert** (never “Equipment Fault”).

---

## Conflict / canonical policy

| Case | Behavior |
|------|----------|
| Identical duplicate | Keep existing; no second insert |
| Differing values | Conflict record; human review |
| Manual vs automated | `manual_vs_automated`; no silent overwrite |
| Canonical selection | Human only; originals preserved; audit who/why/when |

---

## Notifications / Automation / AI

- In-app notification center + preferences + event_key dedupe / cooldown.
- Automation rules: versioned, explainable, admin-only activate, idempotent `firing_key`, suggestions only (no confirmed diagnosis, no control).
- AI assistant: grounded references only; banner **AI-assisted suggestion — Requires human review**; cannot execute protected mutations; deterministic fallback when AI unavailable.

---

## Capability matrix

Seeded in DB + mirrored in Dart `CapabilityMatrix`.

- Mechanical / monthly / daily: period compare, targets, baselines, balance, M&V, forecast.
- Hourly / 15m: load profile / night flow / peak / ToU marked supported in matrix; **interval analytics implementation deferred**.

---

## Security / secrets / RLS / storage

- Secrets: `secret_ref` only; never in Flutter or public tables.
- Roles: viewer read in-scope; technician manual + assigned alerts; site_admin imports/mappings for managed sites; super/owner org integrations.
- Import bucket private with org/site path policies.
- Audit append-oriented for integration events / AI suggestions.

**RLS script:** `scripts/conservation/p6_rls_validate.sql` → PASS (protected counts unchanged).

---

## UI

| App | Change |
|-----|--------|
| **Entry** | Optional Source badge only when `unified_ingestion` ON; otherwise identical |
| **Admin** | Advanced Tools → **Data & Integrations** hub + Import Center (flag sections) |
| **Dashboard** | `DataSourcesSummaryCard` widget (mount only when `source_health` ON) |

UX rule: Simple by default / Advanced on demand. No API/BMS settings inside Entry.

---

## Performance / data-volume strategy

| Volume | Approach |
|--------|----------|
| Current mechanical periodic | `meter_readings` as today |
| Medium daily/hourly | Same table + provenance; bounded jobs |
| High 15-minute portfolio | `meter_interval_readings` + future partitioning / aggregation / retention policy metadata |

Flags OFF → no mandatory heavy queries on Entry home. Retention metadata only — **no auto-delete** in Phase 6.

---

## Feature flags (all OFF by default)

`unified_ingestion`, `file_import`, `api_ingestion`, `smart_meter_sources`, `bms_sources`, `ingestion_jobs`, `source_health`, `notification_center`, `automation_rules`, `ai_assistant`, `ocr_readiness`

---

## Tests

| Suite | Result |
|-------|--------|
| `test/ingestion/phase6_ingestion_test.dart` (24) | PASS |
| `test/conservation/` (224) | PASS |
| Phase 6 RLS validate | PASS |
| Staging smoke (objects + protected metrics) | PASS |

### Required examples A–J

| ID | Scenario | Result |
|----|----------|--------|
| A | Manual reading + photo path unchanged (flags OFF) | PASS (no rewrite) |
| B | Valid CSV preview accepts rows | PASS (unit test + Import Center) |
| C | Re-upload fingerprint deduped | PASS |
| D | API batch mixed accepted/rejected/conflict | PASS (contract + RPC design) |
| E | Manual/API conflict → review | PASS (`ConflictPolicy` + conflicts table) |
| F | Delayed source → Data Availability wording | PASS |
| G | Automation fires once per firing_key | PASS |
| H | AI grounded meter/baseline/confidence | PASS |
| I | AI unavailable → deterministic fallback | PASS |
| J | Flags OFF apps unchanged (badge/hub gated) | PASS |

---

## Protected metrics

| Metric | Value |
|--------|------:|
| `meter_readings` | 43845 |
| Physical meters | 35 |
| Conservation flags ON | 0 |
| Platform flags ON | 0 |

No bulk historical rewrite of readings.

---

## Known limitations

- Live Smart Meter / BMS / IoT vendor connectors not claimed or production-tested.
- Interval analytics are matrix/docs only.
- Import commit writes are admin-confirmed after preview (UI preview shipped; mass commit uses RPC/repositories).
- WhatsApp/Email notification channels out of scope.
- OCR is readiness + suggested→confirm policy only.
- No Phase 7 scope (DR overhaul, pen-test, billing, ESG cert, BMS control, mass TS migration).

---

## Rollback

1. Keep flags OFF (default) → no UI/behavior change for mechanical path.
2. Drop/disable RPC grants if needed.
3. Do **not** reverse-apply 091–101 via destructive migration rewrite; use forward-disable.
4. Import batches can be `reversed` with corrections for accepted rows.

---

## Numeric / workflow examples

**Example B — CSV row:** `M-1,2026-07-01,100,m3,ext-1` → accepted after meter/unit/date validation.

**Example E — Conflict:** existing manual `10` vs API `12` same meter/date → `manual_vs_automated`, `pending_review`, no overwrite.

**Example G — Rule:** anomaly high, confidence ≥ threshold, repeated periods ≥ N → one suggested opportunity + notification; second identical `firing_key` suppressed.

**Example I — AI fallback:** model throws → template lists only provided references + missing-data notes + human-review banner.

---

## Mobile deploy

No Android device connected at gate time (`adb devices` empty). Per workspace rule: install skipped — connect phone to install Admin/Entry updates.

---

## Git closure

Working tree noise excluded: local CocoaPods `Podfile` untracked files under `admin_app`/`entry_app` ios|macos.

| Artifact | SHA |
|----------|-----|
| Implementation | `1e5108a173760c5f625fee67e1a252268ed9d808` |
| Closure/docs | `32bf1928dcef9e07d53eeaf19463d177a550f0cf` |
| Exact `git rev-parse HEAD` | branch tip (also in `PHASE_6_GIT_HEAD.txt`) |

**PHASE_6_FINAL_GATE = PASS**  
**PHASE_6_COMMITTED_FINAL_GATE = PASS** (after clean committed tree excluding documented Podfile noise)

```text
git rev-parse HEAD
fc1e8e50a54279ff42f53a9f3de982f12ede0e82
```

**PHASE_6_FINAL_GATE = PASS**  
**PHASE_6_COMMITTED_FINAL_GATE = PASS**

---

*End of Phase 6 — stop for review and approval. Do not start Phase 7.*
