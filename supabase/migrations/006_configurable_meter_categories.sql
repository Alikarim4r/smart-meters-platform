-- =============================================================================
-- Smart Meters Platform — Configurable Meter Categories
-- Migration: 006_configurable_meter_categories.sql
-- Status: DRAFT — DO NOT EXECUTE until reviewed and approved
-- Depends on: 001_schema.sql, 002_rls_policies.sql, 005_user_approval.sql
--
-- PREREQUISITE (separate transaction — same pattern as 004_user_approval_enum):
--   ALTER TYPE public.meter_category ADD VALUE IF NOT EXISTS 'fuel';
-- Required so new fuel meters can populate legacy meters.category (NOT NULL).
--
-- Strategy:
--   1. Add meter_categories / meter_units / meter_sources (admin-configurable)
--   2. Add category_id / source_id / unit_id to meters (nullable → backfill → NOT NULL)
--   3. Keep legacy enum columns (category, source, unit) for transition compatibility
--   4. Sync legacy enums from FK refs via trigger (Flutter v1 can migrate gradually)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. meter_categories
-- -----------------------------------------------------------------------------

create table if not exists public.meter_categories (
  id                      uuid primary key default gen_random_uuid(),
  code                    text not null,
  name_en                 text not null,
  name_ar                 text,
  base_unit_code          text not null,
  icon                    text,
  color                   text,
  is_system               boolean not null default false,
  is_active               boolean not null default true,
  sort_order              integer not null default 0,
  supports_cop_output     boolean not null default false,
  supports_electric_input boolean not null default false,
  is_consumption_category boolean not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),

  constraint meter_categories_code_not_empty
    check (char_length(trim(code)) > 0),
  constraint meter_categories_name_en_not_empty
    check (char_length(trim(name_en)) > 0),
  constraint meter_categories_base_unit_code_not_empty
    check (char_length(trim(base_unit_code)) > 0),
  constraint meter_categories_code_unique unique (code)
);

create index if not exists meter_categories_is_active_idx
  on public.meter_categories (is_active, sort_order);

comment on table public.meter_categories is
  'Admin-managed meter categories (water, electricity, btu, fuel, …). System rows seeded in migration.';
comment on column public.meter_categories.supports_cop_output is
  'When true, meters in this category may be linked as COP cooling/BTU output.';
comment on column public.meter_categories.supports_electric_input is
  'When true, meters in this category may be linked as COP electricity input.';
comment on column public.meter_categories.is_consumption_category is
  'When true, category appears in consumption dashboards and entry flows.';

-- -----------------------------------------------------------------------------
-- 2. meter_units
-- -----------------------------------------------------------------------------

create table if not exists public.meter_units (
  id                  uuid primary key default gen_random_uuid(),
  category_id         uuid not null references public.meter_categories (id) on delete restrict,
  code                text not null,
  name_en             text not null,
  name_ar             text,
  unit_to_base_factor numeric(20, 10) not null,
  is_base             boolean not null default false,
  is_active           boolean not null default true,
  sort_order          integer not null default 0,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint meter_units_code_not_empty check (char_length(trim(code)) > 0),
  constraint meter_units_name_en_not_empty check (char_length(trim(name_en)) > 0),
  constraint meter_units_factor_positive check (unit_to_base_factor > 0),
  constraint meter_units_category_code_unique unique (category_id, code)
);

create index if not exists meter_units_category_id_idx
  on public.meter_units (category_id, is_active, sort_order);

-- -----------------------------------------------------------------------------
-- 3. meter_sources
-- -----------------------------------------------------------------------------

create table if not exists public.meter_sources (
  id          uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.meter_categories (id) on delete restrict,
  code        text not null,
  name_en     text not null,
  name_ar     text,
  is_active   boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint meter_sources_code_not_empty check (char_length(trim(code)) > 0),
  constraint meter_sources_name_en_not_empty check (char_length(trim(name_en)) > 0),
  constraint meter_sources_category_code_unique unique (category_id, code)
);

