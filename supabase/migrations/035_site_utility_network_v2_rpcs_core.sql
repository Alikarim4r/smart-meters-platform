-- =============================================================================
-- Migration: 035_site_utility_network_v2_rpcs_core.sql
-- Core transactional RPCs: draft lock, create network/assets, connect, snapshot.
-- =============================================================================

create or replace function public.utility_require_auth()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;
  return v_uid;
end;
$$;

create or replace function public.utility_assert_draft_lock(
  p_revision_id uuid,
  p_expected_lock_version integer
)
returns public.site_utility_network_revisions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
begin
  select * into v_rev
  from public.site_utility_network_revisions
  where id = p_revision_id
  for update;

  if v_rev.id is null then
    raise exception 'Revision not found';
  end if;
  if v_rev.status <> 'draft' then
    raise exception 'Only draft revisions can be mutated';
  end if;
  if not public.can_manage_utility_network(v_rev.network_id) then
    raise exception 'Not allowed to manage this utility network' using errcode = '42501';
  end if;
  if v_rev.lock_version <> p_expected_lock_version then
    raise exception
      'Network draft version conflict: expected %, actual %',
      p_expected_lock_version, v_rev.lock_version
      using errcode = '40001';
  end if;

  update public.site_utility_network_revisions
  set lock_version = lock_version + 1
  where id = p_revision_id
  returning * into v_rev;

  return v_rev;
end;
$$;

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
        (p_asset_id, 'drain', 'Drain', 'صرف', 'out', 'drain')
      on conflict (asset_id, code) do nothing;
    end if;
  elsif p_asset_type = 'treatment_unit' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'product', 'Product', 'منتج', 'out', 'product'),
      (p_asset_id, 'reject', 'Reject', 'مرفوض', 'out', 'reject')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type in ('filter', 'pump') then
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

