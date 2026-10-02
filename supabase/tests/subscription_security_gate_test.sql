-- pgTAP: Subscription Security & Enforcement Gate (PR #2, migration 20261002170000).
-- Adversarial regression suite: role/scope, entitlement tampering, quota
-- enforcement, function/RLS hardening. Self-contained fixture, rolled back.
-- Run only against a disposable/local database (see
-- docs/regression/SUBSCRIPTION_SECURITY_ENFORCEMENT_GATE.md).
begin;
select plan(113);

-- ---------------------------------------------------------------------------
-- Identity switch helpers (session-local, not persisted).
-- ---------------------------------------------------------------------------
create function pg_temp.act(p_key text) returns void language plpgsql as $$
begin
  reset role;
  if p_key = 'postgres' then
    perform set_config('request.jwt.claims', '', true);
  elsif p_key = 'anon' then
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    set local role anon;
  else
    perform set_config('request.jwt.claims',
      json_build_object('sub', current_setting('test.' || p_key), 'role', 'authenticated')::text, true);
    set local role authenticated;
  end if;
end $$;

-- Forged-claims variant: same user, plus client-controlled billing/role claims.
create function pg_temp.act_forged(p_key text) returns void language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claims', json_build_object(
    'sub', current_setting('test.' || p_key), 'role', 'authenticated',
    'plan', 'enterprise', 'subscription_status', 'active',
    'max_sites', 1000000, 'max_meters', 1000000,
    'features', json_build_object('automation', true, 'custom_limits', true),
    'user_role', 'super_admin', 'organization_id', current_setting('test.org_b'),
    'app_metadata', json_build_object('role', 'super_admin', 'plan', 'enterprise'),
    'user_metadata', json_build_object('role', 'super_admin', 'max_sites', 1000000)
  )::text, true);
  set local role authenticated;
end $$;

create function pg_temp.k(p_key text) returns uuid language sql stable as $$
  select current_setting('test.' || p_key)::uuid
$$;

-- ---------------------------------------------------------------------------
-- Fixture (as postgres)
-- ---------------------------------------------------------------------------
do $$
declare
  v_users text[] := array['viewer','tech','site_admin','legacy_site_admin','org_admin_a','org_admin_b'];
  v_key text;
  v_id uuid;
  v_role_site_admin uuid := (select id from public.roles where code = 'site_admin');
  v_role_org_admin uuid := (select id from public.roles where code = 'org_admin');
  v_role_viewer uuid := (select id from public.roles where code = 'viewer');
  v_role_entry uuid := (select id from public.roles where code = 'reading_entry');