create index if not exists meter_sources_category_id_idx
  on public.meter_sources (category_id, is_active, sort_order);

-- -----------------------------------------------------------------------------
-- 4. meters — add FK columns (nullable until backfill)
-- -----------------------------------------------------------------------------

alter table public.meters
  add column if not exists category_id uuid references public.meter_categories (id) on delete restrict,
  add column if not exists source_id uuid references public.meter_sources (id) on delete restrict,
  add column if not exists unit_id uuid references public.meter_units (id) on delete restrict;

create index if not exists meters_category_id_idx on public.meters (site_id, category_id);

comment on column public.meters.category is 'LEGACY — prefer category_id. Kept for transition.';
comment on column public.meters.source is 'LEGACY — prefer source_id. Kept for transition.';
comment on column public.meters.unit is 'LEGACY — prefer unit_id. Kept for transition.';
comment on column public.meters.unit_to_base_factor is
  'LEGACY — derived from unit_id when set. Kept for compatibility.';
comment on column public.meters.base_unit is
  'LEGACY — derived from meter_categories.base_unit_code when category_id set.';

-- -----------------------------------------------------------------------------
-- 5. Seed system categories (fixed UUIDs)
-- -----------------------------------------------------------------------------

insert into public.meter_categories (
  id, code, name_en, name_ar, base_unit_code, icon, color,
  is_system, is_active, sort_order,
  supports_cop_output, supports_electric_input, is_consumption_category
)
values
  (
    'c1111111-1111-4111-8111-111111111101',
    'water', 'Water', 'مياه', 'm3', 'water_drop', '#2196F3',
    true, true, 10,
    false, false, true
  ),
  (
    'c1111111-1111-4111-8111-111111111102',
    'electricity', 'Electricity', 'كهرباء', 'kWh', 'bolt', '#FFC107',
    true, true, 20,
    false, true, true
  ),
  (
    'c1111111-1111-4111-8111-111111111103',
    'btu', 'BTU / Cooling', 'تبريد', 'kWh thermal', 'ac_unit', '#00BCD4',
    true, true, 30,
    true, false, true
  ),
  (
    'c1111111-1111-4111-8111-111111111104',
    'fuel', 'Fuel / Diesel', 'وقود', 'liter', 'local_gas_station', '#795548',
    true, true, 40,
    false, false, true
  )
