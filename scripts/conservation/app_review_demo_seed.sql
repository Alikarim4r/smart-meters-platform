-- =============================================================================
-- APP REVIEW DEMO SEED (Staging) — tagged APP_REVIEW_DEMO
-- Site: MOEHE HQ 22222222-2222-4222-8222-222222222222
-- Org:  11111111-1111-4111-8111-111111111111
-- Does NOT modify meter_readings.
-- =============================================================================

do $$
declare
  v_org uuid := '11111111-1111-4111-8111-111111111111';
  v_site uuid := '22222222-2222-4222-8222-222222222222';
  v_meter uuid := '33333333-3333-4333-8333-333333333301';
  v_meter2 uuid := '7e01e663-cf5e-4d6b-a7e0-901a2e557a49';
  v_super uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddd01';
  v_vm uuid := 'a1111111-1111-4111-8111-1111111111d1';
  v_bg uuid;
  v_target uuid;
  v_baseline uuid;
  v_opp uuid;
  v_inv uuid;
  v_action uuid;
  v_evid uuid;
  v_tariff uuid;
  v_mv_est uuid;
  v_mv_ver uuid;
  v_persist uuid;
  v_ef uuid;
  v_carbon uuid;
  v_forecast uuid;
  v_batch uuid;
  v_readings int;
