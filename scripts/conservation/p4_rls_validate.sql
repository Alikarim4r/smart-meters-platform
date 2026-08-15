-- Phase 4 RLS: confirmed_cause authority, M&V, tariffs, action costs.
-- Cleans fixtures. Does not permanently mutate meter_readings.
do $$
declare
  v_viewer uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  v_tech uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_site_admin uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  v_super uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddd01';
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_out uuid := 'b82f2bb2-b85c-472e-b6e3-69c1ac97c1fb';
  v_opp uuid;
  v_inv uuid;
  v_act uuid;
  v_baseline uuid;
  v_mv uuid;
  v_tariff uuid;
  v_ok boolean;
  v_readings int;
  v_flags_on int;
begin
  select count(*) into v_readings from meter_readings;
  select count(*) into v_flags_on from conservation_feature_flags where enabled = true;

  reset role;
  delete from conservation_measurement_verifications where notes like 'p4_rls_%';
  delete from utility_tariffs where source_notes like 'p4_rls_%';
  delete from conservation_actions where title like 'p4_rls_%';
  delete from conservation_investigations where notes like 'p4_rls_%' or finding_summary like 'p4_rls_%';
  delete from conservation_opportunities where title like 'p4_rls_%';
  -- baselines may be shared; only delete if we created p4_rls labeled
  delete from conservation_baselines where notes like 'p4_rls_%' or label like 'p4_rls_%';

  -- Fixture setup as login role (bypass RLS for test scaffolding)
  reset role;

  insert into conservation_baselines (
    site_id, scope_type, version_number, label,
    reference_period_start, reference_period_end,
    calculation_method, baseline_value, unit_code, status,
    notes, created_by, approved_by, approved_at,
    data_completeness, confidence_score, boundary_quality
  ) values (
    v_hq, 'site', 9001, 'p4_rls_baseline',
    current_date - 60, current_date - 31,
    'total_period', 1000, 'm3', 'approved',
    'p4_rls_baseline', v_super, v_super, now(),
    1.0, 95, 'exact_pre_period'
  ) returning id into v_baseline;

  insert into conservation_opportunities (
    site_id, utility_type, origin, source_type, source_fingerprint,
    title, description, detected_period_start, detected_period_end,
    unit_code, estimated_waste_quantity, confidence_score, priority, status,
    created_by
  ) values (
    v_hq, 'water', 'manual', 'manual', 'p4_rls_fp',
    'p4_rls_opp', 'Potential excess', current_date - 30, current_date,
    'm3', 100, 90, 'high', 'monitoring', v_super
  ) returning id into v_opp;

  insert into conservation_investigations (
    opportunity_id, site_id, assigned_to, assigned_by, assigned_at,
    investigation_status, notes, created_by
  ) values (
    v_opp, v_hq, v_tech, v_super, now(),
    'assigned', 'p4_rls_inv', v_super
  ) returning id into v_inv;

  insert into conservation_actions (
    opportunity_id, investigation_id, site_id, title, action_type,
    owner_id, priority, status, created_by,
    completed_at, completion_notes,
    implementation_cost, cost_currency, cost_source
  ) values (
    v_opp, v_inv, v_hq, 'p4_rls_action', 'repair_leak',
    v_tech, 'high', 'completed', v_super,
    now(), 'p4_rls done',
    500, 'QAR', 'invoice'
  ) returning id into v_act;

  insert into utility_tariffs (
    organization_id, site_id, utility_type, rate, currency, unit_code,
    effective_from, status, source_notes, created_by
  )
  select s.organization_id, v_hq, 'water', 5.5, 'QAR', 'm3',
         current_date - 365, 'active', 'p4_rls_tariff', v_super
  from sites s where s.id = v_hq
  returning id into v_tariff;

  insert into conservation_measurement_verifications (
    site_id, opportunity_id, action_id, baseline_id, utility_type,
    verification_method, pre_period_start, pre_period_end,
    post_period_start, post_period_end, baseline_value, actual_post_value,
    estimated_saving_quantity, unit_code, data_completeness, confidence_score,
    status, notes, created_by, estimated_at
  ) values (
    v_hq, v_opp, v_act, v_baseline, 'water',
    'baseline_comparison', current_date - 60, current_date - 31,
    current_date - 30, current_date, 1000, 730,
    270, 'm3', 0.96, 93,
    'estimated', 'p4_rls_mv', v_super, now()
  ) returning id into v_mv;

  -- Begin role impersonation tests
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  update conservation_investigations
    set proposed_cause = 'operational_usage', finding_summary = 'p4_rls_finding'
  where id = v_inv;
  if not found then raise exception 'RLS FAIL tech cannot set proposed_cause'; end if;

  begin
    update conservation_investigations
      set confirmed_cause = 'confirmed_leak',
          confirmed_by = v_tech,
          confirmed_at = now()
    where id = v_inv;
    raise exception 'RLS FAIL tech set confirmed_cause';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;

  -- TECH cannot verify M&V
  begin
    update conservation_measurement_verifications
      set status = 'verification_pending'
    where id = v_mv;
    -- may or may not allow status bump; verify to verified must fail
    update conservation_measurement_verifications
      set status = 'verified',
          verified_saving_quantity = 270,
          verified_by = v_tech,
          verified_at = now()
    where id = v_mv;
    if found then
      -- if update appeared to work under RLS, still check authority trigger/policy
      null;
    end if;
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;

  -- Re-check: if still not verified as tech, good. If verified, FAIL.
  select status = 'verified' into v_ok
  from conservation_measurement_verifications where id = v_mv;
  if v_ok then raise exception 'RLS FAIL tech verified M&V'; end if;

  -- TECH cannot insert tariff
  begin
    insert into utility_tariffs (
      organization_id, utility_type, rate, currency, unit_code,
      effective_from, status, source_notes
    )
    select organization_id, 'water', 1, 'QAR', 'm3', current_date, 'active', 'p4_rls_tech'
    from sites where id = v_hq;
    raise exception 'RLS FAIL tech inserted tariff';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- VIEWER: select MV, no write
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  set local role authenticated;
  select exists(select 1 from conservation_measurement_verifications where id = v_mv) into v_ok;
  if not v_ok then raise exception 'RLS FAIL viewer cannot see MV'; end if;
  begin
    update conservation_measurement_verifications set notes = 'hack' where id = v_mv;
    if found then raise exception 'RLS FAIL viewer updated MV'; end if;
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- SITE ADMIN: confirm cause + verify path
  perform set_config('request.jwt.claim.sub', v_site_admin::text, true);
  set local role authenticated;
  update conservation_investigations
    set confirmed_cause = 'operational_usage',
        confirmed_by = v_site_admin,
        confirmed_at = now()
  where id = v_inv;
  if not found then raise exception 'RLS FAIL site_admin cannot confirm cause'; end if;

  update conservation_measurement_verifications
    set status = 'verification_pending'
  where id = v_mv;
  update conservation_measurement_verifications
    set status = 'verified',
        verified_saving_quantity = 270,
        verified_by = v_site_admin,
        verified_at = now(),
        tariff_id = v_tariff,
        cost_avoided = 1485,
        cost_currency = 'QAR'
  where id = v_mv;
  if not found then raise exception 'RLS FAIL site_admin cannot verify MV'; end if;

  -- Out-of-scope site denied for tariff/MV insert
  begin
    insert into conservation_measurement_verifications (
      site_id, opportunity_id, baseline_id, utility_type, verification_method,
      pre_period_start, pre_period_end, post_period_start, post_period_end,
      baseline_value, unit_code, confidence_score, status, notes, created_by
    ) values (
      v_out, v_opp, v_baseline, 'water', 'baseline_comparison',
      current_date - 10, current_date - 5, current_date - 4, current_date,
      1, 'm3', 80, 'draft', 'p4_rls_oos', v_site_admin
    );
    raise exception 'RLS FAIL site_admin inserted out-of-scope MV';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- Cleanup
  delete from conservation_measurement_verifications where id = v_mv or notes like 'p4_rls_%';
  delete from utility_tariffs where id = v_tariff or source_notes like 'p4_rls_%';
  delete from conservation_actions where id = v_act;
  delete from conservation_investigations where id = v_inv;
  delete from conservation_opportunities where id = v_opp;
  delete from conservation_baselines where id = v_baseline;

  if (select count(*) from meter_readings) <> v_readings then
    raise exception 'RLS FAIL meter_readings mutated';
  end if;
  if (select count(*) from conservation_feature_flags where enabled = true) <> v_flags_on then
    raise exception 'RLS FAIL flags changed';
  end if;

  raise notice 'P4_RLS_RESULT=PASS';
end $$;
