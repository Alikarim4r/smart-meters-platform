-- =============================================================================
-- Migration: 040_utility_network_phase_c_import_snapshot.sql
-- Phase C backend:
-- - list_utility_networks_for_site
-- - get_draft_network_snapshot / get_published_network_snapshot
-- - import_legacy_network_apply(revision_id, expected_lock_version, site_id)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- List networks for a site (readable if manage OR full snapshot read).
-- ---------------------------------------------------------------------------
create or replace function public.list_utility_networks_for_site(p_site_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rows jsonb;
begin
  if p_site_id is null then
    raise exception 'site_id is required';
  end if;

  -- Site must be accessible; networks further filtered by manage/read helpers.
  if not (public.is_super_admin() or public.has_site_access(p_site_id)) then
    raise exception 'Not allowed to access this site' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(x order by x->>'code'), '[]'::jsonb)
  into v_rows
  from (
    select jsonb_build_object(
      'network_id', n.id,
      'category_id', n.category_id,
      'code', n.code,
      'name_en', n.name_en,
      'name_ar', n.name_ar,
      'draft_revision_id', n.draft_revision_id,
      'published_revision_id', n.published_revision_id,
      'status', case
        when n.published_revision_id is not null then 'published'
        when n.draft_revision_id is not null then 'draft'
        else 'empty'
      end,
      'member_count', (
        select count(*)::int from public.site_utility_network_members m
        where m.network_id = n.id
      ),
      'default_view_id', (
        select v.id from public.site_utility_network_views v
        where v.network_id = n.id and v.is_default
        order by v.sort_order
        limit 1
      )
    ) as x
    from public.site_utility_networks n
    join public.site_utility_network_members mem
      on mem.network_id = n.id and mem.site_id = p_site_id
    where public.can_manage_utility_network(n.id)
       or public.can_read_utility_network_snapshot(n.id)
       or (
         -- Draft-only networks: visible to managers of all members (same as manage)
         public.can_manage_utility_network(n.id)
       )
  ) q;

  return jsonb_build_object(
    'site_id', p_site_id,
    'networks', coalesce(v_rows, '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Explicit draft / published snapshot loaders
-- ---------------------------------------------------------------------------
create or replace function public.get_draft_network_snapshot(p_network_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_network public.site_utility_networks;
  v_draft_id uuid;
  v_snap jsonb;
begin
  select * into v_network from public.site_utility_networks where id = p_network_id;
  if v_network.id is null then
    raise exception 'Network not found';
  end if;
  if not public.can_manage_utility_network(p_network_id) then
    raise exception 'Draft revisions are not readable' using errcode = '42501';
  end if;

  v_draft_id := v_network.draft_revision_id;
  if v_draft_id is null then
    select id into v_draft_id
    from public.site_utility_network_revisions
    where network_id = p_network_id and status = 'draft'
    order by created_at desc
    limit 1;
  end if;

  if v_draft_id is null then
    return jsonb_build_object(
      'status', 'no_draft',
      'network_id', p_network_id,
      'network', jsonb_build_object(
        'id', v_network.id,
        'code', v_network.code,
        'name_en', v_network.name_en,
        'name_ar', v_network.name_ar,
        'category_id', v_network.category_id,
        'draft_revision_id', null,
        'published_revision_id', v_network.published_revision_id
      )
    );
  end if;

  v_snap := public.get_network_snapshot(p_network_id, v_draft_id);
  return v_snap || jsonb_build_object('status', 'ok');
end;
$$;

create or replace function public.get_published_network_snapshot(p_network_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_network public.site_utility_networks;
  v_pub_id uuid;
  v_snap jsonb;
begin
  select * into v_network from public.site_utility_networks where id = p_network_id;
  if v_network.id is null then
    raise exception 'Network not found';
  end if;

  if not public.can_read_utility_network_snapshot(p_network_id)
     and not public.can_manage_utility_network(p_network_id) then
    raise exception 'Not allowed to read this network snapshot' using errcode = '42501';
  end if;

  v_pub_id := v_network.published_revision_id;
  if v_pub_id is null then
    return jsonb_build_object(
      'status', 'not_published',
      'network_id', p_network_id,
      'network', jsonb_build_object(
        'id', v_network.id,
        'code', v_network.code,
        'name_en', v_network.name_en,
        'name_ar', v_network.name_ar,
        'category_id', v_network.category_id,
        'draft_revision_id', v_network.draft_revision_id,
        'published_revision_id', null
      ),
      'revision', null,
      'nodes', '[]'::jsonb,
      'connections', '[]'::jsonb,
      'placements', '[]'::jsonb,
      'views', '[]'::jsonb,
      'members', (
        select coalesce(jsonb_agg(jsonb_build_object('site_id', m.site_id)), '[]'::jsonb)
        from public.site_utility_network_members m where m.network_id = p_network_id
      )
    );
  end if;

  -- Readers must not be able to coerce a draft via published loader.
  if exists (
    select 1 from public.site_utility_network_revisions r
    where r.id = v_pub_id and r.status <> 'published'
  ) then
    raise exception 'Published revision pointer is invalid';
  end if;

  v_snap := public.get_network_snapshot(p_network_id, v_pub_id);
  return v_snap || jsonb_build_object('status', 'ok');
end;
$$;

-- Harden generic snapshot: draft revision_id requires manage (already).
-- Explicitly reject when non-manager passes a draft revision_id.
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
  perform public.utility_require_auth();

  select * into v_network from public.site_utility_networks where id = p_network_id;
  if v_network.id is null then
    raise exception 'Network not found';
  end if;

  v_revision_id := coalesce(p_revision_id, v_network.published_revision_id);
  if v_revision_id is null then
    return jsonb_build_object(
      'status', 'not_published',
      'network_id', p_network_id,
      'revision_id', null,
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
    'status', 'ok',
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
      'network_id', v_rev.network_id,
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
            'direction', p.direction, 'port_role', p.port_role, 'properties', p.properties,
            'asset_id', p.asset_id
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
        'revision_id', c.revision_id,
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
        'revision_id', vn.revision_id,
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

-- ---------------------------------------------------------------------------
-- Import apply with required revision lock
-- ---------------------------------------------------------------------------
drop function if exists public.import_legacy_network_apply(uuid, uuid, uuid, text);

create or replace function public.import_legacy_network_apply(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_site_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev public.site_utility_network_revisions;
  v_network public.site_utility_networks;
  v_plan jsonb;
  v_view_id uuid;
  v_action jsonb;
  v_added int := 0;
  v_skipped int := 0;
  v_edges_before int := 0;
  v_edges_after int := 0;
  v_nodes_before int := 0;
  v_nodes_after int := 0;
  v_changed boolean := false;
  v_legacy_to_node jsonb := '{}'::jsonb;
  v_asset_id uuid;
  v_node_id uuid;
  v_from_node uuid;
  v_to_node uuid;
  v_from_port uuid;
  v_to_port uuid;
  v_from_asset uuid;
  v_to_asset uuid;
  v_kind text;
  v_sync text;
  v_conn_kind text;
  v_meter record;
  v_tank record;
  v_code text;
  v_ins int;
begin
  v_rev := public.utility_check_draft_lock(p_revision_id, p_expected_lock_version);
  select * into v_network from public.site_utility_networks where id = v_rev.network_id;

  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = v_rev.network_id and site_id = p_site_id
  ) then
    raise exception 'Site is not a member of this network';
  end if;
  if not public.can_manage_site_meters(p_site_id) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;

  select id into v_view_id
  from public.site_utility_network_views
  where network_id = v_rev.network_id and is_default
  limit 1;

  select count(*) into v_nodes_before
  from public.site_utility_revision_nodes where revision_id = p_revision_id;
  select count(*) into v_edges_before
  from public.site_utility_revision_connections where revision_id = p_revision_id;

  v_plan := public.import_legacy_network_plan(p_site_id, v_network.category_id, v_rev.network_id);

  -- Existing mappings
  for v_action in select * from jsonb_array_elements(v_plan->'actions')
  loop
    if v_action->>'action' = 'skipped' then
      v_skipped := v_skipped + 1;
      if v_action->>'reason' = 'meter_asset_exists' then
        select a.id into v_asset_id from public.site_utility_assets a
        join public.site_network_nodes n on n.ref_meter_id = a.ref_meter_id
        where n.id = (v_action->>'legacy_node_id')::uuid and a.status = 'active'
        limit 1;
      elsif v_action->>'reason' = 'tank_asset_exists' then
        select a.id into v_asset_id from public.site_utility_assets a
        join public.site_network_nodes n on n.ref_tank_id = a.ref_tank_id
        where n.id = (v_action->>'legacy_node_id')::uuid and a.status = 'active'
        limit 1;
      else
        continue;
      end if;
      if v_asset_id is null then continue; end if;

      insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
      values (p_revision_id, v_asset_id, (v_action->>'legacy_node_id')::uuid)
      on conflict (revision_id, asset_id) do update
        set legacy_node_id = coalesce(site_utility_revision_nodes.legacy_node_id, excluded.legacy_node_id)
      returning id into v_node_id;
      get diagnostics v_ins = row_count;
      if v_ins > 0 then v_changed := true; end if;

      v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);

      if v_view_id is not null then
        insert into public.site_utility_view_nodes (revision_id, view_id, node_id, pos_x, pos_y)
        select p_revision_id, v_view_id, v_node_id, n.pos_x, n.pos_y
        from public.site_network_nodes n
        where n.id = (v_action->>'legacy_node_id')::uuid
        on conflict (revision_id, view_id, node_id) do nothing;
        get diagnostics v_ins = row_count;
        if v_ins > 0 then v_changed := true; end if;
      end if;
    end if;
  end loop;

  for v_action in select * from jsonb_array_elements(v_plan->'actions')
  loop
    if v_action->>'action' = 'add_meter_asset' then
      if exists (
        select 1 from public.site_utility_revision_nodes
        where revision_id = p_revision_id
          and legacy_node_id = (v_action->>'legacy_node_id')::uuid
      ) then
        v_skipped := v_skipped + 1;
        select id into v_node_id from public.site_utility_revision_nodes
        where revision_id = p_revision_id and legacy_node_id = (v_action->>'legacy_node_id')::uuid;
        v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
        continue;
      end if;
      select * into v_meter from public.meters where id = (v_action->>'ref_meter_id')::uuid;
      select id into v_asset_id from public.site_utility_assets
      where ref_meter_id = v_meter.id and status = 'active' limit 1;
      if v_asset_id is null then
        insert into public.site_utility_assets (
          site_id, asset_type, name_en, name_ar, code, ref_meter_id, meter_role, created_by, updated_by
        ) values (
          p_site_id, 'meter', v_meter.name_en, coalesce(v_meter.name_ar, v_meter.name_en),
          v_meter.meter_code, v_meter.id, 'process', v_uid, v_uid
        ) returning id into v_asset_id;
        perform public.utility_default_ports_for_asset(v_asset_id, 'meter', false);
        v_changed := true;
      end if;
      insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
      values (p_revision_id, v_asset_id, (v_action->>'legacy_node_id')::uuid)
      on conflict (revision_id, asset_id) do update
        set legacy_node_id = coalesce(site_utility_revision_nodes.legacy_node_id, excluded.legacy_node_id)
      returning id into v_node_id;
      v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
      if v_view_id is not null then
        insert into public.site_utility_view_nodes (revision_id, view_id, node_id, pos_x, pos_y)
        values (
          p_revision_id, v_view_id, v_node_id,
          (v_action->>'pos_x')::double precision,
          (v_action->>'pos_y')::double precision
        )
        on conflict (revision_id, view_id, node_id) do nothing;
      end if;
      v_added := v_added + 1;
      v_changed := true;

    elsif v_action->>'action' = 'add_tank_asset' then
      if exists (
        select 1 from public.site_utility_revision_nodes
        where revision_id = p_revision_id
          and legacy_node_id = (v_action->>'legacy_node_id')::uuid
      ) then
        v_skipped := v_skipped + 1;
        select id into v_node_id from public.site_utility_revision_nodes
        where revision_id = p_revision_id and legacy_node_id = (v_action->>'legacy_node_id')::uuid;
        v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
        continue;
      end if;
      select * into v_tank from public.site_tanks where id = (v_action->>'ref_tank_id')::uuid;
      select id into v_asset_id from public.site_utility_assets
      where ref_tank_id = v_tank.id and status = 'active' limit 1;
      if v_asset_id is null then
        v_code := 'tank-' || substr(v_tank.id::text, 1, 8);
        insert into public.site_utility_assets (
          site_id, asset_type, name_en, name_ar, code, ref_tank_id, created_by, updated_by
        ) values (
          p_site_id, 'tank', v_tank.name_en, coalesce(v_tank.name_ar, v_tank.name_en),
          v_code, v_tank.id, v_uid, v_uid
        ) returning id into v_asset_id;
        perform public.utility_default_ports_for_asset(v_asset_id, 'tank', true);
        v_changed := true;
      end if;
      insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
      values (p_revision_id, v_asset_id, (v_action->>'legacy_node_id')::uuid)
      on conflict (revision_id, asset_id) do update
        set legacy_node_id = coalesce(site_utility_revision_nodes.legacy_node_id, excluded.legacy_node_id)
      returning id into v_node_id;
      v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
      if v_view_id is not null then
        insert into public.site_utility_view_nodes (revision_id, view_id, node_id, pos_x, pos_y)
        values (
          p_revision_id, v_view_id, v_node_id,
          (v_action->>'pos_x')::double precision,
          (v_action->>'pos_y')::double precision
        )
        on conflict do nothing;
      end if;
      v_added := v_added + 1;
      v_changed := true;

    elsif v_action->>'action' = 'add_tanker_loading' then
      if exists (
        select 1 from public.site_utility_revision_nodes
        where revision_id = p_revision_id
          and legacy_node_id = (v_action->>'legacy_node_id')::uuid
      ) then
        v_skipped := v_skipped + 1;
        select id into v_node_id from public.site_utility_revision_nodes
        where revision_id = p_revision_id and legacy_node_id = (v_action->>'legacy_node_id')::uuid;
        v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
        continue;
      end if;
      v_code := 'tanker-' || substr(v_action->>'legacy_node_id', 1, 8);
      select id into v_asset_id from public.site_utility_assets
      where site_id = p_site_id and code = v_code and status = 'active' limit 1;
      if v_asset_id is null then
        begin
          insert into public.site_utility_assets (
            site_id, asset_type, service_type, name_en, name_ar, code, created_by, updated_by
          ) values (
            p_site_id, 'tanker_loading', 'offsite_disposal',
            coalesce(v_action->>'label_en', 'Tanker loading'),
            coalesce(v_action->>'label_ar', 'تحميل تانكر'),
            v_code, v_uid, v_uid
          ) returning id into v_asset_id;
          perform public.utility_default_ports_for_asset(v_asset_id, 'tanker_loading', false);
          v_changed := true;
        exception when unique_violation then
          select id into v_asset_id from public.site_utility_assets
          where site_id = p_site_id and code = v_code limit 1;
        end;
      end if;
      insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
      values (p_revision_id, v_asset_id, (v_action->>'legacy_node_id')::uuid)
      on conflict (revision_id, asset_id) do update
        set legacy_node_id = coalesce(site_utility_revision_nodes.legacy_node_id, excluded.legacy_node_id)
      returning id into v_node_id;
      v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
      if v_view_id is not null then
        insert into public.site_utility_view_nodes (revision_id, view_id, node_id, pos_x, pos_y)
        values (
          p_revision_id, v_view_id, v_node_id,
          (v_action->>'pos_x')::double precision,
          (v_action->>'pos_y')::double precision
        )
        on conflict do nothing;
      end if;
      v_added := v_added + 1;
      v_changed := true;

    elsif v_action->>'action' = 'add_discharge_point' then
      if exists (
        select 1 from public.site_utility_revision_nodes
        where revision_id = p_revision_id
          and legacy_node_id = (v_action->>'legacy_node_id')::uuid
      ) then
        v_skipped := v_skipped + 1;
        select id into v_node_id from public.site_utility_revision_nodes
        where revision_id = p_revision_id and legacy_node_id = (v_action->>'legacy_node_id')::uuid;
        v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
        continue;
      end if;
      v_code := 'drain-' || substr(v_action->>'legacy_node_id', 1, 8);
      select id into v_asset_id from public.site_utility_assets
      where site_id = p_site_id and code = v_code and status = 'active' limit 1;
      if v_asset_id is null then
        begin
          insert into public.site_utility_assets (
            site_id, asset_type, service_type, name_en, name_ar, code, created_by, updated_by
          ) values (
            p_site_id, 'discharge_point', 'floor_drain',
            coalesce(v_action->>'label_en', 'Ground drain'),
            coalesce(v_action->>'label_ar', 'صرف أرضي'),
            v_code, v_uid, v_uid
          ) returning id into v_asset_id;
          perform public.utility_default_ports_for_asset(v_asset_id, 'discharge_point', false);
          v_changed := true;
        exception when unique_violation then
          select id into v_asset_id from public.site_utility_assets
          where site_id = p_site_id and code = v_code limit 1;
        end;
      end if;
      insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
      values (p_revision_id, v_asset_id, (v_action->>'legacy_node_id')::uuid)
      on conflict (revision_id, asset_id) do update
        set legacy_node_id = coalesce(site_utility_revision_nodes.legacy_node_id, excluded.legacy_node_id)
      returning id into v_node_id;
      v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
      if v_view_id is not null then
        insert into public.site_utility_view_nodes (revision_id, view_id, node_id, pos_x, pos_y)
        values (
          p_revision_id, v_view_id, v_node_id,
          (v_action->>'pos_x')::double precision,
          (v_action->>'pos_y')::double precision
        )
        on conflict do nothing;
      end if;
      v_added := v_added + 1;
      v_changed := true;
    end if;
  end loop;

  select coalesce(jsonb_object_agg(legacy_node_id::text, id::text), '{}'::jsonb)
    into v_legacy_to_node
  from public.site_utility_revision_nodes
  where revision_id = p_revision_id and legacy_node_id is not null;

  for v_action in select * from jsonb_array_elements(v_plan->'actions')
  loop
    if v_action->>'action' <> 'add_connection' then
      continue;
    end if;
    v_from_node := (v_legacy_to_node->> (v_action->>'from_legacy_node_id'))::uuid;
    v_to_node := (v_legacy_to_node->> (v_action->>'to_legacy_node_id'))::uuid;
    if v_from_node is null or v_to_node is null then
      continue;
    end if;

    select asset_id into v_from_asset from public.site_utility_revision_nodes where id = v_from_node;
    select asset_id into v_to_asset from public.site_utility_revision_nodes where id = v_to_node;

    v_kind := v_action->>'edge_kind';
    v_conn_kind := case v_kind
      when 'pour' then 'transfer'
      when 'supply' then 'supply'
      when 'overflow' then 'overflow'
      when 'washout' then 'washout'
      when 'discharge' then 'discharge'
      else 'transfer'
    end;
    v_sync := v_action->>'legacy_sync_status';

    if v_conn_kind in ('overflow', 'washout', 'drain') then
      perform public.utility_default_ports_for_asset(v_from_asset, 'tank', true);
    end if;

    if v_conn_kind = 'overflow' then
      select id into v_from_port from public.site_utility_asset_ports
      where asset_id = v_from_asset and port_role = 'overflow' limit 1;
    elsif v_conn_kind = 'washout' then
      select id into v_from_port from public.site_utility_asset_ports
      where asset_id = v_from_asset and port_role in ('washout', 'drain')
      order by case port_role when 'washout' then 0 else 1 end limit 1;
    elsif v_conn_kind = 'drain' then
      select id into v_from_port from public.site_utility_asset_ports
      where asset_id = v_from_asset and port_role = 'drain' limit 1;
    elsif v_conn_kind in ('discharge', 'tanker_transport') then
      select id into v_from_port from public.site_utility_asset_ports
      where asset_id = v_from_asset
        and port_role in ('tanker_transfer', 'outlet', 'drain', 'overflow')
      order by case port_role
        when 'tanker_transfer' then 0 when 'outlet' then 1 when 'drain' then 2 else 3
      end limit 1;
    else
      select id into v_from_port from public.site_utility_asset_ports
      where asset_id = v_from_asset and direction in ('out', 'bidirectional')
      order by case port_role
        when 'outlet' then 0 when 'product' then 1 when 'tanker_transfer' then 2 else 3
      end limit 1;
    end if;

    select id into v_to_port from public.site_utility_asset_ports
    where asset_id = v_to_asset and direction in ('in', 'bidirectional')
    order by case port_role when 'inlet' then 0 else 1 end
    limit 1;

    if v_from_port is null or v_to_port is null then
      continue;
    end if;

    insert into public.site_utility_revision_connections (
      revision_id, from_node_id, from_port_id, to_node_id, to_port_id,
      connection_kind, transport_mode, legacy_sync_status, legacy_edge_id
    ) values (
      p_revision_id, v_from_node, v_from_port, v_to_node, v_to_port,
      v_conn_kind,
      case when v_conn_kind in ('overflow', 'washout', 'drain', 'discharge')
        then 'open_drain' else 'pipe' end,
      v_sync, (v_action->>'legacy_edge_id')::uuid
    )
    on conflict (revision_id, from_port_id, to_port_id, connection_kind) do nothing;
    get diagnostics v_ins = row_count;
    if v_ins > 0 then v_changed := true; end if;
  end loop;

  select count(*) into v_nodes_after
  from public.site_utility_revision_nodes where revision_id = p_revision_id;
  select count(*) into v_edges_after
  from public.site_utility_revision_connections where revision_id = p_revision_id;

  -- Idempotent: bump lock only when graph size actually grew.
  v_changed := (v_nodes_after > v_nodes_before) or (v_edges_after > v_edges_before);

  if v_changed then
    v_rev := public.utility_bump_draft_lock(p_revision_id);
  end if;

  return jsonb_build_object(
    'dry_run', false,
    'status', case when v_changed then 'imported' else 'unchanged' end,
    'changed', v_changed,
    'network_id', v_rev.network_id,
    'draft_revision_id', p_revision_id,
    'lock_version', v_rev.lock_version,
    'default_view_id', v_view_id,
    'assets_added', v_added,
    'assets_skipped', v_skipped,
    'nodes_before', v_nodes_before,
    'nodes_after', v_nodes_after,
    'connections_before', v_edges_before,
    'connections_after', v_edges_after,
    'legacy_nodes', v_plan->'legacy_nodes',
    'legacy_edges', v_plan->'legacy_edges',
    'plan', v_plan
  );
end;
$$;

revoke all on function public.list_utility_networks_for_site(uuid) from public;
revoke all on function public.get_draft_network_snapshot(uuid) from public;
revoke all on function public.get_published_network_snapshot(uuid) from public;
revoke all on function public.import_legacy_network_apply(uuid, integer, uuid) from public;

grant execute on function public.list_utility_networks_for_site(uuid) to authenticated;
grant execute on function public.get_draft_network_snapshot(uuid) to authenticated;
grant execute on function public.get_published_network_snapshot(uuid) to authenticated;
grant execute on function public.import_legacy_network_apply(uuid, integer, uuid) to authenticated;
grant execute on function public.get_network_snapshot(uuid, uuid) to authenticated;
