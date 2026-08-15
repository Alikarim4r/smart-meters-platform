-- =============================================================================
-- Attach ≥12 units per category BY CODE (works even if category UUIDs differ)
-- Run in Staging SQL Editor, then reopen Add Meter in Admin.
-- =============================================================================

-- Enum values (safe to re-run)
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

-- WATER by code
insert into public.meter_units (
  category_id, code, name_en, name_ar, unit_to_base_factor, is_base, is_active, sort_order
)
select c.id, v.code, v.name_en, v.name_ar, v.factor, v.is_base, true, v.sort_order
from public.meter_categories c
cross join (
  values
    ('m3', 'Cubic metre (m³)', 'متر مكعب', 1::numeric, true, 1),
    ('liter', 'Litre', 'لتر', 0.001, false, 2),
    ('dm3', 'Cubic decimetre (dm³)', 'دسيمتر مكعب', 0.001, false, 3),
    ('gallon', 'US gallon', 'غالون أمريكي', 0.00378541, false, 4),
    ('ml', 'Millilitre', 'مليلتر', 0.000001, false, 10),
    ('cm3', 'Cubic centimetre (cm³)', 'سنتيمتر مكعب', 0.000001, false, 11),
    ('gal_imp', 'Imperial gallon', 'غالون إمبراطوري', 0.00454609, false, 12),
    ('ft3', 'Cubic foot (ft³)', 'قدم مكعب', 0.0283168466, false, 13),
    ('yd3', 'Cubic yard (yd³)', 'ياردة مكعبة', 0.764554858, false, 14),
    ('bbl', 'Oil barrel (bbl)', 'برميل نفطي', 0.1589872949, false, 15),
    ('acre_ft', 'Acre-foot', 'قدم فدان', 1233.4818375, false, 16),
    ('megalitre', 'Megalitre (ML)', 'ميغا لتر', 1000, false, 17)
) as v(code, name_en, name_ar, factor, is_base, sort_order)
where c.code = 'water'
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_base = excluded.is_base,
  is_active = true,
  sort_order = excluded.sort_order,
  updated_at = now();

-- ELECTRICITY by code
insert into public.meter_units (
  category_id, code, name_en, name_ar, unit_to_base_factor, is_base, is_active, sort_order
)
select c.id, v.code, v.name_en, v.name_ar, v.factor, v.is_base, true, v.sort_order
from public.meter_categories c
cross join (
  values
    ('kwh', 'Kilowatt-hour (kWh)', 'كيلوواط ساعة', 1::numeric, true, 1),
    ('mwh', 'Megawatt-hour (MWh)', 'ميجاواط ساعة', 1000, false, 2),
    ('wh', 'Watt-hour (Wh)', 'واط ساعة', 0.001, false, 3),
    ('kvah', 'Kilovolt-ampere-hour (kVAh)', 'كيلوفولت أمبير ساعة', 1, false, 4),
    ('gwh', 'Gigawatt-hour (GWh)', 'غيغاواط ساعة', 1000000, false, 10),
    ('j', 'Joule', 'جول', 0.0000000002777777778, false, 11),
    ('kj', 'Kilojoule', 'كيلوجول', 0.000277777778, false, 12),
    ('mj', 'Megajoule', 'ميغاجول', 0.277777778, false, 13),
    ('gj', 'Gigajoule', 'غيغاجول', 277.777778, false, 14),
    ('kcal', 'Kilocalorie', 'كيلوكالوري', 0.001163, false, 15),
    ('mvah', 'Megavolt-ampere-hour (MVAh)', 'ميغافولت أمبير ساعة', 1000, false, 16),
    ('therm', 'Therm', 'ثرم', 29.307107, false, 17)
) as v(code, name_en, name_ar, factor, is_base, sort_order)
where c.code = 'electricity'
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_base = excluded.is_base,
  is_active = true,
  sort_order = excluded.sort_order,
  updated_at = now();

