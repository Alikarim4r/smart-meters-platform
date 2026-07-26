-- =============================================================================
-- Migration: 017_gj_catalog_and_reclassify.sql
-- GJ catalog unit, sync/protect updates, and admin_reclassify_meter RPC.
-- Requires 016 (enum label `gj` committed).
-- COP wiring for MOEHE HQ CHW loops is applied via staging script.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Factor lookup: include gj
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
    when p_category = 'electricity' and p_unit = 'kvah' then 1
    -- BTU → kWh thermal
    when p_category = 'btu' and p_unit = 'kwh_thermal' then 1
    when p_category = 'btu' and p_unit = 'btu'         then 0.000293071
    when p_category = 'btu' and p_unit = 'ton_hour'    then 3.51685
    when p_category = 'btu' and p_unit = 'rt_hour'     then 3.51685
    when p_category = 'btu' and p_unit = 'gj'          then 277.777778
    else null
  end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Catalog unit: gj under BTU category
-- -----------------------------------------------------------------------------

insert into public.meter_units (
  id, category_id, code, name_en, name_ar, unit_to_base_factor, is_base, sort_order, is_active
)
values (
  'e1111111-1111-4111-8111-111111111305',
  'c1111111-1111-4111-8111-111111111103',
  'gj',
  'GJ',
  'جيجاجول',
  277.777778,
  false,
  5,
  true
)
on conflict (category_id, code) do update set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  unit_to_base_factor = excluded.unit_to_base_factor,
  is_active = true,
  sort_order = excluded.sort_order;

-- Allow sync trigger to map catalog gj → legacy enum
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
    'm3', 'liter', 'dm3', 'gallon', 'kwh', 'mwh', 'wh', 'kvah',
    'kwh_thermal', 'btu', 'ton_hour', 'rt_hour', 'gj'
  ) then
    new.unit := v_unit.code::public.meter_unit;
  end if;

  new.unit_to_base_factor := v_unit.unit_to_base_factor;
  new.base_unit := v_category.base_unit_code;

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Protect trigger — allow controlled bypass for reclassify
-- -----------------------------------------------------------------------------

create or replace function public.protect_meter_unit_integrity()
returns trigger
language plpgsql
as $$
declare
  v_bypass boolean;
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
    v_bypass := coalesce(
      current_setting('app.bypass_meter_unit_integrity', true),
      'false'
    ) = 'true';

    if not v_bypass then
      raise exception
        'Cannot change unit/category after readings exist for meter %. Create a new meter instead.',
        old.meter_code;
    end if;
  end if;

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Super-admin reclassify + renormalize readings
-- -----------------------------------------------------------------------------

create or replace function public.admin_reclassify_meter(
  p_meter_id uuid,
  p_category_id uuid,
  p_source_id uuid,
  p_unit_id uuid,
  p_name_en text default null,
  p_name_ar text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_factor numeric;
  v_base text;
  v_cat_code text;
  v_unit_code text;
begin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can reclassify meters with existing readings';
  end if;

  if not exists (select 1 from public.meters where id = p_meter_id) then
    raise exception 'Meter % not found', p_meter_id;
  end if;

  select mc.code, mc.base_unit_code, mu.code, mu.unit_to_base_factor
    into v_cat_code, v_base, v_unit_code, v_factor
  from public.meter_categories mc
  join public.meter_units mu on mu.category_id = mc.id
  where mc.id = p_category_id
    and mu.id = p_unit_id;

  if not found then
    raise exception 'category_id/unit_id mismatch';
  end if;

  if not exists (
    select 1 from public.meter_sources
    where id = p_source_id and category_id = p_category_id
  ) then
    raise exception 'source_id does not belong to category_id';
  end if;

  perform set_config('app.bypass_meter_unit_integrity', 'true', true);

  update public.meters
  set category_id = p_category_id,
      source_id = p_source_id,
      unit_id = p_unit_id,
      name_en = coalesce(nullif(trim(p_name_en), ''), name_en),
      name_ar = coalesce(nullif(trim(p_name_ar), ''), name_ar),
      updated_at = now()
  where id = p_meter_id;

  -- Ensure factors are applied even if sync missed a race.
  update public.meters
  set unit_to_base_factor = v_factor,
      base_unit = v_base,
      category = v_cat_code::public.meter_category,
      unit = v_unit_code::public.meter_unit
  where id = p_meter_id;

  -- Renormalize all readings for this meter.
  update public.meter_readings r
  set normalized_value = r.raw_value * v_factor * m.meter_multiplier,
      updated_at = now()
  from public.meters m
  where r.meter_id = m.id
    and m.id = p_meter_id;

  perform set_config('app.bypass_meter_unit_integrity', 'false', true);
end;
$$;

revoke all on function public.admin_reclassify_meter(uuid, uuid, uuid, uuid, text, text) from public;
grant execute on function public.admin_reclassify_meter(uuid, uuid, uuid, uuid, text, text) to authenticated;

comment on function public.admin_reclassify_meter(uuid, uuid, uuid, uuid, text, text) is
  'Super-admin only: reclassify meter category/source/unit after readings exist and renormalize readings.';
