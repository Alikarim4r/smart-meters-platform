-- =============================================================================
-- Migration: 049_utility_network_sync_tank_names_on_update.sql
-- Keep site_tanks.name_* in sync when a tank asset is renamed via update_asset,
-- so unique (site_id, name_en) does not block creating additional tanks.
-- =============================================================================

create or replace function public.update_asset(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_asset_id uuid,
  p_code text default null,
  p_name_en text default null,
  p_name_ar text default null,
  p_service_type text default null,
  p_facility_area_id uuid default null,
  p_properties jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev public.site_utility_network_revisions;
  v_asset public.site_utility_assets;
  v_code text;
  v_name_en text;
  v_name_ar text;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if not exists (
    select 1 from public.site_utility_revision_nodes
    where revision_id = p_revision_id and asset_id = p_asset_id
  ) then
    raise exception 'Asset is not in this revision';
  end if;

  select * into v_asset from public.site_utility_assets where id = p_asset_id;
  if v_asset.id is null then
    raise exception 'Asset not found';
  end if;
  if v_asset.status = 'archived' then
    raise exception 'Cannot update archived asset';
  end if;

  v_code := coalesce(nullif(trim(p_code), ''), v_asset.code);
  v_name_en := coalesce(nullif(trim(p_name_en), ''), v_asset.name_en);
  v_name_ar := case
    when p_name_ar is null then v_asset.name_ar
    when nullif(trim(p_name_ar), '') is null then v_name_en
    else trim(p_name_ar)
  end;

  update public.site_utility_assets
  set
    code = v_code,
    name_en = v_name_en,
    name_ar = v_name_ar,
    service_type = case
      when p_service_type is null then service_type
      when trim(p_service_type) = '' then null
      else trim(p_service_type)
    end,
    facility_area_id = coalesce(p_facility_area_id, facility_area_id),
    properties = coalesce(p_properties, properties),
    updated_by = v_uid,
    updated_at = now()
  where id = p_asset_id
  returning * into v_asset;

  if v_asset.asset_type = 'tank' and v_asset.ref_tank_id is not null then
    update public.site_tanks
    set
      name_en = v_asset.name_en,
      name_ar = coalesce(v_asset.name_ar, v_asset.name_en),
      updated_at = now()
    where id = v_asset.ref_tank_id
      and (
        name_en is distinct from v_asset.name_en
        or name_ar is distinct from coalesce(v_asset.name_ar, v_asset.name_en)
      );
  end if;

  return jsonb_build_object(
    'asset_id', v_asset.id,
    'code', v_asset.code,
    'name_en', v_asset.name_en,
    'name_ar', v_asset.name_ar,
    'service_type', v_asset.service_type,
    'facility_area_id', v_asset.facility_area_id,
    'properties', v_asset.properties,
    'lock_version', v_rev.lock_version
  );
end;
$$;

comment on function public.update_asset is
  'Update utility asset fields in a draft; tank assets also sync site_tanks names.';
