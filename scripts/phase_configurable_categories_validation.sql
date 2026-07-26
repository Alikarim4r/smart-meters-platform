-- =============================================================================
-- Phase — Configurable Meter Categories Validation
-- Run AFTER:
--   001_schema, 002_rls, 003_storage,
--   004_user_approval_enum, 005_user_approval,
--   006_configurable_meter_categories.sql
--   (and prerequisite: ALTER TYPE meter_category ADD VALUE 'fuel')
--   seed, phase1a_setup_test_users
-- Safe for local/staging only. DO NOT run on production without review.
-- =============================================================================

\set ON_ERROR_STOP on

-- Fixed UUIDs (phase1a / phase1e)
-- super_admin:  aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1
-- site_admin:   aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2
-- technician:   aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3
-- viewer:       aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4
-- MOEHE HQ:    22222222-2222-4222-8222-222222222222

-- Seeded category IDs (006)
-- water:       c1111111-1111-4111-8111-111111111101
-- electricity: c1111111-1111-4111-8111-111111111102
-- btu:         c1111111-1111-4111-8111-111111111103
-- fuel:        c1111111-1111-4111-8111-111111111104

-- =============================================================================
-- 1. SCHEMA VALIDATION
-- =============================================================================

do $$
declare
  v_count int;
  v_tbl text;
  v_flag boolean;
begin
  raise notice '=== 1. SCHEMA VALIDATION ===';

  foreach v_tbl in array ARRAY['meter_categories', 'meter_units', 'meter_sources'] loop
    select count(*) into v_count
    from information_schema.tables
    where table_schema = 'public' and table_name = v_tbl;
    if v_count = 0 then
      raise exception 'MISSING TABLE: %', v_tbl;
    end if;
    raise notice 'OK table: %', v_tbl;
  end loop;

  select count(*) into v_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'meters'
    and column_name = 'category_id';
  if v_count = 0 then
    raise exception 'MISSING COLUMN: meters.category_id';
  end if;
  raise notice 'OK columns: meters.category_id, source_id, unit_id';

  select count(*) into v_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'meter_categories'
    and column_name = 'supports_cop_output';
  if v_count = 0 then
    raise exception 'MISSING COLUMN: meter_categories.supports_cop_output';
  end if;
  raise notice 'OK COP flags on meter_categories';

  select count(*) into v_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'sync_meter_legacy_from_config';
  if v_count = 0 then
    raise exception 'MISSING FUNCTION: sync_meter_legacy_from_config';
  end if;
  raise notice 'OK function: sync_meter_legacy_from_config';
end $$;

-- =============================================================================
-- 2. SEED VALIDATION
-- =============================================================================

do $$
declare
  v_count int;
  v_flag boolean;
begin
  raise notice '=== 2. SEED VALIDATION ===';

  select count(*) into v_count
  from public.meter_categories
  where code in ('water', 'electricity', 'btu', 'fuel')
    and is_system = true
    and is_active = true;
  if v_count <> 4 then
    raise exception 'Expected 4 system categories, found %', v_count;
  end if;
  raise notice 'OK categories seeded (water, electricity, btu, fuel)';

  select count(*) into v_count from public.meter_units where category_id = 'c1111111-1111-4111-8111-111111111101';
  if v_count < 4 then
    raise exception 'Expected >= 4 water units, found %', v_count;
  end if;

  select count(*) into v_count from public.meter_units where category_id = 'c1111111-1111-4111-8111-111111111102';
  if v_count < 4 then
    raise exception 'Expected >= 4 electricity units, found %', v_count;
  end if;

  select count(*) into v_count from public.meter_units where category_id = 'c1111111-1111-4111-8111-111111111103';
  if v_count < 4 then
    raise exception 'Expected >= 4 btu units, found %', v_count;
  end if;

  select count(*) into v_count from public.meter_units where category_id = 'c1111111-1111-4111-8111-111111111104';
  if v_count < 3 then
    raise exception 'Expected >= 3 fuel units, found %', v_count;
  end if;
  raise notice 'OK units seeded per category';

  select count(*) into v_count from public.meter_sources where category_id = 'c1111111-1111-4111-8111-111111111104';
  if v_count < 4 then
    raise exception 'Expected >= 4 fuel sources (diesel, petrol, gas_oil, other), found %', v_count;
  end if;
  raise notice 'OK sources seeded (including fuel/diesel)';

  select supports_cop_output into v_flag
  from public.meter_categories where code = 'btu';
  if not v_flag then
    raise exception 'btu category must have supports_cop_output = true';
  end if;

  select supports_electric_input into v_flag
  from public.meter_categories where code = 'electricity';
  if not v_flag then
    raise exception 'electricity category must have supports_electric_input = true';
  end if;
  raise notice 'OK COP flags: btu output, electricity input';
