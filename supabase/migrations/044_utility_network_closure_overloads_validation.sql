-- =============================================================================
-- Migration: 044_utility_network_closure_overloads_validation.sql
-- Closure for simplified treeing:
--   * Drop stale RPC overloads that break SQL tests / PostgREST
--   * Ensure import_legacy_network_plan has additions/skipped (041 body)
--   * Strengthen validate_network_draft (self/dup/broken = error; cycles = warning)
-- Safe to re-run; does not seed/duplicate network data.
-- =============================================================================

-- Stale overloads (no trailing boolean / old apply signature)
drop function if exists public.connect_ports(uuid, integer, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb);
drop function if exists public.attach_existing_meter_to_draft(uuid, integer, uuid, uuid, double precision, double precision, text, uuid, uuid, uuid[], text, text, text);
drop function if exists public.create_meter_in_network_draft(uuid, integer, uuid, text, text, text, uuid, uuid, uuid, text, uuid, uuid, double precision, double precision, uuid, uuid[], text, text, text);
drop function if exists public.utility_connect_ports_unlocked(uuid, uuid, uuid, uuid, uuid, text, text, text, text, text, jsonb);
drop function if exists public.import_legacy_network_apply(uuid, uuid, uuid, text);


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
  v_revision_id uuid;
  v_additions int := 0;
  v_updates int := 0;
  v_skipped int := 0;
  r record;
