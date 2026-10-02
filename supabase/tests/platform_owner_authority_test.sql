-- pgTAP: platform-owner authorization is server-authoritative (migration 120).
-- Collision-safe: reuses an existing owner auth user if present, otherwise
-- creates one; the attacker uses a random address. Rolled back at the end.
begin;
select plan(20);

do $$
declare
  v_owner uuid;
  v_attacker uuid := gen_random_uuid();
  v_attacker_email text := 'attacker-' || gen_random_uuid()::text || '@example.test';
begin
  select u.id into v_owner
  from auth.users u
  where lower(trim(u.email)) = (public.platform_owner_emails())[1]
  limit 1;

  if v_owner is null then
    v_owner := gen_random_uuid();
    insert into auth.users (
      id, instance_id, aud, role, email, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) values (
      v_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
      'authenticated', (public.platform_owner_emails())[1], now(),
      '{}'::jsonb, '{}'::jsonb, now(), now()
    );
  else
    update auth.users set email_confirmed_at = coalesce(email_confirmed_at, now())
    where id = v_owner;
  end if;

  insert into auth.users (
    id, instance_id, aud, role, email, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    v_attacker, '00000000-0000-0000-0000-000000000000', 'authenticated',
    'authenticated', v_attacker_email, now(),
    '{}'::jsonb, '{}'::jsonb, now(), now()
  );

  insert into public.profiles (id, full_name, email, role, is_active, approval_status)
  values
    (v_owner, 'Owner', (public.platform_owner_emails())[1], 'super_admin', true, 'approved'),
    (v_attacker, 'Attacker', v_attacker_email, 'viewer', true, 'approved')
  on conflict (id) do nothing;

  -- Touch rows so the BEFORE trigger recomputes the flag.
  update public.profiles set full_name = full_name where id in (v_owner, v_attacker);

  perform set_config('test.owner', v_owner::text, true);
  perform set_config('test.attacker', v_attacker::text, true);
end;
$$;

-- Server-side identity checks
select ok(public.is_platform_owner_user(current_setting('test.owner')::uuid),
  'confirmed owner auth user is platform owner');
select ok(not public.is_platform_owner_user(current_setting('test.attacker')::uuid),
  'other user is not platform owner');
select ok(not public.is_platform_owner_user(null), 'null user is not owner');

-- Server-maintained client flag
select is((select is_platform_owner from public.profiles where id = current_setting('test.owner')::uuid),
  true, 'owner profile flag is true (legitimate access preserved)');
select is((select is_platform_owner from public.profiles where id = current_setting('test.attacker')::uuid),
  false, 'attacker profile flag is false');

-- Act as the attacker through the API role
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.attacker'), 'role', 'authenticated')::text, true);

select ok(not public.is_platform_owner(), 'is_platform_owner() false for attacker');

select throws_ok(
  format($q$update public.profiles set email = %L where id = %L$q$,
         'alikarim4r@gmail.com', current_setting('test.attacker')),
  '42501', null, 'attacker cannot rewrite profile email to the owner address');

select lives_ok(
  format($q$update public.profiles set is_platform_owner = true where id = %L$q$,
         current_setting('test.attacker')),
  'client write to is_platform_owner is accepted but overwritten');

select ok(not public.is_platform_owner(), 'still not owner after flag write attempt');

-- Regression (122): self-update must not hit 42P17 policy recursion, and
-- the WITH CHECK must still block privilege self-escalation.
select lives_ok(
  format($q$update public.profiles set full_name = 'Renamed' where id = %L$q$,
         current_setting('test.attacker')),
  'benign self-update of own profile succeeds (no 42P17 recursion)');
select is((select full_name from public.profiles where id = current_setting('test.attacker')::uuid),
  'Renamed', 'benign self-update persisted');
select throws_ok(
  format($q$update public.profiles set role = 'super_admin' where id = %L$q$,
         current_setting('test.attacker')),
  '42501', null, 'self role escalation is rejected by RLS');
select throws_ok(
  format($q$update public.profiles set is_active = false where id = %L$q$,
         current_setting('test.attacker')),
  '42501', null, 'self is_active change is rejected by RLS');
select throws_ok(
  format($q$update public.profiles set approval_status = 'pending' where id = %L$q$,
         current_setting('test.attacker')),
  '42501', null, 'self approval_status change is rejected by RLS');

select throws_ok('select public.platform_owner_emails()', '42501', null,
  'allowlist function is not callable by API roles');
select throws_ok(
  format($q$select public.is_platform_owner_user(%L::uuid)$q$, current_setting('test.owner')),
  '42501', null, 'per-user owner probe is not callable by API roles');

-- Act as the owner
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('test.owner'), 'role', 'authenticated')::text, true);
select ok(public.is_platform_owner(), 'is_platform_owner() true for owner');

reset role;

select ok(
  (select with_check !~* 'from\s+(public\.)?profiles'
   from pg_policies
   where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_update_own'),
  'profiles_update_own WITH CHECK no longer self-references profiles');

select is((select is_platform_owner from public.profiles where id = current_setting('test.attacker')::uuid),
  false, 'attacker flag still false after write attempt');

-- auth.users change keeps the flag in sync (unconfirmed email is not owner)
update auth.users set email_confirmed_at = null where id = current_setting('test.owner')::uuid;
select is((select is_platform_owner from public.profiles where id = current_setting('test.owner')::uuid),
  false, 'unconfirming the owner email clears the flag via auth.users trigger');

select * from finish();
rollback;
