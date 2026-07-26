# Project Status

**Last updated:** 2026-07-11  
**Environment:** Staging `iqcxgtpcfhoapnklxdyl` (hosted Supabase)  
**Platforms:** Android + macOS desktop (Flutter)

---

## Summary

The Smart Meters Platform is a Supabase-backed replacement for legacy Firebase meter apps. Three Flutter apps share `smart_meters_core`:

| App | Roles | Purpose |
|-----|-------|---------|
| **dashboard_app** | super_admin, site_admin, technician, viewer | Read-only analytics, charts, alerts, exports |
| **entry_app** | technician, site_admin | Daily meter reading entry + offline sync |
| **admin_app** | super_admin, site_admin | Catalog, sites, meters, users, corrections, policy |

Legacy Firebase apps remain **frozen** — not modified.

---

## Completed (demo-ready)

### Backend (staging)
- Migrations 001–010 applied (schema, RLS, configurable categories, policy settings)
- Migration `011` (reading indexes): authored — **apply via SQL Editor if not yet present**
- MOEHE HQ **limited** dataset: **49 meters**, **~4,853 readings** (Jan–Jul 2026)
  - Full historical import was pruned for staging stability (`scripts/prune_staging_moehe_limited.py`)
- Idempotent import script: `scripts/import_moehe_hq_reports.py`
- Session-only auth (anon key); no `service_role` in Flutter
- Closeout checklist: `docs/STAGING_CLOSEOUT.md`

### Dashboard
- Site overview, per-site tabs (Overview, Categories, Meters, Readings, COP, Alerts)
- Historical month filters: March / April / May 2026
- Chart month selector for imported data
- PDF/Excel export (site summary, readings, all-sites)
- Luxury demo theme (navy + gold palette)
- **macOS + Android** builds

### Entry
- Site → category → meter → reading flow
- Offline queue + sync
- Photo capture (policy-driven)
- Shared login/theme polish

### Admin
- Meter catalog, zones, sites, meters, users, corrections, settings
- User approval workflow
- Policy settings UI

---

## Demo showcase site

| Field | Value |
|-------|-------|
| Site | MOEHE HQ |
| site_id | `22222222-2222-4222-8222-222222222222` |
| Meters | 49 (water 28, electricity 13, btu 5, fuel 3) |
| Imported readings | ~4,853 (Jan–Jul 2026, limited staging set) |
| Flow meters | Stored under **water** with traceability in `name_ar` |

---

## Network topology (design direction)

```
┌─────────────────┐     HTTPS (anon + JWT)     ┌──────────────────────┐
│  Flutter apps   │ ─────────────────────────► │  Supabase (staging)  │
│  Android/macOS  │                            │  PostgREST + Auth    │
└────────┬────────┘                            │  Storage (photos)    │
         │                                     └──────────┬───────────┘
         │ offline SQLite (entry only)                    │
         ▼                                                ▼
┌─────────────────┐                            ┌──────────────────────┐
│  Local queue    │                            │  RLS per role/site   │
└─────────────────┘                            └──────────────────────┘

Legacy Firebase apps ──► read-only reference (no changes)
```

Future production: same topology with production Supabase project; optional edge functions for heavy report generation.

---

## Validation accounts (staging)

| Email | Role | Apps |
|-------|------|------|
| test-super-admin@validation.local | super_admin | All |
| test-site-admin@validation.local | site_admin | All |
| test-site-technician@validation.local | technician | Entry, Dashboard |
| test-viewer@validation.local | viewer | Dashboard |

Passwords: see `scripts/phase1a_setup_test_users.sql`.

---

## Known limitations

- Hourly charts not supported
- Custom date-range picker not implemented (month presets cover import window)
- `printing` plugin lacks Swift Package Manager on macOS (warning only; build succeeds)
- Import script may report `meters_updated` on idempotent re-run (metadata refresh)

---

## Related docs

- [STAGING_CLOSEOUT.md](STAGING_CLOSEOUT.md) — staging lock-down checklist
- [DEMO_SCRIPT.md](DEMO_SCRIPT.md) — presentation walkthrough
- [RUN_COMMANDS.md](RUN_COMMANDS.md) — build/run reference
- [NEXT_STEPS.md](NEXT_STEPS.md) — post-demo roadmap
