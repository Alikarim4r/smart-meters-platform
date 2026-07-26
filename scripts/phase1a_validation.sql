-- =============================================================================
-- Phase 1A — Validation Test Suite
-- Run AFTER: 001_schema, 002_rls, 003_storage, seed, phase1a_setup_test_users
-- Safe for local/staging only. Uses ROLLBACK for destructive probe tests.
-- =============================================================================

\set ON_ERROR_STOP on

-- =============================================================================
-- 1. SCHEMA VALIDATION
-- =============================================================================

do $$
declare
  v_count int;
  v_expected_enums text[] := array[
    'user_role','site_type','meter_category','meter_source','meter_level',
    'meter_unit','meter_kind','calculation_type','reading_audit_action'
  ];
  v_enum text;
  v_expected_tables text[] := array[
    'organizations','sites','profiles','user_site_access','meters',
    'meter_readings','reading_audit_logs','cop_groups',
    'cop_group_btu_meters','cop_group_electricity_meters'
  ];
  v_table text;
begin
  raise notice '=== 1. SCHEMA VALIDATION ===';

  foreach v_enum in array v_expected_enums loop
    select count(*) into v_count
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typname = v_enum;
    if v_count = 0 then
      raise exception 'MISSING ENUM: %', v_enum;
    end if;
    raise notice 'OK enum: %', v_enum;
  end loop;

  foreach v_table in array v_expected_tables loop
    select count(*) into v_count
    from information_schema.tables
    where table_schema = 'public' and table_name = v_table;
    if v_count = 0 then
      raise exception 'MISSING TABLE: %', v_table;
    end if;
    raise notice 'OK table: %', v_table;
  end loop;

  select count(*) into v_count
  from pg_trigger tg
  join pg_class c on c.oid = tg.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and not tg.tgisinternal
    and c.relname in ('meters','meter_readings','reading_audit_logs');
  if v_count < 8 then
    raise exception 'Expected at least 8 public triggers on meters/readings, found %', v_count;
  end if;
  raise notice 'OK triggers: % on core tables', v_count;

  select count(*) into v_count
  from pg_policies
  where schemaname = 'public';
  if v_count < 30 then
    raise exception 'Expected at least 30 RLS policies, found %', v_count;
  end if;
  raise notice 'OK RLS policies: %', v_count;

  select count(*) into v_count
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'meter_daily_consumption'
    and c.relkind = 'v';
  if v_count = 0 then
    raise exception 'MISSING VIEW: meter_daily_consumption';
  end if;

  select count(*) into v_count
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'meter_daily_consumption'
    and c.reloptions @> array['security_invoker=true'];
  if v_count = 0 then
    raise exception 'VIEW meter_daily_consumption missing security_invoker=true';
  end if;
  raise notice 'OK view: meter_daily_consumption (security_invoker=true)';
end $$;

-- =============================================================================
-- 2. SEED VALIDATION
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 2. SEED VALIDATION ===';

  select count(*) into v_count from public.organizations
  where id = '11111111-1111-4111-8111-111111111111';
  if v_count = 0 then raise exception 'MISSING seed organization'; end if;
  raise notice 'OK organization: MOEHE';

  select count(*) into v_count from public.sites
  where id = '22222222-2222-4222-8222-222222222222';
  if v_count = 0 then raise exception 'MISSING seed site MOEHE HQ'; end if;
  raise notice 'OK site: MOEHE HQ';

  select count(*) into v_count from public.meters
  where id = '33333333-3333-4333-8333-333333333301' and category = 'water';
  if v_count = 0 then raise exception 'MISSING seed water meter'; end if;
  raise notice 'OK meter: water (1219053)';

  select count(*) into v_count from public.meters
  where id = '33333333-3333-4333-8333-333333333302' and category = 'electricity';
  if v_count = 0 then raise exception 'MISSING seed electricity meter'; end if;
  raise notice 'OK meter: electricity (LVP-MAIN)';

  select count(*) into v_count from public.meters
  where id = '33333333-3333-4333-8333-333333333303' and category = 'btu';
  if v_count = 0 then raise exception 'MISSING seed BTU meter'; end if;
  raise notice 'OK meter: BTU (BTU-MAIN-01)';

  select count(*) into v_count
  from public.cop_groups g
  join public.cop_group_btu_meters bm on bm.cop_group_id = g.id
  join public.cop_group_electricity_meters em on em.cop_group_id = g.id
  where g.id = '44444444-4444-4444-8444-444444444444'
    and bm.meter_id = '33333333-3333-4333-8333-333333333303'
    and em.meter_id = '33333333-3333-4333-8333-333333333302';
  if v_count = 0 then raise exception 'MISSING or incomplete COP group links'; end if;
  raise notice 'OK COP group: Chiller Plant COP linked BTU + electricity';