begin
  perform set_config('test.org_a', gen_random_uuid()::text, true);
  perform set_config('test.org_b', gen_random_uuid()::text, true);
  perform set_config('test.site_a1', gen_random_uuid()::text, true);
  perform set_config('test.site_b1', gen_random_uuid()::text, true);
  perform set_config('test.zone_b', gen_random_uuid()::text, true);
  perform set_config('test.meter_a1', gen_random_uuid()::text, true);
  perform set_config('test.meter_b1', gen_random_uuid()::text, true);

  insert into public.organizations (id, name_en, name_ar) values
    (pg_temp.k('org_a'), 'gate-org-a', 'gate-org-a'),
    (pg_temp.k('org_b'), 'gate-org-b', 'gate-org-b');

  -- Deterministic server-side entitlements for both tenants.
  insert into public.organization_subscriptions
    (organization_id, plan, status, provider, current_period_start, current_period_end,
     max_users, max_sites, max_meters, features, provider_customer_ref, provider_subscription_ref)
  values
    (pg_temp.k('org_a'), 'starter', 'active', 'manual', now(), now() + interval '30 days',
     10, 2, 3, '{"dashboard":true,"reports":true,"odd_flag":"yes"}', 'cust-secret-a', 'sub-secret-a'),
    (pg_temp.k('org_b'), 'professional', 'active', 'manual', now(), now() + interval '30 days',
     10, 3, 2, '{"dashboard":true,"reports":true,"advanced_reports":true}', 'cust-secret-b', 'sub-secret-b')
  on conflict (organization_id) do update set
    plan = excluded.plan, status = excluded.status, provider = excluded.provider,
    current_period_start = excluded.current_period_start,
    current_period_end = excluded.current_period_end, grace_period_end = null,
    max_users = excluded.max_users, max_sites = excluded.max_sites,
    max_meters = excluded.max_meters, features = excluded.features,
    provider_customer_ref = excluded.provider_customer_ref,
    provider_subscription_ref = excluded.provider_subscription_ref;

  insert into public.zones (id, organization_id, code, name_en, name_ar)
  values (pg_temp.k('zone_b'), pg_temp.k('org_b'), 'gate_zb', 'gate-zone-b', 'gate-zone-b');

  insert into public.sites (id, organization_id, name_en, name_ar) values
    (pg_temp.k('site_a1'), pg_temp.k('org_a'), 'gate-site-a1', 'gate-site-a1'),
    (pg_temp.k('site_b1'), pg_temp.k('org_b'), 'gate-site-b1', 'gate-site-b1');

  insert into public.meters (id, site_id, meter_code, name_en, name_ar, category, unit, base_unit) values
    (pg_temp.k('meter_a1'), pg_temp.k('site_a1'), 'GATE-A1', 'gate-a1', 'gate-a1', 'water', 'm3', 'm3'),
    (pg_temp.k('meter_b1'), pg_temp.k('site_b1'), 'GATE-B1', 'gate-b1', 'gate-b1', 'water', 'm3', 'm3');

  foreach v_key in array v_users loop
    v_id := gen_random_uuid();
    perform set_config('test.' || v_key, v_id::text, true);
    insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      'gate-' || v_key || '-' || v_id || '@example.test', now(), '{}', '{}', now(), now());
    insert into public.profiles (id, full_name, email, role, is_active, approval_status)
    values (v_id, 'gate ' || v_key, 'gate-' || v_key || '-' || v_id || '@example.test',
      case v_key when 'viewer' then 'viewer' when 'tech' then 'technician' else 'site_admin' end::public.user_role,
      true, 'approved')
    on conflict (id) do update set role = excluded.role, is_active = true, approval_status = 'approved';
  end loop;

  -- Viewer: scoped viewer on A1 + legacy read access.
  insert into public.user_scope_assignments (user_id, role_id, site_id)
    values (pg_temp.k('viewer'), v_role_viewer, pg_temp.k('site_a1'));
  insert into public.user_site_access (user_id, site_id, role, can_read)
    values (pg_temp.k('viewer'), pg_temp.k('site_a1'), 'viewer', true);
  -- Technician: reading entry on A1 + legacy write access.
  insert into public.user_scope_assignments (user_id, role_id, site_id)
    values (pg_temp.k('tech'), v_role_entry, pg_temp.k('site_a1'));
  insert into public.user_site_access (user_id, site_id, role, can_read, can_write)
    values (pg_temp.k('tech'), pg_temp.k('site_a1'), 'technician', true, true);
  -- Site Admin (scope model) on A1.
  insert into public.user_scope_assignments (user_id, role_id, site_id)
    values (pg_temp.k('site_admin'), v_role_site_admin, pg_temp.k('site_a1'));
  -- Site Admin (legacy model) on A1.
  insert into public.user_site_access (user_id, site_id, role, can_read, can_write, can_manage_meters)
    values (pg_temp.k('legacy_site_admin'), pg_temp.k('site_a1'), 'site_admin', true, true, true);
  -- Org admins.
  insert into public.user_scope_assignments (user_id, role_id, organization_id) values
    (pg_temp.k('org_admin_a'), v_role_org_admin, pg_temp.k('org_a')),
    (pg_temp.k('org_admin_b'), v_role_org_admin, pg_temp.k('org_b'));
end $$;

-- ===========================================================================
-- D. Function / grant hardening (catalog assertions)
-- ===========================================================================
select is(
  (select count(*)::int from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.prosecdef
     and has_function_privilege('anon', p.oid, 'EXECUTE')),
  0, 'D1 anon cannot execute any public SECURITY DEFINER function');

select ok(not has_function_privilege('authenticated', 'public.enforce_subscription_site_limit()', 'EXECUTE'),
  'D2 authenticated cannot execute site-limit trigger function');
select ok(not has_function_privilege('authenticated', 'public.enforce_subscription_meter_limit()', 'EXECUTE'),
  'D3 authenticated cannot execute meter-limit trigger function');

