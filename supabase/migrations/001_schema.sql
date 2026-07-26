-- =============================================================================
-- Smart Meters Platform — Schema Migration Draft
-- Migration: 001_schema.sql
-- Status: DRAFT — DO NOT EXECUTE without approval
-- Project: smart-meters-platform (Supabase)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Extensions
-- -----------------------------------------------------------------------------

create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------

create type public.user_role as enum (
  'super_admin',
  'site_admin',
  'technician',
  'viewer'
);

create type public.site_type as enum (
  'headquarters',
  'school',
  'kindergarten',
  'office',
  'warehouse',
  'training_center',
  'other'
);

create type public.meter_category as enum (
  'water',
  'electricity',
  'btu'
);

create type public.meter_source as enum (
  'kahramaa',
  'tse',
  'ro',
  'tanker',
  'generator',
  'solar',
  'chilled_water',
  'cooling_energy',
  'other'
);

create type public.meter_level as enum (
  'main',
  'sub'
);

create type public.meter_unit as enum (
  -- Water
  'm3',
  'liter',
  'dm3',
  'gallon',
  -- Electricity
  'kwh',
  'mwh',
  'wh',
  'kvah',
  -- BTU / cooling
  'kwh_thermal',
  'btu',
  'ton_hour',
  'rt_hour'
);

create type public.meter_kind as enum (
  'physical',
  'virtual'
);

create type public.calculation_type as enum (
  'direct_reading',
  'sum_children',
  'parent_minus_children',
  'manual_adjustment'
);

create type public.reading_audit_action as enum (
  'create',
  'update',
  'delete',
  'restore'
);

-- -----------------------------------------------------------------------------
-- Helper: unit to base factor lookup
-- Base units: water = m3, electricity = kWh, btu = kWh thermal
-- -----------------------------------------------------------------------------

create or replace function public.unit_to_base_factor(
  p_category public.meter_category,
  p_unit public.meter_unit
)
returns numeric
language sql
immutable
as $$
  select case
    -- Water → m3
    when p_category = 'water' and p_unit = 'm3'     then 1
    when p_category = 'water' and p_unit = 'liter' then 0.001
    when p_category = 'water' and p_unit = 'dm3'    then 0.001
    when p_category = 'water' and p_unit = 'gallon' then 0.00378541
    -- Electricity → kWh
    when p_category = 'electricity' and p_unit = 'kwh'  then 1
    when p_category = 'electricity' and p_unit = 'mwh'  then 1000
    when p_category = 'electricity' and p_unit = 'wh'   then 0.001
    when p_category = 'electricity' and p_unit = 'kvah' then 1  -- approximate
    -- BTU → kWh thermal
    when p_category = 'btu' and p_unit = 'kwh_thermal' then 1
    when p_category = 'btu' and p_unit = 'btu'         then 0.000293071
    when p_category = 'btu' and p_unit = 'ton_hour'    then 3.51685
    when p_category = 'btu' and p_unit = 'rt_hour'     then 3.51685
    else null
  end;
$$;

create or replace function public.base_unit_for_category(
  p_category public.meter_category
)
returns text
language sql
immutable
as $$
  select case p_category
    when 'water'       then 'm3'
    when 'electricity' then 'kWh'
    when 'btu'         then 'kWh thermal'
  end;
$$;

-- Qatar business date for technician reading entry (Asia/Qatar timezone)
create or replace function public.current_business_date()
returns date
language sql
stable
as $$
  select (timezone('Asia/Qatar', now()))::date;
$$;

comment on function public.current_business_date is
  'Returns today''s date in Asia/Qatar timezone for technician reading submission rules.';

-- -----------------------------------------------------------------------------
-- organizations
-- -----------------------------------------------------------------------------

create table public.organizations (
  id          uuid primary key default gen_random_uuid(),
  name_en     text not null,
  name_ar     text not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint organizations_name_en_not_empty check (char_length(trim(name_en)) > 0),
  constraint organizations_name_ar_not_empty check (char_length(trim(name_ar)) > 0)
);

create index organizations_is_active_idx on public.organizations (is_active);

