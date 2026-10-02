-- pgTAP: Google Play Billing v1 + server-side max_users
-- (migrations 20261002180000, 20261002181000).
-- Adversarial regression suite: seat quota, billing privileges, service-only
-- apply boundary, product/package/base-plan/account-binding mismatch, Google
-- state mapping, replacement/linked tokens, single-flight acknowledgement.
-- Self-contained fixture, rolled back. Disposable/local databases only (see
-- docs/regression/GOOGLE_PLAY_BILLING_V1.md). No live Play data is used.
begin;
select plan(120);

-- ---------------------------------------------------------------------------
-- Identity switch helpers (session-local).
-- ---------------------------------------------------------------------------
create function pg_temp.act(p_key text) returns void language plpgsql as $$
begin
  reset role;
  if p_key = 'postgres' then
    perform set_config('request.jwt.claims', '', true);
  elsif p_key = 'anon' then
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    set local role anon;
  elsif p_key = 'service' then
    perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
    set local role service_role;
  else
    perform set_config('request.jwt.claims',
      json_build_object('sub', current_setting('test.' || p_key), 'role', 'authenticated')::text, true);
    set local role authenticated;
  end if;
end $$;

create function pg_temp.k(p_key text) returns uuid language sql stable as $$
  select current_setting('test.' || p_key)::uuid
$$;

-- Simulated verified Google evidence -> service apply. p_binding: 'AUTO' = the
-- org's correct binding, 'NONE' = absent, anything else is passed verbatim.
create function pg_temp.gp(
  p_org text, p_token text, p_state text, p_expiry interval,
  p_product text default 'smartmeters_professional', p_base text default 'professional-monthly',
  p_binding text default 'AUTO', p_linked text default null,
  p_package text default 'com.smartmeters.admin_app',
  p_ack text default 'ACKNOWLEDGEMENT_STATE_PENDING') returns jsonb language plpgsql as $$
begin
  return public.billing_apply_google_play_verification(
    pg_temp.k(p_org), p_token, p_package, p_product, p_base, null, p_state, p_ack,
    case when p_expiry is null then null else now() + p_expiry end, p_linked, 'GPA.0000-0000-0000-00000',
    case p_binding when 'AUTO' then public.billing_google_play_account_binding(pg_temp.k(p_org))
                   when 'NONE' then null else p_binding end,
    false, null, 'client_verify');
end $$;

create function pg_temp.sub(p_org text) returns text language sql stable as $$
  select plan::text || '/' || status::text || '/' || provider::text || '/' || cancel_at_period_end::text
    from public.organization_subscriptions where organization_id = pg_temp.k(p_org)
$$;

create function pg_temp.has_access(p_org text) returns boolean language sql stable as $$
  select public.subscription_row_has_access(status, current_period_end, grace_period_end)
    from public.organization_subscriptions where organization_id = pg_temp.k(p_org)
$$;

-- ---------------------------------------------------------------------------
-- Fixture (as postgres)
-- ---------------------------------------------------------------------------
do $$
declare
  v_users text[] := array['org_admin_a','org_admin_b','viewer_a','super_a','u1','u2','u3','u4','u5'];
  v_key text; v_id uuid;
  v_role_org_admin uuid := (select id from public.roles where code = 'org_admin');
  v_role_viewer uuid := (select id from public.roles where code = 'viewer');