select is(
  (select count(*)::int from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and (p.proname like '%subscription%')
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  0, 'D4 every subscription function pins search_path');

select is(
  (select count(*)::int from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname like '%subscription%'
     and p.prosecdef and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  0, 'D5 no SECURITY DEFINER subscription function is directly callable by authenticated');

select is(
  (select count(*)::int from unnest(array['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) priv
   where has_table_privilege('authenticated', 'public.organization_subscriptions', priv)),
  0, 'D6 authenticated holds no write/TRUNCATE/TRIGGER/REFERENCES on organization_subscriptions');

select is(
  (select count(*)::int from unnest(array['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) priv
   where has_table_privilege('authenticated', 'public.subscription_plan_catalog', priv)),
  0, 'D7 authenticated holds no write/TRUNCATE/TRIGGER/REFERENCES on subscription_plan_catalog');

select ok(
  not has_column_privilege('authenticated', 'public.organization_subscriptions', 'provider_customer_ref', 'SELECT')
  and not has_column_privilege('authenticated', 'public.organization_subscriptions', 'provider_subscription_ref', 'SELECT'),
  'D8 billing provider references are not client-readable');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.organization_subscriptions'::regclass)
  and (select relrowsecurity from pg_class where oid = 'public.subscription_plan_catalog'::regclass),
  'D9 RLS enabled on subscription tables');

-- ===========================================================================
-- B. Entitlement / subscription tampering
-- ===========================================================================
select pg_temp.act('anon');
select throws_ok('select * from public.organization_subscriptions', '42501', null,
  'B1 anon cannot read subscriptions');
select throws_ok(format('select * from public.subscription_access_state(%L)', pg_temp.k('org_a')), '42501', null,
  'B2 anon cannot call subscription_access_state');
select throws_ok(format('select public.subscription_has_feature(%L, %L)', pg_temp.k('org_a'), 'dashboard'), '42501', null,
  'B3 anon cannot call subscription_has_feature');
select throws_ok(format('select * from public.subscription_usage(%L)', pg_temp.k('org_a')), '42501', null,
  'B4 anon cannot call subscription_usage');

select pg_temp.act('viewer');
select throws_ok(format($q$insert into public.organization_subscriptions (organization_id, max_users, max_sites, max_meters)
  values (%L, 1, 1000, 1000)$q$, pg_temp.k('org_b')), '42501', null, 'B5 viewer cannot insert a subscription');
select throws_ok(format($q$update public.organization_subscriptions set max_sites = 1000 where organization_id = %L$q$,
  pg_temp.k('org_a')), '42501', null, 'B6 viewer cannot raise max_sites');

select pg_temp.act('org_admin_a');
select throws_ok(format($q$update public.organization_subscriptions set plan = 'enterprise', max_meters = 1000000,
  features = '{"automation":true}' where organization_id = %L$q$, pg_temp.k('org_a')), '42501', null,
  'B7 org admin cannot self-upgrade plan/limits/features');
select throws_ok(format($q$update public.organization_subscriptions set status = 'active', current_period_end = now() + interval '10 years'
  where organization_id = %L$q$, pg_temp.k('org_a')), '42501', null, 'B8 org admin cannot extend status/period');
select throws_ok(format('delete from public.organization_subscriptions where organization_id = %L', pg_temp.k('org_a')),
  '42501', null, 'B9 org admin cannot delete subscription row');
select throws_ok('update public.subscription_plan_catalog set max_sites = 1000000', '42501', null,
  'B10 org admin cannot rewrite plan catalog');

-- TRUNCATE bypasses RLS; probe it inside a subtransaction that is always
-- rolled back so a successful exploit cannot cascade into later assertions.
create function pg_temp.try_rollback(p_sql text) returns text language plpgsql as $$
begin
  begin
    execute p_sql;
    raise exception using errcode = 'P0099', message = 'ALLOWED';
  exception when others then
    return case when sqlstate = 'P0099' then 'ALLOWED' else sqlstate end;
  end;
end $$;

select pg_temp.act('site_admin');
select is(pg_temp.try_rollback('truncate public.organization_subscriptions'), '42501',
  'B11 site admin cannot TRUNCATE subscriptions (RLS bypass vector)');
select is(pg_temp.try_rollback('truncate public.subscription_plan_catalog'), '42501',
  'B12 site admin cannot TRUNCATE plan catalog');
select pg_temp.act('postgres');
select is((select count(*)::int from public.organization_subscriptions
           where organization_id in (pg_temp.k('org_a'), pg_temp.k('org_b'))), 2,
  'B12b subscription rows survive TRUNCATE attempts');

select pg_temp.act('viewer');
select throws_ok(format('select provider_subscription_ref from public.organization_subscriptions where organization_id = %L',
  pg_temp.k('org_a')), '42501', null, 'B13 viewer cannot read own org billing provider refs');
select is((select count(*)::int from public.subscription_access_state(pg_temp.k('org_a'))), 1,
  'B14 viewer reads own org entitlement (legit)');
select is((select count(*)::int from public.subscription_access_state(pg_temp.k('org_b'))), 0,
  'B15 viewer cannot read other org entitlement (IDOR)');
select is((select count(*)::int from public.subscription_usage(pg_temp.k('org_b'))), 0,
  'B16 viewer cannot read other org usage (IDOR)');
select is(public.subscription_has_feature(pg_temp.k('org_b'), 'dashboard'), false,
  'B17 viewer cannot probe other org features (IDOR)');
select is((select count(*)::int from public.organization_subscriptions where organization_id = pg_temp.k('org_b')), 0,
  'B18 viewer cannot select other org subscription row');
select lives_ok(format('select public.subscription_has_feature(%L, %L)', pg_temp.k('org_a'), 'odd_flag'),
  'B19 non-boolean feature value does not error');
select is(public.subscription_has_feature(pg_temp.k('org_a'), 'dashboard'), true,
  'B20 viewer sees granted feature for own org (legit)');

-- Forged JWT claims must not affect entitlement evaluation.
select pg_temp.act_forged('viewer');
select is((select max_sites from public.subscription_access_state(pg_temp.k('org_a'))), 2,
  'B21 forged max_sites claim ignored: server value returned');
select is((select plan::text from public.subscription_access_state(pg_temp.k('org_a'))), 'starter',
  'B22 forged plan claim ignored');
select is(public.subscription_has_feature(pg_temp.k('org_a'), 'automation'), false,
  'B23 forged features claim does not grant automation');
select is((select count(*)::int from public.subscription_access_state(pg_temp.k('org_b'))), 0,
  'B24 forged organization_id claim does not grant other-org read');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'x', 'x')$q$,
  pg_temp.k('org_a')), '42501', null, 'B25 forged super_admin claims do not grant site creation');

-- ===========================================================================
-- A. Role / scope
-- ===========================================================================
-- Viewer
select pg_temp.act('viewer');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'v', 'v')$q$,
  pg_temp.k('org_a')), '42501', null, 'A1 viewer cannot create site');
