# Project Status

**Last updated:** 2026-08-06  
**Branch:** `hardening/pre-production-20260804`  
**Environment:** Staging Supabase `iqcxgtpcfhoapnklxdyl`  
**Production:** Not promoted yet  
**Platforms:** Android · iOS · macOS · Web · Windows · Linux (Flutter)

---

## Summary

The Smart Meters Platform is a Supabase-backed replacement for legacy Firebase meter apps. Three Flutter apps share `smart_meters_core`:

| App | Roles | Purpose |
|-----|-------|---------|
| **dashboard_app** | super_admin, site_admin, technician, viewer | Analytics, charts, alerts, reports, Conservation |
| **entry_app** | technician, site_admin | Field readings, photos, offline sync |
| **admin_app** | super_admin, site_admin | Catalog, network, users, import, Conservation admin |

Legacy Firebase apps remain **frozen** — not modified.

---

## Current readiness

| Gate | Status |
|------|--------|
| Conservation Phases 1–6 | Closed (PASS) |
| Pre-production hardening (115–117) | Applied on Staging |
| Notifications shade + Android widgets | Shipped on Staging |
| Phase 7 UX | Implemented (tabs, AR i18n, numbers, Source Health empty state) |
| Production Supabase / store signing | **Not started** — requires explicit operator cutover |

Official detail: [PROJECT_HEALTH_REPORT_2026-08-05.md](./PROJECT_HEALTH_REPORT_2026-08-05.md) · [PRE_PRODUCTION_HARDENING_2026-08-04.md](./PRE_PRODUCTION_HARDENING_2026-08-04.md)

---

## Staging showcase

| Field | Value |
|-------|-------|
| Site | MOEHE HQ |
| site_id | `22222222-2222-4222-8222-222222222222` |
| Portal | https://alikarim4r.github.io/smart-meters-platform/ |

---

## Architecture

```
┌─────────────────┐     HTTPS (anon + JWT)     ┌──────────────────────┐
│  Flutter apps   │ ─────────────────────────► │  Supabase (staging)  │
│  multi-platform │                            │  PostgREST + Auth    │
└────────┬────────┘                            │  Storage (photos)    │
         │                                     └──────────┬───────────┘
         │ offline (entry; user+APP_ENV isolated)         │
         ▼                                                ▼
┌─────────────────┐                            ┌──────────────────────┐
│  Local drafts   │                            │  RLS per role/site   │
└─────────────────┘                            └──────────────────────┘
```

---

## Security posture (Staging)

- No baked production secrets; clients use anon key + RLS  
- Staging verification passwords live in Keychain / local `.env.local` only  
- Soft archival replaces force-delete (migration 116)  
- Review/demo feature flags remain operator-controlled — not auto-disabled  

---

*End of status — 2026-08-06.*
