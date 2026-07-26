-- =============================================================================
-- Migration: 019_org_type_backdate_and_create_user.sql
-- 1) organizations.site_type — optional default site type for an organization
--    (schools ministry → school, awqaf → mosque…). Cascades as the default
--    when creating zones/sites under the organization.
-- 2) profiles.allow_backdated_readings — per-user permission that lets a
--    technician submit readings for past business dates in the Entry app.
--    Enforced in RLS policy + trigger (future dates always rejected).
-- 3) admin_create_user RPC — super_admin creates a ready-to-login user
--    (email+password) directly from the Admin app. Profile starts pending;
--    approval + site assignment reuse admin_approve_user.
-- =============================================================================

-- 1) Organization default site type -------------------------------------------
alter table public.organizations
  add column if not exists site_type public.site_type;

comment on column public.organizations.site_type is
  'Optional: default site type for sites in this organization. Null = mixed.';

-- 2) Per-user backdating permission --------------------------------------------
alter table public.profiles
  add column if not exists allow_backdated_readings boolean not null default false;

comment on column public.profiles.allow_backdated_readings is
  'When true, the user may submit Entry-app readings for past business dates.';

create or replace function public.can_backdate_readings()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select allow_backdated_readings from public.profiles where id = auth.uid()),
    false
  );
$$;

-- RLS: technicians may insert past dates when the per-user flag is on.
drop policy if exists "meter_readings_insert_technician" on public.meter_readings;
create policy "meter_readings_insert_technician"
  on public.meter_readings for insert
  to authenticated
  with check (
    public.is_technician_only_for_site(site_id)
    and entered_by = auth.uid()
    and (
      reading_date = public.current_business_date()
      or (
        public.can_backdate_readings()
        and reading_date < public.current_business_date()
      )
    )
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

-- Trigger mirrors the same rule (defense in depth).
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
    if new.reading_date > public.current_business_date() then
      raise exception
        'Readings cannot be dated in the future (Asia/Qatar business date: %)',
        public.current_business_date();
    end if;

    if new.reading_date <> public.current_business_date()
       and not public.can_backdate_readings() then
      raise exception
        'Technicians can only submit readings for today (Asia/Qatar business date: %). Ask an admin for backdating permission.',
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

-- 3) admin_create_user ----------------------------------------------------------
-- Mirrors scripts/phase1a_setup_test_users.sql (direct auth.users insert with
-- confirmed email), so the account can log in immediately. Super admin only.
create or replace function public.admin_create_user(
  p_email text,
  p_password text,
  p_full_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := gen_random_uuid();
  v_email text := lower(trim(p_email));
begin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can create users';
  end if;

  if v_email is null or position('@' in v_email) < 2 then
    raise exception 'Invalid email address';
  end if;

  if coalesce(length(p_password), 0) < 8 then
    raise exception 'Password must be at least 8 characters';
  end if;

  if exists (select 1 from auth.users where lower(email) = v_email) then
    raise exception 'A user with this email already exists';
  end if;

  insert into auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change
  )
  values (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    v_email,
    extensions.crypt(p_password, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', coalesce(p_full_name, '')),
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

  -- Identity row keeps newer GoTrue versions happy for email/password login.
  insert into auth.identities (
    id,
    user_id,
    provider_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  )
  values (
    gen_random_uuid(),
    v_user_id,
    v_user_id::text,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', v_email,
      'email_verified', true
    ),
    'email',
    now(),
    now(),
    now()
  );

  insert into public.profiles (
    id,
    full_name,
    email,
    role,
    is_active,
    approval_status
  )
  values (
    v_user_id,
    coalesce(nullif(trim(p_full_name), ''), split_part(v_email, '@', 1)),
    v_email,
    'viewer',
    false,
    'pending'
  );

  return v_user_id;
end;
$$;

revoke all on function public.admin_create_user(text, text, text) from public;
grant execute on function public.admin_create_user(text, text, text) to authenticated;