-- BTU by code
insert into public.meter_units (
  category_id, code, name_en, name_ar, unit_to_base_factor, is_base, is_active, sort_order
)
select c.id, v.code, v.name_en, v.name_ar, v.factor, v.is_base, true, v.sort_order
from public.meter_categories c
cross join (
  values
    ('kwh_thermal', 'Kilowatt-hour thermal', 'كيلوواط حراري', 1::numeric, true, 1),
    ('btu', 'BTU', 'وحدة حرارية', 0.000293071, false, 2),
    ('ton_hour', 'Ton-hour', 'طن ساعة', 3.51685, false, 3),
    ('rt_hour', 'RT-hour', 'طن تبريد ساعة', 3.51685, false, 4),
    ('gj', 'Gigajoule', 'غيغاجول', 277.777778, false, 5),
    ('mj', 'Megajoule', 'ميغاجول', 0.277777778, false, 10),
    ('kbtu', 'Thousand BTU (kBTU)', 'ألف وحدة حرارية', 0.29307107, false, 11),
    ('mmbtu', 'Million BTU (MMBtu)', 'مليون وحدة حرارية', 293.07107, false, 12),
    ('therm', 'Therm', 'ثرم', 29.307107, false, 13),
    ('wh_thermal', 'Watt-hour thermal', 'واط ساعة حراري', 0.001, false, 14),
    ('kcal', 'Kilocalorie', 'كيلوكالوري', 0.001163, false, 15),
    ('j', 'Joule', 'جول', 0.0000000002777777778, false, 16),
    ('kj', 'Kilojoule', 'كيلوجول', 0.000277777778, false, 17)
) as v(code, name_en, name_ar, factor, is_base, sort_order)
where c.code = 'btu'
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_base = excluded.is_base,
  is_active = true,
  sort_order = excluded.sort_order,
  updated_at = now();

-- FUEL by code
insert into public.meter_units (
  category_id, code, name_en, name_ar, unit_to_base_factor, is_base, is_active, sort_order
)
select c.id, v.code, v.name_en, v.name_ar, v.factor, v.is_base, true, v.sort_order
from public.meter_categories c
cross join (
  values
    ('liter', 'Litre', 'لتر', 1::numeric, true, 1),
    ('gallon', 'US gallon', 'غالون أمريكي', 3.78541, false, 2),
    ('m3', 'Cubic metre (m³)', 'متر مكعب', 1000, false, 3),
    ('ml', 'Millilitre', 'مليلتر', 0.001, false, 10),
    ('dm3', 'Cubic decimetre (dm³)', 'دسيمتر مكعب', 1, false, 11),
    ('gal_imp', 'Imperial gallon', 'غالون إمبراطوري', 4.54609, false, 12),
    ('ft3', 'Cubic foot (ft³)', 'قدم مكعب', 28.3168466, false, 13),
    ('bbl', 'Oil barrel (bbl)', 'برميل نفطي', 158.9872949, false, 14),
    ('us_pint', 'US pint', 'باينت أمريكي', 0.473176473, false, 15),
    ('us_quart', 'US quart', 'كوارت أمريكي', 0.946352946, false, 16),
    ('hectolitre', 'Hectolitre', 'هكتولتر', 100, false, 17),
    ('imperial_pint', 'Imperial pint', 'باينت إمبراطوري', 0.56826125, false, 18)
) as v(code, name_en, name_ar, factor, is_base, sort_order)
where c.code = 'fuel'
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_base = excluded.is_base,
  is_active = true,
  sort_order = excluded.sort_order,
  updated_at = now();

-- Diagnostic: category ids the app uses + unit counts
select c.id, c.code, c.name_en, count(u.*) as units
from public.meter_categories c
left join public.meter_units u on u.category_id = c.id and u.is_active
where c.code in ('water', 'electricity', 'btu', 'fuel')
group by c.id, c.code, c.name_en
order by c.code;
