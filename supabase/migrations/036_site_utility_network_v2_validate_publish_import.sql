-- =============================================================================
-- Migration: 036_site_utility_network_v2_validate_publish_import.sql
-- validate_network_draft, publish_network_draft, import 031, reconcile.
-- =============================================================================

create or replace function public.validate_network_draft(p_revision_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_errors jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  r record;
begin
  select * into v_rev from public.site_utility_network_revisions where id = p_revision_id;
  if v_rev.id is null then
    raise exception 'Revision not found';
  end if;
  if v_rev.status <> 'draft' then
    raise exception 'validate_network_draft only applies to draft revisions';
  end if;
  if not public.can_manage_utility_network(v_rev.network_id) then
    raise exception 'Not allowed to manage this utility network' using errcode = '42501';
  end if;

  -- Orphan / member checks
  for r in
    select n.id as node_id, a.id as asset_id, a.site_id, a.code
    from public.site_utility_revision_nodes n
    join public.site_utility_assets a on a.id = n.asset_id
    where n.revision_id = p_revision_id
      and not exists (
        select 1 from public.site_utility_network_members m
        where m.network_id = v_rev.network_id and m.site_id = a.site_id
      )
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'asset_site_not_member',
      'severity', 'error',
      'node_id', r.node_id,
      'asset_id', r.asset_id,
      'message', format('Asset %s site is not a network member', r.code)
    ));
  end loop;

  -- Meter/tank ref site drift (should be prevented by trigger; still report)
  for r in
    select a.id, a.code, a.site_id, a.ref_meter_id
    from public.site_utility_revision_nodes n
    join public.site_utility_assets a on a.id = n.asset_id
    join public.meters m on m.id = a.ref_meter_id
    where n.revision_id = p_revision_id and m.site_id <> a.site_id
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'meter_site_mismatch',
      'severity', 'error',
      'asset_id', r.id,
      'message', format('Meter ref site mismatch for %s', r.code)
    ));
  end loop;

  for r in
    select a.id, a.code
    from public.site_utility_revision_nodes n
    join public.site_utility_assets a on a.id = n.asset_id
    join public.site_tanks t on t.id = a.ref_tank_id
    where n.revision_id = p_revision_id and t.site_id <> a.site_id
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'tank_site_mismatch',
      'severity', 'error',
      'asset_id', r.id,
      'message', format('Tank ref site mismatch for %s', r.code)
    ));
  end loop;

  -- Discharge outflow (also enforced by trigger)
  for r in
    select c.id
    from public.site_utility_revision_connections c
    join public.site_utility_revision_nodes n on n.id = c.from_node_id
    join public.site_utility_assets a on a.id = n.asset_id
    where c.revision_id = p_revision_id and a.asset_type = 'discharge_point'
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'discharge_has_outflow',
      'severity', 'error',
      'connection_id', r.id,
      'message', 'Discharge point cannot have outgoing connections'
    ));
  end loop;

  -- Overflow / washout without destination already impossible if connection exists;
  -- warn tanks that have overflow port but no overflow connection
  for r in
    select a.code, a.id as asset_id, p.port_role
    from public.site_utility_revision_nodes n
    join public.site_utility_assets a on a.id = n.asset_id
    join public.site_utility_asset_ports p on p.asset_id = a.id
    where n.revision_id = p_revision_id
      and a.asset_type = 'tank'
      and p.port_role in ('overflow', 'washout')
      and not exists (
        select 1 from public.site_utility_revision_connections c
        where c.revision_id = p_revision_id and c.from_port_id = p.id
      )
  loop
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'tank_aux_port_unconnected',
      'severity', 'warning',
      'asset_id', r.asset_id,
      'message', format('Tank %s %s port has no connection', r.code, r.port_role)
    ));
  end loop;

  -- TSE / RO reject into potable path (configurable warning/error via water_type)
  for r in
    select c.id, c.water_type, fp.port_role, ta.service_type as to_service
    from public.site_utility_revision_connections c
    join public.site_utility_asset_ports fp on fp.id = c.from_port_id
    join public.site_utility_revision_nodes tn on tn.id = c.to_node_id
    join public.site_utility_assets ta on ta.id = tn.asset_id
    where c.revision_id = p_revision_id
      and (
        fp.port_role = 'reject'
        or c.water_type in ('tse', 'ro_reject')
        or exists (
          select 1 from public.site_utility_revision_nodes fn
          join public.site_utility_assets fa on fa.id = fn.asset_id
          where fn.id = c.from_node_id and fa.service_type in ('tse', 'ro_reject')
        )
      )
      and (
        ta.service_type = 'potable'
        or c.water_type = 'potable'
      )
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'non_potable_into_potable',
      'severity', 'error',
      'connection_id', r.id,
      'message', 'Non-potable / RO reject must not connect into potable path'
    ));
  end loop;

  -- Cycles not marked recirculation (directed graph DFS on nodes)
  for r in
    with recursive edges as (
      select from_node_id, to_node_id, connection_kind, id
      from public.site_utility_revision_connections
      where revision_id = p_revision_id
    ),
    walk as (
      select e.from_node_id as start_id, e.to_node_id as node_id,
             array[e.from_node_id, e.to_node_id] as path,
             e.connection_kind = 'recirculation' as has_recirc,
             e.id as edge_id,
             1 as depth
      from edges e
      union all
      select w.start_id, e.to_node_id,
             w.path || e.to_node_id,
             w.has_recirc or (e.connection_kind = 'recirculation'),
             e.id,
             w.depth + 1
      from walk w
      join edges e on e.from_node_id = w.node_id
      where w.depth < 64
        and not (e.to_node_id = any (w.path))
    )
    select distinct w.edge_id as id
    from walk w
    join edges e on e.from_node_id = w.node_id and e.to_node_id = w.start_id
    where not w.has_recirc
      and e.connection_kind <> 'recirculation'
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'cycle_without_recirculation',
      'severity', 'error',
      'connection_id', r.id,
      'message', 'Graph cycle detected without recirculation classification'
    ));
  end loop;

  -- parent_meter_id projection cycle among synced meter→meter edges
  for r in
    with recursive synced as (
      select
        fa.ref_meter_id as parent_id,
        ta.ref_meter_id as child_id,
        c.id as connection_id
      from public.site_utility_revision_connections c
      join public.site_utility_revision_nodes fn on fn.id = c.from_node_id
      join public.site_utility_revision_nodes tn on tn.id = c.to_node_id
      join public.site_utility_assets fa on fa.id = fn.asset_id
      join public.site_utility_assets ta on ta.id = tn.asset_id
      where c.revision_id = p_revision_id
        and c.legacy_sync_status = 'synced'
        and fa.asset_type = 'meter' and ta.asset_type = 'meter'
    ),
    walk as (
      select child_id as id, parent_id, array[child_id] as path, connection_id, 1 as depth
      from synced
      union all
      select s.child_id, s.parent_id, w.path || s.child_id, s.connection_id, w.depth + 1
      from walk w
      join synced s on s.parent_id = w.id
      where w.depth < 32 and not (s.child_id = any (w.path))
    )
    select connection_id as id
    from walk
    where parent_id = any (path)
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'legacy_parent_meter_cycle',
      'severity', 'error',
      'connection_id', r.id,
      'message', 'Synced meter hierarchy would form a parent_meter_id cycle'
    ));
  end loop;

  -- Legacy sync conflicts (expected parent differs)
  for r in
    select c.id, ta.ref_meter_id as child_id, fa.ref_meter_id as expected_parent, m.parent_meter_id as actual_parent
    from public.site_utility_revision_connections c
    join public.site_utility_revision_nodes fn on fn.id = c.from_node_id
    join public.site_utility_revision_nodes tn on tn.id = c.to_node_id
    join public.site_utility_assets fa on fa.id = fn.asset_id
    join public.site_utility_assets ta on ta.id = tn.asset_id
    join public.meters m on m.id = ta.ref_meter_id
    where c.revision_id = p_revision_id
      and c.legacy_sync_status = 'synced'
      and fa.asset_type = 'meter' and ta.asset_type = 'meter'
      and m.parent_meter_id is distinct from fa.ref_meter_id
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'legacy_sync_conflict_parent',
      'severity', 'error',
      'connection_id', r.id,
      'message', 'Synced meter→meter edge conflicts with meters.parent_meter_id'
    ));
  end loop;

  -- Potable into non-potable without documented protection → warning
  for r in
    select c.id
    from public.site_utility_revision_connections c
    join public.site_utility_revision_nodes fn on fn.id = c.from_node_id
    join public.site_utility_assets fa on fa.id = fn.asset_id
    join public.site_utility_revision_nodes tn on tn.id = c.to_node_id
    join public.site_utility_assets ta on ta.id = tn.asset_id
    where c.revision_id = p_revision_id
      and (fa.service_type = 'potable' or c.water_type = 'potable')
      and ta.service_type is not null
      and ta.service_type not in ('potable', 'fountain')
      and coalesce(c.properties->>'protection', '') = ''
  loop
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'potable_to_non_potable_unprotected',
      'severity', 'warning',
      'connection_id', r.id,
      'message', 'Potable connected to non-potable without recorded protection'
    ));
  end loop;

  return jsonb_build_object(
    'revision_id', p_revision_id,
    'ok', jsonb_array_length(v_errors) = 0,
    'errors', v_errors,
    'warnings', v_warnings
  );