begin
  perform set_config('test.org_a', gen_random_uuid()::text, true);
  perform set_config('test.org_b', gen_random_uuid()::text, true);
  perform set_config('test.site_a1', gen_random_uuid()::text, true);
  perform set_config('test.site_a2', gen_random_uuid()::text, true);
  perform set_config('test.site_b1', gen_random_uuid()::text, true);
  perform set_config('test.zone_a', gen_random_uuid()::text, true);
  perform set_config('test.role_viewer', v_role_viewer::text, true);
  perform set_config('test.binding_b', public.billing_google_play_account_binding(pg_temp.k('org_b')), true);

  insert into public.organizations (id, name_en, name_ar) values
    (pg_temp.k('org_a'), 'bill-org-a', 'bill-org-a'), (pg_temp.k('org_b'), 'bill-org-b', 'bill-org-b');
  update public.organization_subscriptions set plan = 'starter', status = 'active', provider = 'manual',
    current_period_end = now() + interval '30 days', max_users = 3, max_sites = 5, max_meters = 50
   where organization_id in (pg_temp.k('org_a'), pg_temp.k('org_b'));

  insert into public.zones (id, organization_id, code, name_en, name_ar)
    values (pg_temp.k('zone_a'), pg_temp.k('org_a'), 'bill_za', 'bill-zone-a', 'bill-zone-a');
  insert into public.sites (id, organization_id, name_en, name_ar) values
    (pg_temp.k('site_a1'), pg_temp.k('org_a'), 'bill-a1', 'bill-a1'),
    (pg_temp.k('site_a2'), pg_temp.k('org_a'), 'bill-a2', 'bill-a2'),
    (pg_temp.k('site_b1'), pg_temp.k('org_b'), 'bill-b1', 'bill-b1');

  foreach v_key in array v_users loop
    v_id := gen_random_uuid();
    perform set_config('test.' || v_key, v_id::text, true);
    insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      'bill-' || v_key || '-' || v_id || '@example.test', now(), '{}', '{}', now(), now());
    insert into public.profiles (id, full_name, email, role, is_active, approval_status)
    values (v_id, 'bill ' || v_key, 'bill-' || v_key || '-' || v_id || '@example.test',
      (case when v_key = 'super_a' then 'super_admin' when v_key like 'u_' then 'technician' else 'site_admin' end)::public.user_role,
      true, (case when v_key = 'u5' then 'pending' else 'approved' end)::public.approval_status)
    on conflict (id) do update set role = excluded.role, is_active = true, approval_status = excluded.approval_status;
  end loop;

  -- Seats in org A before tests: org_admin_a (org scope) + viewer_a (site scope) = 2 of max 3.
  insert into public.user_scope_assignments (user_id, role_id, organization_id) values
    (pg_temp.k('org_admin_a'), v_role_org_admin, pg_temp.k('org_a')),
    (pg_temp.k('org_admin_b'), v_role_org_admin, pg_temp.k('org_b'));
  insert into public.user_scope_assignments (user_id, role_id, site_id)
    values (pg_temp.k('viewer_a'), v_role_viewer, pg_temp.k('site_a1'));
end $$;

-- ===========================================================================
-- S. Server-side max_users (BILL-SEAT-*)
-- ===========================================================================
select ok(not has_function_privilege('authenticated', 'public.enforce_subscription_user_limit()', 'EXECUTE')
  and not has_function_privilege('anon', 'public.enforce_subscription_user_limit()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.enforce_subscription_user_limit_on_move()', 'EXECUTE'),
  'S1 seat-limit trigger functions are not callable by API roles');

select pg_temp.act('org_admin_a');
select is((select active_users::int from public.subscription_usage(pg_temp.k('org_a'))), 2,
  'S2 usage counts org-scoped and site-scoped seats');
select lives_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, site_id) values (%L, %L, %L)$q$,
  pg_temp.k('u1'), pg_temp.k('role_viewer'), pg_temp.k('site_a2')), 'S3 org admin grants a seat within max_users');
select throws_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, site_id) values (%L, %L, %L)$q$,
  pg_temp.k('u2'), pg_temp.k('role_viewer'), pg_temp.k('site_a1')), 'P0001', 'SUBSCRIPTION_USER_LIMIT_REACHED:3',
  'S4 site-scope grant for a new user beyond max_users is rejected');
select throws_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, zone_id) values (%L, %L, %L)$q$,
  pg_temp.k('u2'), pg_temp.k('role_viewer'), pg_temp.k('zone_a')), 'P0001', 'SUBSCRIPTION_USER_LIMIT_REACHED:3',
  'S5 zone-scope grant beyond max_users is rejected');
-- Org-scope role grants are RLS-restricted for org admins; exercise the
-- trigger on the service/owner path (it must hold for every writer).
select pg_temp.act('postgres');
select throws_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, organization_id) values (%L, %L, %L)$q$,
  pg_temp.k('u2'), pg_temp.k('role_viewer'), pg_temp.k('org_a')), 'P0001', 'SUBSCRIPTION_USER_LIMIT_REACHED:3',
  'S6 org-scope grant beyond max_users is rejected (service path too)');
select pg_temp.act('org_admin_a');
select throws_ok(format($q$insert into public.user_site_access (user_id, site_id, role, can_read) values (%L, %L, 'viewer', true)$q$,
  pg_temp.k('u2'), pg_temp.k('site_a1')), 'P0001', 'SUBSCRIPTION_USER_LIMIT_REACHED:3',
  'S7 legacy user_site_access grant beyond max_users is rejected');
select lives_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, site_id) values (%L, %L, %L)$q$,
  pg_temp.k('u1'), pg_temp.k('role_viewer'), pg_temp.k('site_a1')),
  'S8 extra grant for an already-seated user consumes no seat (allowed at the limit)');
select throws_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, site_id) values (%L, %L, %L), (%L, %L, %L)$q$,
  pg_temp.k('u2'), pg_temp.k('role_viewer'), pg_temp.k('site_a1'), pg_temp.k('u3'), pg_temp.k('role_viewer'), pg_temp.k('site_a2')),
  'P0001', 'SUBSCRIPTION_USER_LIMIT_REACHED:3', 'S9 multi-row grant across the limit is rejected atomically');
