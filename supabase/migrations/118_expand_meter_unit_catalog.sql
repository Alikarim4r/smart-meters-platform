-- =============================================================================
-- Migration: 118_expand_meter_unit_catalog.sql
-- Expand meter unit dropdowns: ≥10 English-named units per system category
-- (water, electricity, btu, fuel) in meter_units + Phase-2 units/measurement_units.
-- Conversion factors remain relative to each category base_unit_code.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Legacy enum: allow new codes on meters.unit (additive)
-- -----------------------------------------------------------------------------
alter type public.meter_unit add value if not exists 'ml';
alter type public.meter_unit add value if not exists 'cm3';
alter type public.meter_unit add value if not exists 'gal_imp';
alter type public.meter_unit add value if not exists 'ft3';
alter type public.meter_unit add value if not exists 'yd3';
alter type public.meter_unit add value if not exists 'bbl';
alter type public.meter_unit add value if not exists 'acre_ft';
alter type public.meter_unit add value if not exists 'megalitre';
alter type public.meter_unit add value if not exists 'gwh';
alter type public.meter_unit add value if not exists 'j';
alter type public.meter_unit add value if not exists 'kj';
alter type public.meter_unit add value if not exists 'mj';
alter type public.meter_unit add value if not exists 'kcal';
alter type public.meter_unit add value if not exists 'mvah';
alter type public.meter_unit add value if not exists 'therm';
alter type public.meter_unit add value if not exists 'kbtu';
alter type public.meter_unit add value if not exists 'mmbtu';
alter type public.meter_unit add value if not exists 'wh_thermal';
alter type public.meter_unit add value if not exists 'us_pint';
alter type public.meter_unit add value if not exists 'us_quart';
alter type public.meter_unit add value if not exists 'hectolitre';
alter type public.meter_unit add value if not exists 'imperial_pint';

-- -----------------------------------------------------------------------------
-- 2) Rename known volume unit for clarity (English catalog label)
-- -----------------------------------------------------------------------------
update public.meter_units
set name_en = 'Cubic metre (m³)',
    name_ar = coalesce(nullif(name_ar, ''), 'متر مكعب'),
    updated_at = now()
where category_id = 'c1111111-1111-4111-8111-111111111101'
  and code = 'm3';

update public.meter_units
set name_en = 'Cubic decimetre (dm³)',
    name_ar = coalesce(nullif(name_ar, ''), 'دسيمتر مكعب'),
    updated_at = now()
where category_id = 'c1111111-1111-4111-8111-111111111101'
  and code = 'dm3';

update public.meter_units
set name_en = 'Litre',
    updated_at = now()
where category_id = 'c1111111-1111-4111-8111-111111111101'
  and code = 'liter';

update public.meter_units
set name_en = 'US gallon',
    updated_at = now()
where category_id = 'c1111111-1111-4111-8111-111111111101'
  and code = 'gallon';