begin
  if not public.can_manage_site_meters(p_site_id) then
    raise exception 'Not allowed to manage meters for site' using errcode = '42501';
  end if;

  if p_network_id is not null then
    select draft_revision_id into v_revision_id
    from public.site_utility_networks
    where id = p_network_id;
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
      if v_revision_id is not null
         and public.utility_legacy_node_already_in_revision(v_revision_id, r.id) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'already_in_revision',
          'legacy_node_id', r.id, 'kind', 'meter'
        ));
        v_skipped := v_skipped + 1;
        v_existing_assets := v_existing_assets + 1;
      elsif exists (
        select 1 from public.site_utility_assets a
        where a.ref_meter_id = r.ref_meter_id and a.status = 'active'
      ) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'meter_asset_exists',
          'legacy_node_id', r.id, 'kind', 'meter'
        ));
        v_skipped := v_skipped + 1;
        v_existing_assets := v_existing_assets + 1;
      else
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'add_meter_asset', 'legacy_node_id', r.id,
          'ref_meter_id', r.ref_meter_id, 'pos_x', r.pos_x, 'pos_y', r.pos_y
        ));
        v_additions := v_additions + 1;
      end if;
    elsif r.kind = 'tank' then
      if v_revision_id is not null
         and public.utility_legacy_node_already_in_revision(v_revision_id, r.id) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'already_in_revision',
          'legacy_node_id', r.id, 'kind', 'tank'
        ));
        v_skipped := v_skipped + 1;
        v_existing_assets := v_existing_assets + 1;
      elsif exists (
        select 1 from public.site_utility_assets a
        where a.ref_tank_id = r.ref_tank_id and a.status = 'active'
      ) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'tank_asset_exists',
          'legacy_node_id', r.id, 'kind', 'tank'
        ));
        v_skipped := v_skipped + 1;
        v_existing_assets := v_existing_assets + 1;
      else
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'add_tank_asset', 'legacy_node_id', r.id,
          'ref_tank_id', r.ref_tank_id, 'pos_x', r.pos_x, 'pos_y', r.pos_y
        ));
        v_additions := v_additions + 1;
      end if;
    elsif r.kind = 'tanker_discharge' then
      if v_revision_id is not null
         and public.utility_legacy_node_already_in_revision(v_revision_id, r.id) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'already_in_revision',
          'legacy_node_id', r.id, 'kind', 'tanker_loading'
        ));
        v_skipped := v_skipped + 1;
      else
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'add_tanker_loading', 'legacy_node_id', r.id,
          'label_en', r.label_en, 'label_ar', r.label_ar,
          'pos_x', r.pos_x, 'pos_y', r.pos_y
        ));
        v_additions := v_additions + 1;
      end if;
    elsif r.kind = 'ground_drain' then
      if v_revision_id is not null
         and public.utility_legacy_node_already_in_revision(v_revision_id, r.id) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'already_in_revision',
          'legacy_node_id', r.id, 'kind', 'discharge_point'
        ));
        v_skipped := v_skipped + 1;
      else
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'add_discharge_point', 'legacy_node_id', r.id,
          'label_en', r.label_en, 'label_ar', r.label_ar,
          'pos_x', r.pos_x, 'pos_y', r.pos_y
        ));
        v_additions := v_additions + 1;
      end if;
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
    if v_revision_id is not null
       and public.utility_legacy_connection_already_in_revision(
         v_revision_id, r.id, r.from_node_id, r.to_node_id, r.edge_kind::text
       ) then
      v_actions := v_actions || jsonb_build_array(jsonb_build_object(
        'action', 'skipped',
        'reason', 'connection_exists',
        'legacy_edge_id', r.id,
        'from_legacy_node_id', r.from_node_id,
        'to_legacy_node_id', r.to_node_id,
        'edge_kind', r.edge_kind,
        'connection_kind', public.utility_legacy_edge_conn_kind(r.edge_kind::text),
        'match_key', 'revision+ports+kind[+legacy_edge_id]'
      ));
      v_skipped := v_skipped + 1;
    else
      v_actions := v_actions || jsonb_build_array(jsonb_build_object(
        'action', 'add_connection',
        'legacy_edge_id', r.id,
        'from_legacy_node_id', r.from_node_id,
        'to_legacy_node_id', r.to_node_id,
        'edge_kind', r.edge_kind,
        'connection_kind', public.utility_legacy_edge_conn_kind(r.edge_kind::text),
        'legacy_sync_status', case
          when r.from_kind = 'meter' and r.to_kind = 'meter' and r.edge_kind::text = 'supply'
            then 'synced'
          when r.from_kind = 'meter' and r.to_kind = 'tank' and r.edge_kind::text = 'pour'
            then 'synced'
          else 'graph_only'
        end,
        'match_key', 'revision+ports+kind[+legacy_edge_id]'
      ));
      v_additions := v_additions + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'site_id', p_site_id,
    'category_id', p_category_id,
    'network_id', p_network_id,
    'draft_revision_id', v_revision_id,
    'legacy_nodes', v_nodes,
    'legacy_edges', v_edges,
    'existing_mapped_assets', v_existing_assets,
    'additions', v_additions,
    'updates', v_updates,
    'skipped', v_skipped,
    'unchanged', v_skipped,
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

  -- TSE / RO reject into potable path
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


  -- Self-connection (also DB check; report for publish gate)
  for r in
    select c.id
    from public.site_utility_revision_connections c
    where c.revision_id = p_revision_id
      and c.from_node_id = c.to_node_id
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'self_connection',
      'severity', 'error',
      'connection_id', r.id,
      'message', 'Connection cannot link a node to itself'
    ));
  end loop;

  -- Duplicate connections (same ports + kind)
  for r in
    select (array_agg(c.id))[1] as id
    from public.site_utility_revision_connections c
    where c.revision_id = p_revision_id
    group by c.from_port_id, c.to_port_id, c.connection_kind
    having count(*) > 1
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'duplicate_connection',
      'severity', 'error',
      'connection_id', r.id,
      'message', 'Duplicate connection between the same ports'
    ));
  end loop;

  -- Missing / deleted endpoints
  for r in
    select c.id
    from public.site_utility_revision_connections c
    where c.revision_id = p_revision_id
      and (
        not exists (select 1 from public.site_utility_revision_nodes n where n.id = c.from_node_id and n.revision_id = p_revision_id)
        or not exists (select 1 from public.site_utility_revision_nodes n where n.id = c.to_node_id and n.revision_id = p_revision_id)
        or not exists (select 1 from public.site_utility_asset_ports p where p.id = c.from_port_id)
        or not exists (select 1 from public.site_utility_asset_ports p where p.id = c.to_port_id)
      )
  loop
    v_errors := v_errors || jsonb_build_array(jsonb_build_object(
      'code', 'broken_connection_endpoint',
      'severity', 'error',
      'connection_id', r.id,
      'message', 'Connection references a missing node or port'
    ));
  end loop;

  -- Cycles: warning only (directed graph; do not block open/publish)
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
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'cycle_without_recirculation',
      'severity', 'warning',
      'connection_id', r.id,
      'message', 'Graph cycle detected without recirculation classification'
    ));
  end loop;

  -- Legacy parent_meter projection: informational only (v2 is source of truth)
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
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'legacy_parent_meter_cycle',
      'severity', 'warning',
      'connection_id', r.id,
      'message', 'Legacy parent_meter projection would cycle (ignored; v2 is source of truth)'
    ));
  end loop;

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
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'legacy_sync_conflict_parent',
      'severity', 'warning',
      'connection_id', r.id,
      'message', 'meters.parent_meter_id differs from v2 edge (deprecated; not synced)'
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