-- -----------------------------------------------------------------------------
-- sites
-- -----------------------------------------------------------------------------

create table public.sites (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete restrict,
  name_en         text not null,
  name_ar         text not null,
  site_type       public.site_type not null default 'other',
  location        text,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint sites_name_en_not_empty check (char_length(trim(name_en)) > 0),
  constraint sites_name_ar_not_empty check (char_length(trim(name_ar)) > 0)
);

create index sites_organization_id_idx on public.sites (organization_id);
create index sites_is_active_idx on public.sites (is_active);
create index sites_site_type_idx on public.sites (site_type);

-- -----------------------------------------------------------------------------
-- profiles (extends auth.users)
-- -----------------------------------------------------------------------------

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null,
  email       text not null,
  role        public.user_role not null default 'viewer',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint profiles_full_name_not_empty check (char_length(trim(full_name)) > 0),
  constraint profiles_email_not_empty check (char_length(trim(email)) > 0)
);

create index profiles_role_idx on public.profiles (role);
create index profiles_is_active_idx on public.profiles (is_active);

-- Auto-create profile on auth.users insert
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.email,
    coalesce((new.raw_user_meta_data ->> 'role')::public.user_role, 'viewer')
  );
  return new;
end;
$$;

-- Trigger attached after auth schema is confirmed available:
-- create trigger on_auth_user_created
--   after insert on auth.users
--   for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- user_site_access
-- -----------------------------------------------------------------------------

create table public.user_site_access (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles (id) on delete cascade,
  site_id            uuid not null references public.sites (id) on delete cascade,
  role               public.user_role not null,
  can_read           boolean not null default true,
  can_write          boolean not null default false,
  can_manage_meters  boolean not null default false,
  created_at         timestamptz not null default now(),

  constraint user_site_access_unique_user_site unique (user_id, site_id)
);

create index user_site_access_user_id_idx on public.user_site_access (user_id);
create index user_site_access_site_id_idx on public.user_site_access (site_id);

-- -----------------------------------------------------------------------------
-- meters
-- -----------------------------------------------------------------------------

create table public.meters (
  id                   uuid primary key default gen_random_uuid(),
  site_id              uuid not null references public.sites (id) on delete restrict,
  meter_code           text not null,
  name_en              text not null,
  name_ar              text not null,
  category             public.meter_category not null,
  source               public.meter_source not null default 'other',
  level                public.meter_level not null default 'main',
  parent_meter_id      uuid references public.meters (id) on delete restrict,
  meter_kind           public.meter_kind not null default 'physical',
  calculation_type     public.calculation_type not null default 'direct_reading',
  unit                 public.meter_unit not null,
  unit_to_base_factor  numeric(20, 10) not null,
  base_unit            text not null,
  meter_multiplier     numeric(20, 10) not null default 1,
  sort_order           integer not null default 0,
  is_active            boolean not null default true,
  include_in_dashboard boolean not null default true,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint meters_meter_code_not_empty check (char_length(trim(meter_code)) > 0),
  constraint meters_name_en_not_empty check (char_length(trim(name_en)) > 0),
  constraint meters_name_ar_not_empty check (char_length(trim(name_ar)) > 0),
  constraint meters_meter_multiplier_positive check (meter_multiplier > 0),
  constraint meters_unit_to_base_factor_positive check (unit_to_base_factor > 0),
  constraint meters_unique_code_per_site unique (site_id, meter_code),
  constraint meters_sub_requires_parent check (
    level = 'main' or parent_meter_id is not null
  ),
  constraint meters_main_no_parent check (
    level = 'sub' or parent_meter_id is null
  ),
  constraint meters_physical_direct_reading check (
    meter_kind = 'virtual' or calculation_type = 'direct_reading'
  ),
  constraint meters_virtual_not_direct check (
    meter_kind = 'physical' or calculation_type <> 'direct_reading'
  ),
  constraint meters_virtual_parent_required check (
    calculation_type <> 'parent_minus_children' or parent_meter_id is not null
  )
);

