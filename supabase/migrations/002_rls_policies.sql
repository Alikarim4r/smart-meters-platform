-- =============================================================================
-- Smart Meters Platform — Row Level Security Policies
-- Migration: 002_rls_policies.sql
-- Status: DRAFT — DO NOT EXECUTE without approval
-- Depends on: 001_schema.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Helper functions for RLS
-- All run as SECURITY DEFINER with search_path locked to public.
-- -----------------------------------------------------------------------------

create or replace function public.current_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid();
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
    and is_active = true;
$$;

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
      and is_active = true
  );
$$;

-- Returns true if the current user has any access row for the site
create or replace function public.has_site_access(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or exists (
      select 1
      from public.user_site_access usa
      join public.profiles p on p.id = usa.user_id
      where usa.user_id = auth.uid()
        and usa.site_id = p_site_id
        and usa.can_read = true
        and p.is_active = true
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
    or exists (
      select 1
      from public.user_site_access usa
      join public.profiles p on p.id = usa.user_id
      where usa.user_id = auth.uid()
        and usa.site_id = p_site_id
        and usa.can_write = true
        and p.is_active = true
        and usa.role in ('site_admin', 'technician')
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
    or exists (
      select 1
      from public.user_site_access usa
      join public.profiles p on p.id = usa.user_id
      where usa.user_id = auth.uid()
        and usa.site_id = p_site_id
        and usa.can_manage_meters = true
        and p.is_active = true
        and usa.role = 'site_admin'
    );
$$;

create or replace function public.can_manage_site_meters(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin() or public.can_manage_site(p_site_id);
$$;

-- True when user is technician at site (not super_admin or site_admin for that site)
create or replace function public.is_technician_only_for_site(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_site_access usa
    join public.profiles p on p.id = usa.user_id
    where usa.user_id = auth.uid()
      and usa.site_id = p_site_id
      and usa.role = 'technician'
      and usa.can_write = true
      and p.is_active = true
  )
  and not public.is_super_admin()
  and not public.can_manage_site(p_site_id);
$$;

create or replace function public.is_admin_for_site(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin() or public.can_manage_site(p_site_id);
$$;

-- Technician: today-only inserts; no update/delete (defense in depth with RLS)
create or replace function public.validate_technician_reading_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_site_id uuid;
  v_meter record;
begin
  v_site_id := coalesce(new.site_id, old.site_id);

  if not public.is_technician_only_for_site(v_site_id) then
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    if new.reading_date <> public.current_business_date() then
      raise exception
        'Technicians can only submit readings for today (Asia/Qatar business date: %)',
        public.current_business_date();
    end if;

    if new.entered_by is distinct from auth.uid() then
      raise exception 'Technicians cannot set entered_by to another user';
    end if;

    select site_id, meter_kind, calculation_type, is_active
    into v_meter
    from public.meters
    where id = new.meter_id;

    if v_meter.meter_kind <> 'physical' or v_meter.calculation_type <> 'direct_reading' then
      raise exception 'Technicians can only submit readings for physical meters';
    end if;

    if not v_meter.is_active then
      raise exception 'Technicians can only submit readings for active meters';
    end if;

    if v_meter.site_id <> new.site_id then
      raise exception 'Meter must belong to the reading site';
    end if;

    return new;
  elsif tg_op = 'UPDATE' then
    raise exception 'Technicians cannot modify saved readings. Contact a site admin for correction.';
  elsif tg_op = 'DELETE' then
    raise exception 'Technicians cannot delete readings. Contact a site admin for correction.';
  end if;

  return coalesce(new, old);
end;
$$;

create trigger meter_readings_b_validate_technician
  before insert or update or delete on public.meter_readings
  for each row execute function public.validate_technician_reading_rules();

-- Resolve site_id from meter_id (for COP junction tables)
create or replace function public.meter_site_id(p_meter_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select site_id from public.meters where id = p_meter_id;
$$;

create or replace function public.cop_group_site_id(p_cop_group_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select site_id from public.cop_groups where id = p_cop_group_id;
$$;

-- -----------------------------------------------------------------------------
-- organizations
-- -----------------------------------------------------------------------------

create policy "organizations_select"
  on public.organizations for select
  to authenticated
  using (
    public.is_super_admin()
    or exists (
      select 1
      from public.sites s
      join public.user_site_access usa on usa.site_id = s.id
      where s.organization_id = organizations.id
        and usa.user_id = auth.uid()
        and usa.can_read = true
    )
  );

create policy "organizations_insert"
  on public.organizations for insert
  to authenticated
  with check (public.is_super_admin());

create policy "organizations_update"
  on public.organizations for update
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

create policy "organizations_delete"
  on public.organizations for delete
  to authenticated
  using (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- sites
-- -----------------------------------------------------------------------------

create policy "sites_select"
  on public.sites for select
  to authenticated
  using (public.has_site_access(id));

create policy "sites_insert"
  on public.sites for insert
  to authenticated
  with check (public.is_super_admin());

create policy "sites_update"
  on public.sites for update
  to authenticated
  using (public.is_super_admin() or public.can_manage_site(id))
  with check (public.is_super_admin() or public.can_manage_site(id));

create policy "sites_delete"
  on public.sites for delete
  to authenticated
  using (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- profiles
-- -----------------------------------------------------------------------------

-- Users can read their own profile; super_admin can read all
create policy "profiles_select_own"
  on public.profiles for select
  to authenticated
  using (
    id = auth.uid()
    or public.is_super_admin()
    or exists (
      -- Site admins can see profiles of users assigned to their sites
      select 1
      from public.user_site_access usa_target
      join public.user_site_access usa_admin on usa_admin.site_id = usa_target.site_id
      where usa_target.user_id = profiles.id
        and usa_admin.user_id = auth.uid()
        and usa_admin.role = 'site_admin'
        and usa_admin.can_manage_meters = true
    )
  );

create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (id = auth.uid() or public.is_super_admin())
  with check (
    -- Non-super-admins cannot change their own role
    public.is_super_admin()
    or (id = auth.uid() and role = (select p.role from public.profiles p where p.id = auth.uid()))
  );

create policy "profiles_insert"
  on public.profiles for insert
  to authenticated
  with check (public.is_super_admin());

create policy "profiles_delete"
  on public.profiles for delete
  to authenticated
  using (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- user_site_access
-- -----------------------------------------------------------------------------

create policy "user_site_access_select"
  on public.user_site_access for select
  to authenticated
  using (
    user_id = auth.uid()
    or public.is_super_admin()
    or public.can_manage_site(site_id)
  );

create policy "user_site_access_insert"
  on public.user_site_access for insert
  to authenticated
  with check (
    public.is_super_admin()
    or public.can_manage_site(site_id)
  );

create policy "user_site_access_update"
  on public.user_site_access for update
  to authenticated
  using (
    public.is_super_admin()
    or public.can_manage_site(site_id)
  )
  with check (
    public.is_super_admin()
    or public.can_manage_site(site_id)
  );

create policy "user_site_access_delete"
  on public.user_site_access for delete
  to authenticated
  using (
    public.is_super_admin()
    or public.can_manage_site(site_id)
  );

-- -----------------------------------------------------------------------------
-- meters
-- -----------------------------------------------------------------------------

create policy "meters_select"
  on public.meters for select
  to authenticated
  using (public.has_site_access(site_id));

create policy "meters_insert"
  on public.meters for insert
  to authenticated
  with check (public.can_manage_site_meters(site_id));

create policy "meters_update"
  on public.meters for update
  to authenticated
  using (public.can_manage_site_meters(site_id))
  with check (public.can_manage_site_meters(site_id));

create policy "meters_delete"
  on public.meters for delete
  to authenticated
  using (public.is_super_admin() or public.can_manage_site(site_id));

-- -----------------------------------------------------------------------------
-- meter_readings
-- Technicians: create today (Qatar) only; no update/delete/restore/backdate.
-- Admins: full CRUD on permitted sites; all changes audit-logged via triggers.
-- -----------------------------------------------------------------------------

create policy "meter_readings_select"
  on public.meter_readings for select
  to authenticated
  using (public.has_site_access(site_id));

create policy "meter_readings_insert_technician"
  on public.meter_readings for insert
  to authenticated
  with check (
    public.is_technician_only_for_site(site_id)
    and entered_by = auth.uid()
    and reading_date = public.current_business_date()
    and exists (
      select 1
      from public.meters m
      where m.id = meter_id
        and m.site_id = meter_readings.site_id
        and m.is_active = true
        and m.meter_kind = 'physical'
        and m.calculation_type = 'direct_reading'
    )
  );

create policy "meter_readings_insert_admin"
  on public.meter_readings for insert
  to authenticated
  with check (
    public.is_admin_for_site(site_id)
    and entered_by = auth.uid()
    and exists (
      select 1
      from public.meters m
      where m.id = meter_id
        and m.site_id = meter_readings.site_id
        and m.meter_kind = 'physical'
        and m.calculation_type = 'direct_reading'
    )
  );

create policy "meter_readings_update_admin"
  on public.meter_readings for update
  to authenticated
  using (public.is_admin_for_site(site_id))
  with check (public.is_admin_for_site(site_id));

create policy "meter_readings_delete_admin"
  on public.meter_readings for delete
  to authenticated
  using (public.is_admin_for_site(site_id));

-- -----------------------------------------------------------------------------
-- reading_audit_logs (read-only for admins; writes via SECURITY DEFINER triggers)
-- -----------------------------------------------------------------------------

create policy "reading_audit_logs_select"
  on public.reading_audit_logs for select
  to authenticated
  using (
    public.is_super_admin()
    or public.can_manage_site(site_id)
  );

-- No insert/update/delete policies — clients cannot write audit logs directly.

-- -----------------------------------------------------------------------------
-- Admin RPCs (require RLS helper functions above)
-- -----------------------------------------------------------------------------

create or replace function public.admin_update_meter_multiplier(
  p_meter_id uuid,
  p_new_multiplier numeric,
  p_note text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_site_id uuid;
  v_old_multiplier numeric;
begin
  if p_new_multiplier is null or p_new_multiplier <= 0 then
    raise exception 'meter_multiplier must be positive';
  end if;

  if p_note is null or char_length(trim(p_note)) < 10 then
    raise exception 'A justification note (min 10 characters) is required when changing meter_multiplier after readings exist';
  end if;

  select site_id, meter_multiplier
  into v_site_id, v_old_multiplier
  from public.meters
  where id = p_meter_id;

  if not found then
    raise exception 'Meter not found';
  end if;

  if not (public.is_super_admin() or public.can_manage_site(v_site_id)) then
    raise exception 'Only super_admin or site_admin can change meter_multiplier after readings exist';
  end if;

  if not public.meter_has_readings(p_meter_id) then
    update public.meters
    set meter_multiplier = p_new_multiplier
    where id = p_meter_id;
    return;
  end if;

  perform set_config('app.bypass_meter_multiplier_guard', 'true', true);

  update public.meters
  set meter_multiplier = p_new_multiplier
  where id = p_meter_id;

  perform set_config('app.bypass_meter_multiplier_guard', 'false', true);

  -- Touch raw_value to fire normalized_value recalculation via trigger
  update public.meter_readings r
  set raw_value = r.raw_value
  where r.meter_id = p_meter_id;

  raise notice 'meter_multiplier changed from % to % for meter %. Justification: %',
    v_old_multiplier, p_new_multiplier, p_meter_id, p_note;
end;
$$;

comment on function public.admin_update_meter_multiplier is
  'Changes meter_multiplier with role check and justification. Recalculates normalized readings.';

create or replace function public.admin_restore_meter_reading(
  p_meter_id uuid,
  p_site_id uuid,
  p_reading_date date,
  p_raw_value numeric,
  p_image_url text default null,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reading_id uuid;
begin
  if not (public.is_super_admin() or public.can_manage_site(p_site_id)) then
    raise exception 'Only super_admin or site_admin can restore readings';
  end if;

  if p_note is null or char_length(trim(p_note)) < 10 then
    raise exception 'A correction reason (min 10 characters) is required to restore a reading';
  end if;

  perform set_config('app.reading_audit_action', 'restore', true);

  insert into public.meter_readings (
    site_id, meter_id, reading_date, raw_value, normalized_value,
    image_url, note, entered_by
  ) values (
    p_site_id, p_meter_id, p_reading_date, p_raw_value, 0,
    p_image_url, p_note, auth.uid()
  )
  returning id into v_reading_id;

  perform set_config('app.reading_audit_action', '', true);

  return v_reading_id;
end;
$$;

comment on function public.admin_restore_meter_reading is
  'Restores a deleted reading and logs action = restore in reading_audit_logs.';

grant execute on function public.admin_update_meter_multiplier(uuid, numeric, text) to authenticated;
grant execute on function public.admin_restore_meter_reading(uuid, uuid, date, numeric, text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- cop_groups
-- -----------------------------------------------------------------------------

create policy "cop_groups_select"
  on public.cop_groups for select
  to authenticated
  using (public.has_site_access(site_id));

create policy "cop_groups_insert"
  on public.cop_groups for insert
  to authenticated
  with check (public.can_manage_site(site_id));

create policy "cop_groups_update"
  on public.cop_groups for update
  to authenticated
  using (public.can_manage_site(site_id))
  with check (public.can_manage_site(site_id));

create policy "cop_groups_delete"
  on public.cop_groups for delete
  to authenticated
  using (public.can_manage_site(site_id) or public.is_super_admin());

-- -----------------------------------------------------------------------------
-- cop_group_btu_meters
-- -----------------------------------------------------------------------------

create policy "cop_group_btu_meters_select"
  on public.cop_group_btu_meters for select
  to authenticated
  using (public.has_site_access(public.cop_group_site_id(cop_group_id)));

create policy "cop_group_btu_meters_insert"
  on public.cop_group_btu_meters for insert
  to authenticated
  with check (public.can_manage_site(public.cop_group_site_id(cop_group_id)));

create policy "cop_group_btu_meters_update"
  on public.cop_group_btu_meters for update
  to authenticated
  using (public.can_manage_site(public.cop_group_site_id(cop_group_id)))
  with check (public.can_manage_site(public.cop_group_site_id(cop_group_id)));

create policy "cop_group_btu_meters_delete"
  on public.cop_group_btu_meters for delete
  to authenticated
  using (public.can_manage_site(public.cop_group_site_id(cop_group_id)));

-- -----------------------------------------------------------------------------
-- cop_group_electricity_meters
-- -----------------------------------------------------------------------------

create policy "cop_group_electricity_meters_select"
  on public.cop_group_electricity_meters for select
  to authenticated
  using (public.has_site_access(public.cop_group_site_id(cop_group_id)));

create policy "cop_group_electricity_meters_insert"
  on public.cop_group_electricity_meters for insert
  to authenticated
  with check (public.can_manage_site(public.cop_group_site_id(cop_group_id)));

create policy "cop_group_electricity_meters_update"
  on public.cop_group_electricity_meters for update
  to authenticated
  using (public.can_manage_site(public.cop_group_site_id(cop_group_id)))
  with check (public.can_manage_site(public.cop_group_site_id(cop_group_id)));

create policy "cop_group_electricity_meters_delete"
  on public.cop_group_electricity_meters for delete
  to authenticated
  using (public.can_manage_site(public.cop_group_site_id(cop_group_id)));

-- -----------------------------------------------------------------------------
-- meter_daily_consumption view
-- security_invoker (set in 001) ensures meter_readings RLS filters rows per caller.
-- -----------------------------------------------------------------------------

grant select on public.meter_daily_consumption to authenticated;

-- -----------------------------------------------------------------------------
-- Table privileges for authenticated role (RLS enforces row-level access)
-- -----------------------------------------------------------------------------

grant usage on schema public to authenticated;

grant select, insert, update, delete on all tables in schema public to authenticated;

-- Audit log: read via RLS only; writes via SECURITY DEFINER triggers
revoke insert, update, delete on public.reading_audit_logs from authenticated;

grant select on public.meter_daily_consumption to authenticated;

revoke execute on function public.audit_meter_reading_change() from authenticated, anon, public;

-- -----------------------------------------------------------------------------
-- Policy summary (reference)
-- -----------------------------------------------------------------------------
--
-- | Role         | Organizations | Sites      | Meters     | Readings        | COP  | Audit logs |
-- |--------------|---------------|------------|------------|-----------------|------|------------|
-- | super_admin  | CRUD all      | CRUD all   | CRUD all   | CRUD all        | CRUD | Read all   |
-- | site_admin   | Read (via site)| Manage assigned | CRUD assigned | Read + delete | CRUD assigned | Read assigned |
-- | technician   | Read (via site)| Read assigned | Read assigned | Create today only (Qatar); no update/delete | Read | No access  |
-- | viewer       | Read (via site)| Read assigned | Read assigned | Read assigned (no write)                    | Read | No access  |
--
-- No policies for anon role — unauthenticated access denied by default.
-- -----------------------------------------------------------------------------