select is_empty(format($q$update public.sites set name_en = 'pwned' where id = %L returning id$q$, pg_temp.k('site_a1')),
  'A2 viewer cannot update site');
select is_empty(format('delete from public.sites where id = %L returning id', pg_temp.k('site_a1')),
  'A3 viewer cannot delete site');
select throws_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'V-1', 'v', 'v', 'water', 'm3', 'm3')$q$, pg_temp.k('site_a1')), '42501', null, 'A4 viewer cannot create meter');
select is_empty(format($q$update public.meters set name_en = 'pwned' where id = %L returning id$q$, pg_temp.k('meter_a1')),
  'A5 viewer cannot update meter');
select is_empty(format('delete from public.meters where id = %L returning id', pg_temp.k('meter_a1')),
  'A6 viewer cannot delete meter');
select throws_ok(format($q$update public.profiles set role = 'super_admin' where id = %L$q$, pg_temp.k('viewer')),
  '42501', null, 'A7 viewer cannot self-escalate profile role');
select throws_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, organization_id)
  values (%L, (select id from public.roles where code = 'org_admin'), %L)$q$, pg_temp.k('viewer'), pg_temp.k('org_a')),
  '42501', null, 'A8 viewer cannot grant self org_admin scope');
select throws_ok(format($q$insert into public.user_site_access (user_id, site_id, role, can_manage_meters)
  values (%L, %L, 'site_admin', true)$q$, pg_temp.k('viewer'), pg_temp.k('site_a1')),
  '42501', null, 'A9 viewer cannot grant self legacy site_admin');