create index meters_site_id_idx on public.meters (site_id);
create index meters_category_idx on public.meters (site_id, category);
create index meters_parent_meter_id_idx on public.meters (parent_meter_id);
create index meters_is_active_idx on public.meters (is_active);
create index meters_meter_kind_idx on public.meters (meter_kind);
create index meters_calculation_type_idx on public.meters (calculation_type);

-- v1 hierarchy: one-level only — sub meters may reference main meters only.
-- Same site and same category enforced below. Multi-level deferred to v2.
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

  -- Prevent self-reference before parent lookup
  if new.parent_meter_id = new.id then
    raise exception 'Meter cannot be its own parent';
  end if;

  select site_id, category, level
  into v_parent
  from public.meters
  where id = new.parent_meter_id;

  if not found then
    raise exception 'Parent meter % not found', new.parent_meter_id;
  end if;

  if v_parent.site_id <> new.site_id then
    raise exception 'Parent meter must belong to the same site';
  end if;

  if v_parent.category <> new.category then
    raise exception 'Parent meter must have the same category';
  end if;

  if v_parent.level <> 'main' then
    raise exception 'Parent meter must be a main meter (v1 one-level hierarchy)';
  end if;

  return new;
end;
$$;

create trigger meters_validate_parent
  before insert or update on public.meters
  for each row execute function public.validate_meter_parent();

-- Auto-set unit_to_base_factor and base_unit from unit + category
create or replace function public.set_meter_unit_defaults()
returns trigger
language plpgsql
as $$
declare
  v_factor numeric;
begin
  v_factor := public.unit_to_base_factor(new.category, new.unit);
  if v_factor is null then
    raise exception 'Unit % is not valid for category %', new.unit, new.category;
  end if;
  new.unit_to_base_factor := v_factor;
  new.base_unit := public.base_unit_for_category(new.category);
  return new;
end;
$$;

create trigger meters_set_unit_defaults
  before insert or update of unit, category on public.meters
  for each row execute function public.set_meter_unit_defaults();

-- -----------------------------------------------------------------------------
-- meter_readings
-- -----------------------------------------------------------------------------

create table public.meter_readings (
  id                uuid primary key default gen_random_uuid(),
  site_id           uuid not null references public.sites (id) on delete restrict,
  meter_id          uuid not null references public.meters (id) on delete restrict,
  reading_date      date not null,
  raw_value         numeric(20, 6) not null,
  normalized_value  numeric(20, 6) not null,
  image_url         text,
  note              text,
  entered_by        uuid references public.profiles (id) on delete set null,
  entered_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint meter_readings_raw_value_non_negative check (raw_value >= 0),
  constraint meter_readings_normalized_value_non_negative check (normalized_value >= 0),
  constraint meter_readings_unique_meter_date unique (meter_id, reading_date)
);

create index meter_readings_site_id_idx on public.meter_readings (site_id);
create index meter_readings_meter_id_idx on public.meter_readings (meter_id);
create index meter_readings_reading_date_idx on public.meter_readings (reading_date);
create index meter_readings_site_date_idx on public.meter_readings (site_id, reading_date);

-- Ensure site_id matches meter; reject readings on virtual/calculated meters
create or replace function public.validate_reading_site()
returns trigger
language plpgsql
as $$
declare
  v_meter record;
begin
  select site_id, meter_kind, calculation_type
  into v_meter
  from public.meters
  where id = new.meter_id;

  if not found then
    raise exception 'Meter not found';
  end if;

  if v_meter.site_id <> new.site_id then
    raise exception 'Reading site_id must match meter site_id';
  end if;

  if v_meter.meter_kind = 'virtual' then
    raise exception 'Virtual meters cannot have direct readings; values are calculated';
  end if;

  if v_meter.calculation_type <> 'direct_reading' then
    raise exception 'Only meters with calculation_type direct_reading can receive readings';
  end if;

  return new;
end;
$$;

-- Compute normalized_value on insert/update (runs after validate — trigger name enforces order)
create or replace function public.compute_normalized_reading()
returns trigger
language plpgsql
as $$
declare
  v_meter record;
