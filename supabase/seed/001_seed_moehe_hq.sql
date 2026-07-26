-- =============================================================================
-- Smart Meters Platform — Seed Data Draft
-- Seed: 001_seed_moehe_hq.sql
-- Status: DRAFT — DO NOT EXECUTE without approval
-- Depends on: 001_schema.sql, 002_rls_policies.sql
-- =============================================================================
--
-- Sample data for Ministry of Education and Higher Education HQ.
-- Uses fixed UUIDs for cross-reference in docs and migration scripts.
--
-- NOTE: Profiles require auth.users rows. This seed inserts org/site/meters/COP
-- only. User seeding is a separate step after auth users are created.
-- =============================================================================

-- Fixed UUIDs for reproducibility
-- Organization
--   11111111-1111-4111-8111-111111111111  MOEHE
-- Site
--   22222222-2222-4222-8222-222222222222  MOEHE HQ
-- Meters
--   33333333-3333-4333-8333-333333333301  Main Kahramaa water (physical)
--   33333333-3333-4333-8333-333333333302  Main electricity (physical)
--   33333333-3333-4333-8333-333333333303  Main chilled water BTU (physical)
--   33333333-3333-4333-8333-333333333304  Water Features WF (virtual, future — commented)
-- COP Group
--   44444444-4444-4444-8444-444444444444  Chiller Plant COP

begin;

-- -----------------------------------------------------------------------------
-- Organization
-- -----------------------------------------------------------------------------

insert into public.organizations (id, name_en, name_ar, is_active)
values (
  '11111111-1111-4111-8111-111111111111',
  'Ministry of Education and Higher Education',
  'وزارة التعليم والتعليم العالي',
  true
)
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Site
-- -----------------------------------------------------------------------------

insert into public.sites (
  id,
  organization_id,
  name_en,
  name_ar,
  site_type,
  location,
  is_active
)
values (
  '22222222-2222-4222-8222-222222222222',
  '11111111-1111-4111-8111-111111111111',
  'MOEHE HQ',
  'مقر وزارة التعليم والتعليم العالي',
  'headquarters',
  'Doha, Qatar',
  true
)
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Meters
-- -----------------------------------------------------------------------------

-- Water: Main Kahramaa meter (legacy code 1219053)
insert into public.meters (
  id,
  site_id,
  meter_code,
  name_en,
  name_ar,
  category,
  source,
  level,
  parent_meter_id,
  meter_kind,
  calculation_type,
  unit,
  unit_to_base_factor,
  base_unit,
  meter_multiplier,
  sort_order,
  is_active,
  include_in_dashboard
)
values (
  '33333333-3333-4333-8333-333333333301',
  '22222222-2222-4222-8222-222222222222',
  '1219053',
  'Main Kahramaa Water Meter',
  'عداد المياه الرئيسي - كهرماء',
  'water',
  'kahramaa',
  'main',
  null,
  'physical',
  'direct_reading',
  'm3',
  1,
  'm3',
  1,
  10,
  true,
  true
)
on conflict (id) do nothing;

-- Electricity: Main meter (legacy LVP-MAIN aggregate reference)
insert into public.meters (
  id,
  site_id,
  meter_code,
  name_en,
  name_ar,
  category,
  source,
  level,
  parent_meter_id,
  meter_kind,
  calculation_type,
  unit,
  unit_to_base_factor,
  base_unit,
  meter_multiplier,
  sort_order,
  is_active,
  include_in_dashboard
)
values (
  '33333333-3333-4333-8333-333333333302',
  '22222222-2222-4222-8222-222222222222',
  'LVP-MAIN',
  'Main Electricity Meter',
  'عداد الكهرباء الرئيسي',
  'electricity',
  'kahramaa',
  'main',
  null,
  'physical',
  'direct_reading',
  'kwh',
  1,
  'kWh',
  1,
  20,
  true,
  true
)
on conflict (id) do nothing;