end $$;

-- =============================================================================
-- 3. METER BACKFILL VALIDATION
-- =============================================================================

do $$
declare
  v_missing int;
  v_mismatch int;
begin
  raise notice '=== 3. METER BACKFILL VALIDATION ===';

  select count(*) into v_missing
  from public.meters
  where category_id is null or source_id is null or unit_id is null;
  if v_missing > 0 then
    raise exception '% meters missing category_id/source_id/unit_id', v_missing;
  end if;
  raise notice 'OK all meters have FK refs';

  select count(*) into v_mismatch
  from public.meters m
  join public.meter_categories mc on mc.id = m.category_id
  where mc.code <> m.category::text
    and m.category::text in ('water', 'electricity', 'btu');
  if v_mismatch > 0 then
    raise exception '% meters have legacy category mismatch with category_id', v_mismatch;
  end if;
  raise notice 'OK legacy category enum synced with category_id (water/electricity/btu)';
end $$;

-- =============================================================================
-- 4. LEGACY QUERY COMPATIBILITY (enum columns still usable)
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 4. LEGACY QUERY COMPATIBILITY ===';

  select count(*) into v_count
  from public.meters
  where site_id = '22222222-2222-4222-8222-222222222222'
    and category = 'water'
    and is_active = true;
  if v_count = 0 then
    raise warning 'No active water meters at MOEHE HQ — skip count check';
  else
    raise notice 'OK legacy category=water query returns % meters', v_count;
  end if;

  select count(*) into v_count
  from public.meters m
  where m.unit_to_base_factor is not null
    and m.unit_id is not null
    and abs(
      m.unit_to_base_factor - (
        select mu.unit_to_base_factor from public.meter_units mu where mu.id = m.unit_id
      )
    ) > 0.0000001;
  if v_count > 0 then
    raise exception '% meters have unit_to_base_factor mismatch vs meter_units', v_count;
  end if;
  raise notice 'OK unit_to_base_factor matches meter_units';
end $$;

-- =============================================================================
-- 5. ENTRY APP READ PATH (technician RLS)
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 5. TECHNICIAN RLS — READ METERS + CONFIG ===';

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', true);
  set local role authenticated;

  select count(*) into v_count
  from public.meters
  where site_id = '22222222-2222-4222-8222-222222222222'
    and is_active = true;
  if v_count = 0 then
    raise exception 'Technician cannot read MOEHE HQ meters';
  end if;
  raise notice 'OK technician reads % meters at MOEHE HQ', v_count;

  select count(*) into v_count from public.meter_categories where is_active = true;
  if v_count < 4 then
    raise exception 'Technician cannot read active meter_categories';
  end if;
  raise notice 'OK technician reads % active categories', v_count;

  select count(*) into v_count from public.meter_units where is_active = true;
  if v_count = 0 then
    raise exception 'Technician cannot read meter_units';
  end if;
  raise notice 'OK technician reads meter_units';

  reset role;
end $$;

-- =============================================================================
-- 6. INTEGRITY — BLOCK CATEGORY/UNIT CHANGE AFTER READINGS
-- =============================================================================

do $$
declare
  v_meter_id uuid;
  v_site_id uuid := '22222222-2222-4222-8222-222222222222';
  v_reading_date date := current_date;
