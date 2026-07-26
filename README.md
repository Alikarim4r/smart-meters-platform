# Smart Meters Platform

Supabase-backed multi-site smart meters platform. Phase 1C adds Flutter app scaffolding only.

## Repository layout

```
smart-meters-platform/
├── apps/
│   ├── admin_app/       # super_admin, site_admin
│   ├── entry_app/       # technician, site_admin (write)
│   └── dashboard_app/   # all roles (read)
├── packages/
│   └── smart_meters_core/   # shared auth, models, theme
├── supabase/            # migrations, seed
├── scripts/             # SQL validation, staging run helper
└── docs/
```

## Prerequisites

- Flutter 3.x (stable)
- Supabase staging project linked (`iqcxgtpcfhoapnklxdyl`)
- Staging validation users (see `scripts/phase1a_setup_test_users.sql`)

## Run against staging

See [docs/PHASE1C_STAGING_AUTH.md](docs/PHASE1C_STAGING_AUTH.md).

```bash
export SUPABASE_URL=https://iqcxgtpcfhoapnklxdyl.supabase.co
export SUPABASE_ANON_KEY=<anon-key-from-dashboard>

./scripts/run_staging_app.sh entry
```

## Legacy Firebase apps

Frozen — do not modify `water_readings_app`, `electricity_readings_app`, `meters_dashboard_app`, `meters_admin_app`.

## Documentation

- [Project status](docs/PROJECT_STATUS.md)
- [Demo script](docs/DEMO_SCRIPT.md)
- [Run commands](docs/RUN_COMMANDS.md)
- [Next steps](docs/NEXT_STEPS.md)
- [Product architecture](docs/PRODUCT_ARCHITECTURE.md)
- [Flutter architecture](docs/FLUTTER_ARCHITECTURE.md)
- [Phase 1A validation](docs/PHASE1A_VALIDATION_STEPS.md)
- [Phase 1C staging auth](docs/PHASE1C_STAGING_AUTH.md)