begin
  select count(*) into v_readings from meter_readings;

  -- ---------- cleanup prior demo ----------
  delete from conservation_carbon_results
    where lineage->>'demo_tag' = 'APP_REVIEW_DEMO';
  delete from conservation_saving_persistence
    where lineage->>'demo_tag' = 'APP_REVIEW_DEMO';
  delete from conservation_measurement_verifications
    where notes like 'APP_REVIEW_DEMO%';
  delete from conservation_evidence
    where notes like 'APP_REVIEW_DEMO%' or title like 'APP_REVIEW_DEMO%';
  delete from conservation_actions
    where completion_notes like 'APP_REVIEW_DEMO%' or title like 'APP_REVIEW_DEMO%';
  delete from conservation_investigations
    where notes like 'APP_REVIEW_DEMO%' or finding_summary like 'APP_REVIEW_DEMO%';
  delete from conservation_opportunities
    where source_fingerprint like 'app_review_demo%' or title like 'APP_REVIEW_DEMO%';
  delete from conservation_balance_group_members bgm
    using conservation_balance_groups bg
    where bgm.balance_group_id = bg.id and bg.notes like 'APP_REVIEW_DEMO%';
  delete from conservation_balance_groups where notes like 'APP_REVIEW_DEMO%';
  delete from conservation_virtual_meter_members
    where virtual_meter_id = v_vm;
  delete from meters where id = v_vm or meter_code = 'APP_REVIEW_DEMO_VM';
  delete from conservation_baselines where notes like 'APP_REVIEW_DEMO%';
  delete from conservation_targets
    where created_by = v_super
      and site_id = v_site
      and unit_code = 'm3'
      and period_type = 'monthly'
      and target_value = 999001.0000; -- demo sentinel
  -- safer target cleanup via notes if column exists — use sentinel value above only for insert tag
  delete from utility_tariffs where source_notes like 'APP_REVIEW_DEMO%';
  delete from emission_factors where notes like 'APP_REVIEW_DEMO%' or source like 'APP_REVIEW_DEMO%';
  delete from conservation_forecast_results
    where lineage->>'demo_tag' = 'APP_REVIEW_DEMO';
  delete from conservation_portfolio_summaries
    where lineage->>'demo_tag' = 'APP_REVIEW_DEMO';
  delete from import_batch_rows ibr
    using import_batches ib
    where ibr.batch_id = ib.id and ib.file_name like 'APP_REVIEW_DEMO%';
  delete from import_batches where file_name like 'APP_REVIEW_DEMO%';
  delete from site_conservation_profiles
    where profile_notes like 'APP_REVIEW_DEMO%';

  -- ---------- Virtual meter (additive meters row) ----------
  insert into meters (
    id, site_id, meter_code, name_en, name_ar,
    category_id, source_id, unit_id, level,
    meter_kind, calculation_type, unit_to_base_factor, base_unit,
    meter_multiplier, is_active, include_in_dashboard, sort_order
  ) values (
    v_vm, v_site, 'APP_REVIEW_DEMO_VM',
    'APP_REVIEW_DEMO Virtual Sum', 'عداد افتراضي تجريبي',
    'c1111111-1111-4111-8111-111111111101',
    'b1111111-1111-4111-8111-111111111101',
    'e1111111-1111-4111-8111-111111111101',
    'main',
    'virtual', 'sum_children', 1, 'm3',
    1, true, true, 9990
  );

  insert into conservation_virtual_meter_members (virtual_meter_id, member_meter_id)
  values (v_vm, v_meter), (v_vm, v_meter2);

  -- ---------- Target ----------
  insert into conservation_targets (
    site_id, scope_type, period_type, period_start, period_end,
    target_value, unit_code, version, status, created_by
  ) values (
    v_site, 'site', 'monthly', date_trunc('month', current_date)::date,
    (date_trunc('month', current_date) + interval '1 month - 1 day')::date,
    999001.0000, 'm3', 1, 'active', v_super
  ) returning id into v_target;

  -- ---------- Approved baseline ----------
  insert into conservation_baselines (
    site_id, scope_type, utility_code, version_number, label,
    reference_period_start, reference_period_end, calculation_method,
    baseline_value, unit_code, status, valid_from,
    created_by, approved_by, approved_at, notes,
    data_completeness, confidence_score, boundary_quality
  ) values (
    v_site, 'site', 'water', 1, 'APP_REVIEW_DEMO Baseline',
    (current_date - 90), (current_date - 60), 'total_period',
    12000, 'm3', 'approved', current_date - 30,
    v_super, v_super, now(), 'APP_REVIEW_DEMO approved baseline',
    0.95, 80, 'exact_pre_period'
  ) returning id into v_baseline;

  -- ---------- Balance group ----------
  insert into conservation_balance_groups (
    site_id, name, utility_code, unit_code, main_meter_id, status, notes, created_by
  ) values (
    v_site, 'APP_REVIEW_DEMO Water Balance', 'water', 'm3', v_meter, 'active',
    'APP_REVIEW_DEMO balance group', v_super
  ) returning id into v_bg;

  insert into conservation_balance_group_members (balance_group_id, member_meter_id)
  values (v_bg, v_meter2);

  -- ---------- Opportunity (anomaly-like source) ----------
  insert into conservation_opportunities (
    site_id, meter_id, balance_group_id, utility_type, origin, source_type,
    source_fingerprint, title, description,
    detected_period_start, detected_period_end, unit_code,
    estimated_waste_quantity, confidence_score, priority, status,
    source_snapshot, created_by
  ) values (
    v_site, v_meter, v_bg, 'water', 'manual', 'periodic_anomaly',
    'app_review_demo_opp_v1',
    'APP_REVIEW_DEMO High consumption opportunity',
    'Demo Potential Excess for UI review — not a Verified Saving.',
    current_date - 30, current_date - 1, 'm3',
    250, 78, 'high', 'under_investigation',
    jsonb_build_object('demo_tag', 'APP_REVIEW_DEMO'),
    v_super
  ) returning id into v_opp;

  -- ---------- Investigation ----------
  insert into conservation_investigations (
    opportunity_id, site_id, investigation_status, finding_summary,
    possible_cause, notes, created_by, investigation_started_at
  ) values (
    v_opp, v_site, 'in_progress',
    'APP_REVIEW_DEMO investigation in progress',
    'Check valves and night flow',
    'APP_REVIEW_DEMO investigation',
    v_super, now()
  ) returning id into v_inv;

  -- ---------- Action ----------
  insert into conservation_actions (
    opportunity_id, investigation_id, site_id, title, description,
    action_type, priority, status, completion_notes, created_by
  ) values (
    v_opp, v_inv, v_site,
    'APP_REVIEW_DEMO Repair valve',
    'Demo action — human review required',
    'repair_leak', 'high', 'open',
    'APP_REVIEW_DEMO action',
    v_super
  ) returning id into v_action;

  -- ---------- Evidence ----------
  insert into conservation_evidence (
    site_id, opportunity_id, investigation_id, action_id,
    evidence_kind, evidence_phase, title, notes, uploaded_by
  ) values (
    v_site, v_opp, v_inv, v_action,
    'note', 'general',
    'APP_REVIEW_DEMO evidence note',
    'APP_REVIEW_DEMO evidence — no storage object',
    v_super
  ) returning id into v_evid;

  -- ---------- Tariff ----------
  insert into utility_tariffs (
    organization_id, site_id, utility_type, rate, currency, unit_code,
    effective_from, status, source_notes, created_by
  ) values (
    v_org, v_site, 'water', 5.5, 'QAR', 'm3',
    current_date - 365, 'active', 'APP_REVIEW_DEMO tariff', v_super
  ) returning id into v_tariff;

  -- ---------- Estimated M&V ----------
  insert into conservation_measurement_verifications (
    site_id, opportunity_id, action_id, baseline_id, target_id, meter_id,
    utility_type, verification_method, pre_period_start, pre_period_end,
    post_period_start, post_period_end, baseline_value, actual_post_value,
    estimated_saving_quantity, unit_code, confidence_score, status,
    tariff_id, cost_avoided, cost_currency, notes, created_by, estimated_at
  ) values (
    v_site, v_opp, v_action, v_baseline, v_target, v_meter,
    'water', 'before_after_period',
    current_date - 90, current_date - 60,
    current_date - 30, current_date - 1,
    12000, 11000, 1000, 'm3', 75, 'estimated',
    v_tariff, 5500, 'QAR',
    'APP_REVIEW_DEMO estimated M&V', v_super, now()
  ) returning id into v_mv_est;

  -- ---------- Verified M&V ----------
  insert into conservation_measurement_verifications (
    site_id, opportunity_id, action_id, baseline_id, target_id, meter_id,
    utility_type, verification_method, calculation_version,
    pre_period_start, pre_period_end, post_period_start, post_period_end,
    baseline_value, actual_post_value, estimated_saving_quantity,
    verified_saving_quantity, unit_code, confidence_score, status,
    tariff_id, cost_avoided, cost_currency, notes, created_by,
    estimated_at, verified_by, verified_at
  ) values (
    v_site, v_opp, v_action, v_baseline, v_target, v_meter,
    'water', 'before_after_period', 2,
    current_date - 90, current_date - 60,
    current_date - 30, current_date - 1,
    12000, 11100, 900, 850, 'm3', 82, 'verified',
    v_tariff, 4675, 'QAR',
    'APP_REVIEW_DEMO verified M&V', v_super,
    now(), v_super, now()
  ) returning id into v_mv_ver;

  -- ---------- Persistence ----------
  insert into conservation_saving_persistence (
    site_id, measurement_verification_id, follow_up_window,
    follow_up_start, follow_up_end, expected_reference_consumption,
    actual_consumption, sustained_quantity, persistence_pct,
    data_completeness, confidence_score, status, lineage, created_by
  ) values (
    v_site, v_mv_ver, '1m',
    current_date - 30, current_date - 1, 11100,
    11200, 750, 88.2,
    0.9, 70, 'sustained',
    jsonb_build_object('demo_tag', 'APP_REVIEW_DEMO'),
    v_super
  ) returning id into v_persist;

  -- ---------- Emission factor + carbon ----------
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  insert into emission_factors (
    organization_id, utility_or_fuel_type, geography, factor, unit_code,
    source, effective_from, status, notes, created_by, approved_by, approved_at
  ) values (
    v_org, 'water_related', 'QA', 0.12, 'm3',
    'APP_REVIEW_DEMO factor', current_date - 30, 'active',
    'APP_REVIEW_DEMO emission factor', v_super, v_super, now()
  ) returning id into v_ef;
  perform set_config('request.jwt.claim.sub', '', true);

  insert into conservation_carbon_results (
    site_id, measurement_verification_id, quantity_basis, saving_quantity,
    emission_factor_id, factor_value_snapshot, factor_source_snapshot,
    factor_effective_from_snapshot, carbon_avoided, carbon_unit, status,
    lineage, created_by
  ) values (
    v_site, v_mv_ver, 'verified_saving', 850,
    v_ef, 0.12, 'APP_REVIEW_DEMO factor',
    current_date - 30, 102.0, 'kgCO2e', 'computed',
    jsonb_build_object('demo_tag', 'APP_REVIEW_DEMO'),
    v_super
  ) returning id into v_carbon;

  -- ---------- Forecast ----------
  insert into conservation_forecast_results (
    site_id, utility_type, forecast_horizon, method, history_length,
    expected_value, expected_low, expected_high, target_value,
    confidence, status, lineage, created_by, warnings
  ) values (
    v_site, 'water', 'month_end', 'run_rate', 12,
    10500, 9800, 11200, 999001,
    'medium', 'computed',
    jsonb_build_object('demo_tag', 'APP_REVIEW_DEMO'),
    v_super,
    '["APP_REVIEW_DEMO forecast"]'::jsonb
  ) returning id into v_forecast;

  -- ---------- Portfolio summary (site scope) ----------
  delete from conservation_portfolio_summaries
    where organization_id = v_org and site_id = v_site and scope_level = 'site'
      and lineage->>'demo_tag' = 'APP_REVIEW_DEMO';
  insert into conservation_portfolio_summaries (
    organization_id, site_id, scope_level, period_start, period_end,
    verified_savings_total, cost_avoided_total, cost_currency,
    carbon_avoided_total, carbon_unit, open_opportunities,
    lineage
  ) values (
    v_org, v_site, 'site', current_date - 30, current_date,
    850, 4675, 'QAR', 102.0, 'kgCO2e', 1,
    jsonb_build_object('demo_tag', 'APP_REVIEW_DEMO')
  );

  -- ---------- Import preview batch ----------
  insert into import_batches (
    organization_id, site_id, source_type, file_name, file_fingerprint,
    status, dry_run, rows_total, rows_accepted, rows_rejected,
    imported_by, column_mapping
  ) values (
    v_org, v_site, 'csv_import', 'APP_REVIEW_DEMO_preview.csv',
    'app_review_demo_fp_v1',
    'preview', true, 2, 1, 1,
    v_super,
    '{"meter_code":"meter_code","reading_date":"reading_date","raw_value":"raw_value"}'::jsonb
  ) returning id into v_batch;

  insert into import_batch_rows (
    batch_id, row_number, raw_payload, resolved_meter_id, resolved_site_id,
    reading_date, raw_value, unit_code, status, error_code, error_message
  ) values
  (v_batch, 2, '{"meter_code":"1219053"}'::jsonb, v_meter, v_site,
   current_date - 2, 100, 'm3', 'accepted', null, null),
  (v_batch, 3, '{"meter_code":"UNKNOWN"}'::jsonb, null, null,
   null, null, null, 'rejected', 'unknown_meter', 'APP_REVIEW_DEMO row error');

  -- ---------- Site conservation profile ----------
  insert into site_conservation_profiles (
    site_id, floor_area_m2, occupancy_count, peer_group, profile_notes, updated_by
  ) values (
    v_site, 12345.67, 500, 'administrative', 'APP_REVIEW_DEMO profile', v_super
  )
  on conflict (site_id) do update
    set floor_area_m2 = excluded.floor_area_m2,
        occupancy_count = excluded.occupancy_count,
        peer_group = excluded.peer_group,
        profile_notes = excluded.profile_notes,
        updated_by = excluded.updated_by,
        updated_at = now();

  if (select count(*) from meter_readings) <> v_readings then
    raise exception 'PROTECTED: meter_readings count changed during demo seed';
  end if;

  raise notice 'APP_REVIEW_DEMO seed OK target=% baseline=% opp=% mv_est=% mv_ver=% batch=% readings=%',
    v_target, v_baseline, v_opp, v_mv_est, v_mv_ver, v_batch, v_readings;