-- -----------------------------------------------------------------------------
-- 3) Expand meter_units (≥10 per category)
--    Factors relative to category base: water=m3, electricity=kWh,
--    btu=kWh thermal, fuel=liter.
-- -----------------------------------------------------------------------------
insert into public.meter_units (
  id, category_id, code, name_en, name_ar, unit_to_base_factor, is_base, is_active, sort_order
)
values
  -- Water (base m³) — additional
  ('e1111111-1111-4111-8111-111111111105', 'c1111111-1111-4111-8111-111111111101', 'ml', 'Millilitre', 'مليلتر', 0.000001, false, true, 10),
  ('e1111111-1111-4111-8111-111111111106', 'c1111111-1111-4111-8111-111111111101', 'cm3', 'Cubic centimetre (cm³)', 'سنتيمتر مكعب', 0.000001, false, true, 11),
  ('e1111111-1111-4111-8111-111111111107', 'c1111111-1111-4111-8111-111111111101', 'gal_imp', 'Imperial gallon', 'غالون إمبراطوري', 0.00454609, false, true, 12),
  ('e1111111-1111-4111-8111-111111111108', 'c1111111-1111-4111-8111-111111111101', 'ft3', 'Cubic foot (ft³)', 'قدم مكعب', 0.0283168466, false, true, 13),
  ('e1111111-1111-4111-8111-111111111109', 'c1111111-1111-4111-8111-111111111101', 'yd3', 'Cubic yard (yd³)', 'ياردة مكعبة', 0.764554858, false, true, 14),
  ('e1111111-1111-4111-8111-111111111110', 'c1111111-1111-4111-8111-111111111101', 'bbl', 'Oil barrel (bbl)', 'برميل نفطي', 0.1589872949, false, true, 15),
  ('e1111111-1111-4111-8111-111111111111', 'c1111111-1111-4111-8111-111111111101', 'acre_ft', 'Acre-foot', 'قدم فدان', 1233.4818375, false, true, 16),
  ('e1111111-1111-4111-8111-111111111112', 'c1111111-1111-4111-8111-111111111101', 'megalitre', 'Megalitre (ML)', 'ميغا لتر', 1000, false, true, 17),

  -- Electricity (base kWh) — additional
  ('e1111111-1111-4111-8111-111111111205', 'c1111111-1111-4111-8111-111111111102', 'gwh', 'Gigawatt-hour (GWh)', 'غيغاواط ساعة', 1000000, false, true, 10),
  ('e1111111-1111-4111-8111-111111111206', 'c1111111-1111-4111-8111-111111111102', 'j', 'Joule', 'جول', 0.0000000002777777778, false, true, 11),
  ('e1111111-1111-4111-8111-111111111207', 'c1111111-1111-4111-8111-111111111102', 'kj', 'Kilojoule', 'كيلوجول', 0.000277777778, false, true, 12),
  ('e1111111-1111-4111-8111-111111111208', 'c1111111-1111-4111-8111-111111111102', 'mj', 'Megajoule', 'ميغاجول', 0.277777778, false, true, 13),
  ('e1111111-1111-4111-8111-111111111209', 'c1111111-1111-4111-8111-111111111102', 'gj', 'Gigajoule', 'غيغاجول', 277.777778, false, true, 14),
  ('e1111111-1111-4111-8111-111111111210', 'c1111111-1111-4111-8111-111111111102', 'kcal', 'Kilocalorie', 'كيلوكالوري', 0.001163, false, true, 15),
  ('e1111111-1111-4111-8111-111111111211', 'c1111111-1111-4111-8111-111111111102', 'mvah', 'Megavolt-ampere-hour (MVAh)', 'ميغافولت أمبير ساعة', 1000, false, true, 16),
  ('e1111111-1111-4111-8111-111111111212', 'c1111111-1111-4111-8111-111111111102', 'therm', 'Therm', 'ثرم', 29.307107, false, true, 17),

  -- BTU / Cooling (base kWh thermal) — additional
  ('e1111111-1111-4111-8111-111111111306', 'c1111111-1111-4111-8111-111111111103', 'mj', 'Megajoule', 'ميغاجول', 0.277777778, false, true, 10),
  ('e1111111-1111-4111-8111-111111111307', 'c1111111-1111-4111-8111-111111111103', 'kbtu', 'Thousand BTU (kBTU)', 'ألف وحدة حرارية', 0.29307107, false, true, 11),
  ('e1111111-1111-4111-8111-111111111308', 'c1111111-1111-4111-8111-111111111103', 'mmbtu', 'Million BTU (MMBtu)', 'مليون وحدة حرارية', 293.07107, false, true, 12),
  ('e1111111-1111-4111-8111-111111111309', 'c1111111-1111-4111-8111-111111111103', 'therm', 'Therm', 'ثرم', 29.307107, false, true, 13),
  ('e1111111-1111-4111-8111-111111111310', 'c1111111-1111-4111-8111-111111111103', 'wh_thermal', 'Watt-hour thermal', 'واط ساعة حراري', 0.001, false, true, 14),
  ('e1111111-1111-4111-8111-111111111311', 'c1111111-1111-4111-8111-111111111103', 'kcal', 'Kilocalorie', 'كيلوكالوري', 0.001163, false, true, 15),
  ('e1111111-1111-4111-8111-111111111312', 'c1111111-1111-4111-8111-111111111103', 'j', 'Joule', 'جول', 0.0000000002777777778, false, true, 16),
  ('e1111111-1111-4111-8111-111111111313', 'c1111111-1111-4111-8111-111111111103', 'kj', 'Kilojoule', 'كيلوجول', 0.000277777778, false, true, 17),

  -- Fuel (base litre) — additional
  ('e1111111-1111-4111-8111-111111111404', 'c1111111-1111-4111-8111-111111111104', 'ml', 'Millilitre', 'مليلتر', 0.001, false, true, 10),
  ('e1111111-1111-4111-8111-111111111405', 'c1111111-1111-4111-8111-111111111104', 'dm3', 'Cubic decimetre (dm³)', 'دسيمتر مكعب', 1, false, true, 11),
  ('e1111111-1111-4111-8111-111111111406', 'c1111111-1111-4111-8111-111111111104', 'gal_imp', 'Imperial gallon', 'غالون إمبراطوري', 4.54609, false, true, 12),
  ('e1111111-1111-4111-8111-111111111407', 'c1111111-1111-4111-8111-111111111104', 'ft3', 'Cubic foot (ft³)', 'قدم مكعب', 28.3168466, false, true, 13),
  ('e1111111-1111-4111-8111-111111111408', 'c1111111-1111-4111-8111-111111111104', 'bbl', 'Oil barrel (bbl)', 'برميل نفطي', 158.9872949, false, true, 14),
  ('e1111111-1111-4111-8111-111111111409', 'c1111111-1111-4111-8111-111111111104', 'us_pint', 'US pint', 'باينت أمريكي', 0.473176473, false, true, 15),
  ('e1111111-1111-4111-8111-111111111410', 'c1111111-1111-4111-8111-111111111104', 'us_quart', 'US quart', 'كوارت أمريكي', 0.946352946, false, true, 16),
  ('e1111111-1111-4111-8111-111111111411', 'c1111111-1111-4111-8111-111111111104', 'hectolitre', 'Hectolitre', 'هكتولتر', 100, false, true, 17),
  ('e1111111-1111-4111-8111-111111111412', 'c1111111-1111-4111-8111-111111111104', 'imperial_pint', 'Imperial pint', 'باينت إمبراطوري', 0.56826125, false, true, 18)
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_active = true,
  sort_order = excluded.sort_order,
  updated_at = now();