begin
  select unit_to_base_factor, meter_multiplier
  into v_meter
  from public.meters
  where id = new.meter_id;

  if not found then
    raise exception 'Meter % not found for reading normalization', new.meter_id;
  end if;

  new.normalized_value := new.raw_value * v_meter.unit_to_base_factor * v_meter.meter_multiplier;
  return new;
end;
$$;

create trigger meter_readings_a_validate_site
  before insert or update on public.meter_readings
  for each row execute function public.validate_reading_site();

create trigger meter_readings_c_compute_normalized
  before insert or update of raw_value, meter_id on public.meter_readings
  for each row execute function public.compute_normalized_reading();

-- Technician reading rules trigger defined in 002_rls_policies.sql (after is_technician_only_for_site)

-- Block unit/category changes after readings exist; guard meter_multiplier
create or replace function public.meter_has_readings(p_meter_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.meter_readings where meter_id = p_meter_id
  );
$$;

create or replace function public.protect_meter_unit_integrity()
returns trigger
language plpgsql
as $$
declare
  v_bypass_multiplier boolean;
begin
  if tg_op = 'INSERT' then
    return new;
  end if;

  if not public.meter_has_readings(old.id) then
    return new;
  end if;

  if new.unit is distinct from old.unit
    or new.unit_to_base_factor is distinct from old.unit_to_base_factor
    or new.base_unit is distinct from old.base_unit
    or new.category is distinct from old.category
  then
    raise exception
      'Cannot change unit, unit_to_base_factor, base_unit, or category after readings exist for meter %. Create a new meter instead.',
      old.meter_code;
  end if;

  if new.meter_multiplier is distinct from old.meter_multiplier then
    v_bypass_multiplier := coalesce(
      current_setting('app.bypass_meter_multiplier_guard', true),
      'false'
    ) = 'true';

    if not v_bypass_multiplier then
      raise exception
        'Cannot change meter_multiplier after readings exist for meter %. Use admin_update_meter_multiplier() with documented justification.',
        old.meter_code;
    end if;
  end if;

  return new;
end;
$$;

create trigger meters_protect_unit_integrity
  before update on public.meters
  for each row execute function public.protect_meter_unit_integrity();

-- -----------------------------------------------------------------------------
-- reading_audit_logs
-- Append-only audit trail for reading changes (v1)
-- -----------------------------------------------------------------------------

create table public.reading_audit_logs (
  id                    uuid primary key default gen_random_uuid(),
  reading_id            uuid,
  meter_id              uuid not null references public.meters (id) on delete restrict,
  site_id               uuid not null references public.sites (id) on delete restrict,
  action                public.reading_audit_action not null,
  old_raw_value         numeric(20, 6),
  new_raw_value         numeric(20, 6),
  old_normalized_value  numeric(20, 6),
  new_normalized_value  numeric(20, 6),
  old_reading_date      date,
  new_reading_date      date,
  old_image_url         text,
  new_image_url         text,
  changed_by            uuid references public.profiles (id) on delete set null,
  changed_at            timestamptz not null default now(),
  note                  text
);

create index reading_audit_logs_reading_id_idx
  on public.reading_audit_logs (reading_id);
create index reading_audit_logs_meter_id_idx
  on public.reading_audit_logs (meter_id);
create index reading_audit_logs_site_id_idx
  on public.reading_audit_logs (site_id);
create index reading_audit_logs_changed_by_idx
  on public.reading_audit_logs (changed_by);
create index reading_audit_logs_changed_at_idx
  on public.reading_audit_logs (changed_at desc);
create index reading_audit_logs_site_changed_at_idx
  on public.reading_audit_logs (site_id, changed_at desc);
create index reading_audit_logs_action_idx
  on public.reading_audit_logs (action);

comment on table public.reading_audit_logs is
  'Append-only audit log for meter_readings create/update/delete/restore. Written by triggers and admin RPCs only.';

create or replace function public.audit_meter_reading_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action public.reading_audit_action;
  v_changed_by uuid;
