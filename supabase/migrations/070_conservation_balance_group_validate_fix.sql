-- Hotfix for 068 validate function (meters has unit_id, not unit_code).
-- Additive REPLACE only — no DROP of tables. Does not touch 056–062.
create or replace function public.conservation_balance_group_validate()
returns trigger
language plpgsql
as $$
declare
  v_group record;
  v_main record;
  v_member record;
  v_virtual record;
begin
  if tg_table_name = 'conservation_balance_groups' then
    select m.id, m.site_id, m.meter_kind
      into v_main
    from public.meters m
    where m.id = new.main_meter_id;

    if not found then
      raise exception 'Main meter % not found', new.main_meter_id;
    end if;
    if v_main.site_id <> new.site_id then
      raise exception 'Main meter must belong to balance group site';
    end if;

    if new.virtual_meter_id is not null then
      select m.id, m.site_id, m.meter_kind, m.calculation_type
        into v_virtual
      from public.meters m
      where m.id = new.virtual_meter_id;
      if not found then
        raise exception 'Virtual meter % not found', new.virtual_meter_id;
      end if;
      if v_virtual.site_id <> new.site_id then
        raise exception 'Virtual meter must belong to balance group site';
      end if;
      if v_virtual.meter_kind <> 'virtual' then
        raise exception 'virtual_meter_id must reference meter_kind=virtual';
      end if;
      if v_virtual.calculation_type <> 'parent_minus_children' then
        raise exception 'Linked virtual meter must use parent_minus_children';
      end if;
    end if;
    return new;
  end if;

  select g.*, s.organization_id
    into v_group
  from public.conservation_balance_groups g
  join public.sites s on s.id = g.site_id
  where g.id = new.balance_group_id;

  if not found then
    raise exception 'Balance group % not found', new.balance_group_id;
  end if;

  if new.member_meter_id = v_group.main_meter_id then
    raise exception 'Member cannot be the main meter';
  end if;

  select m.id, m.site_id into v_member
  from public.meters m
  where m.id = new.member_meter_id;

  if not found then
    raise exception 'Member meter % not found', new.member_meter_id;
  end if;
  if v_member.site_id <> v_group.site_id then
    raise exception 'Balance members must be on the same site';
  end if;

  return new;
end;
$$;
