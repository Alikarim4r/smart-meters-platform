-- =============================================================================
-- Migration: 038_utility_network_meter_picker_rpcs.sql
-- Phase A additions for existing/new meter placement in network drafts.
-- - list_available_meters_for_network
-- - attach_existing_meter_to_draft (no new meters row; no duplicate asset/node)
-- - create_meter_in_network_draft (atomic create + optional links + parent sync)
-- Does not modify 031 tables. Does not touch Production by itself.
-- =============================================================================

-- Internal connection writer (no lock bump). Call only after utility_assert_draft_lock.
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
  p_properties jsonb default '{}'::jsonb
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

-- Resolve default outlet/inlet ports for meter (or first out/in).
create or replace function public.utility_default_out_port(p_asset_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.site_utility_asset_ports
  where asset_id = p_asset_id
    and direction in ('out', 'bidirectional')
  order by case port_role
    when 'outlet' then 0
    when 'product' then 1
    when 'tanker_transfer' then 2
    else 3
  end, code
  limit 1;
$$;

create or replace function public.utility_default_in_port(p_asset_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.site_utility_asset_ports
  where asset_id = p_asset_id
    and direction in ('in', 'bidirectional')
  order by case port_role when 'inlet' then 0 else 1 end, code
  limit 1;
$$;

create or replace function public.utility_link_meter_neighbors(
  p_revision_id uuid,
  p_new_node_id uuid,
  p_upstream_node_id uuid,
  p_downstream_node_ids uuid[],
  p_connection_kind text default 'supply',
  p_water_type text default null,
  p_legacy_sync_status text default null
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
      p_legacy_sync_status, '{}'::jsonb
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
        p_legacy_sync_status, '{}'::jsonb
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

-- ---------------------------------------------------------------------------
-- List meters available for network editor (member sites only).
-- status: not_in_network | in_network_not_in_current_view | in_current_view
-- ---------------------------------------------------------------------------
create or replace function public.list_available_meters_for_network(
  p_network_id uuid,
  p_revision_id uuid default null,
  p_view_id uuid default null,
  p_site_id uuid default null,
  p_search text default null,
  p_limit integer default 200
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev_id uuid;
  v_view_id uuid;
  v_category uuid;
  v_rows jsonb;
begin
  if not public.can_manage_utility_network(p_network_id) then
    raise exception 'Not allowed to manage this utility network' using errcode = '42501';
  end if;

  select category_id into v_category
  from public.site_utility_networks where id = p_network_id;
  if v_category is null then
    raise exception 'Network not found';
  end if;

  if p_revision_id is not null then
    v_rev_id := p_revision_id;
    if not exists (
      select 1 from public.site_utility_network_revisions
      where id = v_rev_id and network_id = p_network_id
    ) then
      raise exception 'Revision does not belong to network';
    end if;
  else
    select draft_revision_id into v_rev_id
    from public.site_utility_networks where id = p_network_id;
    if v_rev_id is null then
      select id into v_rev_id
      from public.site_utility_network_revisions
      where network_id = p_network_id and status = 'draft'
      order by created_at desc
      limit 1;
    end if;
  end if;

  v_view_id := p_view_id;
  if v_view_id is null then
    select id into v_view_id
    from public.site_utility_network_views
    where network_id = p_network_id and is_default
    limit 1;
  end if;

  if p_site_id is not null and not exists (
    select 1 from public.site_utility_network_members
    where network_id = p_network_id and site_id = p_site_id
  ) then
    raise exception 'Site is not a member of this network';
  end if;

  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.meter_code), '[]'::jsonb)
  into v_rows
  from (
    select
      m.id as meter_id,
      m.site_id,
      m.meter_code,
      m.name_en,
      m.name_ar,
      m.category_id,
      m.source_id,
      m.unit_id,
      m.level::text as meter_level,
      m.parent_meter_id,
      a.id as asset_id,
      rn.id as node_id,
      case
        when rn.id is null then 'not_in_network'
        when v_view_id is not null and exists (
          select 1 from public.site_utility_view_nodes vn
          where vn.revision_id = v_rev_id
            and vn.view_id = v_view_id
            and vn.node_id = rn.id
        ) then 'in_current_view'
        when rn.id is not null then 'in_network_not_in_current_view'
        else 'not_in_network'
      end as availability_status
    from public.meters m
    join public.site_utility_network_members mem
      on mem.network_id = p_network_id and mem.site_id = m.site_id
    left join public.site_utility_assets a
      on a.ref_meter_id = m.id and a.status = 'active'
    left join public.site_utility_revision_nodes rn
      on rn.revision_id = v_rev_id and rn.asset_id = a.id
    where m.is_active
      and m.category_id = v_category
      and (p_site_id is null or m.site_id = p_site_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or m.meter_code ilike '%' || trim(p_search) || '%'
        or coalesce(m.name_en, '') ilike '%' || trim(p_search) || '%'
        or coalesce(m.name_ar, '') ilike '%' || trim(p_search) || '%'
      )
    order by m.meter_code
    limit greatest(1, least(coalesce(p_limit, 200), 1000))
  ) x;

  return jsonb_build_object(
    'network_id', p_network_id,
    'revision_id', v_rev_id,
    'view_id', v_view_id,
    'meters', coalesce(v_rows, '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Attach existing meter: reuse meters row; upsert asset + revision node + view.
-- ---------------------------------------------------------------------------
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
  p_legacy_sync_status text default null
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
  v_created_asset boolean := false;
  v_created_node boolean := false;
  v_links jsonb := '{}'::jsonb;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

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
    if v_asset.site_id is distinct from v_meter.site_id then
      raise exception 'Existing meter asset site mismatch';
    end if;
    perform public.utility_default_ports_for_asset(v_asset.id, 'meter', false);
    if p_facility_area_id is not null and v_asset.facility_area_id is distinct from p_facility_area_id then
      update public.site_utility_assets
      set facility_area_id = p_facility_area_id, updated_by = v_uid, updated_at = now()
      where id = v_asset.id
      returning * into v_asset;
    end if;
  end if;

  select * into v_node
  from public.site_utility_revision_nodes
  where revision_id = p_revision_id and asset_id = v_asset.id;

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
          updated_at = now();
  end if;

  if p_upstream_node_id is not null or p_downstream_node_ids is not null then
    v_links := public.utility_link_meter_neighbors(
      p_revision_id, v_node.id, p_upstream_node_id, p_downstream_node_ids,
      coalesce(p_connection_kind, 'supply'), p_water_type, p_legacy_sync_status
    );
  end if;

  return jsonb_build_object(
    'meter_id', v_meter.id,
    'asset_id', v_asset.id,
    'node_id', v_node.id,
    'created_asset', v_created_asset,
    'created_node', v_created_node,
    'links', v_links,
    'lock_version', v_rev.lock_version
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Atomic create new meter in draft (+ optional upstream/downstream links).
-- ---------------------------------------------------------------------------
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
  p_legacy_sync_status text default null
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
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = v_rev.network_id and site_id = p_site_id
  ) then
    raise exception 'Asset site is not a member of this network';
  end if;

  if not exists (
    select 1 from public.site_utility_networks
    where id = v_rev.network_id and category_id = p_category_id
  ) then
    raise exception 'Category does not match network category';
  end if;

  -- Insert as main first; synced upstream link sets parent_meter_id + level.
  insert into public.meters (
    site_id, meter_code, name_en, name_ar, category_id, source_id, unit_id,
    level, is_active, include_in_dashboard
  ) values (
    p_site_id, trim(p_meter_code), trim(p_name_en),
    coalesce(nullif(trim(p_name_ar), ''), trim(p_name_en)),
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
      coalesce(p_connection_kind, 'supply'), p_water_type, p_legacy_sync_status
    );
  end if;

  return jsonb_build_object(
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

-- Keep public.connect_ports using unlocked helper (single lock bump).
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
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);
  v_conn := public.utility_connect_ports_unlocked(
    p_revision_id, p_from_node_id, p_from_port_id, p_to_node_id, p_to_port_id,
    p_connection_kind, p_water_type, p_transport_mode, p_operating_mode,
    p_legacy_sync_status, p_properties
  );
  return jsonb_build_object(
    'connection_id', v_conn.id,
    'legacy_sync_status', v_conn.legacy_sync_status,
    'is_consumptive', v_conn.is_consumptive,
    'lock_version', v_rev.lock_version
  );
end;
$$;

revoke all on function public.list_available_meters_for_network(uuid, uuid, uuid, uuid, text, integer) from public;
revoke all on function public.attach_existing_meter_to_draft(uuid, integer, uuid, uuid, double precision, double precision, text, uuid, uuid, uuid[], text, text, text) from public;
revoke all on function public.create_meter_in_network_draft(uuid, integer, uuid, text, text, text, uuid, uuid, uuid, text, uuid, uuid, double precision, double precision, uuid, uuid[], text, text, text) from public;
revoke all on function public.utility_connect_ports_unlocked(uuid, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb) from public;
revoke all on function public.utility_link_meter_neighbors(uuid, uuid, uuid, uuid[], text, text, text) from public;

grant execute on function public.list_available_meters_for_network(uuid, uuid, uuid, uuid, text, integer) to authenticated;
grant execute on function public.attach_existing_meter_to_draft(uuid, integer, uuid, uuid, double precision, double precision, text, uuid, uuid, uuid[], text, text, text) to authenticated;
grant execute on function public.create_meter_in_network_draft(uuid, integer, uuid, text, text, text, uuid, uuid, uuid, text, uuid, uuid, double precision, double precision, uuid, uuid[], text, text, text) to authenticated;
-- unlocked helpers: no grant to authenticated (SECURITY DEFINER callers only)

comment on function public.list_available_meters_for_network is
  'Editor meter picker: meters on member sites with availability_status for draft+view.';
comment on function public.attach_existing_meter_to_draft is
  'Place an existing meters row into draft (reuse asset/node; optional links).';
comment on function public.create_meter_in_network_draft is
  'Atomic new meter + asset + ports + node + view + optional upstream/downstream links.';