select throws_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, site_id) values (%L, %L, %L), (%L, %L, %L)$q$,
  pg_temp.k('u2'), pg_temp.k('role_viewer'), pg_temp.k('site_a1'), pg_temp.k('u2'), pg_temp.k('role_viewer'), pg_temp.k('site_a2')),
  'P0001', 'SUBSCRIPTION_USER_LIMIT_REACHED:3',
  'S9b two grants for the same new user in one statement cannot vouch for each other');

-- Freeing a seat (deactivate all of u1's grants) allows a new user; reactivation then fails.
update public.user_scope_assignments set status = 'inactive' where user_id = pg_temp.k('u1');
select is((select active_users::int from public.subscription_usage(pg_temp.k('org_a'))), 2,
  'S10 deactivated grants free the seat');
select lives_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, site_id) values (%L, %L, %L)$q$,
  pg_temp.k('u2'), pg_temp.k('role_viewer'), pg_temp.k('site_a1')), 'S11 freed seat can be reused by another user');
select throws_ok(format($q$update public.user_scope_assignments set status = 'active' where user_id = %L$q$, pg_temp.k('u1')),
  'P0001', 'SUBSCRIPTION_USER_LIMIT_REACHED:3', 'S12 reactivating a grant beyond max_users is rejected');
-- u2 holds two grants; re-pointing one to a new user keeps u2 seated -> 4 seats.
-- (Re-pointing a user's only grant is a seat swap and is allowed.)
select lives_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, site_id) values (%L, %L, %L)$q$,
  pg_temp.k('u2'), pg_temp.k('role_viewer'), pg_temp.k('site_a2')), 'S13a second grant for a seated user at the limit');
select throws_ok(format($q$update public.user_scope_assignments set user_id = %L where user_id = %L and site_id = %L$q$,
  pg_temp.k('u3'), pg_temp.k('u2'), pg_temp.k('site_a2')), 'P0001', 'SUBSCRIPTION_USER_LIMIT_REACHED:3',
  'S13 re-pointing a grant to a new user beyond max_users is rejected');

-- Cross-tenant: RLS rejects first, never a quota error (no quota oracle).
select pg_temp.act('viewer_a');
select throws_ok(format($q$insert into public.user_scope_assignments (user_id, role_id, site_id) values (%L, %L, %L)$q$,
  pg_temp.k('u4'), pg_temp.k('role_viewer'), pg_temp.k('site_b1')), '42501', null,
  'S14 unauthorized cross-tenant grant fails with 42501, not a quota error');

-- Legacy approval path (super_admin RPC, row_security off) is also enforced.
select pg_temp.act('super_a');
select throws_ok(format($q$select public.admin_approve_user(%L, 'technician', array[%L]::uuid[], null)$q$,
  pg_temp.k('u5'), pg_temp.k('site_a1')), 'P0001', 'SUBSCRIPTION_USER_LIMIT_REACHED:3',
  'S15 admin_approve_user cannot exceed max_users');

-- Inactive subscription blocks new seats; open seats in org B are unaffected.
select pg_temp.act('postgres');
update public.organization_subscriptions set max_users = 10, status = 'past_due' where organization_id = pg_temp.k('org_a');
select throws_ok(format($q$insert into public.user_site_access (user_id, site_id, role, can_read) values (%L, %L, 'viewer', true)$q$,
  pg_temp.k('u4'), pg_temp.k('site_a1')), 'P0001', 'SUBSCRIPTION_INACTIVE', 'S16 inactive subscription blocks new seats');
select lives_ok(format($q$insert into public.user_site_access (user_id, site_id, role, can_read) values (%L, %L, 'viewer', true)$q$,
  pg_temp.k('u4'), pg_temp.k('site_b1')), 'S17 seats are counted per organization');

-- Site move carries its users into the target org's seats (service/owner path).
update public.organization_subscriptions set status = 'active', max_users = 3 where organization_id = pg_temp.k('org_a');
update public.organization_subscriptions set max_users = 2 where organization_id = pg_temp.k('org_b');
select throws_ok(format($q$update public.sites set organization_id = %L where id = %L$q$, pg_temp.k('org_b'), pg_temp.k('site_a1')),
  'P0001', null, 'S18 moving a site into an org without seats for its users is rejected');
-- Downgrade below current usage is non-retroactive: existing grants stay.
update public.organization_subscriptions set max_users = 1 where organization_id = pg_temp.k('org_a');
select is((select count(*)::int from public.user_scope_assignments where user_id = pg_temp.k('viewer_a') and status = 'active'), 1,
  'S19 downgrade below usage leaves existing grants in place');
select throws_ok(format($q$insert into public.user_site_access (user_id, site_id, role, can_read) values (%L, %L, 'viewer', true)$q$,
  pg_temp.k('viewer_a'), pg_temp.k('site_a2')), 'P0001', 'SUBSCRIPTION_USER_LIMIT_REACHED:1',
  'S19b an org over quota cannot add grants until back within max_users');
