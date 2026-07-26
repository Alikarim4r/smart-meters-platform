-- =============================================================================
-- Migration: 039_utility_network_phase_a_closure.sql
-- Phase A closure fixes:
-- 1) Lock bump only after real mutation; attach already_in_current_view no-bump
-- 2) replace_existing_parent (default false) for synced parent conflicts
-- 3) At most one synced legacy parent; extras forced to graph_only
-- 4) Stronger create_meter_in_network_draft validation
-- =============================================================================

-- Drop pre-039 overloads (without replace_existing_parent) to avoid ambiguity.
drop function if exists public.attach_existing_meter_to_draft(uuid, integer, uuid, uuid, double precision, double precision, text, uuid, uuid, uuid[], text, text, text);
drop function if exists public.create_meter_in_network_draft(uuid, integer, uuid, text, text, text, uuid, uuid, uuid, text, uuid, uuid, double precision, double precision, uuid, uuid[], text, text, text);
drop function if exists public.connect_ports(uuid, integer, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb);
drop function if exists public.utility_connect_ports_unlocked(uuid, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb);
drop function if exists public.utility_link_meter_neighbors(uuid, uuid, uuid, uuid[], text, text, text);

-- Check draft + ACL + lock without bumping.
create or replace function public.utility_check_draft_lock(
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
  perform public.utility_require_auth();

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

  return v_rev;
end;
$$;

create or replace function public.utility_bump_draft_lock(p_revision_id uuid)
returns public.site_utility_network_revisions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
begin
  update public.site_utility_network_revisions
  set lock_version = lock_version + 1
  where id = p_revision_id
  returning * into v_rev;

  if v_rev.id is null then
    raise exception 'Revision not found';
  end if;
  return v_rev;
end;
$$;

-- Prefer check+bump for new code; keep assert as check+bump for compatibility.
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
  v_rev := public.utility_check_draft_lock(p_revision_id, p_expected_lock_version);
  return public.utility_bump_draft_lock(p_revision_id);
end;
$$;

-- Connection writer with parent conflict + single synced parent rules.
create or replace function public.utility_connect_ports_unlocked(
  p_revision_id uuid,
  p_from_node_id uuid,
  p_from_port_id uuid,
  p_to_node_id uuid,
  p_to_port_id uuid,
  p_connection_kind text,
  p_water_type text default null,
  p_transport_mode text default 'pipe',
  p_operating_mode text default 'normal',
  p_legacy_sync_status text default null,
  p_properties jsonb default '{}'::jsonb,
  p_replace_existing_parent boolean default false
)
returns public.site_utility_revision_connections
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conn public.site_utility_revision_connections;
  v_sync text;
  v_from_asset public.site_utility_assets;
  v_to_asset public.site_utility_assets;
  v_child public.meters;
  v_existing_synced_from uuid;
  v_existing_synced_conn uuid;
begin
  select a.* into v_from_asset
  from public.site_utility_revision_nodes n
  join public.site_utility_assets a on a.id = n.asset_id
  where n.id = p_from_node_id and n.revision_id = p_revision_id;

  select a.* into v_to_asset
  from public.site_utility_revision_nodes n
  join public.site_utility_assets a on a.id = n.asset_id
  where n.id = p_to_node_id and n.revision_id = p_revision_id;

  if v_from_asset.id is null or v_to_asset.id is null then
    raise exception 'Connection endpoints must belong to the revision';
  end if;

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

  -- Meter→meter supply sync: one legacy parent only; conflict unless replace.
  if v_from_asset.asset_type = 'meter'
     and v_to_asset.asset_type = 'meter'
     and p_connection_kind = 'supply'
     and v_sync = 'synced' then
    select * into v_child from public.meters where id = v_to_asset.ref_meter_id;

    if v_child.id is not null
       and v_child.parent_meter_id is not null
       and v_child.parent_meter_id is distinct from v_from_asset.ref_meter_id
       and not coalesce(p_replace_existing_parent, false) then
      raise exception
        'Downstream meter parent conflict: existing parent %, requested % (set replace_existing_parent=true to replace)',
        v_child.parent_meter_id, v_from_asset.ref_meter_id
        using errcode = '23514';
    end if;

    select c.id, c.from_node_id
      into v_existing_synced_conn, v_existing_synced_from
    from public.site_utility_revision_connections c
    join public.site_utility_revision_nodes fn on fn.id = c.from_node_id
    join public.site_utility_assets fa on fa.id = fn.asset_id
    where c.revision_id = p_revision_id
      and c.to_node_id = p_to_node_id
      and c.legacy_sync_status = 'synced'
      and c.connection_kind = 'supply'
      and fa.asset_type = 'meter'
      and c.from_node_id is distinct from p_from_node_id
    limit 1;

    if v_existing_synced_conn is not null then
      if coalesce(p_replace_existing_parent, false) then
        update public.site_utility_revision_connections
        set legacy_sync_status = 'graph_only', updated_at = now()
        where id = v_existing_synced_conn;
      else
        -- Additional non-projectable edge: never claim synced.
        v_sync := 'graph_only';
      end if;
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
          level = case
            when (select level from public.meters where id = v_from_asset.ref_meter_id) = 'main'
              then 'sub'::public.meter_level
            else 'sub_sub'::public.meter_level
          end
      where id = v_to_asset.ref_meter_id;
    elsif v_from_asset.asset_type = 'meter' and v_to_asset.asset_type = 'tank' then
      update public.meters
      set pours_into_tank = true,
          destination_tank_id = v_to_asset.ref_tank_id
      where id = v_from_asset.ref_meter_id;
    end if;
  end if;

  return v_conn;
end;
$$;

create or replace function public.utility_link_meter_neighbors(
  p_revision_id uuid,
  p_new_node_id uuid,
  p_upstream_node_id uuid,
  p_downstream_node_ids uuid[],
  p_connection_kind text default 'supply',
  p_water_type text default null,
  p_legacy_sync_status text default null,
  p_replace_existing_parent boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_asset uuid;
  v_up_asset uuid;
  v_down uuid;
  v_down_asset uuid;
  v_from_port uuid;
  v_to_port uuid;
  v_conn public.site_utility_revision_connections;
  v_up_conn_id uuid;
  v_down_ids uuid[] := '{}';
begin
  select asset_id into v_new_asset
  from public.site_utility_revision_nodes
  where id = p_new_node_id and revision_id = p_revision_id;

  if p_upstream_node_id is not null then
    select asset_id into v_up_asset
    from public.site_utility_revision_nodes
    where id = p_upstream_node_id and revision_id = p_revision_id;
    if v_up_asset is null then
      raise exception 'Upstream node is not in this revision';
    end if;
    v_from_port := public.utility_default_out_port(v_up_asset);
    v_to_port := public.utility_default_in_port(v_new_asset);
    if v_from_port is null or v_to_port is null then
      raise exception 'Missing ports for upstream link';
    end if;
    v_conn := public.utility_connect_ports_unlocked(
      p_revision_id, p_upstream_node_id, v_from_port,
      p_new_node_id, v_to_port,
      p_connection_kind, p_water_type, 'pipe', 'normal',
      p_legacy_sync_status, '{}'::jsonb, p_replace_existing_parent
    );
    v_up_conn_id := v_conn.id;
  end if;

  if p_downstream_node_ids is not null then
    foreach v_down in array p_downstream_node_ids loop
      select asset_id into v_down_asset
      from public.site_utility_revision_nodes
      where id = v_down and revision_id = p_revision_id;
      if v_down_asset is null then
        raise exception 'Downstream node % is not in this revision', v_down;
      end if;
      v_from_port := public.utility_default_out_port(v_new_asset);
      v_to_port := public.utility_default_in_port(v_down_asset);
      if v_from_port is null or v_to_port is null then
        raise exception 'Missing ports for downstream link';
      end if;
      v_conn := public.utility_connect_ports_unlocked(
        p_revision_id, p_new_node_id, v_from_port,
        v_down, v_to_port,
        p_connection_kind, p_water_type, 'pipe', 'normal',
        p_legacy_sync_status, '{}'::jsonb, p_replace_existing_parent
      );
      v_down_ids := array_append(v_down_ids, v_conn.id);
    end loop;
  end if;

  return jsonb_build_object(
    'upstream_connection_id', v_up_conn_id,
    'downstream_connection_ids', to_jsonb(coalesce(v_down_ids, '{}'::uuid[]))
  );
end;
$$;

-- Attach: early already_in_current_view without lock bump.
create or replace function public.attach_existing_meter_to_draft(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_meter_id uuid,
  p_view_id uuid default null,
  p_pos_x double precision default 0,
  p_pos_y double precision default 0,
  p_meter_role text default 'process',
  p_facility_area_id uuid default null,
  p_upstream_node_id uuid default null,
  p_downstream_node_ids uuid[] default null,
  p_connection_kind text default 'supply',
  p_water_type text default null,
  p_legacy_sync_status text default null,
  p_replace_existing_parent boolean default false
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
  v_view_node_id uuid;
  v_had_view boolean := false;
  v_created_asset boolean := false;
  v_created_node boolean := false;
  v_links jsonb := '{}'::jsonb;
  v_want_links boolean := false;
begin
  v_rev := public.utility_check_draft_lock(p_revision_id, p_expected_lock_version);

  select * into v_meter from public.meters where id = p_meter_id;
  if v_meter.id is null then
    raise exception 'Meter not found';
  end if;
  if not coalesce(v_meter.is_active, false) then
    raise exception 'Meter is inactive';
  end if;
  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = v_rev.network_id and site_id = v_meter.site_id
  ) then
    raise exception 'Meter site is not a member of this network';
  end if;
  if not exists (
    select 1 from public.site_utility_networks n
    where n.id = v_rev.network_id and n.category_id = v_meter.category_id
  ) then
    raise exception 'Meter category does not match network category';
  end if;

  select * into v_asset
  from public.site_utility_assets
  where ref_meter_id = p_meter_id and status = 'active'
  limit 1;

  if v_asset.id is not null then
    select * into v_node
    from public.site_utility_revision_nodes
    where revision_id = p_revision_id and asset_id = v_asset.id;
  end if;

  if v_node.id is not null and p_view_id is not null then
    select id into v_view_node_id
    from public.site_utility_view_nodes
    where revision_id = p_revision_id
      and view_id = p_view_id
      and node_id = v_node.id;
    v_had_view := v_view_node_id is not null;
  end if;

  v_want_links := p_upstream_node_id is not null or p_downstream_node_ids is not null;

  if v_node.id is not null
     and p_view_id is not null
     and v_had_view
     and not v_want_links
     and exists (
       select 1 from public.site_utility_view_nodes vn
       where vn.id = v_view_node_id
         and vn.pos_x is not distinct from p_pos_x
         and vn.pos_y is not distinct from p_pos_y
     ) then
    return jsonb_build_object(
      'status', 'already_in_current_view',
      'meter_id', v_meter.id,
      'asset_id', v_asset.id,
      'node_id', v_node.id,
      'view_node_id', v_view_node_id,
      'created_asset', false,
      'created_node', false,
      'links', '{}'::jsonb,
      'lock_version', v_rev.lock_version
    );
  end if;

  v_rev := public.utility_bump_draft_lock(p_revision_id);

  if v_asset.id is null then
    insert into public.site_utility_assets (
      site_id, facility_area_id, asset_type, name_en, name_ar, code,
      ref_meter_id, meter_role, created_by, updated_by
    ) values (
      v_meter.site_id, p_facility_area_id, 'meter',
      v_meter.name_en, coalesce(v_meter.name_ar, v_meter.name_en), v_meter.meter_code,
      v_meter.id, coalesce(nullif(trim(p_meter_role), ''), 'process'),
      v_uid, v_uid
    ) returning * into v_asset;
    v_created_asset := true;
    perform public.utility_default_ports_for_asset(v_asset.id, 'meter', false);
  else
    perform public.utility_default_ports_for_asset(v_asset.id, 'meter', false);
    if p_facility_area_id is not null
       and v_asset.facility_area_id is distinct from p_facility_area_id then
      update public.site_utility_assets
      set facility_area_id = p_facility_area_id, updated_by = v_uid, updated_at = now()
      where id = v_asset.id
      returning * into v_asset;
    end if;
  end if;

  if v_node.id is null then
    insert into public.site_utility_revision_nodes (revision_id, asset_id)
    values (p_revision_id, v_asset.id)
    returning * into v_node;
    v_created_node := true;
  end if;

  if p_view_id is not null then
    if not exists (
      select 1 from public.site_utility_network_views
      where id = p_view_id and network_id = v_rev.network_id
    ) then
      raise exception 'View does not belong to this network';
    end if;
    insert into public.site_utility_view_nodes (
      revision_id, view_id, node_id, pos_x, pos_y
    ) values (p_revision_id, p_view_id, v_node.id, p_pos_x, p_pos_y)
    on conflict (revision_id, view_id, node_id) do update
      set pos_x = excluded.pos_x,
          pos_y = excluded.pos_y,
          updated_at = now()
    returning id into v_view_node_id;
  end if;

  if v_want_links then
    v_links := public.utility_link_meter_neighbors(
      p_revision_id, v_node.id, p_upstream_node_id, p_downstream_node_ids,
      coalesce(p_connection_kind, 'supply'), p_water_type, p_legacy_sync_status,
      p_replace_existing_parent
    );
  end if;

  return jsonb_build_object(
    'status', case
      when v_created_asset or v_created_node then 'attached'
      when p_view_id is not null and not v_had_view then 'view_placement_added'
      when p_view_id is not null then 'view_placement_updated'
      else 'attached'
    end,
    'meter_id', v_meter.id,
    'asset_id', v_asset.id,
    'node_id', v_node.id,
    'view_node_id', v_view_node_id,
    'created_asset', v_created_asset,
    'created_node', v_created_node,
    'links', v_links,
    'lock_version', v_rev.lock_version
  );
end;
$$;

drop function if exists public.create_meter_in_network_draft(uuid, integer, uuid, text, text, text, uuid, uuid, uuid, text, uuid, uuid, double precision, double precision, uuid, uuid[], text, text, text);

create or replace function public.create_meter_in_network_draft(
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
  p_pos_y double precision default 0,
  p_upstream_node_id uuid default null,
  p_downstream_node_ids uuid[] default null,
  p_connection_kind text default 'supply',
  p_water_type text default null,
  p_legacy_sync_status text default null,
  p_replace_existing_parent boolean default false
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
  v_links jsonb := '{}'::jsonb;
  v_code text := trim(p_meter_code);
  v_name_en text := trim(p_name_en);
  v_name_ar text := coalesce(nullif(trim(p_name_ar), ''), trim(p_name_en));
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if v_code is null or v_code = '' then
    raise exception 'Meter code is required';
  end if;
  if v_name_en is null or v_name_en = '' then
    raise exception 'Meter English name is required';
  end if;

  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = v_rev.network_id and site_id = p_site_id
  ) then
    raise exception 'Asset site is not a member of this network';
  end if;
  if not public.can_manage_site_meters(p_site_id) then
    raise exception 'Not allowed to manage meters for site' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.site_utility_networks
    where id = v_rev.network_id and category_id = p_category_id
  ) then
    raise exception 'Category does not match network category';
  end if;
  if not exists (
    select 1 from public.meter_sources
    where id = p_source_id and category_id = p_category_id and is_active
  ) then
    raise exception 'Source is invalid for category';
  end if;
  if not exists (
    select 1 from public.meter_units
    where id = p_unit_id and category_id = p_category_id and is_active
  ) then
    raise exception 'Unit is invalid for category';
  end if;
  if exists (
    select 1 from public.meters
    where site_id = p_site_id and meter_code = v_code
  ) then
    raise exception 'Meter code already exists for site';
  end if;

  insert into public.meters (
    site_id, meter_code, name_en, name_ar, category_id, source_id, unit_id,
    level, is_active, include_in_dashboard
  ) values (
    p_site_id, v_code, v_name_en, v_name_ar,
    p_category_id, p_source_id, p_unit_id,
    'main'::public.meter_level, true, true
  ) returning * into v_meter;

  insert into public.site_utility_assets (
    site_id, facility_area_id, asset_type, name_en, name_ar, code,
    ref_meter_id, meter_role, created_by, updated_by
  ) values (
    p_site_id, p_facility_area_id, 'meter',
    v_meter.name_en, v_meter.name_ar, v_meter.meter_code,
    v_meter.id, coalesce(nullif(trim(p_meter_role), ''), 'main'),
    v_uid, v_uid
  ) returning * into v_asset;

  perform public.utility_default_ports_for_asset(v_asset.id, 'meter', false);

  insert into public.site_utility_revision_nodes (revision_id, asset_id)
  values (p_revision_id, v_asset.id)
  returning * into v_node;

  if p_view_id is not null then
    if not exists (
      select 1 from public.site_utility_network_views
      where id = p_view_id and network_id = v_rev.network_id
    ) then
      raise exception 'View does not belong to this network';
    end if;
    insert into public.site_utility_view_nodes (
      revision_id, view_id, node_id, pos_x, pos_y
    ) values (p_revision_id, p_view_id, v_node.id, p_pos_x, p_pos_y);
  end if;

  if p_upstream_node_id is not null or p_downstream_node_ids is not null then
    v_links := public.utility_link_meter_neighbors(
      p_revision_id, v_node.id, p_upstream_node_id, p_downstream_node_ids,
      coalesce(p_connection_kind, 'supply'), p_water_type, p_legacy_sync_status,
      p_replace_existing_parent
    );
  end if;

  return jsonb_build_object(
    'status', 'created',
    'meter_id', v_meter.id,
    'asset_id', v_asset.id,
    'node_id', v_node.id,
    'ports', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'code', p.code, 'direction', p.direction, 'port_role', p.port_role
      )), '[]'::jsonb)
      from public.site_utility_asset_ports p where p.asset_id = v_asset.id
    ),
    'links', v_links,
    'lock_version', v_rev.lock_version
  );
