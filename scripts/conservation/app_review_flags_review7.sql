-- Review 7: platform flags only (NOT smart_meter/bms/api/automation/ai)
do $$
declare
  v_org uuid := '11111111-1111-4111-8111-111111111111';
  keys text[] := array[
    'unified_ingestion','file_import','source_health','notification_center'
  ];
  k text; n int;
begin
  foreach k in array keys loop
    update platform_feature_flags
      set enabled = true, updated_at = now()
    where organization_id = v_org and site_id is null and flag_key = k;
    get diagnostics n = row_count;
    if n = 0 then
      insert into platform_feature_flags (organization_id, site_id, flag_key, enabled)
      values (v_org, null, k, true);
    end if;
  end loop;
end $$;
select flag_key, enabled from platform_feature_flags
where organization_id = '11111111-1111-4111-8111-111111111111'
  and site_id is null and enabled order by 1;
