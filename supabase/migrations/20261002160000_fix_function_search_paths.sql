-- Pin search_path for public functions flagged by the production Security Advisor.
-- public is retained because several trigger bodies intentionally use unqualified helper calls.

do $$
begin
  if to_regprocedure('public.base_unit_for_category(meter_category)') is not null then
    execute 'alter function public.base_unit_for_category(meter_category) set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.build_meter_image_path(uuid,uuid,meter_category,date,uuid,text)') is not null then
    execute 'alter function public.build_meter_image_path(uuid,uuid,meter_category,date,uuid,text) set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.clear_archive_metadata_on_reactivate()') is not null then
    execute 'alter function public.clear_archive_metadata_on_reactivate() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.compute_normalized_reading()') is not null then
    execute 'alter function public.compute_normalized_reading() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_action_transition_guard()') is not null then
    execute 'alter function public.conservation_action_transition_guard() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_balance_group_validate()') is not null then
    execute 'alter function public.conservation_balance_group_validate() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_baselines_enforce_immutability()') is not null then
    execute 'alter function public.conservation_baselines_enforce_immutability() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_inv_confirmed_cause_authority()') is not null then
    execute 'alter function public.conservation_inv_confirmed_cause_authority() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_inv_reject_auto_confirm()') is not null then
    execute 'alter function public.conservation_inv_reject_auto_confirm() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_meters_reject_parent_cycle()') is not null then
    execute 'alter function public.conservation_meters_reject_parent_cycle() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_mv_transition_guard()') is not null then
    execute 'alter function public.conservation_mv_transition_guard() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_mv_verify_authority()') is not null then
    execute 'alter function public.conservation_mv_verify_authority() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_norm_model_approve_authority()') is not null then
    execute 'alter function public.conservation_norm_model_approve_authority() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_occ_profile_approve_authority()') is not null then
    execute 'alter function public.conservation_occ_profile_approve_authority() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_vm_members_validate()') is not null then
    execute 'alter function public.conservation_vm_members_validate() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.conservation_weather_ds_approve_authority()') is not null then
    execute 'alter function public.conservation_weather_ds_approve_authority() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.current_business_date()') is not null then
    execute 'alter function public.current_business_date() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.emission_factors_approve_authority()') is not null then
    execute 'alter function public.emission_factors_approve_authority() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.protect_meter_unit_integrity()') is not null then
    execute 'alter function public.protect_meter_unit_integrity() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.set_meter_unit_defaults()') is not null then
    execute 'alter function public.set_meter_unit_defaults() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.set_site_facility_areas_updated_at()') is not null then
    execute 'alter function public.set_site_facility_areas_updated_at() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.set_site_network_updated_at()') is not null then
    execute 'alter function public.set_site_network_updated_at() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.set_site_tanks_updated_at()') is not null then
    execute 'alter function public.set_site_tanks_updated_at() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.set_updated_at()') is not null then
    execute 'alter function public.set_updated_at() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.site_operating_calendar_approve_authority()') is not null then
    execute 'alter function public.site_operating_calendar_approve_authority() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.site_utility_connection_set_consumptive()') is not null then
    execute 'alter function public.site_utility_connection_set_consumptive() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.storage_path_organization_id(text)') is not null then
    execute 'alter function public.storage_path_organization_id(text) set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.storage_path_site_id(text)') is not null then
    execute 'alter function public.storage_path_site_id(text) set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.unit_to_base_factor(meter_category,meter_unit)') is not null then
    execute 'alter function public.unit_to_base_factor(meter_category,meter_unit) set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.utility_legacy_edge_conn_kind(text)') is not null then
    execute 'alter function public.utility_legacy_edge_conn_kind(text) set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.validate_cop_btu_meter()') is not null then
    execute 'alter function public.validate_cop_btu_meter() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.validate_cop_electricity_meter()') is not null then
    execute 'alter function public.validate_cop_electricity_meter() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.validate_meter_parent()') is not null then
    execute 'alter function public.validate_meter_parent() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.validate_org_site_type_ownership()') is not null then
    execute 'alter function public.validate_org_site_type_ownership() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.validate_reading_site()') is not null then
    execute 'alter function public.validate_reading_site() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.validate_zone_default_site_type()') is not null then
    execute 'alter function public.validate_zone_default_site_type() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('public.validate_zone_parent()') is not null then
    execute 'alter function public.validate_zone_parent() set search_path = public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('util_net_test.assert(boolean,text)') is not null then
    execute 'alter function util_net_test.assert(boolean,text) set search_path = util_net_test, public';
  end if;
end
$$;
do $$
begin
  if to_regprocedure('util_net_test.set_user(uuid)') is not null then
    execute 'alter function util_net_test.set_user(uuid) set search_path = util_net_test, public';
  end if;
end
$$;
