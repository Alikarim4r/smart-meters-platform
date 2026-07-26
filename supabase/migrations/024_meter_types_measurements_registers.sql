-- =============================================================================
-- Migration: 024_meter_types_measurements_registers.sql
-- Phase 2 meter catalog (additive — keep meter_categories/units/sources):
-- meter_types, measurement_types, units (global), junction tables,
-- meter_registers, meters.meter_type_id, meter_readings.register_id
-- =============================================================================

-- 1) Core catalog tables ------------------------------------------------------
create table if not exists public.meter_types (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  name_en     text not null,
  name_ar     text not null,
  icon        text,
  color       text,
  is_system   boolean not null default false,
  is_active   boolean not null default true,
  sort_order  integer not null default 0,
  legacy_category_id uuid references public.meter_categories (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint meter_types_code_not_empty check (char_length(trim(code)) > 0)
);

create table if not exists public.measurement_types (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  name_en     text not null,
  name_ar     text not null,
  dimension   text not null, -- energy | volume | mass | flow | pressure | temperature | level | power | percent | other
  is_active   boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.units (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique,
  name_en         text not null,
  name_ar         text not null,
  dimension       text not null,
  unit_to_base_factor numeric not null default 1,
  offset_to_base  numeric not null default 0,
  ref_pressure_kpa numeric,
  ref_temperature_c numeric,
  is_active       boolean not null default true,
  sort_order      integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table if not exists public.meter_type_measurements (
  id                  uuid primary key default gen_random_uuid(),
  meter_type_id       uuid not null references public.meter_types (id) on delete cascade,
  measurement_type_id uuid not null references public.measurement_types (id) on delete cascade,
  is_primary          boolean not null default false,
  sort_order          integer not null default 0,
  unique (meter_type_id, measurement_type_id)
);

create table if not exists public.measurement_units (
  id                  uuid primary key default gen_random_uuid(),
  measurement_type_id uuid not null references public.measurement_types (id) on delete cascade,
  unit_id             uuid not null references public.units (id) on delete cascade,
  is_default          boolean not null default false,
  sort_order          integer not null default 0,
  unique (measurement_type_id, unit_id)
);

create table if not exists public.meter_registers (
  id                  uuid primary key default gen_random_uuid(),
  meter_id            uuid not null references public.meters (id) on delete cascade,
  measurement_type_id uuid not null references public.measurement_types (id) on delete restrict,
  unit_id             uuid not null references public.units (id) on delete restrict,
  name_en             text,
  name_ar             text,
  is_primary          boolean not null default false,
  is_active           boolean not null default true,
  sort_order          integer not null default 0,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create unique index if not exists meter_registers_one_primary_idx
  on public.meter_registers (meter_id)
  where is_primary;

alter table public.meters
  add column if not exists meter_type_id uuid
    references public.meter_types (id) on delete set null;

alter table public.meter_readings
  add column if not exists register_id uuid
    references public.meter_registers (id) on delete set null;

create index if not exists meters_meter_type_id_idx on public.meters (meter_type_id);
create index if not exists meter_readings_register_id_idx on public.meter_readings (register_id);
create index if not exists meter_registers_meter_id_idx on public.meter_registers (meter_id);

create trigger meter_types_set_updated_at
  before update on public.meter_types
  for each row execute function public.set_updated_at();
create trigger meter_registers_set_updated_at
  before update on public.meter_registers
  for each row execute function public.set_updated_at();

-- 2) Seed measurement types ---------------------------------------------------
insert into public.measurement_types (code, name_en, name_ar, dimension, sort_order) values
  ('active_energy', 'Active energy', 'طاقة فعالة', 'energy', 10),
  ('reactive_energy', 'Reactive energy', 'طاقة غير فعالة', 'energy', 20),
  ('power', 'Power / demand', 'قدرة / طلب', 'power', 30),
  ('voltage', 'Voltage', 'جهد', 'other', 40),
  ('current', 'Current', 'تيار', 'other', 50),
  ('volume', 'Volume', 'حجم', 'volume', 60),
  ('mass', 'Mass', 'كتلة', 'mass', 70),
  ('volume_flow', 'Volumetric flow', 'معدل تدفق حجمي', 'flow', 80),
  ('mass_flow', 'Mass flow', 'معدل تدفق كتلي', 'flow', 90),
  ('pressure', 'Pressure', 'ضغط', 'pressure', 100),
  ('temperature', 'Temperature', 'درجة حرارة', 'temperature', 110),
  ('delta_t', 'Temperature difference', 'فرق حرارة', 'temperature', 120),
  ('level', 'Level', 'مستوى', 'level', 130),
  ('percent', 'Percentage', 'نسبة مئوية', 'percent', 140),
  ('thermal_energy', 'Thermal energy', 'طاقة حرارية', 'energy', 150)
on conflict (code) do nothing;

-- 3) Seed units (subset covering current platform + planned catalog) ----------
insert into public.units (code, name_en, name_ar, dimension, unit_to_base_factor, sort_order) values
  ('Wh', 'Watt-hour', 'واط·ساعة', 'energy', 0.001, 10),
  ('kWh', 'Kilowatt-hour', 'كيلوواط·ساعة', 'energy', 1, 20),
  ('MWh', 'Megawatt-hour', 'ميغاواط·ساعة', 'energy', 1000, 30),
  ('GWh', 'Gigawatt-hour', 'غيغاواط·ساعة', 'energy', 1000000, 40),
  ('J', 'Joule', 'جول', 'energy', 1, 50),
  ('kJ', 'Kilojoule', 'كيلوجول', 'energy', 1000, 60),
  ('MJ', 'Megajoule', 'ميغاجول', 'energy', 1000000, 70),
  ('GJ', 'Gigajoule', 'غيغاجول', 'energy', 1000000000, 80),
  ('BTU', 'British thermal unit', 'وحدة حرارية بريطانية', 'energy', 1055.06, 90),
  ('kBTU', 'Thousand BTU', 'ألف BTU', 'energy', 1055060, 100),
  ('MMBtu', 'Million BTU', 'مليون BTU', 'energy', 1055060000, 110),
  ('kW', 'Kilowatt', 'كيلوواط', 'power', 1, 120),
  ('MW', 'Megawatt', 'ميغاواط', 'power', 1000, 130),
  ('V', 'Volt', 'فولت', 'other', 1, 140),
  ('kV', 'Kilovolt', 'كيلوفولت', 'other', 1000, 150),
  ('A', 'Ampere', 'أمبير', 'other', 1, 160),
  ('kA', 'Kiloampere', 'كيلوأمبير', 'other', 1000, 170),
  ('mL', 'Millilitre', 'مليلتر', 'volume', 0.000001, 180),
  ('L', 'Litre', 'لتر', 'volume', 0.001, 190),
  ('m3', 'Cubic metre', 'متر مكعب', 'volume', 1, 200),
  ('gal_us', 'US gallon', 'غالون أمريكي', 'volume', 0.00378541, 210),
  ('ft3', 'Cubic foot', 'قدم مكعب', 'volume', 0.0283168, 220),
  ('g', 'Gram', 'غرام', 'mass', 0.001, 230),
  ('kg', 'Kilogram', 'كيلوغرام', 'mass', 1, 240),
  ('t', 'Tonne', 'طن', 'mass', 1000, 250),
  ('L_s', 'Litre per second', 'لتر/ثانية', 'flow', 1, 260),
  ('m3_h', 'Cubic metre per hour', 'م³/ساعة', 'flow', 1, 270),
  ('Pa', 'Pascal', 'باسكال', 'pressure', 1, 280),
  ('kPa', 'Kilopascal', 'كيلوباسكال', 'pressure', 1000, 290),
  ('bar', 'Bar', 'بار', 'pressure', 100000, 300),
  ('psi', 'PSI', 'رطل/بوصة²', 'pressure', 6894.76, 310),
  ('C', 'Celsius', 'مئوية', 'temperature', 1, 320),
  ('F', 'Fahrenheit', 'فهرنهايت', 'temperature', 1, 330),
  ('K', 'Kelvin', 'كلفن', 'temperature', 1, 340),
  ('mm', 'Millimetre', 'مليمتر', 'level', 0.001, 350),
  ('cm', 'Centimetre', 'سنتيمتر', 'level', 0.01, 360),
  ('m', 'Metre', 'متر', 'level', 1, 370),
  ('pct', 'Percent', '٪', 'percent', 1, 380)
on conflict (code) do nothing;

-- Temperature offset helpers (F/K stored with factor 1; conversion handled in app later)
update public.units set offset_to_base = 0 where code in ('C', 'F', 'K');

-- 4) Migrate meter_categories → meter_types -----------------------------------
insert into public.meter_types (
  code, name_en, name_ar, icon, color, is_system, is_active, sort_order, legacy_category_id
)
select
  c.code,
  c.name_en,
  coalesce(nullif(c.name_ar, ''), c.name_en),
  c.icon,
  c.color,
  c.is_system,
  c.is_active,
  c.sort_order,
  c.id
from public.meter_categories c
on conflict (code) do update set
  legacy_category_id = excluded.legacy_category_id,
  name_en = excluded.name_en,
  name_ar = excluded.name_ar;

update public.meters m
set meter_type_id = mt.id
from public.meter_types mt
where mt.legacy_category_id = m.category_id
  and m.meter_type_id is null;

-- Link meter types to primary measurement by category code heuristics
insert into public.meter_type_measurements (meter_type_id, measurement_type_id, is_primary, sort_order)
select mt.id, mst.id, true, 10
from public.meter_types mt
join public.measurement_types mst on mst.code = case
  when lower(mt.code) in ('electricity', 'electric', 'elec') then 'active_energy'
  when lower(mt.code) in ('water', 'chw', 'chilled_water') then 'volume'
  when lower(mt.code) in ('btu', 'thermal', 'district_cooling') then 'thermal_energy'
  when lower(mt.code) in ('diesel', 'fuel', 'oil') then 'volume'
  when lower(mt.code) in ('gas', 'lpg', 'natural_gas') then 'volume'
  else 'active_energy'
end
on conflict do nothing;

-- Allow common units for those measurements
insert into public.measurement_units (measurement_type_id, unit_id, is_default, sort_order)
select mst.id, u.id, u.code = 'kWh', u.sort_order
from public.measurement_types mst
join public.units u on u.code in ('Wh', 'kWh', 'MWh', 'GWh')
where mst.code = 'active_energy'
on conflict do nothing;

insert into public.measurement_units (measurement_type_id, unit_id, is_default, sort_order)
select mst.id, u.id, u.code = 'GJ', u.sort_order
from public.measurement_types mst
join public.units u on u.code in ('J', 'kJ', 'MJ', 'GJ', 'BTU', 'kBTU', 'MMBtu', 'kWh')
where mst.code = 'thermal_energy'
on conflict do nothing;

insert into public.measurement_units (measurement_type_id, unit_id, is_default, sort_order)
select mst.id, u.id, u.code = 'm3', u.sort_order
from public.measurement_types mst
join public.units u on u.code in ('mL', 'L', 'm3', 'gal_us', 'ft3')
where mst.code = 'volume'
on conflict do nothing;

insert into public.measurement_units (measurement_type_id, unit_id, is_default, sort_order)
select mst.id, u.id, u.code = 'kW', u.sort_order
from public.measurement_types mst
join public.units u on u.code in ('kW', 'MW')
where mst.code = 'power'
on conflict do nothing;

-- 5) Primary register per existing meter + link readings ----------------------
insert into public.meter_registers (
  meter_id, measurement_type_id, unit_id, is_primary, name_en, name_ar
)
select
  m.id,
  coalesce(
    (select mtm.measurement_type_id
     from public.meter_type_measurements mtm
     where mtm.meter_type_id = m.meter_type_id and mtm.is_primary
     limit 1),
    (select id from public.measurement_types where code = 'active_energy' limit 1)
  ),
  coalesce(
    (select u2.id
     from public.units u2
     join public.meter_units mu on lower(mu.code) = lower(u2.code)
     where mu.id = m.unit_id
     limit 1),
    (select u3.id from public.units u3 where u3.code = 'kWh' limit 1)
  ),
  true,
  'Primary',
  'رئيسي'