update public.organization_subscriptions set max_users = 3 where organization_id = pg_temp.k('org_a');
update public.organization_subscriptions set max_users = 3 where organization_id = pg_temp.k('org_b');

-- ===========================================================================
-- G. Billing privileges / boundary (BILL-GP-*)
-- ===========================================================================
select is(
  (select count(*)::int from unnest(array['public.billing_google_play_products','public.billing_google_play_purchases','public.billing_events']) t,
     unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) priv,
     unnest(array['anon','authenticated']) r
   where has_table_privilege(r, t, priv)),
  0, 'G1 anon/authenticated hold no privilege on any billing table');
select is(
  (select count(*)::int from unnest(array['public.billing_google_play_purchases','public.billing_events']) t,
     unnest(array['INSERT','UPDATE','DELETE','TRUNCATE']) priv
   where has_table_privilege('service_role', t, priv)),
  0, 'G2 service_role cannot write purchase evidence or audit directly (functions only)');
select ok(not has_table_privilege('service_role', 'public.billing_google_play_products', 'DELETE')
  and not has_table_privilege('service_role', 'public.billing_google_play_products', 'TRUNCATE'),
  'G3 service_role cannot delete/truncate the product mapping (deactivate instead)');
select ok((select bool_and(relrowsecurity) from pg_class where oid in (
  'public.billing_google_play_products'::regclass, 'public.billing_google_play_purchases'::regclass, 'public.billing_events'::regclass)),
  'G4 RLS enabled on billing tables');
select is(
  (select count(*)::int from unnest(array[
     'public.billing_apply_google_play_verification(uuid,text,text,text,text,text,text,text,timestamptz,text,text,text,boolean,uuid,text)',
     'public.billing_google_play_ack_transition(text,text)',
     'public.billing_google_play_map_state(text,timestamptz,timestamptz)',
     'public.billing_google_play_account_binding(uuid)',
     'public.billing_token_sha256(text)']) f, unnest(array['anon','authenticated','public']) r
   where has_function_privilege(r, f, 'EXECUTE')),
  0, 'G5 service-only billing functions are not executable by anon/authenticated/PUBLIC');
select ok(has_function_privilege('service_role',
  'public.billing_apply_google_play_verification(uuid,text,text,text,text,text,text,text,timestamptz,text,text,text,boolean,uuid,text)', 'EXECUTE')
  and has_function_privilege('service_role', 'public.billing_google_play_ack_transition(text,text)', 'EXECUTE'),
  'G6 service_role can execute the apply/ack boundary');
select ok(not has_function_privilege('anon', 'public.billing_google_play_catalog(uuid)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.billing_google_play_authorize(uuid)', 'EXECUTE'),
  'G7 anon cannot call billing catalog/authorize RPCs');