-- Ensure existing fuel gallon label is clear
update public.meter_units
set name_en = 'US gallon',
    updated_at = now()
where category_id = 'c1111111-1111-4111-8111-111111111104'
  and code = 'gallon';

-- -----------------------------------------------------------------------------
-- 4) Phase-2 global units (codes aligned with meter_units where possible)
-- -----------------------------------------------------------------------------
insert into public.units (code, name_en, name_ar, dimension, unit_to_base_factor, sort_order)
values
  -- Volume (base = m³ for dimension catalog)
  ('dm3', 'Cubic decimetre (dm³)', 'دسيمتر مكعب', 'volume', 0.001, 195),
  ('cm3', 'Cubic centimetre (cm³)', 'سنتيمتر مكعب', 'volume', 0.000001, 185),
  ('liter', 'Litre', 'لتر', 'volume', 0.001, 191),
  ('gallon', 'US gallon', 'غالون أمريكي', 'volume', 0.00378541, 211),
  ('gal_imp', 'Imperial gallon', 'غالون إمبراطوري', 'volume', 0.00454609, 212),
  ('yd3', 'Cubic yard (yd³)', 'ياردة مكعبة', 'volume', 0.764554858, 221),
  ('bbl', 'Oil barrel (bbl)', 'برميل نفطي', 'volume', 0.1589872949, 222),
  ('acre_ft', 'Acre-foot', 'قدم فدان', 'volume', 1233.4818375, 223),
  ('megalitre', 'Megalitre (ML)', 'ميغا لتر', 'volume', 1000, 224),
  ('us_pint', 'US pint', 'باينت أمريكي', 'volume', 0.000473176, 225),
  ('us_quart', 'US quart', 'كوارت أمريكي', 'volume', 0.000946353, 226),
  ('hectolitre', 'Hectolitre', 'هكتولتر', 'volume', 0.1, 227),
  ('imperial_pint', 'Imperial pint', 'باينت إمبراطوري', 'volume', 0.000568261, 228),
  -- Energy / electrical extras (base catalog still kWh-oriented names)
  ('kvah', 'Kilovolt-ampere-hour (kVAh)', 'كيلوفولت أمبير ساعة', 'energy', 1, 41),
  ('mvah', 'Megavolt-ampere-hour (MVAh)', 'ميغافولت أمبير ساعة', 'energy', 1000, 42),
  ('kcal', 'Kilocalorie', 'كيلوكالوري', 'energy', 0.001163, 115),
  ('therm', 'Therm', 'ثرم', 'energy', 29.307107, 116),
  ('kwh_thermal', 'Kilowatt-hour thermal', 'كيلوواط ساعة حراري', 'energy', 1, 117),
  ('wh_thermal', 'Watt-hour thermal', 'واط ساعة حراري', 'energy', 0.001, 118),
  ('ton_hour', 'Ton-hour', 'طن ساعة', 'energy', 3.51685, 119),
  ('rt_hour', 'Refrigeration ton-hour (RT-h)', 'طن تبريد ساعة', 'energy', 3.51685, 120)
