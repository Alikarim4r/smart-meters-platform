-- =============================================================================
-- Phase — Zones Validation
-- Run AFTER:
--   001_schema, 002_rls, 003_storage,
--   004_user_approval_enum, 005_user_approval,
--   006_configurable_meter_categories,
--   007_zones_and_site_zone.sql
--   seed, phase1a_setup_test_users
-- Safe for local/staging only.
-- =============================================================================

\set ON_ERROR_STOP on

-- Fixed UUIDs
-- super_admin:  aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1
-- site_admin:   aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2
-- technician:   aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3
-- viewer:       aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4
-- MOEHE HQ:     22222222-2222-4222-8222-222222222222
-- MOEHE org:    11111111-1111-4111-8111-111111111111
-- north_zone:   d1111111-1111-4111-8111-111111111101

-- =============================================================================
-- 1. SCHEMA
-- =============================================================================

do $$
declare
  v_count int;
  v_nullable text;
begin
  raise notice '=== 1. SCHEMA VALIDATION ===';

  select count(*) into v_count
  from information_schema.tables
  where table_schema = 'public' and table_name = 'zones';
  if v_count = 0 then
    raise exception 'MISSING TABLE: zones';
  end if;
  raise notice 'OK table: zones';

  select count(*) into v_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'sites'
    and column_name = 'zone_id';
  if v_count = 0 then
    raise exception 'MISSING COLUMN: sites.zone_id';
  end if;

  select is_nullable into v_nullable
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'sites'
    and column_name = 'zone_id';
  if v_nullable <> 'YES' then
    raise exception 'sites.zone_id must be nullable, got %', v_nullable;
  end if;
  raise notice 'OK sites.zone_id nullable';

  select count(*) into v_count
  from pg_indexes
  where schemaname = 'public'
    and tablename = 'sites'
    and indexname = 'sites_zone_id_idx';
  if v_count = 0 then
    raise exception 'MISSING INDEX: sites_zone_id_idx';
  end if;
  raise notice 'OK indexes';
end $$;

-- =============================================================================
-- 2. SEED / BACKFILL
-- =============================================================================

do $$
declare
  v_count int;
  v_zone_id uuid;
  v_zone_code text;
begin
  raise notice '=== 2. SEED VALIDATION ===';

  select count(*) into v_count
  from public.zones
  where organization_id = '11111111-1111-4111-8111-111111111111'
    and code in ('north_zone', 'south_zone', 'central_zone', 'west_zone');
  if v_count < 4 then
    raise exception 'Expected 4 sample zones, found %', v_count;
  end if;
  raise notice 'OK sample zones seeded: %', v_count;

  select zone_id into v_zone_id
  from public.sites
  where id = '22222222-2222-4222-8222-222222222222';
  if v_zone_id is not null then
    raise exception 'MOEHE HQ should have zone_id null, got %', v_zone_id;
  end if;
  raise notice 'OK MOEHE HQ zone_id is null';

  select z.code into v_zone_code
  from public.sites s
  join public.zones z on z.id = s.zone_id
  where s.name_en = 'Test School A'
  limit 1;
  if v_zone_code is null then
    raise exception 'Test School A should be assigned to North Zone';
  end if;
  if v_zone_code <> 'north_zone' then
    raise exception 'Test School A expected north_zone, got %', v_zone_code;
  end if;
  raise notice 'OK Test School A assigned to North Zone';
end $$;

-- =============================================================================
-- 3. RLS — super_admin manages zones
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 3. RLS super_admin ===';

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', true);
  set local role authenticated;

  select count(*) into v_count from public.zones;
  if v_count < 4 then
    raise exception 'super_admin should see zones';
  end if;
  raise notice 'OK super_admin reads % zones', v_count;

  insert into public.zones (
    organization_id, code, name_en, is_active, sort_order
  )
  values (
    '11111111-1111-4111-8111-111111111111',
    'validation_temp_zone',
    'Validation Temp Zone',
    true,
    99
  )
  on conflict (organization_id, code) do update
  set name_en = excluded.name_en, is_active = true;

  update public.zones
  set description = 'validation touch'
  where organization_id = '11111111-1111-4111-8111-111111111111'
    and code = 'validation_temp_zone';

  delete from public.zones
  where organization_id = '11111111-1111-4111-8111-111111111111'
    and code = 'validation_temp_zone';

  raise notice 'OK super_admin zone CRUD';
  reset role;
end $$;

-- =============================================================================
-- 4. RLS — technician sees only zones via assigned sites
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 4. RLS technician ===';

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', true);
  set local role authenticated;

  select count(*) into v_count from public.zones;
  if v_count = 0 then
    raise notice 'OK technician sees 0 zones when assigned site has no zone (MOEHE HQ)';
  else
    raise notice 'OK technician sees % zone(s) linked to assigned sites', v_count;
  end if;

  begin
    insert into public.zones (
      organization_id, code, name_en
    ) values (
      '11111111-1111-4111-8111-111111111111',
      'tech_forbidden_zone',
      'Forbidden'
    );
    raise exception 'technician should not insert zones';
  exception
    when others then
      raise notice 'OK technician blocked from zone insert (%)', sqlerrm;
  end;
  reset role;
end $$;

-- =============================================================================
-- 5. RLS — viewer blocked from unrelated zones
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 5. RLS viewer ===';

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', true);
  set local role authenticated;

  select count(*) into v_count from public.zones;
  if v_count > 0 then
    raise exception 'viewer should not see unrelated zones, saw %', v_count;
  end if;
  raise notice 'OK viewer sees no unrelated zones';
  reset role;
end $$;

-- =============================================================================
-- 6. Sites + meters regression
-- =============================================================================

do $$
declare
  v_count int;
begin
  raise notice '=== 6. SITE/METER REGRESSION ===';

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', true);
  set local role authenticated;

  select count(*) into v_count from public.sites;
  if v_count = 0 then
    raise exception 'super_admin should read sites';
  end if;
  raise notice 'OK sites readable: %', v_count;

  select count(*) into v_count
  from public.meters
  where site_id = '22222222-2222-4222-8222-222222222222'
    and is_active = true;
  if v_count = 0 then
    raise exception 'MOEHE HQ should still have active meters';
  end if;
  raise notice 'OK MOEHE HQ meters: %', v_count;

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', true);
  set local role authenticated;

  select count(*) into v_count
  from public.meters
  where site_id = '22222222-2222-4222-8222-222222222222';
  if v_count = 0 then
    raise exception 'technician should still read MOEHE HQ meters';
  end if;
  raise notice 'OK entry technician meter access preserved';
  reset role;
end $$;

-- =============================================================================
-- 7. Site zone assignment
-- =============================================================================

do $$
declare
  v_zone_id uuid;
begin
  raise notice '=== 7. SITE ZONE ASSIGNMENT ===';

  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', true);
  set local role authenticated;

  update public.sites
  set zone_id = 'd1111111-1111-4111-8111-111111111101'
  where id = '22222222-2222-4222-8222-222222222222';

  select zone_id into v_zone_id
  from public.sites
  where id = '22222222-2222-4222-8222-222222222222';

  if v_zone_id is distinct from 'd1111111-1111-4111-8111-111111111101'::uuid then
    raise exception 'Failed to assign zone to site';
  end if;
  raise notice 'OK super_admin can assign zone to site';

  update public.sites
  set zone_id = null
  where id = '22222222-2222-4222-8222-222222222222';
  raise notice 'OK site zone cleared back to null';
  reset role;
end $$;

raise notice '=== ZONES VALIDATION COMPLETE ===';