begin
  v_changed_by := auth.uid();

  if tg_op = 'INSERT' then
    v_action := case
      when coalesce(current_setting('app.reading_audit_action', true), '') = 'restore'
        then 'restore'::public.reading_audit_action
      else 'create'::public.reading_audit_action
    end;

    insert into public.reading_audit_logs (
      reading_id, meter_id, site_id, action,
      old_raw_value, new_raw_value,
      old_normalized_value, new_normalized_value,
      old_reading_date, new_reading_date,
      old_image_url, new_image_url,
      changed_by, note
    ) values (
      new.id, new.meter_id, new.site_id, v_action,
      null, new.raw_value,
      null, new.normalized_value,
      null, new.reading_date,
      null, new.image_url,
      coalesce(new.entered_by, v_changed_by), new.note
    );

    return new;
  elsif tg_op = 'UPDATE' then
    insert into public.reading_audit_logs (
      reading_id, meter_id, site_id, action,
      old_raw_value, new_raw_value,
      old_normalized_value, new_normalized_value,
      old_reading_date, new_reading_date,
      old_image_url, new_image_url,
      changed_by, note
    ) values (
      new.id, new.meter_id, new.site_id, 'update',
      old.raw_value, new.raw_value,
      old.normalized_value, new.normalized_value,
      old.reading_date, new.reading_date,
      old.image_url, new.image_url,
      v_changed_by, new.note
    );

    return new;
  elsif tg_op = 'DELETE' then
    insert into public.reading_audit_logs (
      reading_id, meter_id, site_id, action,
      old_raw_value, new_raw_value,
      old_normalized_value, new_normalized_value,
      old_reading_date, new_reading_date,
      old_image_url, new_image_url,
      changed_by, note
    ) values (
      old.id, old.meter_id, old.site_id, 'delete',
      old.raw_value, null,
      old.normalized_value, null,
      old.reading_date, null,
      old.image_url, null,
      v_changed_by, old.note
    );

    return old;
  end if;

  return null;
end;
$$;

create trigger meter_readings_audit_insert
  after insert on public.meter_readings
  for each row execute function public.audit_meter_reading_change();

create trigger meter_readings_audit_update
  after update on public.meter_readings
  for each row execute function public.audit_meter_reading_change();

create trigger meter_readings_audit_delete
  after delete on public.meter_readings
  for each row execute function public.audit_meter_reading_change();

-- Prevent direct invocation of trigger-only audit function
revoke all on function public.audit_meter_reading_change() from public;
revoke all on function public.audit_meter_reading_change() from authenticated, anon;

-- Admin RPCs that depend on RLS helpers are defined in 002_rls_policies.sql:
--   admin_update_meter_multiplier()
--   admin_restore_meter_reading()

-- -----------------------------------------------------------------------------
-- cop_groups
-- -----------------------------------------------------------------------------

create table public.cop_groups (
  id          uuid primary key default gen_random_uuid(),
  site_id     uuid not null references public.sites (id) on delete restrict,
  name_en     text not null,
  name_ar     text not null,
  description text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint cop_groups_name_en_not_empty check (char_length(trim(name_en)) > 0),
  constraint cop_groups_name_ar_not_empty check (char_length(trim(name_ar)) > 0)
);

create index cop_groups_site_id_idx on public.cop_groups (site_id);
create index cop_groups_is_active_idx on public.cop_groups (is_active);

-- -----------------------------------------------------------------------------
-- cop_group_btu_meters
-- -----------------------------------------------------------------------------

create table public.cop_group_btu_meters (
  id           uuid primary key default gen_random_uuid(),
  cop_group_id uuid not null references public.cop_groups (id) on delete cascade,
  meter_id     uuid not null references public.meters (id) on delete restrict,
  weight       numeric(10, 4) not null default 1,
  created_at   timestamptz not null default now(),

  constraint cop_group_btu_meters_weight_positive check (weight > 0),
  constraint cop_group_btu_meters_unique unique (cop_group_id, meter_id)
);

create index cop_group_btu_meters_cop_group_id_idx
  on public.cop_group_btu_meters (cop_group_id);
create index cop_group_btu_meters_meter_id_idx
  on public.cop_group_btu_meters (meter_id);