-- Create network + first member + draft + default campus view
create or replace function public.create_utility_network(
  p_category_id uuid,
  p_code text,
  p_name_en text,
  p_name_ar text,
  p_member_site_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_site uuid;
  v_network public.site_utility_networks;
  v_rev public.site_utility_network_revisions;
  v_view public.site_utility_network_views;
begin
  if p_member_site_ids is null or cardinality(p_member_site_ids) < 1 then
    raise exception 'At least one member site is required';
  end if;

  foreach v_site in array p_member_site_ids loop
    if not public.can_manage_site_meters(v_site) then
      raise exception 'Not allowed to manage meters for site %', v_site using errcode = '42501';
    end if;
  end loop;

  insert into public.site_utility_networks (
    category_id, code, name_en, name_ar, created_by, updated_by
  ) values (
    p_category_id, trim(p_code), trim(p_name_en),
    coalesce(nullif(trim(p_name_ar), ''), trim(p_name_en)),
    v_uid, v_uid
  ) returning * into v_network;

  foreach v_site in array p_member_site_ids loop
    insert into public.site_utility_network_members (network_id, site_id)
    values (v_network.id, v_site);
  end loop;

  if not public.can_manage_utility_network(v_network.id) then
    raise exception 'Not allowed to manage this utility network' using errcode = '42501';
  end if;

  insert into public.site_utility_network_revisions (
    network_id, status, lock_version, created_by
  ) values (v_network.id, 'draft', 1, v_uid)
  returning * into v_rev;

  insert into public.site_utility_network_views (
    network_id, code, name_en, name_ar, view_kind, is_default, sort_order
  ) values (
    v_network.id, 'campus_overview', 'Campus overview', 'نظرة المجمع',
    'campus_overview', true, 0
  ) returning * into v_view;

  update public.site_utility_networks
  set draft_revision_id = v_rev.id, updated_at = now(), updated_by = v_uid
  where id = v_network.id;

  return jsonb_build_object(
    'network_id', v_network.id,
    'draft_revision_id', v_rev.id,
    'lock_version', v_rev.lock_version,
    'default_view_id', v_view.id
  );
end;
$$;

create or replace function public.ensure_network_draft(p_network_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_network public.site_utility_networks;
  v_rev public.site_utility_network_revisions;
begin
  if not public.can_manage_utility_network(p_network_id) then
    raise exception 'Not allowed to manage this utility network' using errcode = '42501';
  end if;

  select * into v_network from public.site_utility_networks where id = p_network_id;
  if v_network.id is null then
    raise exception 'Network not found';
  end if;

  select * into v_rev
  from public.site_utility_network_revisions
  where network_id = p_network_id and status = 'draft'
  limit 1;

  if v_rev.id is null then
    insert into public.site_utility_network_revisions (
      network_id, status, lock_version, based_on_revision_id, created_by
    ) values (
      p_network_id, 'draft', 1, v_network.published_revision_id, v_uid
    ) returning * into v_rev;

    update public.site_utility_networks
    set draft_revision_id = v_rev.id, updated_at = now(), updated_by = v_uid
    where id = p_network_id;
  end if;

  return jsonb_build_object(
    'network_id', p_network_id,
    'draft_revision_id', v_rev.id,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.create_asset_with_ports(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_site_id uuid,
  p_asset_type text,
  p_code text,
  p_name_en text,
  p_name_ar text,
  p_service_type text default null,
  p_facility_area_id uuid default null,
  p_meter_role text default null,
  p_properties jsonb default '{}'::jsonb,
  p_include_tank_aux_ports boolean default false,
  p_view_id uuid default null,
  p_pos_x double precision default 0,
  p_pos_y double precision default 0
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
  v_node public.site_utility_revision_nodes;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = v_rev.network_id and site_id = p_site_id
  ) then
    raise exception 'Asset site is not a member of this network';
  end if;
  if not public.can_manage_site_meters(p_site_id) then
    raise exception 'Not allowed to manage meters for site' using errcode = '42501';
  end if;

  insert into public.site_utility_assets (
    site_id, facility_area_id, asset_type, service_type, name_en, name_ar,
    code, meter_role, properties, created_by, updated_by
  ) values (
    p_site_id, p_facility_area_id, p_asset_type, p_service_type,
    trim(p_name_en), coalesce(nullif(trim(p_name_ar), ''), trim(p_name_en)),
    trim(p_code), p_meter_role, coalesce(p_properties, '{}'::jsonb), v_uid, v_uid
  ) returning * into v_asset;

  perform public.utility_default_ports_for_asset(
    v_asset.id, p_asset_type, p_include_tank_aux_ports
  );

  insert into public.site_utility_revision_nodes (revision_id, asset_id)
  values (p_revision_id, v_asset.id)
  returning * into v_node;

  if p_view_id is not null then
    insert into public.site_utility_view_nodes (
      revision_id, view_id, node_id, pos_x, pos_y
    ) values (p_revision_id, p_view_id, v_node.id, p_pos_x, p_pos_y)
    on conflict (revision_id, view_id, node_id) do update
      set pos_x = excluded.pos_x, pos_y = excluded.pos_y, updated_at = now();
  end if;

  return jsonb_build_object(
    'asset_id', v_asset.id,
    'node_id', v_node.id,
    'lock_version', v_rev.lock_version,
    'ports', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'code', p.code, 'direction', p.direction, 'port_role', p.port_role
      ) order by p.code), '[]'::jsonb)
      from public.site_utility_asset_ports p where p.asset_id = v_asset.id
    )
  );
end;
$$;

