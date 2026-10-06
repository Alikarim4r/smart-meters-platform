-- Smart Meters STAGING-ONLY demo helper.
-- Removed from the production migration chain so a fresh production database
-- remains zero-state. Run manually only against a staging database that already
-- contains the legacy Demo Org UUID referenced below.


insert into public.zones (
  id, organization_id, code, name_en, name_ar, description, is_active, sort_order
)
values
  (
    'd1111111-1111-4111-8111-111111111101',
    '11111111-1111-4111-8111-111111111111',
    'north_zone',
    'North Zone',
    'المنطقة الشمالية',
    'Northern schools and facilities',
    true,
    1
  ),
  (
    'd1111111-1111-4111-8111-111111111102',
    '11111111-1111-4111-8111-111111111111',
    'south_zone',
    'South Zone',
    'المنطقة الجنوبية',
    'Southern schools and facilities',
    true,
    2
  ),
  (
    'd1111111-1111-4111-8111-111111111103',
    '11111111-1111-4111-8111-111111111111',
    'central_zone',
    'Central Zone',
    'المنطقة الوسطى',
    'Central schools and facilities',
    true,
    3
  ),
  (
    'd1111111-1111-4111-8111-111111111104',
    '11111111-1111-4111-8111-111111111111',
    'west_zone',
    'West Zone',
    'المنطقة الغربية',
    'Western schools and facilities',
    true,
    4
  )
on conflict (organization_id, code) do update
set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  description = excluded.description,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

-- Government HQ Demo remains without a zone (zone_id null by design).

-- Assign Test School A to North Zone when present (safe optional backfill).
update public.sites
set zone_id = 'd1111111-1111-4111-8111-111111111101'
where name_en = 'Test School A'
  and organization_id = '11111111-1111-4111-8111-111111111111'
  and zone_id is null;