select is(
  (select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'billing%'
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  0, 'G8 every billing function pins search_path');
select is(
  (select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'billing%'
     and p.prosecdef and has_function_privilege('authenticated', p.oid, 'EXECUTE')
     and p.proname <> 'billing_google_play_catalog'),
  0, 'G9 the catalog is the only SECURITY DEFINER billing function callable by authenticated');

-- Client mutation attempts (org admin of the org itself).
select pg_temp.act('org_admin_a');
select throws_ok(format($q$insert into public.billing_google_play_products (package_name, product_id, base_plan_id, plan, billing_period, active)
  values ('com.smartmeters.admin_app', 'evil', 'evil-monthly', 'enterprise', 'monthly', true)$q$), '42501', null,
  'G10 org admin cannot add a product mapping');
select throws_ok($q$select * from public.billing_google_play_purchases$q$, '42501', null, 'G11 org admin cannot read purchase tokens');
select throws_ok($q$select * from public.billing_events$q$, '42501', null, 'G12 org admin cannot read billing audit');
select throws_ok(format($q$select public.billing_apply_google_play_verification(%L, 'tok', 'com.smartmeters.admin_app', 'p', 'b', null,
  'SUBSCRIPTION_STATE_ACTIVE', null, now() + interval '1 year', null, null, null, false, null, 'client_verify')$q$, pg_temp.k('org_a')),
  '42501', null, 'G13 org admin cannot call the service apply function');
select throws_ok(format($q$update public.organization_subscriptions set plan = 'enterprise', max_users = 1000000 where organization_id = %L$q$,
  pg_temp.k('org_a')), '42501', null, 'G14 org admin cannot write subscription state');

-- Authorization RPCs.
select is(public.billing_google_play_authorize(pg_temp.k('org_a')), pg_temp.k('org_admin_a'),
  'G15 org admin is authorized for own org and gets own uid');
select throws_ok(format('select public.billing_google_play_authorize(%L)', pg_temp.k('org_b')), '42501', 'BILLING_FORBIDDEN',
  'G16 org admin is not authorized for another org');
select throws_ok(format('select * from public.billing_google_play_catalog(%L)', pg_temp.k('org_b')), '42501', 'BILLING_FORBIDDEN',
  'G17 org admin cannot read another org catalog/binding');
select is((select count(*)::int from public.billing_google_play_catalog(pg_temp.k('org_a'))), 0,
  'G18 empty configuration: catalog is empty (no seeded products)');
select pg_temp.act('viewer_a');
select throws_ok(format('select public.billing_google_play_authorize(%L)', pg_temp.k('org_a')), '42501', 'BILLING_FORBIDDEN',
  'G19 viewer cannot manage billing');
select throws_ok(format('select * from public.billing_google_play_catalog(%L)', pg_temp.k('org_a')), '42501', 'BILLING_FORBIDDEN',
  'G20 viewer cannot read the billing catalog');

-- Empty configuration fails closed even with otherwise valid evidence.
select pg_temp.act('service');
select is(pg_temp.gp('org_a', 'tok-empty', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days')->>'reason', 'PRODUCT_NOT_CONFIGURED',
  'G21 no mapping configured: evidence is rejected');
select is(pg_temp.sub('org_a'), 'starter/active/manual/false', 'G22 rejected evidence leaves entitlement unchanged');

-- Operator configures mapping via service_role (inactive first).
insert into public.billing_google_play_products (package_name, product_id, base_plan_id, plan, billing_period, active) values
  ('com.smartmeters.admin_app', 'smartmeters_professional', 'professional-monthly', 'professional', 'monthly', false),
  ('com.smartmeters.admin_app', 'smartmeters_professional', 'professional-annual', 'professional', 'annual', true),
  ('com.smartmeters.admin_app', 'smartmeters_business', 'business-monthly', 'business', 'monthly', true);
select is(pg_temp.gp('org_a', 'tok-inactive', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days')->>'reason', 'PRODUCT_NOT_CONFIGURED',
  'G23 inactive mapping is not purchasable');
update public.billing_google_play_products set active = true where base_plan_id = 'professional-monthly';
select throws_ok($q$insert into public.billing_google_play_products (package_name, product_id, base_plan_id, plan, billing_period)
  values ('com.smartmeters.admin_app', 'x', 'trial-monthly', 'trial', 'monthly')$q$, '23514', null, 'G24 trial cannot be sold via Play');
select throws_ok($q$insert into public.billing_google_play_products (package_name, product_id, base_plan_id, plan, billing_period)
  values ('com.smartmeters.admin_app', 'Bad Product!', 'b', 'starter', 'monthly')$q$, '23514', null, 'G25 malformed product id rejected');
select throws_ok($q$insert into public.billing_google_play_products (package_name, product_id, base_plan_id, plan, billing_period)
  values ('com.smartmeters.admin_app', 'p', 'b', 'starter', 'weekly')$q$, '23514', null, 'G26 unknown billing period rejected');

-- Mismatches.
select is(pg_temp.gp('org_a', 'tok-pkg', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days', p_package => 'com.evil.app')->>'reason',
  'PRODUCT_NOT_CONFIGURED', 'G27 package mismatch is rejected');
select is(pg_temp.gp('org_a', 'tok-prod', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days', p_product => 'smartmeters_enterprise')->>'reason',
  'PRODUCT_NOT_CONFIGURED', 'G28 unknown product is rejected');
select is(pg_temp.gp('org_a', 'tok-base', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days', p_base => 'business-monthly')->>'reason',
  'PRODUCT_NOT_CONFIGURED', 'G29 base plan from another product is rejected');
select is(pg_temp.gp('org_a', 'tok-nobind', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days', p_binding => 'NONE')->>'reason',
  'ACCOUNT_BINDING_MISSING', 'G30 purchase without account binding is rejected');
select is(pg_temp.gp('org_a', 'tok-xbind', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days',
    p_binding => public.billing_google_play_account_binding(pg_temp.k('org_b')))->>'reason',
  'ACCOUNT_BINDING_MISMATCH', 'G31 purchase bound to another org is rejected');
select is(pg_temp.sub('org_a'), 'starter/active/manual/false', 'G32 mismatches never change entitlement');

-- Happy path: ACTIVE -> active; plan from mapping, limits from catalog.
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days')->>'outcome', 'applied',
  'G33 verified ACTIVE purchase is applied');
select is(pg_temp.sub('org_a'), 'professional/active/google_play/false', 'G34 ACTIVE maps to active professional');
select ok((select s.max_users = c.max_users and s.max_sites = c.max_sites and s.max_meters = c.max_meters and s.features = c.features
  from public.organization_subscriptions s join public.subscription_plan_catalog c on c.plan = s.plan
  where s.organization_id = pg_temp.k('org_a')), 'G35 limits/features come from the server plan catalog');
select is((select provider_subscription_ref from public.organization_subscriptions where organization_id = pg_temp.k('org_a')),
  public.billing_token_sha256('tok-a1'), 'G36 org references the token by sha256, not the raw token');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days')->>'acknowledgement_required', 'true',
  'G37 idempotent re-verify still reports pending acknowledgement');

-- Token replay into another org (even with that org's correct binding).
select is(pg_temp.gp('org_b', 'tok-a1', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days')->>'reason', 'TOKEN_BOUND_TO_OTHER_ORGANIZATION',
  'G38 a token bound to one org cannot be replayed into another');
select is(pg_temp.sub('org_b'), 'starter/active/manual/false', 'G39 replay leaves the other org unchanged');

-- Single-flight acknowledgement.
select is(public.billing_google_play_ack_transition('tok-a1', 'claim'), true, 'G40 first ack claim wins');
select is(public.billing_google_play_ack_transition('tok-a1', 'claim'), false, 'G41 concurrent second ack claim loses');
select is(public.billing_google_play_ack_transition('tok-a1', 'failed'), true, 'G42 failed ack releases the claim');
select is(public.billing_google_play_ack_transition('tok-a1', 'claim'), true, 'G43 claim can be retaken after failure');
select is(public.billing_google_play_ack_transition('tok-a1', 'succeeded'), true, 'G44 ack success recorded');
select is(public.billing_google_play_ack_transition('tok-a1', 'claim'), false, 'G45 acknowledged purchase is never re-acked');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days', p_ack => 'ACKNOWLEDGEMENT_STATE_PENDING')->>'acknowledgement_required',
  'false', 'G46 stale PENDING ack evidence after server ack does not request another ack');
select is(public.billing_google_play_ack_transition('tok-unknown', 'claim'), false, 'G47 unknown token cannot be claimed');
select throws_ok($q$select public.billing_google_play_ack_transition('tok-a1', 'bogus')$q$, '22023', null, 'G48 invalid ack event rejected');

-- State mapping on the current token.
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_CANCELED', interval '10 days')->>'outcome', 'applied',
  'G49 CANCELED evidence for current token is applied');
select is(pg_temp.sub('org_a'), 'professional/active/google_play/true', 'G50 CANCELED + future expiry = active, cancel_at_period_end');
select is(pg_temp.has_access('org_a'), true, 'G51 canceled-but-not-expired keeps access until expiry');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', interval '3 days')->>'mapped_status', 'grace_period',
  'G52 IN_GRACE_PERIOD maps to grace_period');
select ok((select grace_period_end > now() + interval '2 days' and not cancel_at_period_end
  from public.organization_subscriptions where organization_id = pg_temp.k('org_a')), 'G53 grace_period_end follows Google expiry');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_ON_HOLD', interval '-1 day')->>'mapped_status', 'past_due',
  'G54 ON_HOLD maps to past_due');
select is(pg_temp.has_access('org_a'), false, 'G55 ON_HOLD grants no access');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_PAUSED', interval '-1 day')->>'mapped_status', 'past_due',
  'G56 PAUSED maps to past_due (no access)');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days')->>'mapped_status', 'active',
  'G57 recovery to ACTIVE restores access');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_CANCELED', interval '-1 minute')->>'mapped_status', 'expired',
  'G58 CANCELED past expiry = expired');