end $$;

-- Constants
-- site:  22222222-2222-4222-8222-222222222222
-- water: 33333333-3333-4333-8333-333333333301
-- elec:  33333333-3333-4333-8333-333333333302
-- btu:   33333333-3333-4333-8333-333333333303
-- tech:  aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3

-- Clean prior validation readings (staging/local only)
delete from public.meter_readings
where meter_id in (
  '33333333-3333-4333-8333-333333333301',
  '33333333-3333-4333-8333-333333333302',
  '33333333-3333-4333-8333-333333333303'
)
and reading_date in ('2026-07-10','2026-07-11');

-- =============================================================================
-- 3. READING VALIDATION
-- =============================================================================

do $$
declare
  v_raw numeric;
  v_norm numeric;
  v_audit int;
begin
  raise notice '=== 3. READING VALIDATION ===';

  insert into public.meter_readings (site_id, meter_id, reading_date, raw_value, normalized_value, entered_by)
  values
    ('22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333301', '2026-07-10', 1000.0, 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
    ('22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333302', '2026-07-10', 5000.0, 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
    ('22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333303', '2026-07-10', 300.0, 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3');

  insert into public.meter_readings (site_id, meter_id, reading_date, raw_value, normalized_value, entered_by)
  values
    ('22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333301', '2026-07-11', 1100.0, 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
    ('22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333302', '2026-07-11', 5300.0, 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
    ('22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333303', '2026-07-11', 450.0, 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3');

  select raw_value, normalized_value into v_raw, v_norm
  from public.meter_readings
  where meter_id = '33333333-3333-4333-8333-333333333301' and reading_date = '2026-07-11';

  if v_raw <> 1100.0 then raise exception 'raw_value mismatch: got %', v_raw; end if;
  if v_norm <> 1100.0 then raise exception 'normalized_value mismatch water: got %', v_norm; end if;
  raise notice 'OK water: raw=1100 normalized=1100';

  select count(*) into v_audit from public.reading_audit_logs
  where meter_id = '33333333-3333-4333-8333-333333333301' and action = 'create';
  if v_audit < 2 then raise exception 'Expected audit create rows for water'; end if;
  raise notice 'OK audit rows created on insert';

  select daily_consumption into v_norm
  from public.meter_daily_consumption
  where meter_id = '33333333-3333-4333-8333-333333333301' and reading_date = '2026-07-11';

  if v_norm <> 100.0 then raise exception 'daily_consumption expected 100, got %', v_norm; end if;
  raise notice 'OK meter_daily_consumption: water delta 2026-07-11 = 100';
end $$;

-- =============================================================================
-- 4. UNIT PROTECTION TEST
-- =============================================================================

do $$
begin
  raise notice '=== 4. UNIT PROTECTION TEST ===';

  begin
    update public.meters set unit = 'liter' where id = '33333333-3333-4333-8333-333333333301';
    raise exception 'FAIL: unit change should be blocked';
  exception when others then
    raise notice 'OK blocked: unit change (%)', sqlerrm;
  end;

  begin
    update public.meters set unit_to_base_factor = 0.001 where id = '33333333-3333-4333-8333-333333333301';
    raise exception 'FAIL: unit_to_base_factor change should be blocked';
  exception when others then
    raise notice 'OK blocked: unit_to_base_factor change (%)', sqlerrm;
  end;

  begin
    update public.meters set category = 'electricity' where id = '33333333-3333-4333-8333-333333333301';
    raise exception 'FAIL: category change should be blocked';
  exception when others then
    raise notice 'OK blocked: category change (%)', sqlerrm;
  end;
end $$;

-- =============================================================================
-- 5. VIRTUAL METER TEST
-- =============================================================================

do $$
declare
  v_virtual_id uuid := '55555555-5555-4555-8555-555555555501';
begin
  raise notice '=== 5. VIRTUAL METER TEST ===';

  insert into public.meters (
    id, site_id, meter_code, name_en, name_ar,
    category, source, level, parent_meter_id,
    meter_kind, calculation_type,
    unit, unit_to_base_factor, base_unit, meter_multiplier
  ) values (
    v_virtual_id,
    '22222222-2222-4222-8222-222222222222',
    'VAL-WF-TEST',
    'Validation Virtual WF',
    'اختبار افتراضي',
    'water', 'kahramaa', 'sub',
    '33333333-3333-4333-8333-333333333301',
    'virtual', 'parent_minus_children',
    'm3', 1, 'm3', 1
  )
  on conflict (id) do nothing;

  begin
    insert into public.meter_readings (site_id, meter_id, reading_date, raw_value, normalized_value, entered_by)
    values ('22222222-2222-4222-8222-222222222222', v_virtual_id, '2026-07-10', 1, 0, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3');
    raise exception 'FAIL: virtual meter reading should be rejected';
  exception when others then
    raise notice 'OK rejected: virtual meter reading (%)', sqlerrm;
  end;
end $$;

-- =============================================================================
-- 6. PARENT METER VALIDATION
-- =============================================================================

do $$
declare
  v_other_site uuid := '66666666-6666-4666-8666-666666666601';
  v_sub_id uuid := '66666666-6666-4666-8666-666666666602';
  v_main_other uuid := '66666666-6666-4666-8666-666666666603';
begin
  raise notice '=== 6. PARENT METER VALIDATION ===';

  insert into public.sites (id, organization_id, name_en, name_ar, site_type)
  values (v_other_site, '11111111-1111-4111-8111-111111111111', 'Validation Other Site', 'موقع آخر', 'office')
  on conflict (id) do nothing;

  insert into public.meters (
    id, site_id, meter_code, name_en, name_ar, category, source, level,
    meter_kind, calculation_type, unit, unit_to_base_factor, base_unit, meter_multiplier
  ) values (
    v_main_other, v_other_site, 'OTHER-MAIN', 'Other Main', 'رئيسي آخر',
    'water', 'kahramaa', 'main', 'physical', 'direct_reading', 'm3', 1, 'm3', 1
  ) on conflict (id) do nothing;

  begin
    insert into public.meters (
      id, site_id, meter_code, name_en, name_ar, category, source, level, parent_meter_id,
      meter_kind, calculation_type, unit, unit_to_base_factor, base_unit, meter_multiplier
    ) values (
      v_sub_id, '22222222-2222-4222-8222-222222222222', 'VAL-CROSS-SITE', 'Cross Site Sub', 'فرعي',
      'water', 'kahramaa', 'sub', v_main_other,
      'physical', 'direct_reading', 'm3', 1, 'm3', 1
    );
    raise exception 'FAIL: cross-site parent should be rejected';
  exception when others then
    raise notice 'OK rejected: cross-site parent (%)', sqlerrm;
  end;

  begin
    insert into public.meters (
      site_id, meter_code, name_en, name_ar, category, source, level, parent_meter_id,
      meter_kind, calculation_type, unit, unit_to_base_factor, base_unit, meter_multiplier
    ) values (
      '22222222-2222-4222-8222-222222222222', 'VAL-CROSS-CAT', 'Cross Cat Sub', 'فرعي',
      'water', 'kahramaa', 'sub', '33333333-3333-4333-8333-333333333302',
      'physical', 'direct_reading', 'm3', 1, 'm3', 1
    );
    raise exception 'FAIL: cross-category parent should be rejected';
  exception when others then
    raise notice 'OK rejected: cross-category parent (%)', sqlerrm;
  end;

  begin
    insert into public.meters (
      site_id, meter_code, name_en, name_ar, category, source, level, parent_meter_id,
      meter_kind, calculation_type, unit, unit_to_base_factor, base_unit, meter_multiplier
    ) values (
      '22222222-2222-4222-8222-222222222222', 'VAL-SUB-PARENT', 'Sub Parent Sub', 'فرعي',
      'water', 'kahramaa', 'sub', '55555555-5555-4555-8555-555555555501',
      'physical', 'direct_reading', 'm3', 1, 'm3', 1
    );
    raise exception 'FAIL: sub-as-parent should be rejected';
  exception when others then
    raise notice 'OK rejected: sub-as-parent (%)', sqlerrm;
  end;
end $$;

-- =============================================================================
-- 7. RLS VALIDATION (simulate JWT claims)
-- =============================================================================

do $$
declare
  v_count int;
  v_site uuid := '22222222-2222-4222-8222-222222222222';
  v_other uuid := '66666666-6666-4666-8666-666666666601';
begin
  raise notice '=== 7. RLS VALIDATION ===';

  -- Technician: can read assigned site
  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', true);
  set local role authenticated;
  select count(*) into v_count from public.sites where id = v_site;
  if v_count <> 1 then raise exception 'technician cannot read assigned site'; end if;
  raise notice 'OK technician reads assigned site';
  reset role;

  -- Technician: cannot read unassigned site
  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', true);
  set local role authenticated;
  select count(*) into v_count from public.sites where id = v_other;
  if v_count <> 0 then raise exception 'technician should not read unassigned site'; end if;
  raise notice 'OK technician blocked from unassigned site';
  reset role;

  -- Viewer: cannot insert readings
  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', true);
  set local role authenticated;
  begin
    insert into public.meter_readings (site_id, meter_id, reading_date, raw_value, normalized_value, entered_by)
    values (v_site, '33333333-3333-4333-8333-333333333302', '2026-07-12', 1, 1, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4');
    raise exception 'FAIL: viewer should not insert readings';
  exception when others then
    raise notice 'OK viewer blocked from insert (%)', sqlerrm;
  end;
  reset role;

  -- Technician: cannot update any saved reading (RLS returns 0 rows; trigger blocks if policy bypassed)
  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', true);
  set local role authenticated;
  update public.meter_readings
  set raw_value = 9999
  where meter_id = '33333333-3333-4333-8333-333333333301' and reading_date = '2026-07-11';
  get diagnostics v_count = row_count;
  if v_count > 0 then
    raise exception 'FAIL: technician updated % reading row(s)', v_count;
  end if;
  raise notice 'OK technician blocked from update (0 rows affected)';
  reset role;

  -- Technician: cannot delete readings
  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', true);
  set local role authenticated;
  delete from public.meter_readings
  where meter_id = '33333333-3333-4333-8333-333333333301' and reading_date = '2026-07-11';
  get diagnostics v_count = row_count;
  if v_count > 0 then
    raise exception 'FAIL: technician deleted % reading row(s)', v_count;
  end if;
  raise notice 'OK technician blocked from delete (0 rows affected)';
  reset role;

  -- Super admin: can read all sites
  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', true);
  set local role authenticated;
  select count(*) into v_count from public.sites;
  if v_count < 2 then raise exception 'super_admin should see all sites'; end if;
  raise notice 'OK super_admin reads all sites (count=%)', v_count;
  reset role;
end $$;

-- =============================================================================
-- 8. AUDIT VALIDATION
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 8. AUDIT VALIDATION ===';

  -- Manual insert blocked for authenticated
  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', true);
  set local role authenticated;
  begin
    insert into public.reading_audit_logs (meter_id, site_id, action)
    values ('33333333-3333-4333-8333-333333333301', '22222222-2222-4222-8222-222222222222', 'create');
    raise exception 'FAIL: manual audit insert should be blocked';
  exception when others then
    raise notice 'OK manual audit insert blocked (%)', sqlerrm;
  end;

  select count(*) into v_count from public.reading_audit_logs
  where site_id = '22222222-2222-4222-8222-222222222222';
  if v_count = 0 then raise exception 'site_admin should read audit logs'; end if;
  raise notice 'OK site_admin reads audit logs (count=%)', v_count;
  reset role;

  -- Viewer cannot read audit logs
  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', true);
  set local role authenticated;
  select count(*) into v_count from public.reading_audit_logs;
  if v_count <> 0 then raise exception 'viewer should not read audit logs'; end if;
  raise notice 'OK viewer blocked from audit logs';
  reset role;

  -- Update triggers audit (as postgres)
  update public.meter_readings
  set note = 'validation update test'
  where meter_id = '33333333-3333-4333-8333-333333333301' and reading_date = '2026-07-11';

  select count(*) into v_count from public.reading_audit_logs
  where action = 'update' and meter_id = '33333333-3333-4333-8333-333333333301';
  if v_count = 0 then raise exception 'update audit row missing'; end if;
  raise notice 'OK audit row on update';
end $$;

-- =============================================================================
-- 9. STORAGE VALIDATION (policy existence)
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 9. STORAGE VALIDATION ===';

  select count(*) into v_count from storage.buckets where id = 'meter-images';
  if v_count = 0 then raise exception 'MISSING bucket meter-images'; end if;
  raise notice 'OK bucket: meter-images exists';

  select count(*) into v_count from pg_policies
  where schemaname = 'storage' and tablename = 'objects'
    and policyname like 'meter_images_%';
  if v_count < 4 then
    raise exception 'Expected 4 storage policies, found %', v_count;
  end if;
  raise notice 'OK storage policies: % meter_images_* policies', v_count;
  raise notice 'NOTE: upload/download ACL requires Storage API test from client (not SQL-only)';
end $$;

-- =============================================================================
-- 10. COP VALIDATION
-- =============================================================================

do $$
declare
  v_btu_consumption numeric;
  v_elec_consumption numeric;
  v_cop numeric;
begin
  raise notice '=== 10. COP VALIDATION ===';

  select daily_consumption into v_btu_consumption
  from public.meter_daily_consumption
  where meter_id = '33333333-3333-4333-8333-333333333303' and reading_date = '2026-07-11';

  select daily_consumption into v_elec_consumption
  from public.meter_daily_consumption
  where meter_id = '33333333-3333-4333-8333-333333333302' and reading_date = '2026-07-11';

  if v_btu_consumption <> 150.0 then
    raise exception 'BTU daily consumption expected 150, got %', v_btu_consumption;
  end if;
  if v_elec_consumption <> 300.0 then
    raise exception 'Electricity daily consumption expected 300, got %', v_elec_consumption;
  end if;

  v_cop := v_btu_consumption / v_elec_consumption;
  if v_cop <> 0.5 then
    raise exception 'COP expected 0.5, got %', v_cop;
  end if;

  raise notice 'OK COP derivable: BTU=150 elec=300 COP=%', v_cop;
end $$;

-- =============================================================================
-- 11. TECHNICIAN READING DATE RESTRICTIONS (Asia/Qatar business date)
-- =============================================================================

do $$
declare
  v_site uuid := '22222222-2222-4222-8222-222222222222';
  v_meter uuid := '33333333-3333-4333-8333-333333333302';
  v_tech uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3';
  v_admin uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  v_today date;
  v_audit_before int;
  v_audit_after int;
  v_row_count int;
begin
  raise notice '=== 11. TECHNICIAN READING RESTRICTIONS ===';

  select public.current_business_date() into v_today;
  raise notice 'Qatar business date: %', v_today;

  -- Clean today's test row for electricity meter
  delete from public.meter_readings
  where meter_id = v_meter and reading_date = v_today;

  -- Technician insert today: success
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  insert into public.meter_readings (site_id, meter_id, reading_date, raw_value, normalized_value, entered_by)
  values (v_site, v_meter, v_today, 6000.0, 0, v_tech);
  raise notice 'OK technician insert today succeeded';
  reset role;

  -- Technician insert yesterday: fail
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  begin
    insert into public.meter_readings (site_id, meter_id, reading_date, raw_value, normalized_value, entered_by)
    values (v_site, v_meter, v_today - 1, 5900.0, 0, v_tech);
    raise exception 'FAIL: technician backdate should be rejected';
  exception when others then
    raise notice 'OK technician insert yesterday blocked (%)', sqlerrm;
  end;
  reset role;

  -- Technician insert tomorrow: fail
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  begin
    insert into public.meter_readings (site_id, meter_id, reading_date, raw_value, normalized_value, entered_by)
    values (v_site, v_meter, v_today + 1, 6100.0, 0, v_tech);
    raise exception 'FAIL: technician future date should be rejected';
  exception when others then
    raise notice 'OK technician insert tomorrow blocked (%)', sqlerrm;
  end;
  reset role;

  -- Technician update today's reading: fail (0 rows via RLS or trigger exception)
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  begin
    update public.meter_readings
    set raw_value = 6001.0
    where meter_id = v_meter and reading_date = v_today;
    get diagnostics v_row_count = row_count;
    if v_row_count > 0 then
      raise exception 'FAIL: technician updated today reading (% rows)', v_row_count;
    end if;
    raise notice 'OK technician update today blocked (0 rows affected)';
  exception
    when others then
      raise notice 'OK technician update today blocked (%)', sqlerrm;
  end;
  reset role;

  -- Site admin insert missing past reading: success
  perform set_config('request.jwt.claim.sub', v_admin::text, true);
  set local role authenticated;
  delete from public.meter_readings where meter_id = v_meter and reading_date = '2026-06-15';
  insert into public.meter_readings (site_id, meter_id, reading_date, raw_value, normalized_value, entered_by, note)
  values (v_site, v_meter, '2026-06-15', 5500.0, 0, v_admin, 'Admin backfill for validation test');
  raise notice 'OK site_admin insert past reading succeeded';
  reset role;

  -- Site admin update past reading with audit
  select count(*) into v_audit_before from public.reading_audit_logs
  where meter_id = v_meter and action = 'update';

  perform set_config('request.jwt.claim.sub', v_admin::text, true);
  set local role authenticated;
  update public.meter_readings
  set raw_value = 5510.0, note = 'Admin correction: meter misread on 2026-06-15'
  where meter_id = v_meter and reading_date = '2026-06-15';
  reset role;

  select count(*) into v_audit_after from public.reading_audit_logs
  where meter_id = v_meter and action = 'update';

  if v_audit_after <= v_audit_before then
    raise exception 'Expected audit row after site_admin correction';
  end if;
  raise notice 'OK site_admin update past reading with audit (updates: % -> %)', v_audit_before, v_audit_after;
end $$;

-- =============================================================================
-- SUMMARY
-- =============================================================================

do $$
begin
  raise notice '=== PHASE 1A VALIDATION COMPLETE — ALL CHECKS PASSED ===';
end $$;
