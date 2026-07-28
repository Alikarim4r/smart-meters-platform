-- =============================================================================
-- 061: Atomic user approval — require sites for technician/viewer, mirror scopes
-- =============================================================================
-- Fixes: approved accounts with zero readable/writable sites (empty p_site_ids
-- allowed for super_admin actors). Also mirrors user_scope_assignments in the
-- same transaction so Flutter dual-write cannot leave half-applied state.
-- =============================================================================

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
set row_security = off
as $$
declare
  v_actor uuid := auth.uid();
  v_prev_status public.approval_status;
  v_prev_role public.user_role;
  v_site_id uuid;
  v_scope_role_code text;
  v_scope_role_id uuid;
  v_can_write boolean;
  v_can_manage boolean;
begin
  if v_actor is null then
    raise exception 'Not authenticated';
  end if;

  if p_user_id = v_actor and not public.is_super_admin() then
    raise exception 'Users cannot approve themselves';
  end if;

  if p_role = 'super_admin' then
    if not public.is_platform_owner() then
      raise exception 'Only platform owner can approve as super_admin';
    end if;
  elsif p_role not in ('technician', 'viewer', 'site_admin') then
    raise exception 'Invalid role for approval: %', p_role;
  end if;

  if not public.is_super_admin() then
    if public.current_user_role() <> 'site_admin' then
      raise exception 'Only super_admin or site_admin can approve users';
    end if;
    if not public.site_admin_may_manage_user(p_user_id) then
      raise exception 'site_admin cannot approve this user';
    end if;
  end if;

  -- Always require ≥1 site for operational app roles (including when actor is
  -- super_admin / platform owner).
  if p_role in ('technician', 'viewer', 'site_admin') then
    if p_site_ids is null or cardinality(p_site_ids) = 0 then
      raise exception
        'Site assignment required: select at least one site for role %',
        p_role;
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

  v_can_write := p_role in ('technician', 'site_admin', 'super_admin');
  v_can_manage := p_role in ('site_admin', 'super_admin');

  v_scope_role_code := case p_role
    when 'super_admin' then 'system_admin'
    when 'site_admin' then 'site_admin'
    when 'technician' then 'reading_entry'
    when 'viewer' then 'viewer'
    else null
  end;

  if v_scope_role_code is not null then
    select id into v_scope_role_id
    from public.roles
    where code = v_scope_role_code
    limit 1;
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
      if not public.is_super_admin()
         and not public.is_platform_owner()
         and not public.can_manage_site(v_site_id) then
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
        v_can_write,
        v_can_manage
      )
      on conflict (user_id, site_id) do update set
        role = excluded.role,
        can_read = excluded.can_read,
        can_write = excluded.can_write,
        can_manage_meters = excluded.can_manage_meters;

      -- Mirror into scoped RBAC when role catalog row exists (idempotent).
      if v_scope_role_id is not null then
        if not exists (
          select 1
          from public.user_scope_assignments usa
          where usa.user_id = p_user_id
            and usa.role_id = v_scope_role_id
            and usa.site_id = v_site_id
            and usa.status = 'active'
        ) then
          insert into public.user_scope_assignments (
            user_id,
            role_id,
            organization_id,
            zone_id,
            site_id,
            inherit_children,
            status
          )
          values (
            p_user_id,
            v_scope_role_id,
            null,
            null,
            v_site_id,
            false,
            'active'
          );
        end if;
      end if;
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

comment on function public.admin_approve_user(uuid, public.user_role, uuid[], text) is
  'Approve user, require sites for technician/viewer/site_admin, write user_site_access + scope mirror atomically.';
