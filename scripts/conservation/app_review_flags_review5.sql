do $$
declare
  v_org uuid := '11111111-1111-4111-8111-111111111111';
  keys text[] := array[
    'conservation_module','data_quality','period_compare',
    'targets','baseline','virtual_meters',
    'water_balance','energy_balance','benchmarking','intensity',
    'periodic_anomalies','cop_conservation',
    'opportunities','investigations','actions','evidence',
    'savings_estimation','savings_verification','cost_roi','conservation_reports'
  ];
  k text; n int;
begin
  foreach k in array keys loop
    update conservation_feature_flags
      set enabled = true, updated_at = now()
    where organization_id = v_org and site_id is null and flag_key = k;
    get diagnostics n = row_count;
    if n = 0 then
      insert into conservation_feature_flags (organization_id, site_id, flag_key, enabled)
      values (v_org, null, k, true);
    end if;
  end loop;
end $$;
select flag_key, enabled from conservation_feature_flags
where organization_id = '11111111-1111-4111-8111-111111111111'
  and site_id is null and enabled order by 1;
