-- =============================================================================
-- Phase 1E — User Approval Validation
-- Run AFTER:
--   001_schema, 002_rls, 003_storage,
--   004_user_approval_enum, 005_user_approval,
--   seed, phase1a_setup_test_users
-- Safe for local/staging only. DO NOT run on production.
-- =============================================================================

\set ON_ERROR_STOP on

-- Fixed UUIDs (profiles-only test users; no auth.users required for RLS simulation)
-- pending_viewer:          bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1
-- pending_tech_request:    bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2
-- rejected_user:           bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3
-- suspended_user:          bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4

-- Existing phase1a users
-- super_admin:  aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1
-- site_admin:   aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2
-- technician:   aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3
-- viewer:       aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4

-- MOEHE HQ (assigned):     22222222-2222-4222-8222-222222222222
-- Validation other site:   66666666-6666-4666-8666-666666666601

-- =============================================================================
-- 1. SCHEMA VALIDATION
-- =============================================================================

do $$
declare
  v_count int;
  v_fn text;
begin
  raise notice '=== 1. SCHEMA VALIDATION ===';

  select count(*) into v_count
  from pg_type t
  join pg_namespace n on n.oid = t.typnamespace
  where n.nspname = 'public' and t.typname = 'approval_status';
  if v_count = 0 then
    raise exception 'MISSING ENUM: approval_status (run 004_user_approval_enum.sql)';
  end if;
  raise notice 'OK enum: approval_status';

  select count(*) into v_count
  from pg_enum e
  join pg_type t on t.oid = e.enumtypid
  join pg_namespace n on n.oid = t.typnamespace
  where n.nspname = 'public'
    and t.typname = 'user_role'
    and e.enumlabel = 'technician_request';
  if v_count = 0 then
    raise exception 'MISSING ENUM VALUE: user_role.technician_request';
  end if;
  raise notice 'OK enum value: user_role.technician_request';

  select count(*) into v_count
  from information_schema.tables
  where table_schema = 'public' and table_name = 'user_approval_logs';
  if v_count = 0 then
    raise exception 'MISSING TABLE: user_approval_logs';
  end if;
  raise notice 'OK table: user_approval_logs';

  select count(*) into v_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'profiles'
    and column_name = 'approval_status';
  if v_count = 0 then
    raise exception 'MISSING COLUMN: profiles.approval_status';
  end if;
  raise notice 'OK column: profiles.approval_status';

  foreach v_fn in array ARRAY[
    'is_approved_active_user',
    'admin_approve_user',
    'admin_reject_user',
    'admin_suspend_user',
    'site_admin_may_manage_user'
  ] loop
    select count(*) into v_count
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = v_fn;
    if v_count = 0 then
      raise exception 'MISSING FUNCTION: %', v_fn;
    end if;
    raise notice 'OK function: %', v_fn;
  end loop;
end $$;

-- =============================================================================
-- 2. BACKFILL VALIDATION
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 2. BACKFILL VALIDATION ===';

  select count(*) into v_count
  from public.profiles
  where email in (
    'test-super-admin@validation.local',
    'test-site-admin@validation.local',
    'test-technician@validation.local',
    'test-viewer@validation.local'
  )
    and approval_status = 'approved'
    and is_active = true;
  if v_count <> 4 then
    raise exception 'Expected 4 approved validation users, found %', v_count;
  end if;
  raise notice 'OK validation test users backfilled (4/4)';

  select count(*) into v_count
  from public.profiles
  where email = 'alikarim4r@gmail.com';
  if v_count = 1 then
    select count(*) into v_count
    from public.profiles
    where email = 'alikarim4r@gmail.com'
      and approval_status = 'approved'
      and is_active = true;
    if v_count <> 1 then
      raise exception 'alikarim4r@gmail.com must be approved + active after migration';
    end if;
    raise notice 'OK alikarim4r@gmail.com backfilled';
  else
    raise notice 'SKIP alikarim4r@gmail.com (not present in this environment)';
  end if;
end $$;

