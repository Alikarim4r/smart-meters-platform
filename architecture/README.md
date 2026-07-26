# Architecture

Planning artifacts for the smart-meters-platform project.

## Documents

| Path | Description |
|------|-------------|
| [../docs/PRODUCT_ARCHITECTURE.md](../docs/PRODUCT_ARCHITECTURE.md) | Product vision, domain model, workflows |
| [../docs/FLUTTER_ARCHITECTURE.md](../docs/FLUTTER_ARCHITECTURE.md) | Flutter apps and shared package plan |
| [../docs/LEGACY_FIREBASE_MIGRATION_PLAN.md](../docs/LEGACY_FIREBASE_MIGRATION_PLAN.md) | Firebase → Supabase migration |
| [../docs/RISKS_AND_DECISIONS.md](../docs/RISKS_AND_DECISIONS.md) | Open decisions and risk register |

## SQL Drafts (not executed)

| Path | Description |
|------|-------------|
| [../supabase/migrations/001_schema.sql](../supabase/migrations/001_schema.sql) | Tables, enums, triggers, audit logs, views |
| [../supabase/migrations/002_rls_policies.sql](../supabase/migrations/002_rls_policies.sql) | Row Level Security + admin RPCs |
| [../supabase/migrations/003_storage.sql](../supabase/migrations/003_storage.sql) | Storage bucket and policies |
| [../supabase/migrations/004_user_approval_enum.sql](../supabase/migrations/004_user_approval_enum.sql) | Approval enums (`approval_status`, `technician_request`) |
| [../supabase/migrations/005_user_approval.sql](../supabase/migrations/005_user_approval.sql) | User approval workflow, RLS gate, admin RPCs |
| [../supabase/migrations/006_configurable_meter_categories.sql](../supabase/migrations/006_configurable_meter_categories.sql) | Configurable meter categories (applied staging 2026-07-04) |
| [../scripts/phase_configurable_categories_validation.sql](../scripts/phase_configurable_categories_validation.sql) | Post-006 validation (draft) |
| [../supabase/seed/001_seed_moehe_hq.sql](../supabase/seed/001_seed_moehe_hq.sql) | MOEHE HQ sample data |

## Status

**Phase 1G — Configurable meter categories live on staging.** Migration `006` applied; entry_app loads categories from `meter_categories` via `MeterCatalogRepository`.

## Legacy Reference

The frozen Firebase prototype is documented at:

`/Users/ali-laptop/Downloads/meters-legacy-stack/STATUS.md`

Do not modify legacy apps:
- water_readings_app
- electricity_readings_app
- meters_dashboard_app
- meters_admin_app
