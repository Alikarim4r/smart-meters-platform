# Staging Closeout

**Date:** 2026-07-11  
**Environment:** `iqcxgtpcfhoapnklxdyl` (hosted Supabase)  
**Goal:** Dashboard / Entry / Admin stable on **limited real** staging data.

---

## Closeout criteria

| Criterion | Target | Status |
|-----------|--------|--------|
| Auth for validation roles | Sign-in + approved profile | Pass |
| Limited MOEHE dataset | Keep ≥ 2026-01-01 only | **Superseded** — full history restored Jul 11 for 5-year charts (~43,862) |
| Dashboard home + site list | No statement timeout | Pass |
| Charts (30d / 12m) on MOEHE | Completes without hang | Pass (~0.3–5s observed) |
| Entry meters list for MOEHE | Loads | Pass (API 49 meters; macOS app launched) |
| Admin sites / users / categories | Loads | Pass (API + macOS; FAB hero tags fixed) |
| Entry Hive lock on dual macOS launch | Single-instance / retry | Pass (init retries lock) |
| Migration `011` indexes | Applied on staging | **Manual — see below** |
| Android install | Device connected | **Skipped — no device** |

---

## Staging data (after prune)

| Item | Value |
|------|-------|
| Site | MOEHE HQ `22222222-2222-4222-8222-222222222222` |
| Meters | 49 |
| Readings | **~43,862** (Feb 2020–Jul 2026; restored for multi-year charts) |
| Date span | **2020-02-17 → 2026-07-11** |
| Other sites | 4 additional sites (unchanged) |

Prune tool (idempotent if already limited):

```bash
export SUPABASE_URL=https://iqcxgtpcfhoapnklxdyl.supabase.co
export SUPABASE_ANON_KEY=<anon>
python3 scripts/prune_staging_moehe_limited.py --dry-run
python3 scripts/prune_staging_moehe_limited.py
```

---

## Smoke results (2026-07-11)

### API (super_admin / site_admin / technician)

- Sign-in + profile: OK  
- Sites list: OK (≤5 sites)  
- MOEHE meters: OK (49)  
- Ranged readings pages: OK  

### Apps (macOS)

- **Dashboard:** launched; chart fetch ~314ms–5s for 30d/12m  
- **Entry / Admin:** launched against same staging project  

### Android

No device connected (`flutter devices` → macOS only). Connect phone and run:

```bash
export SUPABASE_URL=... SUPABASE_ANON_KEY=...
./scripts/run_staging_app.sh dashboard -d <device_id>
./scripts/run_staging_app.sh entry -d <device_id>
./scripts/run_staging_app.sh admin -d <device_id>
```

---

## Apply performance indexes (required once)

Run in Supabase SQL Editor (staging), contents of  
`supabase/migrations/011_meter_consumption_performance.sql`:

```sql
create index if not exists meter_readings_site_date_desc_idx
  on public.meter_readings (site_id, reading_date desc);

create index if not exists meter_readings_meter_date_desc_idx
  on public.meter_readings (meter_id, reading_date desc);
```

Mark this checklist item Pass after indexes exist.

---

## Validation accounts

See `docs/PHASE1C_STAGING_AUTH.md` / `scripts/phase1a_setup_test_users.sql`.

| Email | Role |
|-------|------|
| `test-super-admin@validation.local` | super_admin |
| `test-site-admin@validation.local` | site_admin |
| `test-technician@validation.local` | technician |
| `test-viewer@validation.local` | viewer |

---

## Out of scope for this closeout

- Production Supabase project  
- Removing staging hints / hardcoded MOEHE presets from apps  
- Full historical re-import (use import script only when intentionally stress-testing)  
- CI / signed release builds  

---

## Verdict

**Staging closed for limited-data demo use:** three apps run against staging with a bounded MOEHE reading set.  
Remaining ops item: confirm/apply migration `011` indexes in the SQL editor, then Android smoke when a device is available.

**App cleanup (2026-07-11):** production builds default to `APP_ENV=production` (no validation-account hints). Local staging runs use `scripts/load_env.sh` + `APP_ENV=staging`. See [GRADUAL_LAUNCH.md](GRADUAL_LAUNCH.md).