end;
$$;

-- connect_ports: pass replace flag
drop function if exists public.connect_ports(uuid, integer, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb);

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
  p_properties jsonb default '{}'::jsonb,
  p_replace_existing_parent boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_conn public.site_utility_revision_connections;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);
  v_conn := public.utility_connect_ports_unlocked(
    p_revision_id, p_from_node_id, p_from_port_id, p_to_node_id, p_to_port_id,
    p_connection_kind, p_water_type, p_transport_mode, p_operating_mode,
    p_legacy_sync_status, p_properties, p_replace_existing_parent
  );
  return jsonb_build_object(
    'connection_id', v_conn.id,
    'legacy_sync_status', v_conn.legacy_sync_status,
    'is_consumptive', v_conn.is_consumptive,
    'lock_version', v_rev.lock_version
  );
end;
$$;

revoke all on function public.utility_check_draft_lock(uuid, integer) from public;
revoke all on function public.utility_bump_draft_lock(uuid) from public;
revoke all on function public.utility_connect_ports_unlocked(uuid, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb, boolean) from public;
revoke all on function public.utility_link_meter_neighbors(uuid, uuid, uuid, uuid[], text, text, text, boolean) from public;

grant execute on function public.attach_existing_meter_to_draft(uuid, integer, uuid, uuid, double precision, double precision, text, uuid, uuid, uuid[], text, text, text, boolean) to authenticated;
grant execute on function public.create_meter_in_network_draft(uuid, integer, uuid, text, text, text, uuid, uuid, uuid, text, uuid, uuid, double precision, double precision, uuid, uuid[], text, text, text, boolean) to authenticated;
grant execute on function public.connect_ports(uuid, integer, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb, boolean) to authenticated;
