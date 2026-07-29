-- P1C RLS validation for conservation_targets
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
begin
  delete from public.conservation_targets where unit_code = 'p1c_rls_probe';

  insert into public.conservation_targets
    (site_id, scope_type, period_type, period_start, period_end,
     target_value, unit_code, version, status)
  values
    (v_hq, 'site', 'monthly', '2026-07-01', '2026-07-31', 100, 'p1c_rls_probe', 1, 'active'),
    (v_ali, 'site', 'monthly', '2026-07-01', '2026-07-31', 100, 'p1c_rls_probe', 1, 'active'),
    (v_arwa, 'site', 'monthly', '2026-07-01', '2026-07-31', 100, 'p1c_rls_probe', 1, 'draft');

  -- VIEWER: HQ yes, Ali no
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  set local role authenticated;
  select exists(select 1 from conservation_targets where site_id = v_hq and unit_code='p1c_rls_probe') into v_ok;
  if not v_ok then raise exception 'RLS FAIL viewer cannot see HQ target'; end if;
  select exists(select 1 from conservation_targets where site_id = v_ali and unit_code='p1c_rls_probe') into v_ok;
  if v_ok then raise exception 'RLS FAIL viewer saw Ali target'; end if;
  begin
    insert into conservation_targets
      (site_id, scope_type, period_type, period_start, period_end, target_value, unit_code, version, status)
    values (v_hq, 'site', 'monthly', '2026-08-01', '2026-08-31', 1, 'p1c_rls_probe', 1, 'draft');
    raise exception 'RLS FAIL viewer inserted';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- TECH: cannot write
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  update conservation_targets set target_value = 999
  where site_id = v_hq and unit_code = 'p1c_rls_probe' and status = 'active';
  get diagnostics v_updated = row_count;
  if v_updated > 0 then raise exception 'RLS FAIL tech updated target'; end if;
  reset role;

  -- SITE ADMIN: can insert draft on HQ; not on Arwa
  perform set_config('request.jwt.claim.sub', v_site_admin::text, true);
  set local role authenticated;
  insert into conservation_targets
    (site_id, scope_type, period_type, period_start, period_end, target_value, unit_code, version, status)
  values (v_hq, 'site', 'annual', '2026-01-01', '2026-12-31', 1000, 'p1c_rls_probe', 1, 'draft');
  begin
    insert into conservation_targets
      (site_id, scope_type, period_type, period_start, period_end, target_value, unit_code, version, status)
    values (v_arwa, 'site', 'annual', '2026-01-01', '2026-12-31', 1000, 'p1c_rls_probe', 2, 'draft');
    -- may fail RLS
  exception when others then null;
  end;
  reset role;
  if exists (
    select 1 from conservation_targets
    where site_id = v_arwa and unit_code = 'p1c_rls_probe' and period_type = 'annual'
  ) then
    raise exception 'RLS FAIL site_admin wrote Arwa annual target';
  end if;

  -- SUPER ADMIN sees all probe rows
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;
  if (select count(*) from conservation_targets where unit_code = 'p1c_rls_probe') < 3 then
    raise exception 'RLS FAIL super_admin visibility';
  end if;
  reset role;

  delete from public.conservation_targets where unit_code = 'p1c_rls_probe';
end;
$$;

select 'P1C_RLS_RESULT=PASS' as result,
       (select count(*)::int from conservation_targets) as remaining_targets,
       (select coalesce(bool_or(enabled), false) from conservation_feature_flags) as any_flag_on;
