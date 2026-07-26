-- =============================================================================
-- Staging-only: additional MOEHE HQ test meters for entry_app all-meters workflow
-- Environment: hosted staging (iqcxgtpcfhoapnklxdyl) — NOT production
-- Safe to re-run: idempotent on (site_id, meter_code)
-- Does NOT insert readings — new meters appear as Pending in entry_app
-- =============================================================================

-- MOEHE HQ site: 22222222-2222-4222-8222-222222222222

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
values
  -- Water (sub meters under main Kahramaa water 1219053)
  (
    '33333333-3333-4333-8333-333333333311',
    '22222222-2222-4222-8222-222222222222',
    'WM-IRR-01',
    'Irrigation Water Meter',
    'عداد مياه الري',
    'water', 'kahramaa', 'sub', '33333333-3333-4333-8333-333333333301',
    'physical', 'direct_reading',
    'm3', 1, 'm3', 1, 11, true, true
  ),
  (
    '33333333-3333-4333-8333-333333333312',
    '22222222-2222-4222-8222-222222222222',
    'WM-BOOST-01',
    'Booster Pump Water Meter',
    'عداد مياه المضخة الرافعة',
    'water', 'kahramaa', 'sub', '33333333-3333-4333-8333-333333333301',
    'physical', 'direct_reading',
    'm3', 1, 'm3', 1, 12, true, true
  ),
  (
    '33333333-3333-4333-8333-333333333313',
    '22222222-2222-4222-8222-222222222222',
    'WM-MOSQUE-01',
    'Mosque Water Meter',
    'عداد مياه المسجد',
    'water', 'kahramaa', 'sub', '33333333-3333-4333-8333-333333333301',
    'physical', 'direct_reading',
    'm3', 1, 'm3', 1, 13, true, true
  ),
  (
    '33333333-3333-4333-8333-333333333314',
    '22222222-2222-4222-8222-222222222222',
    'WM-LAND-01',
    'Landscape Water Meter',
    'عداد مياه المناظر الطبيعية',
    'water', 'kahramaa', 'sub', '33333333-3333-4333-8333-333333333301',
    'physical', 'direct_reading',
    'm3', 1, 'm3', 1, 14, true, true
  ),
  (
    '33333333-3333-4333-8333-333333333315',
    '22222222-2222-4222-8222-222222222222',
    'WM-DOM-01',
    'Domestic Water Meter',
    'عداد المياه المنزلية',
    'water', 'kahramaa', 'sub', '33333333-3333-4333-8333-333333333301',
    'physical', 'direct_reading',
    'm3', 1, 'm3', 1, 15, true, true
  ),
  -- Electricity
  (
    '33333333-3333-4333-8333-333333333321',
    '22222222-2222-4222-8222-222222222222',
    'EM-CHILL-01',
    'Chiller Plant Main Electricity Meter',
    'عداد كهرباء محطة التبريد الرئيسي',
    'electricity', 'kahramaa', 'sub', '33333333-3333-4333-8333-333333333302',
    'physical', 'direct_reading',
    'kwh', 1, 'kWh', 1, 21, true, true
  ),
  (
    '33333333-3333-4333-8333-333333333322',
    '22222222-2222-4222-8222-222222222222',
    'EM-LIGHT-01',
    'Lighting Panel Meter',
    'عداد لوحة الإضاءة',
    'electricity', 'kahramaa', 'sub', '33333333-3333-4333-8333-333333333302',
    'physical', 'direct_reading',
    'kwh', 1, 'kWh', 1, 22, true, true
  ),
  (
    '33333333-3333-4333-8333-333333333323',
    '22222222-2222-4222-8222-222222222222',
    'EM-AHU-01',
    'AHU Panel Meter',
    'عداد لوحة وحدة معالجة الهواء',
    'electricity', 'kahramaa', 'sub', '33333333-3333-4333-8333-333333333302',
    'physical', 'direct_reading',
    'kwh', 1, 'kWh', 1, 23, true, true
  ),
  (
    '33333333-3333-4333-8333-333333333324',
    '22222222-2222-4222-8222-222222222222',
    'EM-EXT-LIGHT-01',
    'External Lighting Meter',
    'عداد الإضاءة الخارجية',
    'electricity', 'kahramaa', 'sub', '33333333-3333-4333-8333-333333333302',
    'physical', 'direct_reading',
    'kwh', 1, 'kWh', 1, 24, true, true
  ),
  -- BTU
  (
    '33333333-3333-4333-8333-333333333331',
    '22222222-2222-4222-8222-222222222222',
    'BTU-CHILL-02',
    'Chiller Plant BTU Meter 02',
    'عداد الطاقة الحرارية لمحطة التبريد 02',
    'btu', 'chilled_water', 'sub', '33333333-3333-4333-8333-333333333303',
    'physical', 'direct_reading',
    'kwh_thermal', 1, 'kWh thermal', 1, 31, true, true
  ),
  (
    '33333333-3333-4333-8333-333333333332',
    '22222222-2222-4222-8222-222222222222',
    'BTU-AHU-B1',
    'AHU BTU Meter B1',
    'عداد الطاقة الحرارية لوحدة معالجة الهواء B1',
    'btu', 'chilled_water', 'sub', '33333333-3333-4333-8333-333333333303',
    'physical', 'direct_reading',
    'kwh_thermal', 1, 'kWh thermal', 1, 32, true, true
  ),
  (
    '33333333-3333-4333-8333-333333333333',
    '22222222-2222-4222-8222-222222222222',
    'BTU-AHU-B2',
    'AHU BTU Meter B2',
    'عداد الطاقة الحرارية لوحدة معالجة الهواء B2',
    'btu', 'chilled_water', 'sub', '33333333-3333-4333-8333-333333333303',
    'physical', 'direct_reading',
    'kwh_thermal', 1, 'kWh thermal', 1, 33, true, true
  ),
  (
    '33333333-3333-4333-8333-333333333334',
    '22222222-2222-4222-8222-222222222222',
    'BTU-CRAC-01',
    'CRAC Unit BTU Meter',
    'عداد الطاقة الحرارية لوحدة CRAC',
    'btu', 'chilled_water', 'sub', '33333333-3333-4333-8333-333333333303',
    'physical', 'direct_reading',
    'kwh_thermal', 1, 'kWh thermal', 1, 34, true, true
  )
on conflict (site_id, meter_code) do nothing;
