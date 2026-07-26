-- =============================================================================
-- Smart Meters Platform — User Approval & Technician Onboarding
-- Migration: 005_user_approval.sql
-- Status: DRAFT — DO NOT EXECUTE until reviewed and approved
-- Depends on: 001_schema.sql, 002_rls_policies.sql, 004_user_approval_enum.sql
--
-- Purpose:
--   - Require admin approval before technicians (and other field users) access data
--   - Block pending/rejected/suspended users at RLS layer
--   - Prevent self-assignment to sites
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. profiles columns
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists approval_status public.approval_status not null default 'pending',
  add column if not exists approval_note text,
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid references public.profiles (id) on delete set null,
  add column if not exists rejected_at timestamptz,
  add column if not exists rejected_by uuid references public.profiles (id) on delete set null;

comment on column public.profiles.approval_status is
  'Gate for all data access. Only approved + is_active users pass RLS helpers.';
comment on column public.profiles.approval_note is
  'Optional admin note on approve/reject/suspend (not shown to end user by default).';

create index if not exists profiles_approval_status_idx
  on public.profiles (approval_status);

-- -----------------------------------------------------------------------------
-- 2. Backfill existing operational accounts (prevents post-migration lockout)
--     Must run after columns exist and before helpers require approval.
-- -----------------------------------------------------------------------------

update public.profiles
set
  approval_status = 'approved',
  is_active = true,
  approved_at = coalesce(approved_at, now()),
  updated_at = now()
where email in (
  'alikarim4r@gmail.com',
  'test-super-admin@validation.local',
  'test-site-admin@validation.local',
  'test-technician@validation.local',
  'test-viewer@validation.local'
);

-- Safety net: legacy accounts with site access or elevated role.
update public.profiles p
set
  approval_status = 'approved',
  is_active = true,
  approved_at = coalesce(p.approved_at, now()),
  updated_at = now()
where p.approval_status = 'pending'
  and (
    p.role = 'super_admin'
    or exists (
      select 1
      from public.user_site_access usa
      where usa.user_id = p.id
    )
  );

-- -----------------------------------------------------------------------------
-- 3. Optional audit trail for approval actions (append-only)
-- -----------------------------------------------------------------------------

create table if not exists public.user_approval_logs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  action          text not null,
  previous_status public.approval_status,
  new_status      public.approval_status not null,
  previous_role   public.user_role,
  new_role        public.user_role,
  note            text,
  acted_by        uuid references public.profiles (id) on delete set null,
  created_at      timestamptz not null default now(),

  constraint user_approval_logs_action_not_empty
    check (char_length(trim(action)) > 0)
);

create index if not exists user_approval_logs_user_id_idx
  on public.user_approval_logs (user_id, created_at desc);

alter table public.user_approval_logs enable row level security;

grant select on public.user_approval_logs to authenticated;

-- -----------------------------------------------------------------------------
-- 4. handle_new_user — default to pending, inactive
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role_text text;
  v_requested_role public.user_role;
begin
  v_role_text := lower(trim(coalesce(
    nullif(new.raw_user_meta_data ->> 'requested_role', ''),
    nullif(new.raw_user_meta_data ->> 'role', ''),
    'viewer'
  )));

  case v_role_text
    when 'technician_request' then
      v_requested_role := 'technician_request';
    when 'viewer' then
      v_requested_role := 'viewer';
    when 'super_admin', 'site_admin', 'technician' then
      v_requested_role := 'technician_request';
    else
      v_requested_role := 'viewer';
  end case;

  insert into public.profiles (
    id,
    full_name,
    email,
    role,
    is_active,
    approval_status
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.email,
    v_requested_role,
    false,
    'pending'
  );

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5. RLS helper functions (replace / extend 002 helpers)
-- -----------------------------------------------------------------------------

create or replace function public.is_approved_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and approval_status = 'approved'
      and is_active = true
  );
$$;

comment on function public.is_approved_active_user is
  'True when caller has approved profile and is_active. Required for all site/meter/reading access.';

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'super_admin'
      and approval_status = 'approved'
      and is_active = true
  );