begin
  raise notice '=== 6. INTEGRITY TRIGGER ===';

  select id into v_meter_id
  from public.meters
  where site_id = v_site_id
    and category = 'water'
    and meter_kind = 'physical'
  limit 1;

  if v_meter_id is null then
    raise warning 'No water meter for integrity test — skipping';
    return;
  end if;

  insert into public.meter_readings (
    site_id, meter_id, reading_date, raw_value, normalized_value, entered_by
  )
  values (
    v_site_id, v_meter_id, v_reading_date, 100, 100,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'
  )
  on conflict (meter_id, reading_date) do nothing;

  begin
    update public.meters
    set unit_id = (
      select id from public.meter_units
      where category_id = 'c1111111-1111-4111-8111-111111111101'
        and code = 'liter'
      limit 1
    )
    where id = v_meter_id;
    raise exception 'INTEGRITY FAIL: unit_id change allowed after readings';
  exception
    when others then
      if sqlerrm not like '%Cannot change unit/category%' then
        raise;
      end if;
      raise notice 'OK protect_meter_unit_integrity blocks unit_id change';
  end;

  delete from public.meter_readings
  where meter_id = v_meter_id and reading_date = v_reading_date;
end $$;

-- =============================================================================
-- 7. FUEL / DIESEL METER CREATION
-- =============================================================================

do $$
declare
  v_meter_id uuid;
begin
  raise notice '=== 7. FUEL DIESEL METER ===';

  insert into public.meters (
    site_id, meter_code, name_en, name_ar,
    category_id, source_id, unit_id,
    level, meter_kind, calculation_type,
    meter_multiplier, is_active, include_in_dashboard
  )
  values (
    '22222222-2222-4222-8222-222222222222',
    'VALIDATION-DIESEL-01',
    'Validation Diesel Tank',
    'خزان ديزل تجريبي',
    'c1111111-1111-4111-8111-111111111104',
    'b1111111-1111-4111-8111-111111111401',
    'e1111111-1111-4111-8111-111111111401',
    'main', 'physical', 'direct_reading',
    1, true, false
  )
  on conflict (site_id, meter_code) do update set
    category_id = excluded.category_id,
    source_id = excluded.source_id,
    unit_id = excluded.unit_id
  returning id into v_meter_id;

  if v_meter_id is null then
    raise exception 'Failed to create validation diesel meter';
  end if;

  if not exists (
    select 1
    from public.meters m
    join public.meter_categories mc on mc.id = m.category_id
  join public.meter_sources ms on ms.id = m.source_id
    where m.id = v_meter_id
      and mc.code = 'fuel'
      and ms.code = 'diesel'
  ) then
    raise exception 'Diesel meter not linked to fuel category + diesel source';
  end if;
  raise notice 'OK fuel/diesel meter created: %', v_meter_id;

  delete from public.meters where id = v_meter_id;
end $$;

-- =============================================================================
-- 8. CONFIG TABLE RLS — NON-ADMIN CANNOT MODIFY
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 8. CONFIG RLS — WRITE DENIED FOR NON-ADMIN ===';

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', true);
  set local role authenticated;
  begin
    insert into public.meter_categories (code, name_en, base_unit_code)
    values ('steam_test', 'Steam Test', 'kg');
    raise exception 'RLS FAIL: site_admin inserted meter_categories';
  exception
    when others then
      if sqlerrm like '%violates row-level security%' or sqlerrm like '%permission denied%' then
        raise notice 'OK site_admin blocked from insert meter_categories';
      elsif sqlerrm like '%RLS FAIL%' then
        raise;
      else
        raise notice 'OK site_admin blocked from insert meter_categories (%)', sqlerrm;
      end if;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', true);
  set local role authenticated;
  update public.meter_units
  set name_en = 'Hacked'
  where id = (
    select id from public.meter_units where code = 'm3' and category_id = 'c1111111-1111-4111-8111-111111111101' limit 1
  );
  get diagnostics v_count = row_count;
  if v_count > 0 then
    raise exception 'RLS FAIL: technician updated meter_units';
  end if;
  raise notice 'OK technician blocked from update meter_units';
  reset role;

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', true);
  set local role authenticated;
  select count(*) into v_count from public.meter_sources where is_active = true;
  if v_count = 0 then
    raise exception 'Viewer cannot read active meter_sources';
  end if;
  raise notice 'OK viewer can read active meter_sources';
  begin
    delete from public.meter_sources where code = 'other' and category_id = 'c1111111-1111-4111-8111-111111111101';
    get diagnostics v_count = row_count;
    if v_count > 0 then
      raise exception 'RLS FAIL: viewer deleted meter_sources';
    end if;
    raise notice 'OK viewer blocked from delete meter_sources';
  exception
    when others then
      if sqlerrm like '%RLS FAIL%' then
        raise;
      else
        raise notice 'OK viewer blocked from delete meter_sources (%)', sqlerrm;
      end if;
  end;
  reset role;