select is_empty(format('select id from public.sites where id = %L', pg_temp.k('site_b1')),
  'A10 viewer cannot read other org site');

-- Technician
select pg_temp.act('tech');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 't', 't')$q$,
  pg_temp.k('org_a')), '42501', null, 'A11 technician cannot create site');
select is_empty(format('delete from public.sites where id = %L returning id', pg_temp.k('site_a1')),
  'A12 technician cannot delete site');
select throws_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'T-1', 't', 't', 'water', 'm3', 'm3')$q$, pg_temp.k('site_a1')), '42501', null, 'A13 technician cannot create meter');
select is_empty(format($q$update public.meters set is_active = false where id = %L returning id$q$, pg_temp.k('meter_a1')),
  'A14 technician cannot update meter');
select throws_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'T-2', 't', 't', 'water', 'm3', 'm3')$q$, pg_temp.k('site_b1')), '42501', null,
  'A15 technician cannot create meter in other org site (IDOR)');
select is_empty(format('select id from public.meters where id = %L', pg_temp.k('meter_b1')),
  'A16 technician cannot read other org meter');
select throws_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, site_id)
  values (%L, (select id from public.roles where code = 'site_admin'), %L)$q$, pg_temp.k('tech'), pg_temp.k('site_a1')),
  '42501', null, 'A17 technician cannot grant self site_admin');
select throws_ok(format($q$update public.profiles set role = 'site_admin' where id = %L$q$, pg_temp.k('tech')),
  '42501', null, 'A18 technician cannot self-escalate profile role');
select throws_ok(format($q$update public.organization_subscriptions set max_meters = 1000 where organization_id = %L$q$,
  pg_temp.k('org_a')), '42501', null, 'A19 technician cannot mutate subscription');

-- Site Admin (scope model)
select pg_temp.act('site_admin');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 's', 's')$q$,
  pg_temp.k('org_a')), '42501', null, 'A20 site admin cannot create sites in own org');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 's', 's')$q$,
  pg_temp.k('org_b')), '42501', null, 'A21 site admin cannot create sites in other org (IDOR)');
select throws_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'S-B', 's', 's', 'water', 'm3', 'm3')$q$, pg_temp.k('site_b1')), '42501', null,
  'A22 site admin cannot create meter in other org site (IDOR)');
select is_empty(format($q$update public.meters set name_en = 'pwned' where id = %L returning id$q$, pg_temp.k('meter_b1')),
  'A23 site admin cannot update other org meter');
select throws_ok(format($q$update public.meters set site_id = %L where id = %L$q$, pg_temp.k('site_b1'), pg_temp.k('meter_a1')),
  '42501', null, 'A24 site admin cannot move own meter into other org site');
select is(pg_temp.try_rollback(format($q$update public.sites set organization_id = %L where id = %L$q$, pg_temp.k('org_b'), pg_temp.k('site_a1'))), '42501',
  'A25 site admin cannot move own site into other org (cross-tenant)');
select is(pg_temp.try_rollback(format($q$update public.sites set zone_id = %L where id = %L$q$, pg_temp.k('zone_b'), pg_temp.k('site_a1'))), '42501',
  'A26 site admin cannot attach own site to other org zone (cross-tenant)');
select throws_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, organization_id)
  values (%L, (select id from public.roles where code = 'org_admin'), %L)$q$, pg_temp.k('site_admin'), pg_temp.k('org_a')),
  '42501', null, 'A27 site admin cannot grant self org_admin');
select throws_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, site_id)
  values (%L, (select id from public.roles where code = 'site_admin'), %L)$q$, pg_temp.k('site_admin'), pg_temp.k('site_b1')),
  '42501', null, 'A28 site admin cannot grant self other-org site_admin');
select is_empty(format('select id from public.sites where id = %L', pg_temp.k('site_b1')),
  'A29 site admin cannot read other org site');
select is_empty(format('delete from public.sites where id = %L returning id', pg_temp.k('site_a1')),
  'A30 site admin cannot delete site');
select lives_ok(format($q$update public.sites set name_en = 'gate-site-a1-renamed' where id = %L$q$, pg_temp.k('site_a1')),
  'A31 site admin can rename own site (legit)');