$$;

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.profiles
  where id = auth.uid()
    and approval_status = 'approved'
    and is_active = true;
$$;

-- Gate all site-scoped access behind approval.
create or replace function public.has_site_access(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or (
      public.is_approved_active_user()
      and exists (
        select 1
        from public.user_site_access usa
        join public.profiles p on p.id = usa.user_id
        where usa.user_id = auth.uid()
          and usa.site_id = p_site_id
          and usa.can_read = true
          and p.approval_status = 'approved'
          and p.is_active = true
      )
    );
$$;

create or replace function public.can_write_site(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or (
      public.is_approved_active_user()
      and exists (
        select 1
        from public.user_site_access usa
        join public.profiles p on p.id = usa.user_id
        where usa.user_id = auth.uid()
          and usa.site_id = p_site_id
          and usa.can_write = true
          and p.approval_status = 'approved'
          and p.is_active = true
          and usa.role in ('site_admin', 'technician')
      )
    );
$$;

create or replace function public.can_manage_site(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or (
      public.is_approved_active_user()
      and exists (
        select 1
        from public.user_site_access usa
        join public.profiles p on p.id = usa.user_id
        where usa.user_id = auth.uid()
          and usa.site_id = p_site_id
          and usa.can_manage_meters = true
          and p.approval_status = 'approved'
          and p.is_active = true
          and usa.role = 'site_admin'
      )
    );
$$;

create or replace function public.is_technician_only_for_site(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_approved_active_user()
    and exists (
      select 1
      from public.user_site_access usa
      join public.profiles p on p.id = usa.user_id
      where usa.user_id = auth.uid()
        and usa.site_id = p_site_id
        and usa.role = 'technician'
        and usa.can_write = true
        and p.role = 'technician'
        and p.approval_status = 'approved'
        and p.is_active = true
    )
    and not public.is_super_admin()
    and not public.can_manage_site(p_site_id);
$$;

-- -----------------------------------------------------------------------------
-- 6. Policy fixes — close approval bypasses from 002
-- -----------------------------------------------------------------------------

drop policy if exists "organizations_select" on public.organizations;
create policy "organizations_select"
  on public.organizations for select
  to authenticated
  using (
    public.is_super_admin()
    or exists (
      select 1
      from public.sites s
      where s.organization_id = organizations.id
        and public.has_site_access(s.id)
    )
  );

drop policy if exists "user_site_access_select" on public.user_site_access;
create policy "user_site_access_select"
  on public.user_site_access for select
  to authenticated
  using (
    (user_id = auth.uid() and public.is_approved_active_user())
    or public.is_super_admin()
    or public.can_manage_site(site_id)
  );

-- -----------------------------------------------------------------------------
-- 7. profiles policies — admins manage approval; users cannot self-approve
-- -----------------------------------------------------------------------------

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  to authenticated
  using (
    id = auth.uid()
    or public.is_super_admin()
    or (
      public.is_approved_active_user()
      and public.current_user_role() = 'site_admin'
      and (
        exists (
          select 1
          from public.user_site_access usa_target
          join public.user_site_access usa_admin on usa_admin.site_id = usa_target.site_id
          where usa_target.user_id = profiles.id
            and usa_admin.user_id = auth.uid()
            and usa_admin.role = 'site_admin'
        )
        or profiles.approval_status = 'pending'
      )
    )
  );

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (id = auth.uid() or public.is_super_admin())
  with check (
    public.is_super_admin()
    or (
      id = auth.uid()
      and role = (select p.role from public.profiles p where p.id = auth.uid())
      and approval_status = (select p.approval_status from public.profiles p where p.id = auth.uid())
      and is_active = (select p.is_active from public.profiles p where p.id = auth.uid())
    )
  );

-- -----------------------------------------------------------------------------
-- 8. user_approval_logs RLS (select admins only; inserts via RPC)
-- -----------------------------------------------------------------------------

drop policy if exists "user_approval_logs_select" on public.user_approval_logs;
create policy "user_approval_logs_select"
  on public.user_approval_logs for select
  to authenticated
  using (
    public.is_super_admin()
    or (
      public.is_approved_active_user()
      and public.current_user_role() = 'site_admin'
      and exists (
        select 1
        from public.user_site_access usa
        where usa.user_id = user_approval_logs.user_id
          and public.can_manage_site(usa.site_id)
      )
    )
  );

-- No INSERT/UPDATE/DELETE policies: authenticated users cannot write logs directly.

-- -----------------------------------------------------------------------------
-- 9. Admin RPCs (approve / reject / suspend) — no self-service
-- -----------------------------------------------------------------------------

create or replace function public.site_admin_may_manage_user(p_target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
      select 1
      from public.profiles tp
      where tp.id = p_target_user_id
        and tp.role = 'super_admin'
    )
    and (
      exists (
        select 1
        from public.profiles tp
        where tp.id = p_target_user_id
          and tp.approval_status = 'pending'
      )
      or exists (
        select 1
        from public.user_site_access usa
        where usa.user_id = p_target_user_id
          and public.can_manage_site(usa.site_id)
      )
    );
$$;

comment on function public.site_admin_may_manage_user is
  'site_admin scope: pending applicants or users with at least one managed site. Never super_admin.';

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

  if p_role = 'technician' and (p_site_ids is null or cardinality(p_site_ids) = 0) then
    raise exception 'Technician approval requires at least one site assignment';
  end if;

  if not public.is_super_admin() then
    if public.current_user_role() <> 'site_admin' then
      raise exception 'Only super_admin or site_admin can approve users';
    end if;
    if not public.site_admin_may_manage_user(p_user_id) then
      raise exception 'site_admin cannot approve this user';
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

create or replace function public.admin_reject_user(
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
begin
  if not public.is_super_admin() then
    if public.current_user_role() <> 'site_admin' then
      raise exception 'Only super_admin or site_admin can reject users';
    end if;
    if not public.site_admin_may_manage_user(p_user_id) then
      raise exception 'site_admin cannot reject this user';
    end if;
  end if;

  select approval_status, role into v_prev_status, v_prev_role
  from public.profiles where id = p_user_id for update;

  if not found then
    raise exception 'User not found';
  end if;

  if v_prev_status <> 'pending' then
    raise exception 'Only pending users can be rejected';
  end if;

  update public.profiles
  set
    approval_status = 'rejected',
    is_active = false,
    approval_note = p_note,
    rejected_at = now(),
    rejected_by = v_actor,
    updated_at = now()
  where id = p_user_id;

  insert into public.user_approval_logs (
    user_id, action, previous_status, new_status,
    previous_role, new_role, note, acted_by
  )
  values (
    p_user_id, 'reject', v_prev_status, 'rejected',
    v_prev_role, v_prev_role, p_note, v_actor
  );
end;
$$;

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
begin
  if not public.is_super_admin() then
    if public.current_user_role() <> 'site_admin' then
      raise exception 'Only super_admin or site_admin can suspend users';
    end if;
    if not public.site_admin_may_manage_user(p_user_id) then
      raise exception 'site_admin cannot suspend this user';
    end if;
  end if;

  select approval_status, role into v_prev_status, v_prev_role
  from public.profiles where id = p_user_id for update;

  if not found then
    raise exception 'User not found';
  end if;

  if exists (
    select 1 from public.profiles where id = p_user_id and role = 'super_admin'
  ) then
    raise exception 'Cannot suspend super_admin';
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

revoke all on function public.admin_approve_user(uuid, public.user_role, uuid[], text) from public;
revoke all on function public.admin_reject_user(uuid, text) from public;
revoke all on function public.admin_suspend_user(uuid, text) from public;
grant execute on function public.admin_approve_user(uuid, public.user_role, uuid[], text) to authenticated;
grant execute on function public.admin_reject_user(uuid, text) to authenticated;
grant execute on function public.admin_suspend_user(uuid, text) to authenticated;