end;
$$;

create or replace function public.utility_clone_revision_content(
  p_from_revision_id uuid,
  p_to_revision_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_node_map jsonb := '{}'::jsonb;
  r record;
  v_new_node uuid;
begin
  for r in
    select * from public.site_utility_revision_nodes where revision_id = p_from_revision_id
  loop
    insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
    values (p_to_revision_id, r.asset_id, r.legacy_node_id)
    returning id into v_new_node;
    v_node_map := v_node_map || jsonb_build_object(r.id::text, v_new_node::text);
  end loop;

  for r in
    select * from public.site_utility_revision_connections where revision_id = p_from_revision_id
  loop
    insert into public.site_utility_revision_connections (
      revision_id, from_node_id, from_port_id, to_node_id, to_port_id,
      connection_kind, water_type, transport_mode, operating_mode, priority,
      normally_open, is_consumptive, legacy_sync_status, legacy_edge_id, properties
    ) values (
      p_to_revision_id,
      (v_node_map->>r.from_node_id::text)::uuid,
      r.from_port_id,
      (v_node_map->>r.to_node_id::text)::uuid,
      r.to_port_id,
      r.connection_kind, r.water_type, r.transport_mode, r.operating_mode, r.priority,
      r.normally_open, r.is_consumptive, r.legacy_sync_status, r.legacy_edge_id, r.properties
    );
  end loop;

  for r in
    select * from public.site_utility_view_nodes where revision_id = p_from_revision_id
  loop
    insert into public.site_utility_view_nodes (
      revision_id, view_id, node_id, pos_x, pos_y, width, height, collapsed
    ) values (
      p_to_revision_id,
      r.view_id,
      (v_node_map->>r.node_id::text)::uuid,
      r.pos_x, r.pos_y, r.width, r.height, r.collapsed
    );
  end loop;
end;
$$;

create or replace function public.publish_network_draft(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_allow_warnings boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev public.site_utility_network_revisions;
  v_validation jsonb;
  v_new_draft public.site_utility_network_revisions;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  v_validation := public.validate_network_draft(p_revision_id);
  if not (v_validation->>'ok')::boolean then
    raise exception 'Publish blocked by validation errors: %', v_validation->>'errors';
  end if;
  if not p_allow_warnings
     and jsonb_array_length(v_validation->'warnings') > 0 then
    raise exception 'Publish blocked by warnings';
  end if;

  update public.site_utility_network_revisions
  set status = 'published',
      published_at = now(),
      published_by = v_uid
  where id = p_revision_id;

  insert into public.site_utility_network_revisions (
    network_id, status, lock_version, based_on_revision_id, created_by
  ) values (
    v_rev.network_id, 'draft', 1, p_revision_id, v_uid
  ) returning * into v_new_draft;

  perform public.utility_clone_revision_content(p_revision_id, v_new_draft.id);

  update public.site_utility_networks
  set published_revision_id = p_revision_id,
      draft_revision_id = v_new_draft.id,
      updated_at = now(),
      updated_by = v_uid
  where id = v_rev.network_id;

  return jsonb_build_object(
    'published_revision_id', p_revision_id,
    'new_draft_revision_id', v_new_draft.id,
    'lock_version', v_new_draft.lock_version,
    'validation', v_validation
  );
end;
$$;

-- Shared import planner (dry-run + apply)
create or replace function public.import_legacy_network_plan(
  p_site_id uuid,
  p_category_id uuid,
  p_network_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nodes int;
  v_edges int;
  v_existing_assets int := 0;
  v_actions jsonb := '[]'::jsonb;
  r record;
begin
  if not public.can_manage_site_meters(p_site_id) then
    raise exception 'Not allowed to manage meters for site' using errcode = '42501';
  end if;

  select count(*) into v_nodes
  from public.site_network_nodes
  where site_id = p_site_id and category_id = p_category_id and is_active;

  select count(*) into v_edges
  from public.site_network_edges
  where site_id = p_site_id and category_id = p_category_id;

  for r in
    select n.*
    from public.site_network_nodes n
    where n.site_id = p_site_id and n.category_id = p_category_id and n.is_active
  loop
    if r.kind = 'meter' then
      if exists (
        select 1 from public.site_utility_assets a
        where a.ref_meter_id = r.ref_meter_id and a.status = 'active'
      ) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'meter_asset_exists', 'legacy_node_id', r.id
        ));
        v_existing_assets := v_existing_assets + 1;
      else
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'add_meter_asset', 'legacy_node_id', r.id,
          'ref_meter_id', r.ref_meter_id, 'pos_x', r.pos_x, 'pos_y', r.pos_y
        ));
      end if;
    elsif r.kind = 'tank' then
      if exists (
        select 1 from public.site_utility_assets a
        where a.ref_tank_id = r.ref_tank_id and a.status = 'active'
      ) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'tank_asset_exists', 'legacy_node_id', r.id
        ));
        v_existing_assets := v_existing_assets + 1;
      else
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'add_tank_asset', 'legacy_node_id', r.id,
          'ref_tank_id', r.ref_tank_id, 'pos_x', r.pos_x, 'pos_y', r.pos_y
        ));
      end if;
    elsif r.kind = 'tanker_discharge' then
      v_actions := v_actions || jsonb_build_array(jsonb_build_object(
        'action', 'add_tanker_loading', 'legacy_node_id', r.id,
        'label_en', r.label_en, 'label_ar', r.label_ar,
        'pos_x', r.pos_x, 'pos_y', r.pos_y
      ));
    elsif r.kind = 'ground_drain' then
      v_actions := v_actions || jsonb_build_array(jsonb_build_object(
        'action', 'add_discharge_point', 'legacy_node_id', r.id,
        'label_en', r.label_en, 'label_ar', r.label_ar,
        'pos_x', r.pos_x, 'pos_y', r.pos_y
      ));
    end if;
  end loop;

  for r in
    select e.*,
           fn.kind as from_kind, tn.kind as to_kind
    from public.site_network_edges e
    join public.site_network_nodes fn on fn.id = e.from_node_id
    join public.site_network_nodes tn on tn.id = e.to_node_id
    where e.site_id = p_site_id and e.category_id = p_category_id
  loop
    v_actions := v_actions || jsonb_build_array(jsonb_build_object(
      'action', 'add_connection',
      'legacy_edge_id', r.id,
      'from_legacy_node_id', r.from_node_id,
      'to_legacy_node_id', r.to_node_id,
      'edge_kind', r.edge_kind,
      'legacy_sync_status', case
        when r.from_kind = 'meter' and r.to_kind = 'meter' and r.edge_kind = 'supply'
          then 'synced'
        when r.from_kind = 'meter' and r.to_kind = 'tank' and r.edge_kind = 'pour'
          then 'synced'
        else 'graph_only'
      end
    ));
  end loop;

  return jsonb_build_object(
    'site_id', p_site_id,
    'category_id', p_category_id,
    'network_id', p_network_id,
    'legacy_nodes', v_nodes,
    'legacy_edges', v_edges,
    'existing_mapped_assets', v_existing_assets,
    'actions', v_actions
  );