on conflict (code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  base_unit_code = excluded.base_unit_code,
  icon = excluded.icon,
  color = excluded.color,
  supports_cop_output = excluded.supports_cop_output,
  supports_electric_input = excluded.supports_electric_input,
  is_consumption_category = excluded.is_consumption_category,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- 6. Seed units
-- -----------------------------------------------------------------------------

insert into public.meter_units (
  id, category_id, code, name_en, name_ar, unit_to_base_factor, is_base, sort_order
)
values
  -- Water
  ('e1111111-1111-4111-8111-111111111101', 'c1111111-1111-4111-8111-111111111101', 'm3', 'm³', 'م³', 1, true, 1),
  ('e1111111-1111-4111-8111-111111111102', 'c1111111-1111-4111-8111-111111111101', 'liter', 'Liter', 'لتر', 0.001, false, 2),
  ('e1111111-1111-4111-8111-111111111103', 'c1111111-1111-4111-8111-111111111101', 'dm3', 'dm³', 'دسم³', 0.001, false, 3),
  ('e1111111-1111-4111-8111-111111111104', 'c1111111-1111-4111-8111-111111111101', 'gallon', 'Gallon', 'غالون', 0.00378541, false, 4),
  -- Electricity
  ('e1111111-1111-4111-8111-111111111201', 'c1111111-1111-4111-8111-111111111102', 'kwh', 'kWh', 'كيلوواط ساعة', 1, true, 1),
  ('e1111111-1111-4111-8111-111111111202', 'c1111111-1111-4111-8111-111111111102', 'mwh', 'MWh', 'ميجاواط ساعة', 1000, false, 2),
  ('e1111111-1111-4111-8111-111111111203', 'c1111111-1111-4111-8111-111111111102', 'wh', 'Wh', 'واط ساعة', 0.001, false, 3),
  ('e1111111-1111-4111-8111-111111111204', 'c1111111-1111-4111-8111-111111111102', 'kvah', 'kVAh', 'كيلوفولت أمبير ساعة', 1, false, 4),
  -- BTU / Cooling
  ('e1111111-1111-4111-8111-111111111301', 'c1111111-1111-4111-8111-111111111103', 'kwh_thermal', 'kWh thermal', 'كيلوواط حراري', 1, true, 1),
  ('e1111111-1111-4111-8111-111111111302', 'c1111111-1111-4111-8111-111111111103', 'btu', 'BTU', 'وحدة حرارية', 0.000293071, false, 2),
  ('e1111111-1111-4111-8111-111111111303', 'c1111111-1111-4111-8111-111111111103', 'ton_hour', 'ton-hour', 'طن ساعة', 3.51685, false, 3),
  ('e1111111-1111-4111-8111-111111111304', 'c1111111-1111-4111-8111-111111111103', 'rt_hour', 'RT-hour', 'طن تبريد ساعة', 3.51685, false, 4),
  -- Fuel
  ('e1111111-1111-4111-8111-111111111401', 'c1111111-1111-4111-8111-111111111104', 'liter', 'Liter', 'لتر', 1, true, 1),
  ('e1111111-1111-4111-8111-111111111402', 'c1111111-1111-4111-8111-111111111104', 'gallon', 'Gallon', 'غالون', 3.78541, false, 2),
  ('e1111111-1111-4111-8111-111111111403', 'c1111111-1111-4111-8111-111111111104', 'm3', 'm³', 'م³', 1000, false, 3)
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_base = excluded.is_base,
  sort_order = excluded.sort_order,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- 7. Seed sources
-- -----------------------------------------------------------------------------

insert into public.meter_sources (id, category_id, code, name_en, name_ar, sort_order)
values
  -- Water
  ('b1111111-1111-4111-8111-111111111101', 'c1111111-1111-4111-8111-111111111101', 'kahramaa', 'Kahramaa', 'كهرماء', 1),
  ('b1111111-1111-4111-8111-111111111102', 'c1111111-1111-4111-8111-111111111101', 'tse', 'TSE', 'مياه معالجة', 2),
  ('b1111111-1111-4111-8111-111111111103', 'c1111111-1111-4111-8111-111111111101', 'ro', 'RO', 'تناضح عكسي', 3),
  ('b1111111-1111-4111-8111-111111111104', 'c1111111-1111-4111-8111-111111111101', 'tanker', 'Tanker', 'صهريج', 4),
  ('b1111111-1111-4111-8111-111111111105', 'c1111111-1111-4111-8111-111111111101', 'irrigation', 'Irrigation', 'ري', 5),
  ('b1111111-1111-4111-8111-111111111106', 'c1111111-1111-4111-8111-111111111101', 'other', 'Other', 'أخرى', 99),
  -- Electricity
  ('b1111111-1111-4111-8111-111111111201', 'c1111111-1111-4111-8111-111111111102', 'kahramaa', 'Kahramaa', 'كهرماء', 1),
  ('b1111111-1111-4111-8111-111111111202', 'c1111111-1111-4111-8111-111111111102', 'generator', 'Generator', 'مولد', 2),
  ('b1111111-1111-4111-8111-111111111203', 'c1111111-1111-4111-8111-111111111102', 'solar', 'Solar', 'طاقة شمسية', 3),
  ('b1111111-1111-4111-8111-111111111204', 'c1111111-1111-4111-8111-111111111102', 'ups', 'UPS', 'مزود طاقة', 4),
  ('b1111111-1111-4111-8111-111111111205', 'c1111111-1111-4111-8111-111111111102', 'other', 'Other', 'أخرى', 99),
  -- BTU
  ('b1111111-1111-4111-8111-111111111301', 'c1111111-1111-4111-8111-111111111103', 'chilled_water', 'Chilled Water', 'مياه مبردة', 1),
  ('b1111111-1111-4111-8111-111111111302', 'c1111111-1111-4111-8111-111111111103', 'cooling_energy', 'Cooling Energy', 'طاقة تبريد', 2),
  ('b1111111-1111-4111-8111-111111111303', 'c1111111-1111-4111-8111-111111111103', 'ahu', 'AHU', 'وحدة معالجة هواء', 3),
  ('b1111111-1111-4111-8111-111111111304', 'c1111111-1111-4111-8111-111111111103', 'crac', 'CRAC', 'وحدة CRAC', 4),
  ('b1111111-1111-4111-8111-111111111305', 'c1111111-1111-4111-8111-111111111103', 'other', 'Other', 'أخرى', 99),
  -- Fuel
  ('b1111111-1111-4111-8111-111111111401', 'c1111111-1111-4111-8111-111111111104', 'diesel', 'Diesel', 'ديزل', 1),
  ('b1111111-1111-4111-8111-111111111402', 'c1111111-1111-4111-8111-111111111104', 'petrol', 'Petrol', 'بنزين', 2),
  ('b1111111-1111-4111-8111-111111111403', 'c1111111-1111-4111-8111-111111111104', 'gas_oil', 'Gas Oil', 'زيت غاز', 3),
  ('b1111111-1111-4111-8111-111111111404', 'c1111111-1111-4111-8111-111111111104', 'other', 'Other', 'أخرى', 99)
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  sort_order = excluded.sort_order,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- 8. Backfill existing meters
-- -----------------------------------------------------------------------------

update public.meters m
set
  category_id = mc.id,
  source_id = ms.id,
  unit_id = mu.id
from public.meter_categories mc,
     public.meter_sources ms,
     public.meter_units mu
where mc.code = m.category::text
  and ms.category_id = mc.id
  and ms.code = m.source::text
  and mu.category_id = mc.id
  and mu.code = m.unit::text
  and (
    m.category_id is distinct from mc.id
    or m.source_id is distinct from ms.id
    or m.unit_id is distinct from mu.id
  );

-- -----------------------------------------------------------------------------
-- 9. Helper: unit factor from configurable unit_id
-- -----------------------------------------------------------------------------

create or replace function public.unit_factor_from_unit_id(p_unit_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select unit_to_base_factor
  from public.meter_units
  where id = p_unit_id
    and is_active = true;
$$;

-- -----------------------------------------------------------------------------
-- 10. Sync legacy enum columns + factors from FK refs (transition)
-- -----------------------------------------------------------------------------

-- Legacy-only inserts (admin scripts, phase1a) still work: enum -> FK lookup
create or replace function public.sync_meter_fk_from_legacy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cat_id uuid;
  v_src_id uuid;
  v_unit_id uuid;
begin
  if new.category_id is not null and new.source_id is not null and new.unit_id is not null then
    return new;
  end if;

  if new.category is null or new.source is null or new.unit is null then
    return new;
  end if;

  select id into v_cat_id
  from public.meter_categories
  where code = new.category::text;

  if v_cat_id is null then
    raise exception 'Unknown legacy category % — no meter_categories row', new.category;
  end if;

  select ms.id into v_src_id
  from public.meter_sources ms
  where ms.category_id = v_cat_id
    and ms.code = new.source::text;

  if v_src_id is null then
    raise exception 'Unknown legacy source % for category %', new.source, new.category;
  end if;

  select mu.id into v_unit_id
  from public.meter_units mu
  where mu.category_id = v_cat_id
    and mu.code = new.unit::text;

  if v_unit_id is null then
    raise exception 'Unknown legacy unit % for category %', new.unit, new.category;
  end if;

  new.category_id := coalesce(new.category_id, v_cat_id);
  new.source_id := coalesce(new.source_id, v_src_id);
  new.unit_id := coalesce(new.unit_id, v_unit_id);

  return new;
end;
$$;

drop trigger if exists meters_sync_fk_from_legacy on public.meters;
create trigger meters_sync_fk_from_legacy
  before insert or update of category, source, unit
  on public.meters
  for each row execute function public.sync_meter_fk_from_legacy();

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

  -- Legacy enum columns (values that exist in Postgres enums; fuel requires 006a enum add)
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
    'm3', 'liter', 'dm3', 'gallon', 'kwh', 'mwh', 'wh', 'kvah',
    'kwh_thermal', 'btu', 'ton_hour', 'rt_hour'
  ) then
    new.unit := v_unit.code::public.meter_unit;
  end if;

  new.unit_to_base_factor := v_unit.unit_to_base_factor;
  new.base_unit := v_category.base_unit_code;

  return new;
end;
$$;

drop trigger if exists meters_sync_legacy_from_config on public.meters;
create trigger meters_sync_legacy_from_config
  before insert or update of category_id, source_id, unit_id
  on public.meters
  for each row execute function public.sync_meter_legacy_from_config();

-- -----------------------------------------------------------------------------
-- 12. Finalize backfill: sync legacy columns, enforce NOT NULL on FKs
-- -----------------------------------------------------------------------------

update public.meters m
set category_id = m.category_id;

alter table public.meters
  alter column category_id set not null,
  alter column source_id set not null,
  alter column unit_id set not null;

-- Extend set_meter_unit_defaults: prefer unit_id path; legacy enum path remains for old clients
create or replace function public.set_meter_unit_defaults()
returns trigger
language plpgsql
as $$
declare
  v_factor numeric;
begin
  if new.unit_id is not null then
    return new; -- sync_meter_legacy_from_config already set factors
  end if;

  v_factor := public.unit_to_base_factor(new.category, new.unit);
  if v_factor is null then
    raise exception 'Unit % is not valid for category %', new.unit, new.category;
  end if;
  new.unit_to_base_factor := v_factor;
  new.base_unit := public.base_unit_for_category(new.category);
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 13. Parent validation — use category_id (same category within site)
-- -----------------------------------------------------------------------------

create or replace function public.validate_meter_parent()
returns trigger
language plpgsql
as $$
declare
  v_parent record;
begin
  if new.parent_meter_id is null then
    return new;
  end if;

  if new.parent_meter_id = new.id then
    raise exception 'Meter cannot be its own parent';
  end if;

  select site_id, category_id, level
  into v_parent
  from public.meters
  where id = new.parent_meter_id;

  if not found then
    raise exception 'Parent meter % not found', new.parent_meter_id;
  end if;

  if v_parent.site_id <> new.site_id then
    raise exception 'Parent meter must belong to the same site';
  end if;

  if v_parent.category_id <> new.category_id then
    raise exception 'Parent meter must have the same category';
  end if;

  if v_parent.level <> 'main' then
    raise exception 'Parent meter must be a main meter (v1 one-level hierarchy)';
  end if;

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 14. Protect unit/category integrity — include FK columns
-- -----------------------------------------------------------------------------

create or replace function public.protect_meter_unit_integrity()
returns trigger
language plpgsql
as $$
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if not exists (
    select 1 from public.meter_readings where meter_id = old.id limit 1
  ) then
    return new;
  end if;

  if new.unit is distinct from old.unit
    or new.unit_to_base_factor is distinct from old.unit_to_base_factor
    or new.base_unit is distinct from old.base_unit
    or new.category is distinct from old.category
    or new.category_id is distinct from old.category_id
    or new.source_id is distinct from old.source_id
    or new.unit_id is distinct from old.unit_id
  then
    raise exception
      'Cannot change unit/category after readings exist for meter %. Create a new meter instead.',
      old.id;
  end if;

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 15. COP validation — use category flags (not hardcoded enum only)
-- -----------------------------------------------------------------------------

create or replace function public.validate_cop_btu_meter()
returns trigger
language plpgsql
as $$
declare
  v_meter record;
  v_group_site_id uuid;
begin
  select site_id into v_group_site_id
  from public.cop_groups
  where id = new.cop_group_id;

  select m.site_id, mc.supports_cop_output, mc.code
  into v_meter
  from public.meters m
  join public.meter_categories mc on mc.id = m.category_id
  where m.id = new.meter_id;

  if not coalesce(v_meter.supports_cop_output, false)
     and v_meter.code <> 'btu' then
    raise exception 'COP BTU link requires a category with supports_cop_output';
  end if;

  if v_meter.site_id <> v_group_site_id then
    raise exception 'BTU meter must belong to the same site as the COP group';
  end if;

  return new;
end;
$$;

create or replace function public.validate_cop_electricity_meter()
returns trigger
language plpgsql
as $$
declare
  v_meter record;
  v_group_site_id uuid;
begin
  select site_id into v_group_site_id
  from public.cop_groups
  where id = new.cop_group_id;

  select m.site_id, m.category_id, mc.supports_electric_input, mc.code
  into v_meter
  from public.meters m
  join public.meter_categories mc on mc.id = m.category_id
  where m.id = new.meter_id;

  if not coalesce(v_meter.supports_electric_input, false)
     and v_meter.code <> 'electricity' then
    raise exception 'COP electricity link requires a category with supports_electric_input';
  end if;

  if v_meter.site_id <> v_group_site_id then
    raise exception 'Electricity meter must belong to the same site as the COP group';
  end if;

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 16. RLS — config tables
-- -----------------------------------------------------------------------------

alter table public.meter_categories enable row level security;
alter table public.meter_units enable row level security;
alter table public.meter_sources enable row level security;

drop policy if exists "meter_categories_select" on public.meter_categories;
create policy "meter_categories_select"
  on public.meter_categories for select
  to authenticated
  using (
    public.is_super_admin()
    or (
      public.is_approved_active_user()
      and (is_active or public.current_user_role() = 'site_admin')
    )
  );

drop policy if exists "meter_categories_insert" on public.meter_categories;
create policy "meter_categories_insert"
  on public.meter_categories for insert
  to authenticated
  with check (public.is_super_admin());

drop policy if exists "meter_categories_update" on public.meter_categories;
create policy "meter_categories_update"
  on public.meter_categories for update
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists "meter_categories_delete" on public.meter_categories;
create policy "meter_categories_delete"
  on public.meter_categories for delete
  to authenticated
  using (public.is_super_admin());

-- meter_units
drop policy if exists "meter_units_select" on public.meter_units;
create policy "meter_units_select"
  on public.meter_units for select
  to authenticated
  using (
    public.is_super_admin()
    or (
      public.is_approved_active_user()
      and (is_active or public.current_user_role() = 'site_admin')
    )
  );

drop policy if exists "meter_units_insert" on public.meter_units;
create policy "meter_units_insert"
  on public.meter_units for insert
  to authenticated
  with check (public.is_super_admin());

drop policy if exists "meter_units_update" on public.meter_units;
create policy "meter_units_update"
  on public.meter_units for update
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists "meter_units_delete" on public.meter_units;
create policy "meter_units_delete"
  on public.meter_units for delete
  to authenticated
  using (public.is_super_admin());

-- meter_sources
drop policy if exists "meter_sources_select" on public.meter_sources;
create policy "meter_sources_select"
  on public.meter_sources for select
  to authenticated
  using (
    public.is_super_admin()
    or (
      public.is_approved_active_user()
      and (is_active or public.current_user_role() = 'site_admin')
    )
  );

drop policy if exists "meter_sources_insert" on public.meter_sources;
create policy "meter_sources_insert"
  on public.meter_sources for insert
  to authenticated
  with check (public.is_super_admin());

drop policy if exists "meter_sources_update" on public.meter_sources;
create policy "meter_sources_update"
  on public.meter_sources for update
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists "meter_sources_delete" on public.meter_sources;
create policy "meter_sources_delete"
  on public.meter_sources for delete
  to authenticated
  using (public.is_super_admin());

-- Grants (002 grants existing tables; new tables need explicit grants — RLS still restricts writes)
grant select, insert, update, delete on public.meter_categories to authenticated;
grant select, insert, update, delete on public.meter_units to authenticated;
grant select, insert, update, delete on public.meter_sources to authenticated;