-- Site Admin (legacy model)
select pg_temp.act('legacy_site_admin');
select throws_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'L-B', 'l', 'l', 'water', 'm3', 'm3')$q$, pg_temp.k('site_b1')), '42501', null,
  'A32 legacy site admin cannot create meter in other org site (IDOR)');
select is(pg_temp.try_rollback(format($q$update public.sites set organization_id = %L where id = %L$q$, pg_temp.k('org_b'), pg_temp.k('site_a1'))), '42501',
  'A33 legacy site admin cannot move site into other org');

-- Org Admin cross-tenant
select pg_temp.act('org_admin_a');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'o', 'o')$q$,
  pg_temp.k('org_b')), '42501', null, 'A34 org admin A cannot create site in org B (IDOR)');
select is_empty(format($q$update public.sites set name_en = 'pwned' where id = %L returning id$q$, pg_temp.k('site_b1')),
  'A35 org admin A cannot update org B site');
select is(pg_temp.try_rollback(format($q$update public.sites set organization_id = %L where id = %L$q$, pg_temp.k('org_b'), pg_temp.k('site_a1'))), '42501',
  'A36 org admin A cannot push own site into org B');

select pg_temp.act('org_admin_b');
select is(pg_temp.try_rollback(format($q$insert into public.sites (organization_id, zone_id, name_en, name_ar)
  values (%L, %L, 'plant', 'plant')$q$, pg_temp.k('org_a'), pg_temp.k('zone_b'))), '42501',
  'A37 org admin B cannot plant a site in org A via own zone (cross-tenant)');

-- ===========================================================================
-- C. Quota enforcement (org A: max_sites=2, max_meters=3; org B: max_sites=3, max_meters=2)
-- ===========================================================================
select pg_temp.act('org_admin_a');
select lives_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'gate-a2', 'gate-a2')$q$,
  pg_temp.k('org_a')), 'C1 site N (=max_sites) allowed');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'gate-a3', 'gate-a3')$q$,
  pg_temp.k('org_a')), 'P0001', 'SUBSCRIPTION_SITE_LIMIT_REACHED:2', 'C2 site N+1 rejected');
select lives_ok(format($q$insert into public.sites (organization_id, name_en, name_ar, is_active) values (%L, 'gate-a3', 'gate-a3', false)$q$,
  pg_temp.k('org_a')), 'C3 inactive site insert allowed (not counted)');
select throws_ok(format($q$update public.sites set is_active = true where organization_id = %L and name_en = 'gate-a3'$q$,
  pg_temp.k('org_a')), 'P0001', 'SUBSCRIPTION_SITE_LIMIT_REACHED:2', 'C4 reactivation past limit rejected');
select lives_ok(format($q$update public.sites set is_active = false where organization_id = %L and name_en = 'gate-a2'$q$,
  pg_temp.k('org_a')), 'C5 deactivate frees a slot');
select lives_ok(format($q$update public.sites set is_active = true where organization_id = %L and name_en = 'gate-a3'$q$,
  pg_temp.k('org_a')), 'C6 reactivation within limit allowed');
select lives_ok(format($q$delete from public.sites where organization_id = %L and name_en = 'gate-a3'$q$,
  pg_temp.k('org_a')), 'C7 delete frees a slot');
select lives_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'gate-a4', 'gate-a4')$q$,
  pg_temp.k('org_a')), 'C8 recreate after delete allowed');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'gate-a5', 'gate-a5')$q$,
  pg_temp.k('org_a')), 'P0001', 'SUBSCRIPTION_SITE_LIMIT_REACHED:2', 'C9 limit still enforced after recreate');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar)
  select %L, 'gate-bulk-' || g, 'gate-bulk-' || g from generate_series(1, 3) g$q$, pg_temp.k('org_a')),
  'P0001', 'SUBSCRIPTION_SITE_LIMIT_REACHED:2', 'C10 multi-row insert cannot exceed limit');

