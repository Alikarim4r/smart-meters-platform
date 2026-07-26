-- =============================================================================
-- Super-admin force delete (cascade) for meters and sites
-- Migration: 015_admin_force_delete.sql
-- =============================================================================

-- Site admins may delete sites they manage (FK still enforces dependents).
drop policy if exists "sites_delete" on public.sites;
create policy "sites_delete"
  on public.sites for delete
  to authenticated
  using (public.is_super_admin() or public.can_manage_site(id));

create or replace function public.admin_force_delete_meter(p_meter_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_site_id uuid;
begin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can force-delete meters';
  end if;

  select site_id into v_site_id from public.meters where id = p_meter_id;
  if v_site_id is null then
    return;
  end if;

  -- Detach children first (preserve rows but clear parent link).
  update public.meters
  set parent_meter_id = null,
      level = 'main'
  where parent_meter_id = p_meter_id;

  delete from public.cop_group_btu_meters where meter_id = p_meter_id;
  delete from public.cop_group_electricity_meters where meter_id = p_meter_id;

  -- Reading corrections / photos if present
  if to_regclass('public.reading_corrections') is not null then
    execute 'delete from public.reading_corrections where meter_id = $1'
      using p_meter_id;
  end if;

  delete from public.meter_readings where meter_id = p_meter_id;
  delete from public.meters where id = p_meter_id;
end;
$$;

revoke all on function public.admin_force_delete_meter(uuid) from public;
grant execute on function public.admin_force_delete_meter(uuid) to authenticated;

create or replace function public.admin_force_delete_site(p_site_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meter_id uuid;
begin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can force-delete sites';
  end if;

  for v_meter_id in
    select id from public.meters where site_id = p_site_id
  loop
    perform public.admin_force_delete_meter(v_meter_id);
  end loop;

  delete from public.user_site_access where site_id = p_site_id;
  delete from public.site_tanks where site_id = p_site_id;
  delete from public.cop_groups where site_id = p_site_id;
  delete from public.sites where id = p_site_id;
end;
$$;

revoke all on function public.admin_force_delete_site(uuid) from public;
grant execute on function public.admin_force_delete_site(uuid) to authenticated;

comment on function public.admin_force_delete_meter(uuid) is
  'Super-admin only: cascade-delete meter readings/links then the meter.';
comment on function public.admin_force_delete_site(uuid) is
  'Super-admin only: cascade-delete site meters and the site.';
