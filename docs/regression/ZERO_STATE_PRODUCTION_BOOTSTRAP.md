# Zero-State Production Bootstrap Remediation

Date: 2026-10-06
Branch: `release/zero-state-v1`
Target Production project: `smart-meters-production` (`ikcxgxwnuirpyvtnplqk`)

## Purpose

Make the Smart Meters migration chain replayable from an empty database while
keeping Production free of tenant/demo data. These corrections are scoped to
the zero-state release branch and do not rewrite the already-paused Staging
database.

## Migration-history repairs

1. **007 — Demo zones removed from Production migration path**
   - Legacy Demo Org zone inserts and the Test School A backfill were moved to
     `supabase/ops/staging/007_demo_zones.sql`.
   - The versioned Production migration now creates only schema/RLS objects.

2. **041 — stale function revoke removed**
   - Removed the four-argument
     `finalize_legacy_network_cutover(uuid,uuid,boolean,text)` revoke because
     that overload is never created by the versioned chain.
   - The real five-argument function remains revoked from `public` and granted
     only as intended.

3. **056 — return-shape migration made valid**
   - PostgreSQL cannot change OUT/RETURNS TABLE shape with CREATE OR REPLACE.
   - The prior `list_scope_assignees_at(uuid,uuid,uuid)` function is now
     dropped before recreation and its authenticated execute grant is restored.

4. **058/059 — missing tracked migrations restored**
   - Restored `058_ensure_own_pending_profile.sql` and
     `059_report_logos.sql` from Git objects already present in repository
     history.
   - This removes the historical Staging schema-drift dependency that had made
     migration 060 assume columns created only by an out-of-band apply.

5. **118 — unit-catalog UUID collision corrected**
   - BTU supplemental unit UUIDs now begin at suffix 306, preserving suffix 305
     for the existing GJ catalog row created by migration 017.

6. **Non-migrations removed from the migration directory**
   - `118b_force_meter_units.sql` and
     `118c_units_by_category_code.sql` moved to `supabase/ops/staging/`.
   - `118_expand_meter_unit_catalog_VERIFY.sql` moved to
     `supabase/tests/manual/`.

7. **Zero-state seeding disabled**
   - `supabase/config.toml` has `[db.seed] enabled = false` and an empty
     `sql_paths` list.
   - The release checker rejects operational seeds and malformed/duplicate
     migration versions.

## Verification evidence

A completely fresh local Supabase database was started on isolated validation
ports and the entire ordered migration chain replayed successfully through:

`20261002181000_google_play_billing_v1.sql`

Resulting tenant/operational counts:

- organizations: 0
- zones: 0
- sites: 0
- site_tanks: 0
- meters: 0
- meter_readings: 0
- profiles: 0
- user_scope_assignments: 0
- organization_subscriptions: 0

Reference catalogs remained populated as intended:

- meter_categories: 4
- meter_units: 49
- organization_templates: 3
- roles: 9
- permissions: 12
- subscription_plan_catalog: 5

Core tenant tables verified with RLS enabled.

Database regression tests passed:

- production security hardening
- meter rollover consumption (29 assertions)
- platform owner authority (20 assertions)
- subscription security gate (113 assertions)
- Google Play Billing v1 (120 assertions)

Flutter verification passed:

- `smart_meters_core`: 442 tests
- `entry_app`: 20 tests
- `admin_app`: 34 tests
- `dashboard_app`: 80 tests
- total: **576 tests**
- `flutter analyze`: PASS for all four projects

`scripts/check_zero_state_release.py` result:

- `ZERO_STATE_RELEASE=PASS`
- `VERSION=1.0.0+11`
- `OPERATIONAL_SEEDS=0`
- `DEMO_RELEASE_REFERENCES=0`

## Production rule

Do not seed tenant/demo data into Production. Production must start with zero
organizations/sites/meters/readings. Staging-only repair/demo helpers remain
outside `supabase/migrations/`.