end;
$$;

create or replace function public.import_legacy_network_dry_run(
  p_site_id uuid,
  p_category_id uuid,
  p_network_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.import_legacy_network_plan(p_site_id, p_category_id, p_network_id)
    || jsonb_build_object('dry_run', true);
end;
$$;

create or replace function public.import_legacy_network_apply(
  p_site_id uuid,
  p_category_id uuid,
  p_network_id uuid default null,
  p_network_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_plan jsonb;
  v_network_id uuid;
  v_draft jsonb;
  v_rev_id uuid;
  v_lock int;
  v_view_id uuid;
  v_action jsonb;
  v_added int := 0;
  v_skipped int := 0;
  v_edges_added int := 0;
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
begin
  if not public.can_manage_site_meters(p_site_id) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;

  v_plan := public.import_legacy_network_plan(p_site_id, p_category_id, p_network_id);
  v_network_id := p_network_id;

  if v_network_id is null then
    v_draft := public.create_utility_network(
      p_category_id,
      coalesce(p_network_code, 'legacy-' || substr(p_site_id::text, 1, 8)),
      'Imported water network',
      'شبكة مياه مستوردة',
      array[p_site_id]
    );
    v_network_id := (v_draft->>'network_id')::uuid;
    v_rev_id := (v_draft->>'draft_revision_id')::uuid;
    v_lock := (v_draft->>'lock_version')::int;
    v_view_id := (v_draft->>'default_view_id')::uuid;
  else
    if not public.can_manage_utility_network(v_network_id) then
      raise exception 'Not allowed to manage network' using errcode = '42501';
    end if;
    v_draft := public.ensure_network_draft(v_network_id);
    v_rev_id := (v_draft->>'draft_revision_id')::uuid;
    v_lock := (v_draft->>'lock_version')::int;
    select id into v_view_id
    from public.site_utility_network_views
    where network_id = v_network_id and is_default
    limit 1;
  end if;

  -- Map existing assets for skipped meters/tanks
  for v_action in select * from jsonb_array_elements(v_plan->'actions')
  loop
    if v_action->>'action' in ('skipped') then
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

      insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
      values (v_rev_id, v_asset_id, (v_action->>'legacy_node_id')::uuid)
      on conflict (revision_id, asset_id) do update
        set legacy_node_id = coalesce(site_utility_revision_nodes.legacy_node_id, excluded.legacy_node_id)
      returning id into v_node_id;

      v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);

      if v_view_id is not null then
        insert into public.site_utility_view_nodes (revision_id, view_id, node_id, pos_x, pos_y)
        select v_rev_id, v_view_id, v_node_id, n.pos_x, n.pos_y
        from public.site_network_nodes n
        where n.id = (v_action->>'legacy_node_id')::uuid
        on conflict (revision_id, view_id, node_id) do update
          set pos_x = excluded.pos_x, pos_y = excluded.pos_y, updated_at = now();
      end if;
    end if;
  end loop;

  -- Bump lock once before bulk mutations via direct inserts (still draft-checked)
  perform public.utility_assert_draft_lock(v_rev_id, v_lock);
  select lock_version into v_lock from public.site_utility_network_revisions where id = v_rev_id;

  for v_action in select * from jsonb_array_elements(v_plan->'actions')
  loop
    if v_action->>'action' = 'add_meter_asset' then
      select * into v_meter from public.meters where id = (v_action->>'ref_meter_id')::uuid;
      insert into public.site_utility_assets (
        site_id, asset_type, name_en, name_ar, code, ref_meter_id, meter_role, created_by, updated_by
      ) values (
        p_site_id, 'meter', v_meter.name_en, coalesce(v_meter.name_ar, v_meter.name_en),
        v_meter.meter_code, v_meter.id,
        case v_meter.level::text when 'main' then 'main' else 'submeter' end,
        v_uid, v_uid
      ) returning id into v_asset_id;
      perform public.utility_default_ports_for_asset(v_asset_id, 'meter', false);
      insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
      values (v_rev_id, v_asset_id, (v_action->>'legacy_node_id')::uuid)
      returning id into v_node_id;
      v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
      if v_view_id is not null then
        insert into public.site_utility_view_nodes (revision_id, view_id, node_id, pos_x, pos_y)
        values (v_rev_id, v_view_id, v_node_id,
                (v_action->>'pos_x')::double precision,
                (v_action->>'pos_y')::double precision)
        on conflict do nothing;
      end if;
      v_added := v_added + 1;

    elsif v_action->>'action' = 'add_tank_asset' then
      select * into v_tank from public.site_tanks where id = (v_action->>'ref_tank_id')::uuid;
      v_code := 'tank-' || substr(v_tank.id::text, 1, 8);
      insert into public.site_utility_assets (
        site_id, asset_type, name_en, name_ar, code, ref_tank_id, created_by, updated_by
      ) values (
        p_site_id, 'tank', v_tank.name_en, coalesce(v_tank.name_ar, v_tank.name_en),
        v_code, v_tank.id, v_uid, v_uid
      ) returning id into v_asset_id;
      perform public.utility_default_ports_for_asset(v_asset_id, 'tank', true);
      insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
      values (v_rev_id, v_asset_id, (v_action->>'legacy_node_id')::uuid)
      returning id into v_node_id;
      v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
      if v_view_id is not null then
        insert into public.site_utility_view_nodes (revision_id, view_id, node_id, pos_x, pos_y)
        values (v_rev_id, v_view_id, v_node_id,
                (v_action->>'pos_x')::double precision,
                (v_action->>'pos_y')::double precision)
        on conflict do nothing;
      end if;
      v_added := v_added + 1;

    elsif v_action->>'action' = 'add_tanker_loading' then
      if exists (
        select 1 from public.site_utility_revision_nodes
        where revision_id = v_rev_id
          and legacy_node_id = (v_action->>'legacy_node_id')::uuid
      ) then
        v_skipped := v_skipped + 1;
        select id into v_node_id from public.site_utility_revision_nodes
        where revision_id = v_rev_id
          and legacy_node_id = (v_action->>'legacy_node_id')::uuid;
        v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
        continue;
      end if;
      v_code := 'tanker-' || substr(v_action->>'legacy_node_id', 1, 8);
      insert into public.site_utility_assets (
        site_id, asset_type, service_type, name_en, name_ar, code, created_by, updated_by
      ) values (
        p_site_id, 'tanker_loading', 'offsite_disposal',
        coalesce(v_action->>'label_en', 'Tanker loading'),
        coalesce(v_action->>'label_ar', 'تحميل تانكر'),
        v_code, v_uid, v_uid
      ) returning id into v_asset_id;
      perform public.utility_default_ports_for_asset(v_asset_id, 'tanker_loading', false);
      insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
      values (v_rev_id, v_asset_id, (v_action->>'legacy_node_id')::uuid)
      on conflict (revision_id, asset_id) do nothing
      returning id into v_node_id;
      if v_node_id is null then
        select id into v_node_id from public.site_utility_revision_nodes
        where revision_id = v_rev_id and asset_id = v_asset_id;
      end if;
      v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
      if v_view_id is not null then
        insert into public.site_utility_view_nodes (revision_id, view_id, node_id, pos_x, pos_y)
        values (v_rev_id, v_view_id, v_node_id,
                (v_action->>'pos_x')::double precision,
                (v_action->>'pos_y')::double precision)
        on conflict do nothing;
      end if;
      v_added := v_added + 1;

    elsif v_action->>'action' = 'add_discharge_point' then
      -- Idempotent by legacy_node already in revision
      if exists (
        select 1 from public.site_utility_revision_nodes
        where revision_id = v_rev_id
          and legacy_node_id = (v_action->>'legacy_node_id')::uuid
      ) then
        v_skipped := v_skipped + 1;
        select id into v_node_id from public.site_utility_revision_nodes
        where revision_id = v_rev_id and legacy_node_id = (v_action->>'legacy_node_id')::uuid;
        v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
        continue;
      end if;
      v_code := 'drain-' || substr(v_action->>'legacy_node_id', 1, 8);
      insert into public.site_utility_assets (
        site_id, asset_type, service_type, name_en, name_ar, code, created_by, updated_by
      ) values (
        p_site_id, 'discharge_point', 'floor_drain',
        coalesce(v_action->>'label_en', 'Ground drain'),
        coalesce(v_action->>'label_ar', 'صرف أرضي'),
        v_code, v_uid, v_uid
      ) returning id into v_asset_id;
      perform public.utility_default_ports_for_asset(v_asset_id, 'discharge_point', false);
      insert into public.site_utility_revision_nodes (revision_id, asset_id, legacy_node_id)
      values (v_rev_id, v_asset_id, (v_action->>'legacy_node_id')::uuid)
      returning id into v_node_id;
      v_legacy_to_node := v_legacy_to_node || jsonb_build_object(v_action->>'legacy_node_id', v_node_id::text);
      if v_view_id is not null then
        insert into public.site_utility_view_nodes (revision_id, view_id, node_id, pos_x, pos_y)
        values (v_rev_id, v_view_id, v_node_id,
                (v_action->>'pos_x')::double precision,
                (v_action->>'pos_y')::double precision)
        on conflict do nothing;
      end if;
      v_added := v_added + 1;
    end if;
  end loop;

  -- Refresh legacy map from DB for robustness / second run
  select coalesce(jsonb_object_agg(legacy_node_id::text, id::text), '{}'::jsonb)
    into v_legacy_to_node
  from public.site_utility_revision_nodes
  where revision_id = v_rev_id and legacy_node_id is not null;

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

    -- Ensure tank aux ports exist before overflow/washout/drain mapping.
    if v_conn_kind in ('overflow', 'washout', 'drain') then
      perform public.utility_default_ports_for_asset(v_from_asset, 'tank', true);
    end if;

    -- Pick source port by connection kind (do not default overflow edges to outlet).
    if v_conn_kind = 'overflow' then
      select id into v_from_port from public.site_utility_asset_ports
      where asset_id = v_from_asset and port_role = 'overflow' limit 1;
    elsif v_conn_kind = 'washout' then
      select id into v_from_port from public.site_utility_asset_ports
      where asset_id = v_from_asset and port_role in ('washout', 'drain')
      order by case port_role when 'washout' then 0 else 1 end
      limit 1;
    elsif v_conn_kind = 'drain' then
      select id into v_from_port from public.site_utility_asset_ports
      where asset_id = v_from_asset and port_role = 'drain' limit 1;
    elsif v_conn_kind in ('discharge', 'tanker_transport') then
      select id into v_from_port from public.site_utility_asset_ports
      where asset_id = v_from_asset
        and port_role in ('tanker_transfer', 'outlet', 'drain', 'overflow')
      order by case port_role
        when 'tanker_transfer' then 0
        when 'outlet' then 1
        when 'drain' then 2
        else 3
      end
      limit 1;
    else
      select id into v_from_port from public.site_utility_asset_ports
      where asset_id = v_from_asset and direction in ('out', 'bidirectional')
      order by case port_role
        when 'outlet' then 0
        when 'product' then 1
        when 'tanker_transfer' then 2
        else 3
      end
      limit 1;
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
      v_rev_id, v_from_node, v_from_port, v_to_node, v_to_port,
      v_conn_kind,
      case when v_conn_kind in ('overflow', 'washout', 'drain', 'discharge')
        then 'open_drain' else 'pipe' end,
      v_sync, (v_action->>'legacy_edge_id')::uuid
    )
    on conflict (revision_id, from_port_id, to_port_id, connection_kind) do nothing;
    -- Count after loop from DB for accurate idempotent totals
  end loop;

  select count(*) into v_edges_added
  from public.site_utility_revision_connections
  where revision_id = v_rev_id;

  select lock_version into v_lock from public.site_utility_network_revisions where id = v_rev_id;

  return jsonb_build_object(
    'dry_run', false,
    'network_id', v_network_id,
    'draft_revision_id', v_rev_id,
    'lock_version', v_lock,
    'default_view_id', v_view_id,
    'assets_added', v_added,
    'assets_skipped', v_skipped,
    'connections_added', v_edges_added,
    'legacy_nodes', v_plan->'legacy_nodes',
    'legacy_edges', v_plan->'legacy_edges',
    'plan', v_plan
  );
