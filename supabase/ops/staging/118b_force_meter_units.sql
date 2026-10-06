-- =============================================================================
-- FORCE / DIAGNOSE meter units (run in Staging SQL Editor)
-- If counts stay at 3–5, the earlier migration did not land on this project.
-- =============================================================================

-- 1) What you have now
select c.code as category, count(*) as active_units
from public.meter_units u
join public.meter_categories c on c.id = u.category_id
where u.is_active
group by c.code
order by c.code;

-- 2) Re-assert full water catalog (≥12)
insert into public.meter_units (
  id, category_id, code, name_en, name_ar, unit_to_base_factor, is_base, is_active, sort_order
)
values
  ('e1111111-1111-4111-8111-111111111101', 'c1111111-1111-4111-8111-111111111101', 'm3', 'Cubic metre (m³)', 'متر مكعب', 1, true, true, 1),
  ('e1111111-1111-4111-8111-111111111102', 'c1111111-1111-4111-8111-111111111101', 'liter', 'Litre', 'لتر', 0.001, false, true, 2),
  ('e1111111-1111-4111-8111-111111111103', 'c1111111-1111-4111-8111-111111111101', 'dm3', 'Cubic decimetre (dm³)', 'دسيمتر مكعب', 0.001, false, true, 3),
  ('e1111111-1111-4111-8111-111111111104', 'c1111111-1111-4111-8111-111111111101', 'gallon', 'US gallon', 'غالون أمريكي', 0.00378541, false, true, 4),
  ('e1111111-1111-4111-8111-111111111105', 'c1111111-1111-4111-8111-111111111101', 'ml', 'Millilitre', 'مليلتر', 0.000001, false, true, 10),
  ('e1111111-1111-4111-8111-111111111106', 'c1111111-1111-4111-8111-111111111101', 'cm3', 'Cubic centimetre (cm³)', 'سنتيمتر مكعب', 0.000001, false, true, 11),
  ('e1111111-1111-4111-8111-111111111107', 'c1111111-1111-4111-8111-111111111101', 'gal_imp', 'Imperial gallon', 'غالون إمبراطوري', 0.00454609, false, true, 12),
  ('e1111111-1111-4111-8111-111111111108', 'c1111111-1111-4111-8111-111111111101', 'ft3', 'Cubic foot (ft³)', 'قدم مكعب', 0.0283168466, false, true, 13),
  ('e1111111-1111-4111-8111-111111111109', 'c1111111-1111-4111-8111-111111111101', 'yd3', 'Cubic yard (yd³)', 'ياردة مكعبة', 0.764554858, false, true, 14),
  ('e1111111-1111-4111-8111-111111111110', 'c1111111-1111-4111-8111-111111111101', 'bbl', 'Oil barrel (bbl)', 'برميل نفطي', 0.1589872949, false, true, 15),
  ('e1111111-1111-4111-8111-111111111111', 'c1111111-1111-4111-8111-111111111101', 'acre_ft', 'Acre-foot', 'قدم فدان', 1233.4818375, false, true, 16),
  ('e1111111-1111-4111-8111-111111111112', 'c1111111-1111-4111-8111-111111111101', 'megalitre', 'Megalitre (ML)', 'ميغا لتر', 1000, false, true, 17)
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_active = true,
  sort_order = excluded.sort_order,
  updated_at = now();

-- 3) Electricity (≥12)
insert into public.meter_units (
  id, category_id, code, name_en, name_ar, unit_to_base_factor, is_base, is_active, sort_order
)
values
  ('e1111111-1111-4111-8111-111111111201', 'c1111111-1111-4111-8111-111111111102', 'kwh', 'Kilowatt-hour (kWh)', 'كيلوواط ساعة', 1, true, true, 1),
  ('e1111111-1111-4111-8111-111111111202', 'c1111111-1111-4111-8111-111111111102', 'mwh', 'Megawatt-hour (MWh)', 'ميجاواط ساعة', 1000, false, true, 2),
  ('e1111111-1111-4111-8111-111111111203', 'c1111111-1111-4111-8111-111111111102', 'wh', 'Watt-hour (Wh)', 'واط ساعة', 0.001, false, true, 3),
  ('e1111111-1111-4111-8111-111111111204', 'c1111111-1111-4111-8111-111111111102', 'kvah', 'Kilovolt-ampere-hour (kVAh)', 'كيلوفولت أمبير ساعة', 1, false, true, 4),
  ('e1111111-1111-4111-8111-111111111205', 'c1111111-1111-4111-8111-111111111102', 'gwh', 'Gigawatt-hour (GWh)', 'غيغاواط ساعة', 1000000, false, true, 10),
  ('e1111111-1111-4111-8111-111111111206', 'c1111111-1111-4111-8111-111111111102', 'j', 'Joule', 'جول', 0.0000000002777777778, false, true, 11),
  ('e1111111-1111-4111-8111-111111111207', 'c1111111-1111-4111-8111-111111111102', 'kj', 'Kilojoule', 'كيلوجول', 0.000277777778, false, true, 12),
  ('e1111111-1111-4111-8111-111111111208', 'c1111111-1111-4111-8111-111111111102', 'mj', 'Megajoule', 'ميغاجول', 0.277777778, false, true, 13),
  ('e1111111-1111-4111-8111-111111111209', 'c1111111-1111-4111-8111-111111111102', 'gj', 'Gigajoule', 'غيغاجول', 277.777778, false, true, 14),
  ('e1111111-1111-4111-8111-111111111210', 'c1111111-1111-4111-8111-111111111102', 'kcal', 'Kilocalorie', 'كيلوكالوري', 0.001163, false, true, 15),
  ('e1111111-1111-4111-8111-111111111211', 'c1111111-1111-4111-8111-111111111102', 'mvah', 'Megavolt-ampere-hour (MVAh)', 'ميغافولت أمبير ساعة', 1000, false, true, 16),
  ('e1111111-1111-4111-8111-111111111212', 'c1111111-1111-4111-8111-111111111102', 'therm', 'Therm', 'ثرم', 29.307107, false, true, 17)
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_active = true,
  sort_order = excluded.sort_order,
  updated_at = now();