select pg_temp.act('site_admin');
select lives_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'GATE-A1-2', 'm', 'm', 'water', 'm3', 'm3')$q$, pg_temp.k('site_a1')), 'C11 site admin creates meter within quota (legit)');
select lives_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'GATE-A1-3', 'm', 'm', 'water', 'm3', 'm3')$q$, pg_temp.k('site_a1')), 'C12 meter N (=max_meters) allowed');
select throws_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'GATE-A1-4', 'm', 'm', 'water', 'm3', 'm3')$q$, pg_temp.k('site_a1')),
  'P0001', 'SUBSCRIPTION_METER_LIMIT_REACHED:3', 'C13 meter N+1 rejected');
select pg_temp.act_forged('site_admin');
select throws_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'GATE-A1-5', 'm', 'm', 'water', 'm3', 'm3')$q$, pg_temp.k('site_a1')),
  'P0001', 'SUBSCRIPTION_METER_LIMIT_REACHED:3', 'C14 forged max_meters claim cannot bypass meter limit');
select pg_temp.act('site_admin');
select lives_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit, is_active)
  values (%L, 'GATE-A1-6', 'm', 'm', 'water', 'm3', 'm3', false)$q$, pg_temp.k('site_a1')), 'C15 inactive meter insert allowed');
select throws_ok(format($q$update public.meters set is_active = true where meter_code = 'GATE-A1-6' and site_id = %L$q$,
  pg_temp.k('site_a1')), 'P0001', 'SUBSCRIPTION_METER_LIMIT_REACHED:3', 'C16 meter reactivation past limit rejected');

-- Org B usage is isolated from org A's full quota.
select pg_temp.act('org_admin_b');
select lives_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'gate-b2', 'gate-b2')$q$,
  pg_temp.k('org_b')), 'C17 org B quota independent of org A');
select is((select active_sites::int from public.subscription_usage(pg_temp.k('org_b'))), 2,
  'C18 org B usage counts only org B sites');

-- Fill org B's meter quota (2) server-side.
select pg_temp.act('postgres');
insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (pg_temp.k('site_b1'), 'GATE-B1-2', 'b', 'b', 'water', 'm3', 'm3');

-- Unauthorized callers must get an authorization error, not another tenant's quota state.
select pg_temp.act('legacy_site_admin');
select throws_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'ORACLE', 'o', 'o', 'water', 'm3', 'm3')$q$, pg_temp.k('site_b1')), '42501', null,
  'C18b cross-tenant insert into full org returns 42501 (no quota oracle)');

-- Platform/service moves must still respect the target org's quotas.
select pg_temp.act('postgres');
select throws_ok(format($q$update public.meters set site_id = %L where id = %L$q$, pg_temp.k('site_b1'), pg_temp.k('meter_a1')),
  'P0001', 'SUBSCRIPTION_METER_LIMIT_REACHED:2', 'C19 meter move into full org rejected');
select is(pg_temp.try_rollback(format($q$update public.sites set organization_id = %L where id = %L$q$, pg_temp.k('org_b'), pg_temp.k('site_a1'))),
  'P0001', 'C20 site move cannot carry meters past target org meter quota');

-- Subscription states (server-side). Reset org A to 1 active site.
update public.sites set is_active = false where organization_id = pg_temp.k('org_a') and id <> pg_temp.k('site_a1');
update public.organization_subscriptions set status = 'past_due' where organization_id = pg_temp.k('org_a');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'st', 'st')$q$,
  pg_temp.k('org_a')), 'P0001', 'SUBSCRIPTION_INACTIVE', 'C21 past_due blocks site creation');
select pg_temp.act('org_admin_a');
select is((select has_access from public.subscription_access_state(pg_temp.k('org_a'))), false, 'C22 past_due has_access=false');
select pg_temp.act('postgres');
update public.organization_subscriptions set status = 'canceled' where organization_id = pg_temp.k('org_a');
select throws_ok(format($q$insert into public.meters (site_id, meter_code, name_en, name_ar, category, unit, base_unit)
  values (%L, 'ST-1', 's', 's', 'water', 'm3', 'm3')$q$, pg_temp.k('site_a1')), 'P0001', 'SUBSCRIPTION_INACTIVE',
  'C23 canceled blocks meter creation');
update public.organization_subscriptions set status = 'expired' where organization_id = pg_temp.k('org_a');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'st', 'st')$q$,
  pg_temp.k('org_a')), 'P0001', 'SUBSCRIPTION_INACTIVE', 'C24 expired blocks site creation');