select is(pg_temp.has_access('org_a'), false, 'G59 canceled-and-expired grants no access');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_ACTIVE', null)->>'mapped_status', 'expired',
  'G60 ACTIVE without expiry fails closed');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_UNSPECIFIED', interval '30 days')->>'mapped_status', 'expired',
  'G61 UNSPECIFIED fails closed');
select is(pg_temp.gp('org_a', 'tok-a1', 'SOMETHING_NEW', interval '30 days')->>'mapped_status', 'expired',
  'G62 unknown future state fails closed');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_ACTIVE', interval '-1 minute')->>'mapped_status', 'expired',
  'G63 ACTIVE with past expiry fails closed');
select is(pg_temp.gp('org_a', 'tok-a1', 'SUBSCRIPTION_STATE_EXPIRED', interval '-1 day')->>'mapped_status', 'expired',
  'G64 EXPIRED maps to expired');
select is(pg_temp.has_access('org_a'), false, 'G65 EXPIRED grants no access');

-- A non-entitling new token never changes the org; pending never grants.
select is(pg_temp.gp('org_b', 'tok-b-pending', 'SUBSCRIPTION_STATE_PENDING', interval '30 days')->>'reason', 'NOT_ENTITLING',
  'G66 PENDING purchase is recorded without entitlement');