end;
$$;

create or replace function public.reconcile_legacy_network(
  p_network_id uuid,
  p_revision_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev_id uuid;
  v_diffs jsonb := '[]'::jsonb;
  r record;
begin
  if not public.can_manage_utility_network(p_network_id) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;

  select coalesce(p_revision_id, draft_revision_id) into v_rev_id
  from public.site_utility_networks where id = p_network_id;

  for r in
    select c.id as connection_id,
           fa.ref_meter_id as from_meter,
           ta.ref_meter_id as to_meter,
           m.parent_meter_id
    from public.site_utility_revision_connections c
    join public.site_utility_revision_nodes fn on fn.id = c.from_node_id
    join public.site_utility_revision_nodes tn on tn.id = c.to_node_id
    join public.site_utility_assets fa on fa.id = fn.asset_id
    join public.site_utility_assets ta on ta.id = tn.asset_id
    join public.meters m on m.id = ta.ref_meter_id
    where c.revision_id = v_rev_id
      and c.legacy_sync_status = 'synced'
      and fa.asset_type = 'meter' and ta.asset_type = 'meter'
      and m.parent_meter_id is distinct from fa.ref_meter_id
  loop
    v_diffs := v_diffs || jsonb_build_array(jsonb_build_object(
      'type', 'parent_meter_mismatch',
      'connection_id', r.connection_id,
      'expected_parent', r.from_meter,
      'actual_parent', r.parent_meter_id
    ));
  end loop;

  for r in
    select c.id as connection_id,
           fa.ref_meter_id as meter_id,
           ta.ref_tank_id as expected_tank,
           m.destination_tank_id as actual_tank,
           m.pours_into_tank
    from public.site_utility_revision_connections c
    join public.site_utility_revision_nodes fn on fn.id = c.from_node_id
    join public.site_utility_revision_nodes tn on tn.id = c.to_node_id
    join public.site_utility_assets fa on fa.id = fn.asset_id
    join public.site_utility_assets ta on ta.id = tn.asset_id
    join public.meters m on m.id = fa.ref_meter_id
    where c.revision_id = v_rev_id
      and c.legacy_sync_status = 'synced'
      and fa.asset_type = 'meter' and ta.asset_type = 'tank'
      and (m.destination_tank_id is distinct from ta.ref_tank_id or m.pours_into_tank is not true)
  loop
    v_diffs := v_diffs || jsonb_build_array(jsonb_build_object(
      'type', 'destination_tank_mismatch',
      'connection_id', r.connection_id,
      'meter_id', r.meter_id,
      'expected_tank', r.expected_tank,
      'actual_tank', r.actual_tank
    ));
  end loop;

  for r in
    select c.id, c.legacy_sync_status, c.connection_kind
    from public.site_utility_revision_connections c
    where c.revision_id = v_rev_id
      and c.legacy_sync_status = 'graph_only'
  loop
    v_diffs := v_diffs || jsonb_build_array(jsonb_build_object(
      'type', 'graph_only',
      'connection_id', r.id,
      'connection_kind', r.connection_kind,
      'message', 'Not projected to legacy meter fields'
    ));
  end loop;

  return jsonb_build_object(
    'network_id', p_network_id,
    'revision_id', v_rev_id,
    'diffs', v_diffs,
    'mutated', false
  );
end;
$$;

revoke all on function public.validate_network_draft(uuid) from public;
revoke all on function public.publish_network_draft(uuid, integer, boolean) from public;
revoke all on function public.import_legacy_network_dry_run(uuid, uuid, uuid) from public;
revoke all on function public.import_legacy_network_apply(uuid, uuid, uuid, text) from public;
revoke all on function public.reconcile_legacy_network(uuid, uuid) from public;

grant execute on function public.validate_network_draft(uuid) to authenticated;
grant execute on function public.publish_network_draft(uuid, integer, boolean) to authenticated;
grant execute on function public.import_legacy_network_dry_run(uuid, uuid, uuid) to authenticated;
grant execute on function public.import_legacy_network_apply(uuid, uuid, uuid, text) to authenticated;
grant execute on function public.reconcile_legacy_network(uuid, uuid) to authenticated;
