-- P1D RLS + versioning + immutability validation for conservation_baselines
do $$
declare
  v_viewer uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  v_tech uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_site_admin uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  v_super uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddd01';
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_ali uuid := 'e61ac413-2634-46d5-b8dd-f0b5f2f28875';
  v_arwa uuid := '841c5009-959a-4cac-8f42-4efc3cbb517e';
  v_ok boolean;
  v_updated int;
  v_id uuid;
  v_id2 uuid;
  v_ver1 int;
  v_targets_before int;
  v_status text;
begin
  select count(*) into v_targets_before from public.conservation_targets;
  delete from public.conservation_baselines where unit_code = 'p1d_rls_probe';

  -- Seed as super_admin (insert policy requires draft — seed approved via super then update)
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;

  insert into public.conservation_baselines
    (site_id, scope_type, version_number, label, reference_period_start, reference_period_end,
     calculation_method, baseline_value, unit_code, status, boundary_quality,
     data_completeness, confidence_score)
  values
    (v_hq, 'site', 1, 'hq-v1', '2026-01-01', '2026-01-31', 'total_period', 100, 'p1d_rls_probe', 'draft',
     'exact_pre_period', 1.0, 90)
  returning id into v_id;

  update public.conservation_baselines
    set status = 'approved', valid_from = '2026-01-01', approved_by = v_super, approved_at = now()
  where id = v_id;

  insert into public.conservation_baselines
    (site_id, scope_type, version_number, label, reference_period_start, reference_period_end,
     calculation_method, baseline_value, unit_code, status, boundary_quality,
     data_completeness, confidence_score)
  values
    (v_ali, 'site', 1, 'ali-v1', '2026-01-01', '2026-01-31', 'total_period', 100, 'p1d_rls_probe', 'draft',
     'exact_pre_period', 1.0, 90);

  reset role;

  -- VIEWER
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  set local role authenticated;
  select exists(select 1 from conservation_baselines where site_id = v_hq and unit_code='p1d_rls_probe') into v_ok;
  if not v_ok then raise exception 'RLS FAIL viewer cannot see HQ baseline'; end if;
  select exists(select 1 from conservation_baselines where site_id = v_ali and unit_code='p1d_rls_probe') into v_ok;
  if v_ok then raise exception 'RLS FAIL viewer saw Ali baseline'; end if;
  begin
    insert into conservation_baselines
      (site_id, scope_type, version_number, label, reference_period_start, reference_period_end,
       calculation_method, baseline_value, unit_code, status)
    values (v_hq, 'site', 99, 'x', '2026-02-01', '2026-02-28', 'total_period', 1, 'p1d_rls_probe', 'draft');
    raise exception 'RLS FAIL viewer inserted';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- TECH: cannot write
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  update conservation_baselines set notes = 'hack'
  where site_id = v_hq and unit_code = 'p1d_rls_probe' and status = 'approved';
  get diagnostics v_updated = row_count;
  if v_updated > 0 then raise exception 'RLS FAIL tech updated baseline'; end if;
  begin
    insert into conservation_baselines
      (site_id, scope_type, version_number, label, reference_period_start, reference_period_end,
       calculation_method, baseline_value, unit_code, status)
    values (v_hq, 'site', 98, 'tech', '2026-02-01', '2026-02-28', 'total_period', 1, 'p1d_rls_probe', 'draft');
    raise exception 'RLS FAIL tech inserted';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- SITE ADMIN: draft on HQ ok; Arwa out of scope fail
  perform set_config('request.jwt.claim.sub', v_site_admin::text, true);
  set local role authenticated;
  insert into conservation_baselines
    (site_id, scope_type, version_number, label, reference_period_start, reference_period_end,
     calculation_method, baseline_value, unit_code, status, boundary_quality,
     data_completeness, confidence_score)
  values
    (v_hq, 'site', 2, 'hq-draft', '2026-02-01', '2026-02-28', 'total_period', 110, 'p1d_rls_probe', 'draft',
     'exact_pre_period', 1.0, 90)
  returning id into v_id2;

  begin
    insert into conservation_baselines
      (site_id, scope_type, version_number, label, reference_period_start, reference_period_end,
       calculation_method, baseline_value, unit_code, status)
    values (v_arwa, 'site', 1, 'arwa', '2026-02-01', '2026-02-28', 'total_period', 1, 'p1d_rls_probe', 'draft');
    raise exception 'RLS FAIL site_admin inserted Arwa baseline';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;

  -- Approve V2: supersede V1
  update conservation_baselines
    set status = 'superseded', valid_to = '2026-02-28'
  where id = v_id and status = 'approved';
  update conservation_baselines
    set status = 'approved', valid_from = '2026-03-01', approved_by = v_site_admin, approved_at = now()
  where id = v_id2;
  select status into v_status from conservation_baselines where id = v_id;
  if v_status <> 'superseded' then raise exception 'FAIL V1 not superseded'; end if;
  select status into v_status from conservation_baselines where id = v_id2;
  if v_status <> 'approved' then raise exception 'FAIL V2 not approved'; end if;

  -- Immutability: cannot change baseline_value on approved
  begin
    update conservation_baselines set baseline_value = 999 where id = v_id2;
    raise exception 'FAIL immutable baseline_value updated';
  exception when others then
    if sqlerrm like 'FAIL immutable%' then raise; end if;
  end;

  -- Version allocator
  select public.conservation_baselines_next_version(v_hq, 'site', null, 'p1d_rls_probe') into v_ver1;
  if v_ver1 < 3 then raise exception 'FAIL next_version expected >=3 got %', v_ver1; end if;

  -- Unique version constraint
  begin
    insert into conservation_baselines
      (site_id, scope_type, version_number, label, reference_period_start, reference_period_end,
       calculation_method, baseline_value, unit_code, status)
    values (v_hq, 'site', 2, 'dup', '2026-03-01', '2026-03-31', 'total_period', 1, 'p1d_rls_probe', 'draft');
    raise exception 'FAIL duplicate version allowed';
  exception when others then
    if sqlerrm like 'FAIL duplicate%' then raise; end if;
  end;

  reset role;

  -- SUPER ADMIN can select Ali
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;
  select exists(select 1 from conservation_baselines where site_id = v_ali and unit_code='p1d_rls_probe') into v_ok;
  if not v_ok then raise exception 'RLS FAIL super cannot see Ali'; end if;
  reset role;

  delete from public.conservation_baselines where unit_code = 'p1d_rls_probe';

  if (select count(*) from public.conservation_targets) <> v_targets_before then
    raise exception 'FAIL conservation_targets mutated';
  end if;

  if exists(select 1 from conservation_feature_flags where enabled) then
    raise exception 'FAIL feature flag enabled';
  end if;

  raise notice 'P1D_RLS_RESULT=PASS';
end;
$$;

select 'P1D_RLS_RESULT=PASS' as result,
       (select count(*) from conservation_baselines) as remaining_baselines,
       (select count(*) from conservation_targets) as targets_count,
       (select coalesce(bool_or(enabled), false) from conservation_feature_flags) as any_flag_on;
