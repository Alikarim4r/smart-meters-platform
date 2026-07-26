-- =============================================================================
-- Super-admin force delete: organization, zone, user
-- Migration: 028_admin_force_delete_org_zone_user.sql
-- =============================================================================

-- Zone: detach children, then delete (sites.zone_id already ON DELETE SET NULL).
create or replace function public.admin_force_delete_zone(p_zone_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_child uuid;
begin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can force-delete zones';
  end if;

  if not exists (select 1 from public.zones where id = p_zone_id) then
    return;
  end if;

  -- Delete nested child zones first (parent_zone_id is ON DELETE RESTRICT).
  for v_child in
    select id from public.zones where parent_zone_id = p_zone_id
  loop
    perform public.admin_force_delete_zone(v_child);
  end loop;

  update public.zones
  set parent_zone_id = null
  where parent_zone_id = p_zone_id;

  -- Optional: clear default site type refs that might block deletes elsewhere.
  update public.zones
  set default_site_type_id = null
  where id = p_zone_id;

  delete from public.zones where id = p_zone_id;
end;
$$;

revoke all on function public.admin_force_delete_zone(uuid) from public;
grant execute on function public.admin_force_delete_zone(uuid) to authenticated;

comment on function public.admin_force_delete_zone(uuid) is
  'Super-admin only: cascade-delete nested zones, then the zone (sites become unassigned).';

-- Organization: force-delete every site, clear zone parents, delete zones, then org.
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
  if not public.is_super_admin() then
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

  -- Break zone hierarchy so deletes are not blocked by parent_zone_id RESTRICT.
  update public.zones
  set parent_zone_id = null,
      default_site_type_id = null
  where organization_id = p_organization_id;

  for v_zone_id in
    select id from public.zones where organization_id = p_organization_id
  loop
    delete from public.zones where id = v_zone_id;
  end loop;

  -- organization_site_types / policy_settings / user_scope_assignments cascade.
  delete from public.organizations where id = p_organization_id;
end;
$$;

revoke all on function public.admin_force_delete_organization(uuid) from public;
grant execute on function public.admin_force_delete_organization(uuid) to authenticated;

comment on function public.admin_force_delete_organization(uuid) is
  'Super-admin only: cascade-delete org sites/zones then the organization.';

-- User: remove auth.users (profiles cascade). Cannot delete self or other super_admins.
create or replace function public.admin_delete_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_target_role text;
begin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can delete users';
  end if;

  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  if v_actor is not null and p_user_id = v_actor then
    raise exception 'You cannot delete your own account';
  end if;

  select role::text into v_target_role
  from public.profiles
  where id = p_user_id;

  if v_target_role is null then
    -- Still try auth cleanup if profile already gone.
    delete from auth.identities where user_id = p_user_id;
    delete from auth.users where id = p_user_id;
    return;
  end if;

  if v_target_role = 'super_admin' then
    raise exception 'Cannot delete another super_admin account';
  end if;

  -- Clean optional dependents that might RESTRICT (defensive).
  if to_regclass('public.user_site_access') is not null then
    delete from public.user_site_access where user_id = p_user_id;
  end if;
  if to_regclass('public.user_scope_assignments') is not null then
    delete from public.user_scope_assignments where user_id = p_user_id;
  end if;

  delete from auth.identities where user_id = p_user_id;
  delete from auth.users where id = p_user_id;
end;
$$;

revoke all on function public.admin_delete_user(uuid) from public;
grant execute on function public.admin_delete_user(uuid) to authenticated;

comment on function public.admin_delete_user(uuid) is
  'Super-admin only: permanently delete a non-super_admin user (auth + profile).';