create or replace function public.add_asset_to_revision(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_asset_id uuid,
  p_view_id uuid default null,
  p_pos_x double precision default 0,
  p_pos_y double precision default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_asset public.site_utility_assets;
  v_node public.site_utility_revision_nodes;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);
  select * into v_asset from public.site_utility_assets where id = p_asset_id;
  if v_asset.id is null then
    raise exception 'Asset not found';
  end if;
  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = v_rev.network_id and site_id = v_asset.site_id
  ) then
    raise exception 'Asset site is not a member of this network';
  end if;

  insert into public.site_utility_revision_nodes (revision_id, asset_id)
  values (p_revision_id, p_asset_id)
  on conflict (revision_id, asset_id) do update set asset_id = excluded.asset_id
  returning * into v_node;

  if p_view_id is not null then
    insert into public.site_utility_view_nodes (
      revision_id, view_id, node_id, pos_x, pos_y
    ) values (p_revision_id, p_view_id, v_node.id, p_pos_x, p_pos_y)
    on conflict (revision_id, view_id, node_id) do update
      set pos_x = excluded.pos_x, pos_y = excluded.pos_y, updated_at = now();
  end if;

  return jsonb_build_object(
    'node_id', v_node.id,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.create_meter_asset(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_site_id uuid,
  p_meter_code text,
  p_name_en text,
  p_name_ar text,
  p_category_id uuid,
  p_source_id uuid,
  p_unit_id uuid,
  p_meter_role text default 'main',
  p_facility_area_id uuid default null,
  p_view_id uuid default null,
  p_pos_x double precision default 0,
  p_pos_y double precision default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev public.site_utility_network_revisions;
  v_meter public.meters;
  v_asset public.site_utility_assets;
  v_node public.site_utility_revision_nodes;
  v_level text := 'main';
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = v_rev.network_id and site_id = p_site_id
  ) then
    raise exception 'Asset site is not a member of this network';
  end if;

  insert into public.meters (
    site_id, meter_code, name_en, name_ar, category_id, source_id, unit_id,
    level, is_active, include_in_dashboard
  ) values (
    p_site_id, trim(p_meter_code), trim(p_name_en),
    coalesce(nullif(trim(p_name_ar), ''), trim(p_name_en)),
    p_category_id, p_source_id, p_unit_id,
    v_level::public.meter_level, true, true
  ) returning * into v_meter;

  insert into public.site_utility_assets (
    site_id, facility_area_id, asset_type, name_en, name_ar, code,
    ref_meter_id, meter_role, created_by, updated_by
  ) values (
    p_site_id, p_facility_area_id, 'meter',
    v_meter.name_en, v_meter.name_ar, v_meter.meter_code,
    v_meter.id, p_meter_role, v_uid, v_uid
  ) returning * into v_asset;

  perform public.utility_default_ports_for_asset(v_asset.id, 'meter', false);

  insert into public.site_utility_revision_nodes (revision_id, asset_id)
  values (p_revision_id, v_asset.id)
  returning * into v_node;

  if p_view_id is not null then
    insert into public.site_utility_view_nodes (
      revision_id, view_id, node_id, pos_x, pos_y
    ) values (p_revision_id, p_view_id, v_node.id, p_pos_x, p_pos_y);
  end if;

  return jsonb_build_object(
    'meter_id', v_meter.id,
    'asset_id', v_asset.id,
    'node_id', v_node.id,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.create_tank_asset(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_site_id uuid,
  p_name_en text,
  p_name_ar text,
  p_code text default null,
  p_service_type text default null,
  p_facility_area_id uuid default null,
  p_include_aux_ports boolean default true,
  p_view_id uuid default null,
  p_pos_x double precision default 0,
  p_pos_y double precision default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev public.site_utility_network_revisions;
  v_tank public.site_tanks;
  v_asset public.site_utility_assets;
  v_node public.site_utility_revision_nodes;
  v_code text;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = v_rev.network_id and site_id = p_site_id
  ) then
    raise exception 'Asset site is not a member of this network';
  end if;

  insert into public.site_tanks (site_id, name_en, name_ar, is_active)
  values (
    p_site_id, trim(p_name_en),
    coalesce(nullif(trim(p_name_ar), ''), trim(p_name_en)),
    true
  ) returning * into v_tank;

  v_code := coalesce(nullif(trim(p_code), ''), 'tank-' || substr(v_tank.id::text, 1, 8));

  insert into public.site_utility_assets (
    site_id, facility_area_id, asset_type, service_type, name_en, name_ar,
    code, ref_tank_id, created_by, updated_by
  ) values (
    p_site_id, p_facility_area_id, 'tank', p_service_type,
    v_tank.name_en, coalesce(v_tank.name_ar, v_tank.name_en), v_code,
    v_tank.id, v_uid, v_uid
  ) returning * into v_asset;

  perform public.utility_default_ports_for_asset(
    v_asset.id, 'tank', p_include_aux_ports
  );

  insert into public.site_utility_revision_nodes (revision_id, asset_id)
  values (p_revision_id, v_asset.id)
  returning * into v_node;

  if p_view_id is not null then
    insert into public.site_utility_view_nodes (
      revision_id, view_id, node_id, pos_x, pos_y
    ) values (p_revision_id, p_view_id, v_node.id, p_pos_x, p_pos_y);
  end if;

  return jsonb_build_object(
    'tank_id', v_tank.id,
    'asset_id', v_asset.id,
    'node_id', v_node.id,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.connect_ports(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_from_node_id uuid,
  p_from_port_id uuid,
  p_to_node_id uuid,
  p_to_port_id uuid,
  p_connection_kind text,
  p_water_type text default null,
  p_transport_mode text default 'pipe',
  p_operating_mode text default 'normal',
  p_legacy_sync_status text default null,
  p_properties jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_conn public.site_utility_revision_connections;
  v_sync text;
  v_from_asset public.site_utility_assets;
  v_to_asset public.site_utility_assets;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  select a.* into v_from_asset
  from public.site_utility_revision_nodes n
  join public.site_utility_assets a on a.id = n.asset_id
  where n.id = p_from_node_id and n.revision_id = p_revision_id;

  select a.* into v_to_asset
  from public.site_utility_revision_nodes n
  join public.site_utility_assets a on a.id = n.asset_id
  where n.id = p_to_node_id and n.revision_id = p_revision_id;

  v_sync := p_legacy_sync_status;
  if v_sync is null then
    if v_from_asset.asset_type = 'meter' and v_to_asset.asset_type = 'meter'
       and p_connection_kind = 'supply' then
      v_sync := 'synced';
    elsif v_from_asset.asset_type = 'meter' and v_to_asset.asset_type = 'tank'
       and p_connection_kind in ('supply', 'transfer') then
      v_sync := 'synced';
    else
      v_sync := 'graph_only';
    end if;
  end if;

  insert into public.site_utility_revision_connections (
    revision_id, from_node_id, from_port_id, to_node_id, to_port_id,
    connection_kind, water_type, transport_mode, operating_mode,
    legacy_sync_status, properties
  ) values (
    p_revision_id, p_from_node_id, p_from_port_id, p_to_node_id, p_to_port_id,
    p_connection_kind, p_water_type, p_transport_mode, p_operating_mode,
    v_sync, coalesce(p_properties, '{}'::jsonb)
  ) returning * into v_conn;

  -- Legacy sync after insert (same TX). Failures roll back whole RPC.
  if v_conn.legacy_sync_status = 'synced' then
    if v_from_asset.asset_type = 'meter' and v_to_asset.asset_type = 'meter' then
      if exists (
        with recursive walk as (
          select id, parent_meter_id, 1 as depth
          from public.meters where id = v_from_asset.ref_meter_id
          union all
          select m.id, m.parent_meter_id, walk.depth + 1
          from public.meters m
          join walk on m.id = walk.parent_meter_id
          where walk.depth < 32
        )
        select 1 from walk where id = v_to_asset.ref_meter_id
      ) then
        raise exception 'parent_meter_id cycle would be created';
      end if;
      update public.meters
      set parent_meter_id = v_from_asset.ref_meter_id,
          level = 'sub'::public.meter_level
      where id = v_to_asset.ref_meter_id;
    elsif v_from_asset.asset_type = 'meter' and v_to_asset.asset_type = 'tank' then
      update public.meters
      set pours_into_tank = true,
          destination_tank_id = v_to_asset.ref_tank_id
      where id = v_from_asset.ref_meter_id;
    end if;
  end if;

  return jsonb_build_object(
    'connection_id', v_conn.id,
    'legacy_sync_status', v_conn.legacy_sync_status,
    'is_consumptive', v_conn.is_consumptive,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.disconnect_ports(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_connection_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_conn public.site_utility_revision_connections;
  v_from public.site_utility_assets;
  v_to public.site_utility_assets;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  select * into v_conn
  from public.site_utility_revision_connections
  where id = p_connection_id and revision_id = p_revision_id;

  if v_conn.id is null then
    raise exception 'Connection not found';
  end if;

  select a.* into v_from
  from public.site_utility_revision_nodes n
  join public.site_utility_assets a on a.id = n.asset_id
  where n.id = v_conn.from_node_id;
  select a.* into v_to
  from public.site_utility_revision_nodes n
  join public.site_utility_assets a on a.id = n.asset_id
  where n.id = v_conn.to_node_id;

  if v_conn.legacy_sync_status = 'synced' then
    if v_from.asset_type = 'meter' and v_to.asset_type = 'meter' then
      update public.meters
      set parent_meter_id = null,
          level = 'main'::public.meter_level
      where id = v_to.ref_meter_id
        and parent_meter_id = v_from.ref_meter_id;
    elsif v_from.asset_type = 'meter' and v_to.asset_type = 'tank' then
      update public.meters
      set pours_into_tank = false,
          destination_tank_id = null
      where id = v_from.ref_meter_id
        and destination_tank_id = v_to.ref_tank_id;
    end if;
  end if;

  delete from public.site_utility_revision_connections where id = p_connection_id;

  return jsonb_build_object(
    'disconnected', true,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.batch_update_view_positions(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_view_id uuid,
  p_positions jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_item jsonb;
  v_count int := 0;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  for v_item in select * from jsonb_array_elements(coalesce(p_positions, '[]'::jsonb))
  loop
    insert into public.site_utility_view_nodes (
      revision_id, view_id, node_id, pos_x, pos_y, width, height, collapsed
    ) values (
      p_revision_id,
      p_view_id,
      (v_item->>'node_id')::uuid,
      coalesce((v_item->>'pos_x')::double precision, 0),
      coalesce((v_item->>'pos_y')::double precision, 0),
      (v_item->>'width')::double precision,
      (v_item->>'height')::double precision,
      coalesce((v_item->>'collapsed')::boolean, false)
    )
    on conflict (revision_id, view_id, node_id) do update
      set pos_x = excluded.pos_x,
          pos_y = excluded.pos_y,
          width = excluded.width,
          height = excluded.height,
          collapsed = excluded.collapsed,
          updated_at = now();
    v_count := v_count + 1;
  end loop;

  return jsonb_build_object(
    'updated', v_count,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.get_network_snapshot(
  p_network_id uuid,
  p_revision_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_network public.site_utility_networks;
  v_rev public.site_utility_network_revisions;
  v_revision_id uuid;
begin
  select * into v_network from public.site_utility_networks where id = p_network_id;
  if v_network.id is null then
    raise exception 'Network not found';
  end if;

  v_revision_id := coalesce(p_revision_id, v_network.published_revision_id);
  if v_revision_id is null then
    return jsonb_build_object(
      'network_id', p_network_id,
      'revision_id', null,
      'status', null,
      'message', 'No published revision'
    );
  end if;

  select * into v_rev from public.site_utility_network_revisions where id = v_revision_id;
  if v_rev.id is null or v_rev.network_id <> p_network_id then
    raise exception 'Revision not found for network';
  end if;

  if v_rev.status = 'draft' then
    if not public.can_manage_utility_network(p_network_id) then
      raise exception 'Draft revisions are not readable' using errcode = '42501';
    end if;
  else
    if not public.can_read_utility_network_snapshot(p_network_id) then
      raise exception 'Not allowed to read this network snapshot' using errcode = '42501';
    end if;
  end if;

  return jsonb_build_object(
    'network', jsonb_build_object(
      'id', v_network.id,
      'code', v_network.code,
      'name_en', v_network.name_en,
      'name_ar', v_network.name_ar,
      'category_id', v_network.category_id,
      'draft_revision_id', v_network.draft_revision_id,
      'published_revision_id', v_network.published_revision_id
    ),
    'revision', jsonb_build_object(
      'id', v_rev.id,
      'status', v_rev.status,
      'lock_version', v_rev.lock_version,
      'based_on_revision_id', v_rev.based_on_revision_id,
      'published_at', v_rev.published_at
    ),
    'members', (
      select coalesce(jsonb_agg(jsonb_build_object('site_id', m.site_id)), '[]'::jsonb)
      from public.site_utility_network_members m where m.network_id = p_network_id
    ),
    'views', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', v.id, 'code', v.code, 'name_en', v.name_en, 'name_ar', v.name_ar,
        'view_kind', v.view_kind, 'facility_area_id', v.facility_area_id,
        'is_default', v.is_default
      ) order by v.sort_order), '[]'::jsonb)
      from public.site_utility_network_views v where v.network_id = p_network_id
    ),
    'nodes', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'node_id', n.id,
        'asset_id', a.id,
        'site_id', a.site_id,
        'facility_area_id', a.facility_area_id,
        'asset_type', a.asset_type,
        'service_type', a.service_type,
        'code', a.code,
        'name_en', a.name_en,
        'name_ar', a.name_ar,
        'ref_meter_id', a.ref_meter_id,
        'ref_tank_id', a.ref_tank_id,
        'meter_role', a.meter_role,
        'properties', a.properties,
        'ports', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id', p.id, 'code', p.code, 'name_en', p.name_en, 'name_ar', p.name_ar,
            'direction', p.direction, 'port_role', p.port_role, 'properties', p.properties
          ) order by p.code), '[]'::jsonb)
          from public.site_utility_asset_ports p where p.asset_id = a.id
        )
      ) order by a.code), '[]'::jsonb)
      from public.site_utility_revision_nodes n
      join public.site_utility_assets a on a.id = n.asset_id
      where n.revision_id = v_revision_id
    ),
    'connections', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id,
        'from_node_id', c.from_node_id,
        'from_port_id', c.from_port_id,
        'to_node_id', c.to_node_id,
        'to_port_id', c.to_port_id,
        'connection_kind', c.connection_kind,
        'water_type', c.water_type,
        'transport_mode', c.transport_mode,
        'operating_mode', c.operating_mode,
        'is_consumptive', c.is_consumptive,
        'legacy_sync_status', c.legacy_sync_status,
        'properties', c.properties
      )), '[]'::jsonb)
      from public.site_utility_revision_connections c
      where c.revision_id = v_revision_id
    ),
    'placements', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'view_id', vn.view_id,
        'node_id', vn.node_id,
        'pos_x', vn.pos_x,
        'pos_y', vn.pos_y,
        'width', vn.width,
        'height', vn.height,
        'collapsed', vn.collapsed
      )), '[]'::jsonb)
      from public.site_utility_view_nodes vn
      where vn.revision_id = v_revision_id
    )
  );