-- =============================================================================
-- 3. TEST FIXTURES
-- =============================================================================

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
values
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'pending-viewer@validation.local',
    crypt('ValidationPending1!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Pending Viewer"}',
    now(),
    now(),
    '', '', '', ''
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'pending-tech@validation.local',
    crypt('ValidationPending2!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Pending Tech Request","requested_role":"technician_request"}',
    now(),
    now(),
    '', '', '', ''
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'rejected-user@validation.local',
    crypt('ValidationPending3!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Rejected User"}',
    now(),
    now(),
    '', '', '', ''
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'suspended-user@validation.local',
    crypt('ValidationPending4!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Suspended User"}',
    now(),
    now(),
    '', '', '', ''
  )
on conflict (id) do nothing;

insert into auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
)
select
  id,
  id,
  jsonb_build_object('sub', id::text, 'email', email),
  'email',
  id::text,
  now(),
  now(),
  now()
from auth.users
where id in (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4'
)
on conflict (id) do nothing;

do $$
declare
  v_org uuid;
begin
  raise notice '=== 3. TEST FIXTURES ===';

  select organization_id into v_org
  from public.sites
  where id = '22222222-2222-4222-8222-222222222222';

  insert into public.sites (id, organization_id, name_en, name_ar, site_type)
  values (
    '66666666-6666-4666-8666-666666666601',
    v_org,
    'Validation Other Site',
    'موقع تحقق آخر',
    'school'
  )
  on conflict (id) do nothing;

  insert into public.profiles (id, full_name, email, role, is_active, approval_status)
  values
    (
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
      'Pending Viewer',
      'pending-viewer@validation.local',
      'viewer',
      false,
      'pending'
    ),
    (
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
      'Pending Tech Request',
      'pending-tech@validation.local',
      'technician_request',
      false,
      'pending'
    ),
    (
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3',
      'Rejected User',
      'rejected-user@validation.local',
      'viewer',
      false,
      'rejected'
    ),
    (
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4',
      'Suspended User',
      'suspended-user@validation.local',
      'technician',
      false,
      'suspended'
    )
  on conflict (id) do update set
    role = excluded.role,
    is_active = excluded.is_active,
    approval_status = excluded.approval_status;

  raise notice 'OK fixtures: pending/rejected/suspended profiles + other site';
end $$;

-- =============================================================================
-- 4. PENDING USER ISOLATION
-- =============================================================================

do $$
declare
  v_count int;
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_other uuid := '66666666-6666-4666-8666-666666666601';
  v_pending uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  v_meter uuid := '33333333-3333-4333-8333-333333333302';
begin
  raise notice '=== 4. PENDING USER ISOLATION ===';

  perform set_config('request.jwt.claim.sub', v_pending::text, true);
  set local role authenticated;

  select count(*) into v_count from public.profiles where id = v_pending;
  if v_count <> 1 then
    raise exception 'pending user cannot read own profile';
  end if;
  raise notice 'OK pending user reads own profile';

  select count(*) into v_count from public.sites where id = v_hq;
  if v_count <> 0 then
    raise exception 'pending user should not read sites';
  end if;
  raise notice 'OK pending user blocked from sites';

  select count(*) into v_count from public.meters where site_id = v_hq;
  if v_count <> 0 then
    raise exception 'pending user should not read meters';
  end if;
  raise notice 'OK pending user blocked from meters';

  select count(*) into v_count from public.meter_readings where site_id = v_hq;
  if v_count <> 0 then
    raise exception 'pending user should not read meter_readings';
  end if;
  raise notice 'OK pending user blocked from meter_readings';

  select count(*) into v_count from public.meter_daily_consumption where site_id = v_hq;
  if v_count <> 0 then
    raise exception 'pending user should not read meter_daily_consumption';
  end if;
  raise notice 'OK pending user blocked from dashboard view';

  select count(*) into v_count from public.organizations;
  if v_count <> 0 then
    raise exception 'pending user should not read organizations';
  end if;
  raise notice 'OK pending user blocked from organizations';

  select count(*) into v_count from public.user_site_access where user_id = v_pending;
  if v_count <> 0 then
    raise exception 'pending user should not read user_site_access rows';
  end if;
  raise notice 'OK pending user blocked from user_site_access self-read';

  begin
    insert into public.user_site_access (user_id, site_id, role, can_read, can_write, can_manage_meters)
    values (v_pending, v_other, 'technician', true, true, false);
    raise exception 'FAIL: pending user self-assigned site access';
  exception when others then
    raise notice 'OK pending user cannot self-assign site (%)', sqlerrm;
  end;

  reset role;
end $$;

-- =============================================================================
-- 5. TECHNICIAN_REQUEST NOT OPERATIONAL
-- =============================================================================

do $$
declare
  v_count int;
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_meter uuid := '33333333-3333-4333-8333-333333333302';
  v_pending_tech uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
  v_today date;
begin
  raise notice '=== 5. TECHNICIAN_REQUEST NOT OPERATIONAL ===';

  select public.current_business_date() into v_today;

  perform set_config('request.jwt.claim.sub', v_pending_tech::text, true);
  set local role authenticated;

  begin
    insert into public.meter_readings (
      site_id, meter_id, reading_date, raw_value, normalized_value, entered_by
    )
    values (v_hq, v_meter, v_today, 1, 1, v_pending_tech);
    raise exception 'FAIL: technician_request pending user inserted reading';
  exception when others then
    raise notice 'OK technician_request cannot insert reading (%)', sqlerrm;
  end;

  select count(*) into v_count from public.sites where id = v_hq;
  if v_count <> 0 then
    raise exception 'technician_request pending user should not read sites';
  end if;
  raise notice 'OK technician_request pending blocked from sites';

  reset role;
end $$;

-- =============================================================================
-- 6. REJECTED / SUSPENDED BLOCKED
-- =============================================================================

do $$
declare
  v_count int;
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
begin
  raise notice '=== 6. REJECTED / SUSPENDED BLOCKED ===';

  perform set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', true);
  set local role authenticated;
  select count(*) into v_count from public.sites where id = v_hq;
  if v_count <> 0 then raise exception 'rejected user should not read sites'; end if;
  select count(*) into v_count from public.profiles where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3';
  if v_count <> 1 then raise exception 'rejected user should read own profile'; end if;
  reset role;
  raise notice 'OK rejected user: own profile only, no sites';

  perform set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4', true);
  set local role authenticated;
  select count(*) into v_count from public.sites where id = v_hq;
  if v_count <> 0 then raise exception 'suspended user should not read sites'; end if;
  select count(*) into v_count from public.profiles where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4';
  if v_count <> 1 then raise exception 'suspended user should read own profile'; end if;
  reset role;
  raise notice 'OK suspended user: own profile only, no sites';
end $$;

-- =============================================================================
-- 7. SUPER_ADMIN REMAINS ACCESSIBLE
-- =============================================================================

do $$
declare
  v_count int;
  v_super uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
begin
  raise notice '=== 7. SUPER_ADMIN ACCESS ===';

  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;

  select count(*) into v_count from public.sites;
  if v_count < 2 then
    raise exception 'super_admin should see all sites (found %)', v_count;
  end if;
  raise notice 'OK super_admin reads all sites (count=%)', v_count;

  reset role;
end $$;

-- =============================================================================
-- 8. APPROVAL RPCs — PERMISSIONS & SCOPE
-- =============================================================================

do $$
declare
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_other uuid := '66666666-6666-4666-8666-666666666601';
  v_pending_tech uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
  v_super uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_site_admin uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  v_technician uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3';
  v_viewer uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  v_log_count int;
begin
  raise notice '=== 8. APPROVAL RPC PERMISSIONS ===';

  -- Technician cannot approve
  perform set_config('request.jwt.claim.sub', v_technician::text, true);
  set local role authenticated;
  begin
    perform public.admin_approve_user(v_pending_tech, 'technician', array[v_hq], 'should fail');
    raise exception 'FAIL: technician approved user';
  exception when others then
    raise notice 'OK technician cannot approve (%)', sqlerrm;
  end;
  reset role;

  -- Viewer cannot approve
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  set local role authenticated;
  begin
    perform public.admin_approve_user(v_pending_tech, 'viewer', null, 'should fail');
    raise exception 'FAIL: viewer approved user';
  exception when others then
    raise notice 'OK viewer cannot approve (%)', sqlerrm;
  end;
  reset role;

  -- Self-approve blocked
  perform set_config('request.jwt.claim.sub', v_pending_tech::text, true);
  set local role authenticated;
  begin
    perform public.admin_approve_user(v_pending_tech, 'technician', array[v_hq], 'self');
    raise exception 'FAIL: user self-approved';
  exception when others then
    raise notice 'OK self-approve blocked (%)', sqlerrm;
  end;
  reset role;

  -- site_admin cannot assign unmanaged site
  perform set_config('request.jwt.claim.sub', v_site_admin::text, true);
  set local role authenticated;
  begin
    perform public.admin_approve_user(v_pending_tech, 'technician', array[v_other], 'bad site');
    raise exception 'FAIL: site_admin assigned unmanaged site';
  exception when others then
    raise notice 'OK site_admin blocked from unmanaged site (%)', sqlerrm;
  end;
  reset role;

  -- super_admin approves pending technician_request + assigns HQ site
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;
  perform public.admin_approve_user(
    v_pending_tech,
    'technician',
    array[v_hq],
    'approved by validation test'
  );
  reset role;
  raise notice 'OK super_admin approved pending technician';

  select count(*) into v_log_count
  from public.user_approval_logs
  where user_id = v_pending_tech and action = 'approve';
  if v_log_count < 1 then
    raise exception 'approve action not logged';
  end if;
  raise notice 'OK approve action logged';

  -- Approved technician sees assigned site only
  perform set_config('request.jwt.claim.sub', v_pending_tech::text, true);
  set local role authenticated;
  if (select count(*) from public.sites where id = v_hq) <> 1 then
    raise exception 'approved technician cannot read assigned site';
  end if;
  if (select count(*) from public.sites where id = v_other) <> 0 then
    raise exception 'approved technician should not read unassigned site';
  end if;
  reset role;
  raise notice 'OK approved technician: assigned site only';

  -- Manual approval log insert blocked
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  set local role authenticated;
  begin
    insert into public.user_approval_logs (
      user_id, action, new_status, acted_by
    )
    values (v_viewer, 'fake', 'approved', v_viewer);
    raise exception 'FAIL: viewer inserted approval log';
  exception when others then
    raise notice 'OK manual approval log insert blocked (%)', sqlerrm;
  end;
  reset role;
end $$;

-- =============================================================================
-- 9. REJECT / SUSPEND LOGGING
-- =============================================================================

do $$
declare
  v_super uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_pending_viewer uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  v_log_count int;
begin
  raise notice '=== 9. REJECT / SUSPEND LOGGING ===';

  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;
  perform public.admin_reject_user(v_pending_viewer, 'validation reject');
  reset role;

  select count(*) into v_log_count
  from public.user_approval_logs
  where user_id = v_pending_viewer and action = 'reject';
  if v_log_count < 1 then
    raise exception 'reject action not logged';
  end if;
  raise notice 'OK reject action logged';

  -- Re-approve suspended fixture user then suspend for log test
  update public.profiles
  set approval_status = 'approved', is_active = true, role = 'technician'
  where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4';

  insert into public.user_site_access (user_id, site_id, role, can_read, can_write, can_manage_meters)
  values (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4',
    '22222222-2222-4222-8222-222222222222',
    'technician', true, true, false
  )
  on conflict (user_id, site_id) do nothing;

  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;
  perform public.admin_suspend_user('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4', 'validation suspend');
  reset role;

  select count(*) into v_log_count
  from public.user_approval_logs
  where user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb4' and action = 'suspend';
  if v_log_count < 1 then
    raise exception 'suspend action not logged';
  end if;
  raise notice 'OK suspend action logged';
end $$;

-- =============================================================================
-- DONE
-- =============================================================================

do $$
begin
  raise notice '=== PHASE 1E USER APPROVAL VALIDATION: ALL CHECKS PASSED ===';
end $$;