-- Validate BTU meter category and same site as COP group
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

  select site_id, category into v_meter
  from public.meters
  where id = new.meter_id;

  if v_meter.category <> 'btu' then
    raise exception 'COP BTU link requires a BTU category meter';
  end if;

  if v_meter.site_id <> v_group_site_id then
    raise exception 'BTU meter must belong to the same site as the COP group';
  end if;

  return new;
end;
$$;

create trigger cop_group_btu_meters_validate
  before insert or update on public.cop_group_btu_meters
  for each row execute function public.validate_cop_btu_meter();

-- -----------------------------------------------------------------------------
-- cop_group_electricity_meters
-- -----------------------------------------------------------------------------

create table public.cop_group_electricity_meters (
  id           uuid primary key default gen_random_uuid(),
  cop_group_id uuid not null references public.cop_groups (id) on delete cascade,
  meter_id     uuid not null references public.meters (id) on delete restrict,
  weight       numeric(10, 4) not null default 1,
  created_at   timestamptz not null default now(),

  constraint cop_group_electricity_meters_weight_positive check (weight > 0),
  constraint cop_group_electricity_meters_unique unique (cop_group_id, meter_id)
);

create index cop_group_electricity_meters_cop_group_id_idx
  on public.cop_group_electricity_meters (cop_group_id);
create index cop_group_electricity_meters_meter_id_idx
  on public.cop_group_electricity_meters (meter_id);

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

  select site_id, category into v_meter
  from public.meters
  where id = new.meter_id;

  if v_meter.category <> 'electricity' then
    raise exception 'COP electricity link requires an electricity category meter';
  end if;

  if v_meter.site_id <> v_group_site_id then
    raise exception 'Electricity meter must belong to the same site as the COP group';
  end if;

  return new;
end;
$$;

create trigger cop_group_electricity_meters_validate
  before insert or update on public.cop_group_electricity_meters
  for each row execute function public.validate_cop_electricity_meter();

-- -----------------------------------------------------------------------------
-- updated_at trigger (shared)
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger organizations_set_updated_at
  before update on public.organizations
  for each row execute function public.set_updated_at();

create trigger sites_set_updated_at
  before update on public.sites
  for each row execute function public.set_updated_at();

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger meters_set_updated_at
  before update on public.meters
  for each row execute function public.set_updated_at();

create trigger meter_readings_set_updated_at
  before update on public.meter_readings
  for each row execute function public.set_updated_at();

create trigger cop_groups_set_updated_at
  before update on public.cop_groups
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Enable RLS (policies in 002_rls_policies.sql)
-- -----------------------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.sites enable row level security;
alter table public.profiles enable row level security;
alter table public.user_site_access enable row level security;
alter table public.meters enable row level security;
alter table public.meter_readings enable row level security;
alter table public.cop_groups enable row level security;
alter table public.cop_group_btu_meters enable row level security;
alter table public.cop_group_electricity_meters enable row level security;
alter table public.reading_audit_logs enable row level security;

-- Revoke direct writes to audit log from clients (triggers + RPCs only)
revoke insert, update, delete on public.reading_audit_logs from authenticated, anon;

-- -----------------------------------------------------------------------------
-- Views (optional — for dashboard queries)
-- -----------------------------------------------------------------------------

-- Daily consumption per meter (requires two consecutive readings)
-- security_invoker ensures underlying meter_readings RLS applies per caller.
create or replace view public.meter_daily_consumption
with (security_invoker = true)
as
select
  r.meter_id,
  r.site_id,
  r.reading_date,
  r.normalized_value,
  lag(r.normalized_value) over (
    partition by r.meter_id order by r.reading_date
  ) as prev_normalized_value,
  greatest(
    0,
    r.normalized_value - coalesce(
      lag(r.normalized_value) over (
        partition by r.meter_id order by r.reading_date
      ),
      r.normalized_value
    )
  ) as daily_consumption
from public.meter_readings r;

comment on view public.meter_daily_consumption is
  'Computed daily consumption from cumulative normalized readings. First reading yields 0 consumption.';
