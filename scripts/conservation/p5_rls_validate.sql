-- Phase 5 RLS: weather / models / emission factors.
-- Fixture setup as bypass role; impersonation via JWT + authenticated.
-- Does not permanently mutate meter_readings.
do $$
declare
  v_viewer uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  v_tech uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_site_admin uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  v_super uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddd01';
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_org uuid;
  v_ds uuid;
  v_model uuid;
  v_ef uuid;
  v_ok boolean;
  v_readings int;
  v_flags_on int;
  v_meters_phys int;
begin
  select count(*) into v_readings from meter_readings;
  select count(*) into v_flags_on from conservation_feature_flags where enabled = true;
  select count(*) into v_meters_phys from meters where meter_kind = 'physical';
  select organization_id into v_org from sites where id = v_hq;

  reset role;
  delete from conservation_normalization_models where notes like 'p5_rls_%';
  delete from conservation_weather_observations where extra::text like '%p5_rls%';
  delete from conservation_weather_datasets where notes like 'p5_rls_%';
  delete from emission_factors where source like 'p5_rls_%';

  insert into conservation_weather_datasets (
    organization_id, site_id, location_label, source, period_start, period_end,
    quality, status, notes, created_by
  ) values (
    v_org, v_hq, 'Doha p5', 'imported_monthly', current_date - 365, current_date,
    'high', 'draft', 'p5_rls_weather', v_super
  ) returning id into v_ds;

  insert into conservation_weather_observations (
    dataset_id, period_start, period_end, cdd, extra
  ) values (
    v_ds, current_date - 31, current_date - 1, 120, '{"p5_rls":true}'::jsonb
  );

  insert into conservation_normalization_models (
    organization_id, site_id, utility_type, weather_sensitive, method,
    training_period_start, training_period_end, dependent_variable,
    weather_variables, weather_dataset_id, sample_count, goodness_of_fit,
    confidence, status, quality_gate_passed, notes, created_by
  ) values (
    v_org, v_hq, 'cooling', true, 'degree_day',
    current_date - 365, current_date, 'kWh',
    array['cdd'], v_ds, 2, 0.2,
    'unreliable', 'draft', false, 'p5_rls_model', v_super
  ) returning id into v_model;

  insert into emission_factors (
    organization_id, utility_or_fuel_type, geography, factor, unit_code,
    source, effective_from, status, notes, created_by
  ) values (
    v_org, 'grid_electricity', 'QA', 0.45, 'kWh',
    'p5_rls_factor', current_date - 30, 'draft', 'p5_rls', v_super
  ) returning id into v_ef;

  -- TECH: cannot approve weather
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  begin
    update conservation_weather_datasets
      set status = 'approved', approved_by = v_tech, approved_at = now()
    where id = v_ds;
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  select status = 'approved' into v_ok from conservation_weather_datasets where id = v_ds;
  if v_ok then raise exception 'FAIL: technician approved weather dataset'; end if;

  -- TECH: cannot activate emission factor
  begin
    update emission_factors
      set status = 'active', approved_by = v_tech, approved_at = now()
    where id = v_ef;
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  select status = 'active' into v_ok from emission_factors where id = v_ef;
  if v_ok then raise exception 'FAIL: technician activated emission factor'; end if;
  reset role;

  -- SITE ADMIN: can approve weather
  perform set_config('request.jwt.claim.sub', v_site_admin::text, true);
  set local role authenticated;
  update conservation_weather_datasets
    set status = 'approved', approved_by = v_site_admin, approved_at = now()
  where id = v_ds;
  select status = 'approved' into v_ok from conservation_weather_datasets where id = v_ds;
  if not v_ok then raise exception 'FAIL: site_admin could not approve weather'; end if;

  -- Model without quality_gate_passed cannot be approved
  begin
    update conservation_normalization_models
      set status = 'approved', approved_by = v_site_admin, approved_at = now(),
          quality_gate_passed = false
    where id = v_model;
    select status = 'approved' into v_ok from conservation_normalization_models where id = v_model;
    if v_ok then raise exception 'FAIL: model approved with failed quality gates'; end if;
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  select status = 'approved' into v_ok from conservation_normalization_models where id = v_model;
  if v_ok then raise exception 'FAIL: model approved with failed quality gates'; end if;
  reset role;

  -- SUPER: activate emission factor
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;
  update emission_factors
    set status = 'active', approved_by = v_super, approved_at = now()
  where id = v_ef;
  select status = 'active' into v_ok from emission_factors where id = v_ef;
  if not v_ok then raise exception 'FAIL: super could not activate emission factor'; end if;
  reset role;

  -- VIEWER: can select weather
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  set local role authenticated;
  select exists(select 1 from conservation_weather_datasets where id = v_ds) into v_ok;
  if not v_ok then raise exception 'FAIL: viewer cannot select weather dataset'; end if;
  begin
    update conservation_weather_datasets set notes = 'hack' where id = v_ds;
    if found then raise exception 'FAIL: viewer updated weather dataset'; end if;
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;
  reset role;

  delete from conservation_normalization_models where id = v_model;
  delete from conservation_weather_observations where dataset_id = v_ds;
  delete from conservation_weather_datasets where id = v_ds;
  delete from emission_factors where id = v_ef;

  if (select count(*) from meter_readings) <> v_readings then
    raise exception 'FAIL: meter_readings mutated';
  end if;
  if (select count(*) from meters where meter_kind = 'physical') <> v_meters_phys then
    raise exception 'FAIL: physical meters mutated';
  end if;
  if (select count(*) from conservation_feature_flags where enabled = true) <> v_flags_on then
    raise exception 'FAIL: feature flags enabled count changed';
  end if;

  raise notice 'PHASE_5_RLS_PASS readings=% physical=% flags_on=%',
    v_readings, v_meters_phys, v_flags_on;
end $$;