update public.organization_subscriptions set status = 'grace_period', grace_period_end = now() + interval '3 days'
  where organization_id = pg_temp.k('org_a');
select lives_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'gate-grace', 'gate-grace')$q$,
  pg_temp.k('org_a')), 'C25 open grace period allows creation within quota');
update public.sites set is_active = false where organization_id = pg_temp.k('org_a') and name_en = 'gate-grace';
update public.organization_subscriptions set grace_period_end = now() - interval '1 minute'
  where organization_id = pg_temp.k('org_a');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'st', 'st')$q$,
  pg_temp.k('org_a')), 'P0001', 'SUBSCRIPTION_EXPIRED', 'C26 lapsed grace period blocks creation');
select pg_temp.act('org_admin_a');
select is((select has_access from public.subscription_access_state(pg_temp.k('org_a'))), false, 'C27 lapsed grace has_access=false');
select pg_temp.act('postgres');
update public.organization_subscriptions set status = 'trialing', grace_period_end = null,
  current_period_end = now() - interval '1 minute' where organization_id = pg_temp.k('org_a');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'st', 'st')$q$,
  pg_temp.k('org_a')), 'P0001', 'SUBSCRIPTION_EXPIRED', 'C28 trial past current_period_end blocks creation');
select pg_temp.act('org_admin_a');
select is((select has_access from public.subscription_access_state(pg_temp.k('org_a'))), false, 'C29 ended trial has_access=false');
select pg_temp.act('postgres');
select pg_temp.act('org_admin_a');
select is(public.subscription_has_feature(pg_temp.k('org_a'), 'dashboard'), false, 'C30 ended trial grants no features');
select pg_temp.act('postgres');
update public.organization_subscriptions set status = 'active' where organization_id = pg_temp.k('org_a');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'st', 'st')$q$,
  pg_temp.k('org_a')), 'P0001', 'SUBSCRIPTION_EXPIRED', 'C31 active past current_period_end blocks creation');
update public.organization_subscriptions set current_period_end = null where organization_id = pg_temp.k('org_a');
select lives_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'gate-open', 'gate-open')$q$,
  pg_temp.k('org_a')), 'C32 active open-ended contract allows creation within quota');
delete from public.organization_subscriptions where organization_id = pg_temp.k('org_a');
select throws_ok(format($q$insert into public.sites (organization_id, name_en, name_ar) values (%L, 'st', 'st')$q$,
  pg_temp.k('org_a')), 'P0001', 'SUBSCRIPTION_REQUIRED', 'C33 missing subscription fails closed');

-- New organizations are provisioned server-side from the trial catalog entry.
insert into public.organizations (id, name_en, name_ar) values ('00000000-0000-4000-8000-00000000c0de', 'gate-new', 'gate-new');
select is((select plan::text || '/' || status::text || '/' || max_sites || '/' || max_meters
           from public.organization_subscriptions where organization_id = '00000000-0000-4000-8000-00000000c0de'),
  'trial/trialing/1/50', 'C34 new org gets server-provisioned trial from catalog');
select ok((select current_period_end > now() + interval '29 days' and current_period_end < now() + interval '31 days'
           from public.organization_subscriptions where organization_id = '00000000-0000-4000-8000-00000000c0de'),
  'C35 provisioned trial ends after catalog trial_days');

-- ===========================================================================
-- E. Legitimate flows still work
-- ===========================================================================
select pg_temp.act('org_admin_b');
select is((select plan::text from public.subscription_access_state(pg_temp.k('org_b'))), 'professional',
  'E1 org admin reads own entitlement');
select is(public.subscription_has_feature(pg_temp.k('org_b'), 'advanced_reports'), true, 'E2 org admin sees own feature');
select pg_temp.act('tech');
select is((select count(*)::int from public.sites where id = pg_temp.k('site_a1')), 1, 'E3 technician still reads assigned site');
select is((select count(*)::int from public.meters where site_id = pg_temp.k('site_a1') and is_active), 3, 'E4 technician still reads assigned meters');
select pg_temp.act('viewer');
select is((select count(*)::int from public.sites where id = pg_temp.k('site_a1')), 1, 'E5 viewer still reads assigned site');

select pg_temp.act('postgres');
select * from finish();
rollback;
