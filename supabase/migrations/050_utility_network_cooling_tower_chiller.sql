-- =============================================================================
-- Migration: 050_utility_network_cooling_tower_chiller.sql
-- Add cooling_tower and chiller asset types for the network editor palette.
-- =============================================================================

alter table public.site_utility_assets
  drop constraint if exists site_utility_assets_type_check;

alter table public.site_utility_assets
  add constraint site_utility_assets_type_check check (
    asset_type in (
      'external_source', 'meter', 'tank', 'pump', 'filter', 'treatment_unit',
      'junction', 'consumer', 'discharge_point', 'tanker_loading', 'building_portal',
      'cooling_tower', 'chiller'
    )
  );

create or replace function public.utility_default_ports_for_asset(
  p_asset_id uuid,
  p_asset_type text,
  p_include_tank_aux boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_asset_type = 'meter' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'outlet', 'Outlet', 'مخرج', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type = 'tank' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'outlet', 'Outlet', 'مخرج', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
    if p_include_tank_aux then
      insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
      values
        (p_asset_id, 'overflow', 'Overflow', 'فيض', 'out', 'overflow'),
        (p_asset_id, 'washout', 'Washout', 'تنظيف', 'out', 'washout'),
        (p_asset_id, 'drain', 'Drain', 'صرف', 'out', 'drain'),
        (p_asset_id, 'emergency', 'Emergency', 'طوارئ', 'out', 'emergency'),
        (p_asset_id, 'tanker_transfer', 'Tanker transfer', 'نقل تانكر', 'out', 'tanker_transfer')
      on conflict (asset_id, code) do nothing;
    end if;
  elsif p_asset_type = 'treatment_unit' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'product', 'Product', 'منتج', 'out', 'product'),
      (p_asset_id, 'reject', 'Reject', 'مرفوض', 'out', 'reject')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type in ('filter', 'pump', 'cooling_tower', 'chiller') then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'outlet', 'Outlet', 'مخرج', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type = 'external_source' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values (p_asset_id, 'outlet', 'Outlet', 'مخرج', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type in ('discharge_point', 'consumer') then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type = 'tanker_loading' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'tanker_transfer', 'Tanker transfer', 'نقل تانكر', 'out', 'tanker_transfer')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type = 'junction' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'in_1', 'In 1', 'مدخل 1', 'in', 'inlet'),
      (p_asset_id, 'out_1', 'Out 1', 'مخرج 1', 'out', 'outlet'),
      (p_asset_id, 'out_2', 'Out 2', 'مخرج 2', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type = 'building_portal' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'outlet', 'Outlet', 'مخرج', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
  end if;
end;
$$;