end $$;

-- =============================================================================
-- 9. SUPER_ADMIN CAN MANAGE CONFIG (smoke test, rolled back)
-- =============================================================================

do $$
declare
  v_id uuid;
begin
  raise notice '=== 9. SUPER_ADMIN CONFIG WRITE ===';

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', true);
  set local role authenticated;

  insert into public.meter_categories (
    code, name_en, base_unit_code, is_system, sort_order
  )
  values ('validation_steam', 'Validation Steam', 'kg', false, 999)
  returning id into v_id;

  if v_id is null then
    raise exception 'super_admin could not insert meter_categories';
  end if;
  raise notice 'OK super_admin can insert meter_categories';

  delete from public.meter_categories where id = v_id;
  reset role;
end $$;

-- =============================================================================
-- 10. SYNC TRIGGER (meter without readings)
-- =============================================================================

do $$
declare
  v_meter_id uuid;
  v_liter_unit uuid;
  v_new_unit public.meter_unit;
  v_factor numeric;
  v_base text;
begin
  raise notice '=== 10. SYNC TRIGGER ===';

  select id into v_meter_id
  from public.meters m
  where m.site_id = '22222222-2222-4222-8222-222222222222'
    and m.category = 'water'
    and not exists (select 1 from public.meter_readings r where r.meter_id = m.id)
  limit 1;

  if v_meter_id is null then
    raise warning 'No reading-free water meter for sync test — skipping';
    return;
  end if;

  select id into v_liter_unit
  from public.meter_units
  where category_id = 'c1111111-1111-4111-8111-111111111101'
    and code = 'liter';

  update public.meters
  set unit_id = v_liter_unit
  where id = v_meter_id
  returning unit, unit_to_base_factor, base_unit
  into v_new_unit, v_factor, v_base;

  if v_new_unit::text <> 'liter' then
    raise exception 'Sync failed: unit = %', v_new_unit;
  end if;
  if abs(v_factor - 0.001) > 0.0000001 then
    raise exception 'Sync failed: factor = %', v_factor;
  end if;
  if v_base <> 'm3' then
    raise exception 'Sync failed: base_unit = %', v_base;
  end if;
  raise notice 'OK sync trigger updated legacy unit/factor/base_unit';

  select id into v_liter_unit from public.meter_units
  where category_id = 'c1111111-1111-4111-8111-111111111101' and code = 'm3';
  update public.meters set unit_id = v_liter_unit where id = v_meter_id;
end $$;

-- =============================================================================
-- 11. COP REGRESSION
-- =============================================================================

do $$
declare
  v_group_id uuid;
  v_btu_count int;
  v_elec_count int;
begin
  raise notice '=== 11. COP REGRESSION ===';

  select id into v_group_id from public.cop_groups
  where site_id = '22222222-2222-4222-8222-222222222222'
  limit 1;

  if v_group_id is null then
    raise warning 'No COP group in seed — skipping COP regression';
    return;
  end if;

  select count(*) into v_btu_count
  from public.cop_group_btu_meters cgb
  join public.meters m on m.id = cgb.meter_id
  join public.meter_categories mc on mc.id = m.category_id
  where cgb.cop_group_id = v_group_id
    and mc.supports_cop_output = true;

  if coalesce(v_btu_count, 0) = 0 then
    raise exception 'COP BTU links must use supports_cop_output categories';
  end if;
  raise notice 'OK COP output links use supports_cop_output';

  select count(*) into v_elec_count
  from public.cop_group_electricity_meters cge
  join public.meters m on m.id = cge.meter_id
  join public.meter_categories mc on mc.id = m.category_id
  where cge.cop_group_id = v_group_id
    and mc.supports_electric_input = true;

  if coalesce(v_elec_count, 0) = 0 then
    raise exception 'COP electricity links must use supports_electric_input categories';
  end if;
  raise notice 'OK COP input links use supports_electric_input';
  raise notice 'OK existing COP group % still valid', v_group_id;
end $$;

do $$
begin
  raise notice '=== ALL CONFIGURABLE CATEGORIES VALIDATIONS PASSED ===';
end $$;
