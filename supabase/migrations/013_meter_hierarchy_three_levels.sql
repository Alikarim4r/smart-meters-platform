-- =============================================================================
-- Three-level meter hierarchy: main → sub → sub_sub
-- Migration: 013_meter_hierarchy_three_levels.sql
-- Depends on: 012_meter_level_sub_sub_enum.sql (committed)
-- =============================================================================

-- Drop one-level-only checks from 001_schema.
alter table public.meters
  drop constraint if exists meters_sub_requires_parent;

alter table public.meters
  drop constraint if exists meters_main_no_parent;

alter table public.meters
  add constraint meters_main_no_parent check (
    level <> 'main' or parent_meter_id is null
  );

alter table public.meters
  add constraint meters_non_main_requires_parent check (
    level = 'main' or parent_meter_id is not null
  );

comment on column public.meters.level is
  'Hierarchy: main (no parent), sub (parent=main), sub_sub (parent=sub).';

create or replace function public.validate_meter_parent()
returns trigger
language plpgsql
as $$
declare
  v_parent record;
begin
  if new.parent_meter_id is null then
    if new.level <> 'main' then
      raise exception 'Non-main meters require a parent meter';
    end if;
    return new;
  end if;

  if new.level = 'main' then
    raise exception 'Main meters cannot have a parent';
  end if;

  if new.parent_meter_id = new.id then
    raise exception 'Meter cannot be its own parent';
  end if;

  select
    site_id,
    category,
    category_id,
    level
  into v_parent
  from public.meters
  where id = new.parent_meter_id;

  if not found then
    raise exception 'Parent meter % not found', new.parent_meter_id;
  end if;

  if v_parent.site_id <> new.site_id then
    raise exception 'Parent meter must belong to the same site';
  end if;

  -- Prefer category_id when both sides have it; fall back to legacy enum.
  if new.category_id is not null and v_parent.category_id is not null then
    if v_parent.category_id <> new.category_id then
      raise exception 'Parent meter must have the same category';
    end if;
  elsif v_parent.category <> new.category then
    raise exception 'Parent meter must have the same category';
  end if;

  if new.level = 'sub' and v_parent.level <> 'main' then
    raise exception 'Sub meter parent must be a main meter';
  end if;

  if new.level = 'sub_sub' and v_parent.level <> 'sub' then
    raise exception 'Sub-sub meter parent must be a sub meter';
  end if;

  return new;
end;
$$;

comment on function public.validate_meter_parent() is
  'Enforces main→sub→sub_sub hierarchy, same site and category.';