-- 4) BTU / Cooling (≥12)
insert into public.meter_units (
  id, category_id, code, name_en, name_ar, unit_to_base_factor, is_base, is_active, sort_order
)
values
  ('e1111111-1111-4111-8111-111111111301', 'c1111111-1111-4111-8111-111111111103', 'kwh_thermal', 'Kilowatt-hour thermal', 'كيلوواط حراري', 1, true, true, 1),
  ('e1111111-1111-4111-8111-111111111302', 'c1111111-1111-4111-8111-111111111103', 'btu', 'BTU', 'وحدة حرارية', 0.000293071, false, true, 2),
  ('e1111111-1111-4111-8111-111111111303', 'c1111111-1111-4111-8111-111111111103', 'ton_hour', 'Ton-hour', 'طن ساعة', 3.51685, false, true, 3),
  ('e1111111-1111-4111-8111-111111111304', 'c1111111-1111-4111-8111-111111111103', 'rt_hour', 'RT-hour', 'طن تبريد ساعة', 3.51685, false, true, 4),
  ('e1111111-1111-4111-8111-111111111305', 'c1111111-1111-4111-8111-111111111103', 'mj', 'Megajoule', 'ميغاجول', 0.277777778, false, true, 10),
  ('e1111111-1111-4111-8111-111111111306', 'c1111111-1111-4111-8111-111111111103', 'kbtu', 'Thousand BTU (kBTU)', 'ألف وحدة حرارية', 0.29307107, false, true, 11),
  ('e1111111-1111-4111-8111-111111111307', 'c1111111-1111-4111-8111-111111111103', 'mmbtu', 'Million BTU (MMBtu)', 'مليون وحدة حرارية', 293.07107, false, true, 12),
  ('e1111111-1111-4111-8111-111111111308', 'c1111111-1111-4111-8111-111111111103', 'therm', 'Therm', 'ثرم', 29.307107, false, true, 13),
  ('e1111111-1111-4111-8111-111111111309', 'c1111111-1111-4111-8111-111111111103', 'wh_thermal', 'Watt-hour thermal', 'واط ساعة حراري', 0.001, false, true, 14),
  ('e1111111-1111-4111-8111-111111111310', 'c1111111-1111-4111-8111-111111111103', 'kcal', 'Kilocalorie', 'كيلوكالوري', 0.001163, false, true, 15),
  ('e1111111-1111-4111-8111-111111111311', 'c1111111-1111-4111-8111-111111111103', 'j', 'Joule', 'جول', 0.0000000002777777778, false, true, 16),
  ('e1111111-1111-4111-8111-111111111312', 'c1111111-1111-4111-8111-111111111103', 'kj', 'Kilojoule', 'كيلوجول', 0.000277777778, false, true, 17)
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_active = true,
  sort_order = excluded.sort_order,
  updated_at = now();

-- Ensure gj exists on BTU (from earlier migrations)
insert into public.meter_units (
  id, category_id, code, name_en, name_ar, unit_to_base_factor, is_base, is_active, sort_order
)
values
  ('e1111111-1111-4111-8111-111111111313', 'c1111111-1111-4111-8111-111111111103', 'gj', 'Gigajoule', 'غيغاجول', 277.777778, false, true, 5)
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_active = true,
  updated_at = now();

-- 5) Fuel (≥12)
insert into public.meter_units (
  id, category_id, code, name_en, name_ar, unit_to_base_factor, is_base, is_active, sort_order
)
values
  ('e1111111-1111-4111-8111-111111111401', 'c1111111-1111-4111-8111-111111111104', 'liter', 'Litre', 'لتر', 1, true, true, 1),
  ('e1111111-1111-4111-8111-111111111402', 'c1111111-1111-4111-8111-111111111104', 'gallon', 'US gallon', 'غالون أمريكي', 3.78541, false, true, 2),
  ('e1111111-1111-4111-8111-111111111403', 'c1111111-1111-4111-8111-111111111104', 'm3', 'Cubic metre (m³)', 'متر مكعب', 1000, false, true, 3),
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

-- 6) Final counts — each category should be ≥ 12
select c.code as category, count(*) as active_units
from public.meter_units u
join public.meter_categories c on c.id = u.category_id
where u.is_active
group by c.code
order by c.code;
