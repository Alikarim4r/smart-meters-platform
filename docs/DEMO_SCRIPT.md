# Demo Script

**Audience:** MOEHE stakeholders  
**Duration:** ~20 minutes  
**Platform:** macOS desktop (presenter) or Android (field demo)  
**Staging:** `iqcxgtpcfhoapnklxdyl`

---

## Before you start

1. Run dashboard on macOS:
   ```bash
   ./scripts/run_dashboard_macos.sh
   ```
2. Sign in: `test-super-admin@validation.local` (or viewer for read-only demo)
3. Optional: open **Admin** and **Entry** on second screen or device

---

## Act 1 — Platform overview (3 min)

**Dashboard → Sites home**

- Point out unified **navy/gold** branding across apps
- Show **alerts summary** at top (critical/warning/info)
- Search **MOEHE HQ** — note **Demo** badge on showcase site
- Mention: single Supabase backend, role-based access, legacy Firebase untouched

---

## Act 2 — MOEHE HQ deep dive (8 min)

**Open MOEHE HQ → Overview**

- **49 meters** across water, electricity, fuel, BTU
- Set **Chart month** → **March 2026** (imported historical data)
- Toggle period: **Weekly** / **Monthly** — consumption trends from import
- Show **today completion** vs historical context

**Categories tab**

- Water (includes flow meters imported as water)
- Electricity, Fuel, BTU breakdowns
- Month selector → April 2026 category charts

**Meters tab**

- Search sample codes: `1219053`, `CHW-LOOP-1`, `CAP-3000`
- Latest readings and status badges

**Readings tab**

- Filter: **March 2026** → paginated list (~992 rows/month)
- **Load more** for full month
- Show reading notes (import traceability)

**Alerts tab**

- Policy-driven alerts (missing readings, anomalies if configured)

---

## Act 3 — Reports & export (4 min)

**Export icon (site or home)**

- **Site Summary PDF** — Data month anchor: **May 2026**, Period: Monthly
- **Readings Excel** — Mar / Apr / May 2026 separately
- Share / Open on device

Confirm: no errors, file bytes > 0, no `display_name` query failures

---

## Act 4 — Admin & Entry (5 min)

**Admin app** (`./scripts/run_admin_macos.sh`)

- Sites → MOEHE HQ → **Meters** (49 listed, categories correct)
- **Corrections** — audit trail for reading fixes
- **Settings** — policy (photos, alerts, report footer)

**Entry app** (`./scripts/run_entry_macos.sh`)

- Technician flow: Site → Category → Meter → Enter reading
- Show offline indicator and sync behavior (if offline demo desired)

---

## Closing talking points

- Imported **2,944** daily readings from consolidated utility reports (Mar–May 2026)
- Idempotent import — safe to re-run without duplicates
- Android + macOS from same codebase
- Production path: new Supabase project, migrate data, app store deployment

---

## Fallback if network fails

- Use pre-built APK on Android with staging keys baked in at build time
- Show exported PDF/Excel files from earlier run
- Refer to `docs/PROJECT_STATUS.md` for counts and sample meter values