on conflict (code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  dimension = excluded.dimension,
  unit_to_base_factor = excluded.unit_to_base_factor,
  sort_order = excluded.sort_order,
  is_active = true;

-- Improve English labels on existing volume globals
update public.units set name_en = 'Cubic metre (m³)' where code = 'm3';
update public.units set name_en = 'Cubic foot (ft³)' where code = 'ft3';
update public.units set name_en = 'US gallon' where code = 'gal_us';
update public.units set name_en = 'Millilitre' where code = 'mL';
update public.units set name_en = 'Litre' where code = 'L';

-- -----------------------------------------------------------------------------
-- 5) Wire measurement → unit junctions (≥10 each for volume / energy / thermal)
-- -----------------------------------------------------------------------------
insert into public.measurement_units (measurement_type_id, unit_id, is_default, sort_order)
select mst.id, u.id, u.code in ('m3'), u.sort_order
from public.measurement_types mst
join public.units u on u.code in (
  'mL', 'cm3', 'dm3', 'L', 'liter', 'm3', 'gal_us', 'gallon', 'gal_imp',
  'ft3', 'yd3', 'bbl', 'acre_ft', 'megalitre', 'us_pint', 'us_quart',
  'hectolitre', 'imperial_pint'
)
where mst.code = 'volume'
on conflict do nothing;

insert into public.measurement_units (measurement_type_id, unit_id, is_default, sort_order)
select mst.id, u.id, u.code in ('kWh'), u.sort_order
from public.measurement_types mst
join public.units u on u.code in (
  'Wh', 'kWh', 'MWh', 'GWh', 'J', 'kJ', 'MJ', 'GJ',
  'kvah', 'mvah', 'kcal', 'therm', 'BTU'
)
where mst.code = 'active_energy'
on conflict do nothing;

insert into public.measurement_units (measurement_type_id, unit_id, is_default, sort_order)
select mst.id, u.id, u.code in ('kWh', 'kwh_thermal'), u.sort_order
from public.measurement_types mst
join public.units u on u.code in (
  'J', 'kJ', 'MJ', 'GJ', 'BTU', 'kBTU', 'MMBtu', 'kWh',
  'kwh_thermal', 'wh_thermal', 'ton_hour', 'rt_hour', 'therm', 'kcal'
)
where mst.code = 'thermal_energy'
on conflict do nothing;

-- -----------------------------------------------------------------------------
-- 6) Sync trigger: whitelist expanded legacy enum values
-- -----------------------------------------------------------------------------
create or replace function public.sync_meter_legacy_from_config()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category record;
  v_source record;
  v_unit record;
begin
  if new.category_id is null or new.source_id is null or new.unit_id is null then
    return new;
  end if;

  select code, base_unit_code into v_category
  from public.meter_categories
  where id = new.category_id;

  if not found then
    raise exception 'Invalid category_id %', new.category_id;
  end if;

  select code into v_source
  from public.meter_sources
  where id = new.source_id
    and category_id = new.category_id;

  if not found then
    raise exception 'source_id % does not belong to category_id %', new.source_id, new.category_id;
  end if;

  select code, unit_to_base_factor into v_unit
  from public.meter_units
  where id = new.unit_id
    and category_id = new.category_id;

  if not found then
    raise exception 'unit_id % does not belong to category_id %', new.unit_id, new.category_id;
  end if;

  if v_category.code in ('water', 'electricity', 'btu', 'fuel') then
    new.category := v_category.code::public.meter_category;
  end if;

  if v_source.code in (
    'kahramaa', 'tse', 'ro', 'tanker', 'generator', 'solar',
    'chilled_water', 'cooling_energy', 'other'
  ) then
    new.source := v_source.code::public.meter_source;
  else
    new.source := 'other'::public.meter_source;
  end if;

  if v_unit.code in (
    'm3', 'liter', 'dm3', 'gallon', 'ml', 'cm3', 'gal_imp', 'ft3', 'yd3',
    'bbl', 'acre_ft', 'megalitre',
    'kwh', 'mwh', 'wh', 'kvah', 'gwh', 'j', 'kj', 'mj', 'gj', 'kcal', 'mvah', 'therm',
    'kwh_thermal', 'btu', 'ton_hour', 'rt_hour', 'kbtu', 'mmbtu', 'wh_thermal',
    'us_pint', 'us_quart', 'hectolitre', 'imperial_pint'
  ) then
    begin
      new.unit := v_unit.code::public.meter_unit;
    exception when invalid_text_representation then
      -- Enum lag safety: keep previous / leave unset; factors still applied.
      null;
    end;
  end if;

  new.unit_to_base_factor := v_unit.unit_to_base_factor;
  new.base_unit := v_category.base_unit_code;

  return new;
end;
$$;

comment on function public.sync_meter_legacy_from_config() is
  'Copies category/source/unit catalog codes onto legacy meter columns; unit factors from meter_units.';
