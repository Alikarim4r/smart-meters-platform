-- =============================================================================
-- 117: Allow archive-only meter updates without revalidating legacy hierarchy.
--
-- Staging contains legacy hierarchy rows that predate the current validator.
-- Updating only archival/status columns must not fail because of unrelated,
-- pre-existing parent metadata. Hierarchy edits remain fully validated.
-- =============================================================================

create or replace function public.validate_meter_parent()
returns trigger
language plpgsql
as $$
declare
  v_parent record;
begin
  if tg_op = 'UPDATE'
     and new.parent_meter_id is not distinct from old.parent_meter_id
     and new.level is not distinct from old.level
     and new.site_id is not distinct from old.site_id
     and new.category is not distinct from old.category
     and new.category_id is not distinct from old.category_id then
    return new;
  end if;

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
  'Validates hierarchy edits; archive/status-only updates do not revalidate unrelated legacy parent metadata.';
