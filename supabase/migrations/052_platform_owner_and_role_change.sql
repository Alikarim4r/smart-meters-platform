-- Platform owner (super-super-admin) powers for private ministry deployment.
-- Owner email allowlist — never store passwords in SQL/app code.

create or replace function public.is_platform_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and lower(trim(p.email)) = any (array[
        'alikarim4r@gmail.com'
      ])
  );
$$;

comment on function public.is_platform_owner() is
  'True when the signed-in profile email is in the platform-owner allowlist.';

grant execute on function public.is_platform_owner() to authenticated;

-- Ensure known owner account is approved super_admin when present.
update public.profiles
set
  role = 'super_admin',
  approval_status = 'approved',
  is_active = true,
  updated_at = now()
where lower(trim(email)) = 'alikarim4r@gmail.com';

-- Delete users: platform owner may delete other super_admins (not self / not owners).
create or replace function public.admin_delete_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_target_role text;
  v_target_email text;
begin
  if not (public.is_super_admin() or public.is_platform_owner()) then
    raise exception 'Only super_admin can delete users';
  end if;

  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  if v_actor is not null and p_user_id = v_actor then
    raise exception 'You cannot delete your own account';
  end if;

  select role::text, lower(trim(email))
  into v_target_role, v_target_email
  from public.profiles
  where id = p_user_id;

  if v_target_role is null then
    delete from auth.identities where user_id = p_user_id;
    delete from auth.users where id = p_user_id;
    return;
  end if;

  if v_target_email = any (array['alikarim4r@gmail.com']) then
    raise exception 'Cannot delete a platform owner account';
  end if;

  if v_target_role = 'super_admin' and not public.is_platform_owner() then
    raise exception 'Cannot delete another super_admin account';
  end if;

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
  'Super-admin deletes non-super users; platform owner may also delete other super_admins.';

-- Approve: platform owner may grant super_admin.
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
        p_role in ('technician', 'site_admin', 'super_admin'),
        p_role in ('site_admin', 'super_admin')
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

-- Change role for an already-approved account (permissions editor).
create or replace function public.admin_change_user_role(
  p_user_id uuid,
  p_role public.user_role,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_prev_role public.user_role;
  v_prev_status public.approval_status;
  v_target_email text;
begin
  if not (public.is_super_admin() or public.is_platform_owner()) then
    raise exception 'Only super_admin can change user roles';
  end if;

  if p_user_id = v_actor then
    raise exception 'You cannot change your own role here';
  end if;

  if p_role = 'super_admin' and not public.is_platform_owner() then
    raise exception 'Only platform owner can assign super_admin';
  end if;

  if p_role not in ('super_admin', 'site_admin', 'technician', 'viewer') then
    raise exception 'Invalid role: %', p_role;
  end if;

  select role, approval_status, lower(trim(email))
  into v_prev_role, v_prev_status, v_target_email
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'User not found';
  end if;

  if v_target_email = any (array['alikarim4r@gmail.com']) then
    raise exception 'Cannot change platform owner role';
  end if;

  if v_prev_role = 'super_admin' and not public.is_platform_owner() then
    raise exception 'Cannot change another super_admin role';
  end if;

  update public.profiles
  set
    role = p_role,
    approval_note = coalesce(p_note, approval_note),
    updated_at = now()
  where id = p_user_id;

  -- Keep site access flags roughly aligned with role.
  if to_regclass('public.user_site_access') is not null then
    update public.user_site_access
    set
      role = p_role,
      can_read = true,
      can_write = p_role in ('technician', 'site_admin', 'super_admin'),
      can_manage_meters = p_role in ('site_admin', 'super_admin')
    where user_id = p_user_id;
  end if;

  insert into public.user_approval_logs (
    user_id, action, previous_status, new_status,
    previous_role, new_role, note, acted_by
  )
  values (
    p_user_id, 'change_role', v_prev_status, v_prev_status,
    v_prev_role, p_role, p_note, v_actor
  );
end;
$$;

revoke all on function public.admin_change_user_role(uuid, public.user_role, text) from public;
grant execute on function public.admin_change_user_role(uuid, public.user_role, text) to authenticated;

comment on function public.admin_change_user_role(uuid, public.user_role, text) is
  'Super-admin changes roles; platform owner may assign/change super_admin.';

-- Suspend: platform owner may suspend other super_admins.
create or replace function public.admin_suspend_user(
  p_user_id uuid,
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
  v_target_email text;
begin
  if not public.is_super_admin() then
    if public.current_user_role() <> 'site_admin' then
      raise exception 'Only super_admin or site_admin can suspend users';
    end if;
    if not public.site_admin_may_manage_user(p_user_id) then
      raise exception 'site_admin cannot suspend this user';
    end if;
  end if;

  if p_user_id = v_actor then
    raise exception 'You cannot suspend yourself';
  end if;

  select approval_status, role, lower(trim(email))
  into v_prev_status, v_prev_role, v_target_email
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'User not found';
  end if;

  if v_target_email = any (array['alikarim4r@gmail.com']) then
    raise exception 'Cannot suspend a platform owner account';
  end if;

  if v_prev_role = 'super_admin' and not public.is_platform_owner() then
    raise exception 'Cannot suspend a super_admin account';
  end if;

  update public.profiles
  set
    approval_status = 'suspended',
    is_active = false,
    approval_note = p_note,
    updated_at = now()
  where id = p_user_id;

  insert into public.user_approval_logs (
    user_id, action, previous_status, new_status,
    previous_role, new_role, note, acted_by
  )
  values (
    p_user_id, 'suspend', v_prev_status, 'suspended',
    v_prev_role, v_prev_role, p_note, v_actor
  );
end;
$$;