end;
$$;

revoke all on function public.create_utility_network(uuid, text, text, text, uuid[]) from public;
revoke all on function public.ensure_network_draft(uuid) from public;
revoke all on function public.create_asset_with_ports(uuid, integer, uuid, text, text, text, text, text, uuid, text, jsonb, boolean, uuid, double precision, double precision) from public;
revoke all on function public.add_asset_to_revision(uuid, integer, uuid, uuid, double precision, double precision) from public;
revoke all on function public.create_meter_asset(uuid, integer, uuid, text, text, text, uuid, uuid, uuid, text, uuid, uuid, double precision, double precision) from public;
revoke all on function public.create_tank_asset(uuid, integer, uuid, text, text, text, text, uuid, boolean, uuid, double precision, double precision) from public;
revoke all on function public.connect_ports(uuid, integer, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb) from public;
revoke all on function public.disconnect_ports(uuid, integer, uuid) from public;
revoke all on function public.batch_update_view_positions(uuid, integer, uuid, jsonb) from public;
revoke all on function public.get_network_snapshot(uuid, uuid) from public;

grant execute on function public.create_utility_network(uuid, text, text, text, uuid[]) to authenticated;
grant execute on function public.ensure_network_draft(uuid) to authenticated;
grant execute on function public.create_asset_with_ports(uuid, integer, uuid, text, text, text, text, text, uuid, text, jsonb, boolean, uuid, double precision, double precision) to authenticated;
grant execute on function public.add_asset_to_revision(uuid, integer, uuid, uuid, double precision, double precision) to authenticated;
grant execute on function public.create_meter_asset(uuid, integer, uuid, text, text, text, uuid, uuid, uuid, text, uuid, uuid, double precision, double precision) to authenticated;
grant execute on function public.create_tank_asset(uuid, integer, uuid, text, text, text, text, uuid, boolean, uuid, double precision, double precision) to authenticated;
grant execute on function public.connect_ports(uuid, integer, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb) to authenticated;
grant execute on function public.disconnect_ports(uuid, integer, uuid) to authenticated;
grant execute on function public.batch_update_view_positions(uuid, integer, uuid, jsonb) to authenticated;
grant execute on function public.get_network_snapshot(uuid, uuid) to authenticated;
