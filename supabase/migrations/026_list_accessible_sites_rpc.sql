-- =============================================================================
-- Migration: 026_list_accessible_sites_rpc.sql
-- RPCs so Entry/Dashboard resolve inherited scopes (not only user_site_access).
-- Also: approve without site rows when scopes are assigned separately;
--       org scope covers all org sites regardless of inherit flag.
-- =============================================================================

create or replace function public.list_readable_site_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select s.id
  from public.sites s
  where s.is_active = true
    and public.has_site_access(s.id);
$$;

create or replace function public.list_writable_site_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select s.id
  from public.sites s
  where s.is_active = true
    and public.can_write_site(s.id);
$$;

revoke all on function public.list_readable_site_ids() from public;
revoke all on function public.list_writable_site_ids() from public;
grant execute on function public.list_readable_site_ids() to authenticated;
grant execute on function public.list_writable_site_ids() to authenticated;

-- Org scope: cover all current/future sites in the organization
create or replace function public.user_has_scope_for_site(
  p_site_id uuid,
  p_permission text default 'view'
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_zone uuid;
  v_parent uuid;
begin
  if not public.is_approved_active_user() then
    return false;
  end if;

  if public.is_super_admin() then
    return true;
  end if;

  select organization_id, zone_id into v_org, v_zone
  from public.sites where id = p_site_id;
  if v_org is null then
    return false;
  end if;

  if exists (
    select 1
    from public.user_scope_assignments usa
    join public.role_permissions rp on rp.role_id = usa.role_id
    join public.permissions p on p.id = rp.permission_id
    where usa.user_id = auth.uid()
      and usa.status = 'active'
      and usa.site_id = p_site_id
      and p.code = p_permission
  ) then
    return true;
  end if;

  if exists (
    select 1
    from public.user_scope_assignments usa
    join public.role_permissions rp on rp.role_id = usa.role_id
    join public.permissions p on p.id = rp.permission_id
    where usa.user_id = auth.uid()
      and usa.status = 'active'
      and usa.organization_id = v_org
      and p.code = p_permission
  ) then
    return true;
  end if;

  if v_zone is not null then
    if exists (
      select 1
      from public.user_scope_assignments usa
      join public.role_permissions rp on rp.role_id = usa.role_id
      join public.permissions p on p.id = rp.permission_id
      where usa.user_id = auth.uid()
        and usa.status = 'active'
        and usa.zone_id = v_zone
        and p.code = p_permission
    ) then
      return true;
    end if;

    v_parent := v_zone;
    while v_parent is not null loop
      if exists (
        select 1
        from public.user_scope_assignments usa
        join public.role_permissions rp on rp.role_id = usa.role_id
        join public.permissions p on p.id = rp.permission_id
        where usa.user_id = auth.uid()
          and usa.status = 'active'
          and usa.zone_id = v_parent
          and usa.inherit_children = true
          and p.code = p_permission
      ) then
        return true;
      end if;
      select parent_zone_id into v_parent from public.zones where id = v_parent;
    end loop;
  end if;

  return false;
end;
$$;

-- Allow approval without site_ids when scope assignments are used instead.
create or replace function public.admin_approve_user(
  p_user_id uuid,
  p_role public.user_role,
  p_site_ids uuid[],
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_prev_status public.approval_status;
  v_prev_role public.user_role;
  v_site_id uuid;
begin
  if p_user_id = v_actor and not public.is_super_admin() then
    raise exception 'Users cannot approve themselves';
  end if;

  if p_role not in ('technician', 'viewer', 'site_admin') then
    raise exception 'Invalid role for approval: %', p_role;
  end if;

  if not public.is_super_admin() then
    if public.current_user_role() <> 'site_admin' then
      raise exception 'Only super_admin or site_admin can approve users';
    end if;
    if not public.site_admin_may_manage_user(p_user_id) then
      raise exception 'site_admin cannot approve this user';
    end if;
    -- Non-super admins still must assign at least one site via legacy path
    if p_site_ids is null or cardinality(p_site_ids) = 0 then
      raise exception 'Site assignment required';
    end if;
  end if;

  select approval_status, role
  into v_prev_status, v_prev_role
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'User not found';
  end if;

  if v_prev_status not in ('pending', 'suspended') then
    raise exception 'User is not in approvable state: %', v_prev_status;
  end if;

  update public.profiles
  set
    role = p_role,
    approval_status = 'approved',
    is_active = true,
    approval_note = p_note,
    approved_at = now(),
    approved_by = v_actor,
    rejected_at = null,
    rejected_by = null,
    updated_at = now()
  where id = p_user_id;

  if p_site_ids is not null then
    foreach v_site_id in array p_site_ids loop
      if not public.is_super_admin() and not public.can_manage_site(v_site_id) then
        raise exception 'Cannot assign site %', v_site_id;
      end if;

      insert into public.user_site_access (
        user_id, site_id, role, can_read, can_write, can_manage_meters
      )
      values (
        p_user_id,
        v_site_id,
        p_role,
        true,
        p_role in ('technician', 'site_admin'),
        p_role = 'site_admin'
      )
      on conflict (user_id, site_id) do update set
        role = excluded.role,
        can_read = excluded.can_read,
        can_write = excluded.can_write,
        can_manage_meters = excluded.can_manage_meters;
    end loop;
  end if;

  insert into public.user_approval_logs (
    user_id, action, previous_status, new_status,
    previous_role, new_role, note, acted_by
  )
  values (
    p_user_id, 'approve', v_prev_status, 'approved',
    v_prev_role, p_role, p_note, v_actor
  );
end;
$$;
