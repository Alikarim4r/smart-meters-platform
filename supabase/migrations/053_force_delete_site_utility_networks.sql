-- 053: Force-delete sites/orgs must clear utility-network memberships
-- (site_utility_network_members.site_id is ON DELETE RESTRICT).

create or replace function public.prevent_published_revision_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_rev uuid;
begin
  -- Allow cleanup driven by admin force-delete helpers (session GUC).
  if current_setting('app.force_delete_meter', true) = '1'
     or current_setting('app.force_delete_site', true) = '1' then
    if tg_op = 'DELETE' then
      return old;
    end if;
  end if;

  if tg_table_name = 'site_utility_network_revisions' then
    if tg_op = 'DELETE' then
      if old.status = 'published'
         and exists (
           select 1 from public.site_utility_networks n where n.id = old.network_id
         ) then
        raise exception 'Published revision is immutable';
      end if;
      return old;
    end if;
    if old.status = 'published' and (
         new.status is distinct from old.status
      or new.lock_version is distinct from old.lock_version
      or new.network_id is distinct from old.network_id
      or new.based_on_revision_id is distinct from old.based_on_revision_id
      or new.notes is distinct from old.notes
    ) then
      raise exception 'Published revision is immutable';
    end if;
    return new;
  end if;

  v_rev := coalesce(new.revision_id, old.revision_id);
  select status into v_status
  from public.site_utility_network_revisions where id = v_rev;

  if v_status is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    raise exception 'Revision not found for utility network content';
  end if;

  if v_status = 'published' then
    raise exception 'Published revision content is immutable';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- Delete a utility network and its revisions (uses force_delete_site GUC).
create or replace function public.admin_force_delete_utility_network(p_network_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_network_id is null then
    return;
  end if;
  if not exists (select 1 from public.site_utility_networks where id = p_network_id) then
    return;
  end if;

  perform set_config('app.force_delete_site', '1', true);

  update public.site_utility_networks
  set draft_revision_id = null,
      published_revision_id = null
  where id = p_network_id;

  delete from public.site_utility_networks where id = p_network_id;
end;
$$;

revoke all on function public.admin_force_delete_utility_network(uuid) from public;
grant execute on function public.admin_force_delete_utility_network(uuid) to authenticated;

create or replace function public.admin_force_delete_site(p_site_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meter_id uuid;
  v_network_id uuid;
begin
  if not (public.is_super_admin() or public.is_platform_owner()) then
    raise exception 'Only super_admin can force-delete sites';
  end if;

  if not exists (select 1 from public.sites where id = p_site_id) then
    return;
  end if;

  perform set_config('app.force_delete_site', '1', true);

  -- 1) Remove utility-network membership for this site.
  if to_regclass('public.site_utility_network_members') is not null then
    for v_network_id in
      select distinct network_id
      from public.site_utility_network_members
      where site_id = p_site_id
    loop
      delete from public.site_utility_network_members
      where network_id = v_network_id
        and site_id = p_site_id;

      -- If the network has no remaining members, delete the whole network.
      if not exists (
        select 1 from public.site_utility_network_members where network_id = v_network_id
      ) then
        perform public.admin_force_delete_utility_network(v_network_id);
      end if;
    end loop;
  end if;

  -- 2) Legacy 031 site networks (if present).
  if to_regclass('public.site_networks') is not null then
    execute 'delete from public.site_networks where site_id = $1' using p_site_id;
  end if;

  -- 3) Scope assignments pointing at this site.
  if to_regclass('public.user_scope_assignments') is not null then
    delete from public.user_scope_assignments where site_id = p_site_id;
  end if;

  -- 4) Audit rows that still reference the site.
  if to_regclass('public.reading_audit_logs') is not null then
    delete from public.reading_audit_logs where site_id = p_site_id;
  end if;

  -- 5) Meters (cascade readings / utility assets via existing helper).
  for v_meter_id in
    select id from public.meters where site_id = p_site_id
  loop
    perform public.admin_force_delete_meter(v_meter_id);
  end loop;

  -- 6) Remaining site dependents then the site.
  delete from public.user_site_access where site_id = p_site_id;
  if to_regclass('public.site_tanks') is not null then
    delete from public.site_tanks where site_id = p_site_id;
  end if;
  if to_regclass('public.cop_groups') is not null then
    delete from public.cop_groups where site_id = p_site_id;
  end if;
  if to_regclass('public.site_facility_areas') is not null then
    delete from public.site_facility_areas where site_id = p_site_id;
  end if;

  delete from public.sites where id = p_site_id;
end;
$$;

revoke all on function public.admin_force_delete_site(uuid) from public;
grant execute on function public.admin_force_delete_site(uuid) to authenticated;

comment on function public.admin_force_delete_site(uuid) is
  'Super-admin/platform-owner: cascade-delete site including utility network memberships.';

-- Keep org force-delete on the updated site helper (already calls admin_force_delete_site).
create or replace function public.admin_force_delete_organization(p_organization_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_site_id uuid;
  v_zone_id uuid;
begin
  if not (public.is_super_admin() or public.is_platform_owner()) then
    raise exception 'Only super_admin can force-delete organizations';
  end if;

  if not exists (select 1 from public.organizations where id = p_organization_id) then
    return;
  end if;

  for v_site_id in
    select id from public.sites where organization_id = p_organization_id
  loop
    perform public.admin_force_delete_site(v_site_id);
  end loop;

  update public.zones
  set parent_zone_id = null,
      default_site_type_id = null
  where organization_id = p_organization_id;

  for v_zone_id in
    select id from public.zones where organization_id = p_organization_id
  loop
    delete from public.zones where id = v_zone_id;
  end loop;

  delete from public.organizations where id = p_organization_id;
end;
$$;

revoke all on function public.admin_force_delete_organization(uuid) from public;
grant execute on function public.admin_force_delete_organization(uuid) to authenticated;
