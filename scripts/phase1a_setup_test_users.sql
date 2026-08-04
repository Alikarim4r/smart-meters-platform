-- =============================================================================
-- Phase 1A — Test user setup (LOCAL / STAGING ONLY — NOT PRODUCTION)
-- Run AFTER migrations + seed. Requires auth schema access.
-- =============================================================================

begin;

-- Supply passwords as PostgreSQL session settings; never store real values here.
-- Example with psql: set each value with set_config(...) before running this file.
do $credential_guard$
declare
  setting_name text;
begin
  foreach setting_name in array array[
    'app.validation_password_super_admin',
    'app.validation_password_site_admin',
    'app.validation_password_technician',
    'app.validation_password_viewer'
  ]
  loop
    if nullif(current_setting(setting_name, true), '') is null then
      raise exception 'Missing session credential setting: %', setting_name;
    end if;
  end loop;
end
$credential_guard$;

-- Fixed UUIDs for RLS validation (reproducible)
-- super_admin:  aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1
-- site_admin:   aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2
-- technician:   aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3
-- viewer:       aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4

-- MOEHE HQ site from seed
-- 22222222-2222-4222-8222-222222222222

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
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'test-super-admin@validation.local',
    crypt(current_setting('app.validation_password_super_admin'), gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Test Super Admin"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'test-site-admin@validation.local',
    crypt(current_setting('app.validation_password_site_admin'), gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Test Site Admin"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'test-technician@validation.local',
    crypt(current_setting('app.validation_password_technician'), gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Test Technician"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'test-viewer@validation.local',
    crypt(current_setting('app.validation_password_viewer'), gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Test Viewer"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  )
on conflict (id) do nothing;

insert into auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
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
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4'
)
on conflict do nothing;

-- Profiles (trigger may not be enabled yet)
insert into public.profiles (id, full_name, email, role, is_active)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'Test Super Admin', 'test-super-admin@validation.local', 'super_admin', true),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'Test Site Admin', 'test-site-admin@validation.local', 'site_admin', true),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', 'Test Technician', 'test-technician@validation.local', 'technician', true),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', 'Test Viewer', 'test-viewer@validation.local', 'viewer', true)
on conflict (id) do update set
  role = excluded.role,
  full_name = excluded.full_name,
  email = excluded.email,
  is_active = true,
  approval_status = 'approved',
  updated_at = now();

-- Site access for non-super users (MOEHE HQ)
insert into public.user_site_access (user_id, site_id, role, can_read, can_write, can_manage_meters)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', '22222222-2222-4222-8222-222222222222', 'site_admin', true, true, true),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', '22222222-2222-4222-8222-222222222222', 'technician', true, true, false),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', '22222222-2222-4222-8222-222222222222', 'viewer', true, false, false)
on conflict (user_id, site_id) do update set
  role = excluded.role,
  can_read = excluded.can_read,
  can_write = excluded.can_write,
  can_manage_meters = excluded.can_manage_meters;

commit;

-- Passwords are intentionally not stored in source.
-- Required session settings:
--   app.validation_password_super_admin
--   app.validation_password_site_admin
--   app.validation_password_technician
--   app.validation_password_viewer