select is(pg_temp.sub('org_b'), 'starter/active/manual/false', 'G67 PENDING leaves entitlement unchanged');
select is(public.billing_google_play_ack_transition('tok-b-pending', 'claim'), false, 'G68 PENDING purchase cannot be acknowledged');
select is(pg_temp.gp('org_b', 'tok-b-expired', 'SUBSCRIPTION_STATE_EXPIRED', interval '-1 day')->>'entitlement_applied', 'false',
  'G69 stale EXPIRED token for a non-current subscription cannot downgrade the org');

-- Replacement (upgrade): T2 links to current T1.
select is(pg_temp.gp('org_b', 'tok-b1', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days')->>'outcome', 'applied', 'G70 org B buys professional');
select is(pg_temp.gp('org_b', 'tok-b-dup', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days', p_product => 'smartmeters_business',
  p_base => 'business-monthly')->>'reason', 'ACTIVE_GOOGLE_PLAY_SUBSCRIPTION',
  'G71 an unrelated second active Play subscription conflicts instead of overriding');
select is(public.billing_google_play_ack_transition('tok-b-dup', 'claim'), false,
  'G72 conflicting purchase is never acknowledged (Play auto-refunds it)');
select is(pg_temp.gp('org_b', 'tok-b2-cancelled', 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED', interval '30 days',
  p_product => 'smartmeters_business', p_base => 'business-monthly', p_linked => 'tok-b1')->>'entitlement_applied', 'false',
  'G73 PENDING_PURCHASE_CANCELED upgrade grants nothing');
select is(pg_temp.sub('org_b'), 'professional/active/google_play/false', 'G74 old subscription stays after canceled pending upgrade');
select is((select superseded_by_token_sha256 from public.billing_google_play_purchases where purchase_token = 'tok-b1'), null,
  'G75 canceled pending upgrade does not supersede the linked token');
select is(pg_temp.gp('org_b', 'tok-b2', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days', p_product => 'smartmeters_business',
  p_base => 'business-monthly', p_linked => 'tok-b1')->>'outcome', 'applied', 'G76 linked upgrade replaces the current subscription');
select is(pg_temp.sub('org_b'), 'business/active/google_play/false', 'G77 upgrade maps to business');
select is(pg_temp.gp('org_b', 'tok-b1', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days')->>'reason', 'TOKEN_SUPERSEDED',
  'G78 stale evidence for the replaced token is ignored');
select is(pg_temp.sub('org_b'), 'business/active/google_play/false', 'G79 superseded token cannot roll the org back');
select is(pg_temp.gp('org_a', 'tok-a-steal', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days', p_linked => 'tok-b2')->>'reason',
  'LINKED_TOKEN_BOUND_TO_OTHER_ORGANIZATION', 'G80 linking to another org''s token is rejected');

-- Retired product: existing subscriber evidence still resolves; new sales do not.
update public.billing_google_play_products set active = false where product_id = 'smartmeters_business';
select is(pg_temp.gp('org_b', 'tok-b2', 'SUBSCRIPTION_STATE_EXPIRED', interval '-1 minute')->>'outcome', 'applied',
  'G81 expiry for a retired product still propagates to the subscriber');
select is(pg_temp.gp('org_a', 'tok-a-retired', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days', p_product => 'smartmeters_business',
  p_base => 'business-monthly')->>'reason', 'PRODUCT_NOT_CONFIGURED', 'G82 retired product cannot be newly purchased');

-- External contract wins over a store purchase.
select pg_temp.act('postgres');
update public.organization_subscriptions set provider = 'external_contract', plan = 'enterprise', status = 'active',
  current_period_end = null, provider_subscription_ref = null where organization_id = pg_temp.k('org_a');
select pg_temp.act('service');
select is(pg_temp.gp('org_a', 'tok-a-ext', 'SUBSCRIPTION_STATE_ACTIVE', interval '30 days')->>'reason', 'ACTIVE_EXTERNAL_CONTRACT',
  'G83 active external contract is not overridden by a store purchase');

-- Input validation.
select throws_ok(format($q$select public.billing_apply_google_play_verification(%L, 'tok', 'com.smartmeters.admin_app',
  'smartmeters_professional', 'professional-monthly', null, 'SUBSCRIPTION_STATE_ACTIVE', null, now() + interval '1 day', null, null,
  null, false, null, 'client_supplied_source')$q$, pg_temp.k('org_a')), '22023', null, 'G84 unknown source is rejected');
select throws_ok($q$select public.billing_apply_google_play_verification(gen_random_uuid(), 'tok', 'com.smartmeters.admin_app',
  'smartmeters_professional', 'professional-monthly', null, 'SUBSCRIPTION_STATE_ACTIVE', null, now() + interval '1 day', null, null,
  null, false, null, 'client_verify')$q$, '22023', null, 'G85 unknown organization is rejected');

-- Audit: append-only, never stores raw tokens.
select pg_temp.act('postgres');
select ok((select count(*) from public.billing_events where organization_id in (pg_temp.k('org_a'), pg_temp.k('org_b'))) >= 40,
  'G86 every verification and ack transition is audited');
select is((select count(*)::int from public.billing_events e
   where e.organization_id in (pg_temp.k('org_a'), pg_temp.k('org_b'))
     and (e.detail::text like '%tok-%' or coalesce(e.token_sha256, '') like 'tok-%')), 0,
  'G87 audit never contains raw purchase tokens');
select throws_ok($q$update public.billing_events set outcome = 'applied'$q$, '42501', 'BILLING_EVENTS_APPEND_ONLY',
  'G88 audit rows cannot be updated');
select throws_ok($q$delete from public.billing_events$q$, '42501', 'BILLING_EVENTS_APPEND_ONLY', 'G89 audit rows cannot be deleted');

-- Pure state mapping matrix (also mirrored by the Edge Function TS tests).
select is(
  (select string_agg(m.status::text || ':' || m.cancel_at_period_end::text || ':' || m.entitling::text, ',' order by s.ord)
     from (values (1, 'SUBSCRIPTION_STATE_ACTIVE'), (2, 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'), (3, 'SUBSCRIPTION_STATE_CANCELED'),
                  (4, 'SUBSCRIPTION_STATE_EXPIRED'), (5, 'SUBSCRIPTION_STATE_ON_HOLD'), (6, 'SUBSCRIPTION_STATE_PAUSED'),
                  (7, 'SUBSCRIPTION_STATE_PENDING'), (8, 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED'),
                  (9, 'SUBSCRIPTION_STATE_UNSPECIFIED')) s(ord, st),
     lateral public.billing_google_play_map_state(s.st, timestamptz '2030-01-02', timestamptz '2030-01-01') m),
  'active:false:true,grace_period:false:true,active:true:true,expired:false:false,past_due:false:false,past_due:false:false,past_due:false:false,expired:false:false,expired:false:false',
  'G90 state mapping matrix with future expiry');
select is(
  (select string_agg(m.status::text || ':' || m.entitling::text, ',' order by s.ord)
     from (values (1, 'SUBSCRIPTION_STATE_ACTIVE'), (2, 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'), (3, 'SUBSCRIPTION_STATE_CANCELED')) s(ord, st),
     lateral public.billing_google_play_map_state(s.st, timestamptz '2030-01-01', timestamptz '2030-01-01') m),
  'expired:false,past_due:false,expired:false', 'G91 expiry equal to now never entitles');

-- Billing catalog for an authorized org admin now shows configured, active products.
select pg_temp.act('org_admin_b');
select is((select count(*)::int from public.billing_google_play_catalog(pg_temp.k('org_b'))), 2,
  'G92 catalog lists only active configured products');
select is((select distinct account_binding from public.billing_google_play_catalog(pg_temp.k('org_b'))),
  current_setting('test.binding_b'), 'G93 catalog returns the org account binding');
select ok((select bool_and(g.max_users = c.max_users) from public.billing_google_play_catalog(pg_temp.k('org_b')) g
  join public.subscription_plan_catalog c on c.plan = g.plan), 'G94 catalog limits come from the plan catalog');
select ok((select length(account_binding) < 64 and account_binding ~ '^[0-9a-f]+$'
  from public.billing_google_play_catalog(pg_temp.k('org_b')) limit 1), 'G95 account binding is opaque hex under the Play 64-char limit');
select throws_ok(format($q$select provider_subscription_ref from public.organization_subscriptions where organization_id = %L$q$,
  pg_temp.k('org_b')), '42501', null, 'G96 billing references stay hidden from clients (column privilege)');

-- Edge Function contract: PostgREST passes JSON keys as named arguments
-- (createBillingRpc in supabase/functions/_shared/google_play/verify_purchase.ts).
select pg_temp.act('service');
select is((public.billing_apply_google_play_verification(
    p_organization_id => pg_temp.k('org_b'), p_purchase_token => 'tok-named-contract',
    p_package_name => 'com.smartmeters.admin_app', p_product_id => 'smartmeters_professional',
    p_base_plan_id => 'professional-annual', p_offer_id => null,
    p_subscription_state => 'SUBSCRIPTION_STATE_PENDING', p_acknowledgement_state => 'ACKNOWLEDGEMENT_STATE_PENDING',
    p_expiry_time => '2099-02-01T00:00:00.000Z', p_linked_purchase_token => null, p_latest_order_id => null,
    p_obfuscated_account_id => current_setting('test.binding_b'), p_is_test_purchase => false,
    p_actor_id => null, p_source => 'client_verify'))->>'reason',
  'NOT_ENTITLING', 'G97 apply RPC accepts the Edge Function named-argument contract');
select is(public.billing_google_play_ack_transition(p_purchase_token => 'tok-named-contract', p_event => 'failed'), true,
  'G98 ack RPC accepts the Edge Function named-argument contract');

select pg_temp.act('postgres');
select * from finish();
rollback;