-- BTU: Main chilled water meter
insert into public.meters (
  id,
  site_id,
  meter_code,
  name_en,
  name_ar,
  category,
  source,
  level,
  parent_meter_id,
  meter_kind,
  calculation_type,
  unit,
  unit_to_base_factor,
  base_unit,
  meter_multiplier,
  sort_order,
  is_active,
  include_in_dashboard
)
values (
  '33333333-3333-4333-8333-333333333303',
  '22222222-2222-4222-8222-222222222222',
  'BTU-MAIN-01',
  'Main Chilled Water BTU Meter',
  'عداد الطاقة الحرارية للمياه المبردة الرئيسي',
  'btu',
  'chilled_water',
  'main',
  null,
  'physical',
  'direct_reading',
  'kwh_thermal',
  1,
  'kWh thermal',
  1,
  30,
  true,
  true
)
on conflict (id) do nothing;

-- Virtual meter example (legacy WF — uncomment when sub-meters are seeded):
-- insert into public.meters (
--   id, site_id, meter_code, name_en, name_ar,
--   category, source, level, parent_meter_id,
--   meter_kind, calculation_type,
--   unit, unit_to_base_factor, base_unit, meter_multiplier,
--   sort_order, is_active, include_in_dashboard
-- ) values (
--   '33333333-3333-4333-8333-333333333304',
--   '22222222-2222-4222-8222-222222222222',
--   'WF',
--   'Water Features (Residual)',
--   'ميزات المياه (متبقي)',
--   'water', 'kahramaa', 'sub',
--   '33333333-3333-4333-8333-333333333301',
--   'virtual', 'parent_minus_children',
--   'm3', 1, 'm3', 1,
--   99, true, true
-- );

-- -----------------------------------------------------------------------------
-- COP Group: Chiller Plant COP
-- Links sample BTU meter → sample electricity meter
-- -----------------------------------------------------------------------------

insert into public.cop_groups (
  id,
  site_id,
  name_en,
  name_ar,
  description,
  is_active
)
values (
  '44444444-4444-4444-8444-444444444444',
  '22222222-2222-4222-8222-222222222222',
  'Chiller Plant COP',
  'معامل أداء محطة التبريد',
  'Simple COP group linking main chilled water BTU output to main electricity input.',
  true
)
on conflict (id) do nothing;

insert into public.cop_group_btu_meters (cop_group_id, meter_id, weight)
values (
  '44444444-4444-4444-8444-444444444444',
  '33333333-3333-4333-8333-333333333303',
  1
)
on conflict (cop_group_id, meter_id) do nothing;

insert into public.cop_group_electricity_meters (cop_group_id, meter_id, weight)
values (
  '44444444-4444-4444-8444-444444444444',
  '33333333-3333-4333-8333-333333333302',
  1
)
on conflict (cop_group_id, meter_id) do nothing;

-- -----------------------------------------------------------------------------
-- Sample readings (optional baseline — uncomment after approval)
-- -----------------------------------------------------------------------------

-- insert into public.meter_readings (site_id, meter_id, reading_date, raw_value, normalized_value, note)
-- values
--   ('22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333301', '2026-07-01', 125000.0, 125000.0, 'Seed baseline'),
--   ('22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333302', '2026-07-01', 450000.0, 450000.0, 'Seed baseline'),
--   ('22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333303', '2026-07-01', 8500.0, 8500.0, 'Seed baseline');

commit;

-- -----------------------------------------------------------------------------
-- Post-seed: create super_admin user (manual step)
-- -----------------------------------------------------------------------------
--
-- 1. Create user in Supabase Auth dashboard or via Admin API
-- 2. Update profile role:
--    update public.profiles set role = 'super_admin' where email = 'admin@moehe.gov.qa';
-- 3. Optionally assign site access for non-super users:
--    insert into public.user_site_access (user_id, site_id, role, can_read, can_write, can_manage_meters)
--    values ('<user-uuid>', '22222222-2222-4222-8222-222222222222', 'technician', true, true, false);
-- -----------------------------------------------------------------------------
