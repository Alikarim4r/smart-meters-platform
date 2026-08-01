-- CLEANUP APP_REVIEW_DEMO data (does not touch meter_readings)
do $$
declare
  v_org uuid := '11111111-1111-4111-8111-111111111111';
  v_site uuid := '22222222-2222-4222-8222-222222222222';
  v_vm uuid := 'a1111111-1111-4111-8111-1111111111d1';
  v_readings int;
begin
  select count(*) into v_readings from meter_readings;

  delete from conservation_carbon_results where lineage->>'demo_tag' = 'APP_REVIEW_DEMO';
  delete from conservation_saving_persistence where lineage->>'demo_tag' = 'APP_REVIEW_DEMO';
  delete from conservation_measurement_verifications where notes like 'APP_REVIEW_DEMO%';
  delete from conservation_evidence where notes like 'APP_REVIEW_DEMO%' or title like 'APP_REVIEW_DEMO%';
  delete from conservation_actions where completion_notes like 'APP_REVIEW_DEMO%' or title like 'APP_REVIEW_DEMO%';
  delete from conservation_investigations where notes like 'APP_REVIEW_DEMO%' or finding_summary like 'APP_REVIEW_DEMO%';
  delete from conservation_opportunities where source_fingerprint like 'app_review_demo%' or title like 'APP_REVIEW_DEMO%';
  delete from conservation_balance_group_members bgm
    using conservation_balance_groups bg
    where bgm.balance_group_id = bg.id and bg.notes like 'APP_REVIEW_DEMO%';
  delete from conservation_balance_groups where notes like 'APP_REVIEW_DEMO%';
  delete from conservation_virtual_meter_members where virtual_meter_id = v_vm;
  delete from meters where id = v_vm or meter_code = 'APP_REVIEW_DEMO_VM';
  delete from conservation_baselines where notes like 'APP_REVIEW_DEMO%';
  delete from conservation_targets where target_value = 999001.0000 and site_id = v_site;
  delete from utility_tariffs where source_notes like 'APP_REVIEW_DEMO%';
  delete from emission_factors where notes like 'APP_REVIEW_DEMO%' or source like 'APP_REVIEW_DEMO%';
  delete from conservation_forecast_results where lineage->>'demo_tag' = 'APP_REVIEW_DEMO';
  delete from conservation_portfolio_summaries where lineage->>'demo_tag' = 'APP_REVIEW_DEMO';
  delete from import_batch_rows ibr
    using import_batches ib
    where ibr.batch_id = ib.id and ib.file_name like 'APP_REVIEW_DEMO%';
  delete from import_batches where file_name like 'APP_REVIEW_DEMO%';
  update site_conservation_profiles
    set floor_area_m2 = null, occupancy_count = null, peer_group = null,
        profile_notes = null, updated_at = now()
    where site_id = v_site and profile_notes like 'APP_REVIEW_DEMO%';

  update conservation_feature_flags set enabled = false, updated_at = now()
    where organization_id = v_org and enabled = true;
  update platform_feature_flags set enabled = false, updated_at = now()
    where organization_id = v_org and enabled = true;
  delete from conservation_feature_flags
    where organization_id = v_org and enabled = true;
  delete from platform_feature_flags
    where organization_id = v_org and enabled = true;

  if (select count(*) from meter_readings) <> v_readings then
    raise exception 'PROTECTED: meter_readings changed during cleanup';
  end if;
  raise notice 'APP_REVIEW_DEMO cleanup OK; readings=%', v_readings;
end $$;