from public.meters m
where not exists (
  select 1 from public.meter_registers r where r.meter_id = m.id and r.is_primary
);

update public.meter_readings mr
set register_id = r.id
from public.meter_registers r
where r.meter_id = mr.meter_id
  and r.is_primary
  and mr.register_id is null;

-- 6) RLS ----------------------------------------------------------------------
alter table public.meter_types enable row level security;
alter table public.measurement_types enable row level security;
alter table public.units enable row level security;
alter table public.meter_type_measurements enable row level security;
alter table public.measurement_units enable row level security;
alter table public.meter_registers enable row level security;

create policy "meter_types_select" on public.meter_types for select to authenticated using (true);
create policy "measurement_types_select" on public.measurement_types for select to authenticated using (true);
create policy "units_select" on public.units for select to authenticated using (true);
create policy "meter_type_measurements_select" on public.meter_type_measurements for select to authenticated using (true);
create policy "measurement_units_select" on public.measurement_units for select to authenticated using (true);

create policy "meter_types_write" on public.meter_types for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());
create policy "measurement_types_write" on public.measurement_types for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());
create policy "units_write" on public.units for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());
create policy "meter_type_measurements_write" on public.meter_type_measurements for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());
create policy "measurement_units_write" on public.measurement_units for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy "meter_registers_select" on public.meter_registers for select to authenticated
  using (
    public.is_super_admin()
    or public.has_site_access((select site_id from public.meters where id = meter_id))
  );
create policy "meter_registers_write" on public.meter_registers for all to authenticated
  using (
    public.is_super_admin()
    or public.can_manage_site((select site_id from public.meters where id = meter_id))
  )
  with check (
    public.is_super_admin()
    or public.can_manage_site((select site_id from public.meters where id = meter_id))
  );

grant select, insert, update, delete on public.meter_types to authenticated;
grant select, insert, update, delete on public.measurement_types to authenticated;
grant select, insert, update, delete on public.units to authenticated;
grant select, insert, update, delete on public.meter_type_measurements to authenticated;
grant select, insert, update, delete on public.measurement_units to authenticated;
grant select, insert, update, delete on public.meter_registers to authenticated;
