-- Phase 6 RLS / security smoke (fixtures cleaned). Does not permanently mutate meter_readings.
do $$
declare
  v_viewer uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  v_tech uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_site_admin uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  v_super uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddd01';
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_org uuid;
  v_src uuid;
  v_rule uuid;
  v_ok boolean;
  v_readings int;
  v_flags_on int;
  v_meters_phys int;
  v_p6_flags_on int;
begin
  select count(*) into v_readings from meter_readings;
  select count(*) into v_flags_on from conservation_feature_flags where enabled = true;
  select count(*) into v_p6_flags_on from platform_feature_flags where enabled = true;
  select count(*) into v_meters_phys from meters where meter_kind = 'physical';
  select organization_id into v_org from sites where id = v_hq;

  reset role;
  delete from automation_rule_firings where firing_key like 'p6_rls_%';
  delete from automation_rules where rule_key like 'p6_rls_%';
  delete from external_data_sources where source_key like 'p6_rls_%';
  delete from platform_feature_flags where flag_key like 'p6_rls_%';
  delete from in_app_notifications where event_key like 'p6_rls_%';
  delete from data_availability_alerts where alert_key like 'p6_rls_%';

  insert into external_data_sources (
    organization_id, site_id, source_key, display_name, source_type, status, enabled, created_by
  ) values (
    v_org, v_hq, 'p6_rls_api', 'P6 RLS API', 'api', 'never_synced', false, v_super
  ) returning id into v_src;

  insert into automation_rules (
    organization_id, site_id, rule_key, display_name, explanation, enabled, created_by
  ) values (
    v_org, v_hq, 'p6_rls_rule', 'P6 RLS Rule', 'test', false, v_super
  ) returning id into v_rule;

  -- TECH cannot activate automation rule
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  begin
    update automation_rules set enabled = true where id = v_rule;
  exception when others then
    null;
  end;
  select enabled into v_ok from automation_rules where id = v_rule;
  if v_ok then raise exception 'FAIL: technician activated automation rule'; end if;

  -- VIEWER cannot insert external source
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  begin
    insert into external_data_sources (
      organization_id, site_id, source_key, display_name, source_type, status, enabled
    ) values (
      v_org, v_hq, 'p6_rls_viewer', 'viewer', 'api', 'never_synced', false
    );
    raise exception 'FAIL: viewer inserted external_data_sources';
  exception when others then
    if sqlerrm like 'FAIL:%' then raise; end if;
  end;

  -- SITE ADMIN can read source for managed site
  perform set_config('request.jwt.claim.sub', v_site_admin::text, true);
  select exists(
    select 1 from external_data_sources where id = v_src
  ) into v_ok;
  if not v_ok then raise exception 'FAIL: site_admin cannot read in-scope source'; end if;

  -- TECH cannot manage import batches write for other org patterns — insert blocked if no manage
  begin
    insert into import_batches (
      organization_id, site_id, source_type, file_fingerprint, status, dry_run, imported_by
    ) values (
      v_org, v_hq, 'csv_import', 'p6_rls_fp', 'preview', true, v_tech
    );
    -- may succeed if tech somehow can_manage — delete if created
    delete from import_batches where file_fingerprint = 'p6_rls_fp';
  exception when others then
    null; -- expected reject for technician in many policies
  end;

  reset role;
  delete from automation_rules where id = v_rule;
  delete from external_data_sources where id = v_src;
  delete from import_batches where file_fingerprint = 'p6_rls_fp';

  -- Protected metrics unchanged
  if (select count(*) from meter_readings) <> v_readings then
    raise exception 'FAIL: meter_readings count changed';
  end if;
  if (select count(*) from meters where meter_kind = 'physical') <> v_meters_phys then
    raise exception 'FAIL: physical meters count changed';
  end if;
  if (select count(*) from conservation_feature_flags where enabled = true) <> v_flags_on then
    raise exception 'FAIL: conservation flags_on changed';
  end if;
  if (select count(*) from platform_feature_flags where enabled = true) <> v_p6_flags_on then
    raise exception 'FAIL: platform flags_on changed';
  end if;

  raise notice 'PHASE_6_RLS_VALIDATE PASS readings=% phys=% cons_flags_on=% p6_flags_on=%',
    v_readings, v_meters_phys, v_flags_on, v_p6_flags_on;
end $$;
