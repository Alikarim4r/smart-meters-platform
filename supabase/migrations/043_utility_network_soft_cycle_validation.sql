-- =============================================================================
-- Migration: 043_utility_network_soft_cycle_validation.sql
-- Simplified water-network treeing: cycles and legacy parent_meter sync
-- mismatches are warnings, not publish blockers. v2 graph is the source of truth.
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