end $$;

-- Summary
select 'targets' as entity, count(*) as n from conservation_targets where target_value = 999001.0000
union all select 'baselines', count(*) from conservation_baselines where notes like 'APP_REVIEW_DEMO%'
union all select 'virtual_meters', count(*) from meters where meter_code = 'APP_REVIEW_DEMO_VM'
union all select 'balance_groups', count(*) from conservation_balance_groups where notes like 'APP_REVIEW_DEMO%'
union all select 'opportunities', count(*) from conservation_opportunities where source_fingerprint like 'app_review_demo%'
union all select 'investigations', count(*) from conservation_investigations where notes like 'APP_REVIEW_DEMO%'
union all select 'actions', count(*) from conservation_actions where completion_notes like 'APP_REVIEW_DEMO%' or title like 'APP_REVIEW_DEMO%'
union all select 'evidence', count(*) from conservation_evidence where notes like 'APP_REVIEW_DEMO%'
union all select 'tariffs', count(*) from utility_tariffs where source_notes like 'APP_REVIEW_DEMO%'
union all select 'mv', count(*) from conservation_measurement_verifications where notes like 'APP_REVIEW_DEMO%'
union all select 'persistence', count(*) from conservation_saving_persistence where lineage->>'demo_tag' = 'APP_REVIEW_DEMO'
union all select 'emission_factors', count(*) from emission_factors where notes like 'APP_REVIEW_DEMO%'
union all select 'carbon', count(*) from conservation_carbon_results where lineage->>'demo_tag' = 'APP_REVIEW_DEMO'
union all select 'forecasts', count(*) from conservation_forecast_results where lineage->>'demo_tag' = 'APP_REVIEW_DEMO'
union all select 'import_batches', count(*) from import_batches where file_name like 'APP_REVIEW_DEMO%'
union all select 'meter_readings', count(*) from meter_readings;
