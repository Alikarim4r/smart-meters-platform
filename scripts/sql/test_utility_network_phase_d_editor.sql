-- Phase D editor RPC smoke tests
create schema if not exists util_net_test;

create or replace function util_net_test.assert(p_cond boolean, p_msg text)
returns void language plpgsql as $$
begin
  if not coalesce(p_cond, false) then
    raise exception 'ASSERT FAIL: %', p_msg;
  end if;
end;
$$;

create or replace function util_net_test.set_user(p_user_id uuid)
returns void language plpgsql as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
end;
$$;

create or replace function util_net_test.run_phase_d_editor()
returns jsonb
language plpgsql
security definer
set search_path = public, util_net_test
as $$
declare
  v_super uuid;
  v_water uuid;
  v_site uuid;
  v_net jsonb;
  v_network_id uuid;
  v_rev uuid;
  v_lock int;
  v_view uuid;
  v_pass int := 0;
  v_list jsonb;
  v_attach jsonb;
  v_ro jsonb;
  v_drain jsonb;
  v_conn jsonb;
  v_pos jsonb;
  v_val jsonb;
  v_node uuid;
  v_port_out uuid;
  v_port_in uuid;
  v_node_drain uuid;
  v_port_drain uuid;
begin
  select id into v_super from public.profiles
  where role = 'super_admin' and is_active order by created_at limit 1;
  select id into v_water from public.meter_categories where code = 'water' limit 1;
  select id into v_site from public.sites where is_active order by created_at limit 1;
  perform util_net_test.assert(v_super is not null, 'super');
  delete from public.site_utility_networks where code like 'test-phase-d-ed-%';

  perform util_net_test.set_user(v_super);
  v_net := public.create_utility_network(
    v_water, 'test-phase-d-ed-1', 'Phase D editor', 'محرر د', array[v_site]
  );
  v_network_id := (v_net->>'network_id')::uuid;
  v_rev := (v_net->>'draft_revision_id')::uuid;
  v_lock := (v_net->>'lock_version')::int;
  select id into v_view from public.site_utility_network_views
  where network_id = v_network_id and is_default limit 1;

  v_list := public.list_available_tanks_for_network(v_network_id, v_rev, v_view, v_site, null, 50);
  perform util_net_test.assert(v_list ? 'tanks', 'list tanks');
  v_pass := v_pass + 1;

  -- Create RO treatment unit
  v_ro := public.create_asset_with_ports(
    v_rev, v_lock, v_site, 'treatment_unit',
    'test-ro-' || substr(v_rev::text, 1, 8),
    'Test RO', 'محطة تجريبية',
    'water', null, null, '{}'::jsonb, true, v_view, 100, 100
  );
  v_lock := (v_ro->>'lock_version')::int;
  perform util_net_test.assert(v_ro ? 'node_id', 'ro node');
  v_pass := v_pass + 1;

  -- Floor drain
  v_drain := public.create_asset_with_ports(
    v_rev, v_lock, v_site, 'discharge_point',
    'test-drain-' || substr(v_rev::text, 1, 8),
    'Test drain', 'صرف تجريبي',
    'water', null, null, '{}'::jsonb, true, v_view, 300, 100
  );
  v_lock := (v_drain->>'lock_version')::int;
  v_pass := v_pass + 1;

  -- Connect RO reject → drain
  select id into v_node from public.site_utility_revision_nodes
  where id = (v_ro->>'node_id')::uuid;
  select id into v_port_out from public.site_utility_asset_ports
  where asset_id = (v_ro->>'asset_id')::uuid and port_role = 'reject' limit 1;
  select id into v_node_drain from public.site_utility_revision_nodes
  where id = (v_drain->>'node_id')::uuid;
  select id into v_port_drain from public.site_utility_asset_ports
  where asset_id = (v_drain->>'asset_id')::uuid and direction = 'in' limit 1;

  v_conn := public.connect_ports(
    v_rev, v_lock, v_node, v_port_out, v_node_drain, v_port_drain,
    'discharge', 'reject', 'pipe', 'normal', 'graph_only', '{}'::jsonb, false
  );
  v_lock := (v_conn->>'lock_version')::int;
  perform util_net_test.assert(v_conn ? 'connection_id', 'conn');
  v_pass := v_pass + 1;

  -- Refuse remove connected port
  begin
    perform public.remove_asset_port(v_rev, v_lock, v_port_out);
    perform util_net_test.assert(false, 'remove connected port');
  exception when others then
    perform util_net_test.assert(true, 'remove connected refused');
    v_pass := v_pass + 1;
  end;

  -- Move placement
  v_pos := public.batch_update_view_positions(
    v_rev, v_lock, v_view,
    jsonb_build_array(jsonb_build_object(
      'node_id', v_node, 'pos_x', 120, 'pos_y', 140
    ))
  );
  v_lock := (v_pos->>'lock_version')::int;
  v_pass := v_pass + 1;

  -- remove from view keeps revision node
  perform public.remove_asset_from_view(v_rev, v_lock, v_view, v_node_drain);
  select lock_version into v_lock from public.site_utility_network_revisions where id = v_rev;
  perform util_net_test.assert(
    exists (select 1 from public.site_utility_revision_nodes where id = v_node_drain),
    'node remains after view remove'
  );
  v_pass := v_pass + 1;

  v_val := public.validate_network_draft(v_rev);
  perform util_net_test.assert(v_val ? 'errors', 'validate shape');
  v_pass := v_pass + 1;

  -- Stale lock
  begin
    perform public.update_asset(v_rev, v_lock - 1, (v_ro->>'asset_id')::uuid, null, 'x', null, null, null, null);
    perform util_net_test.assert(false, 'stale');
  exception when others then
    perform util_net_test.assert(sqlerrm ilike '%version conflict%', 'stale msg');
    v_pass := v_pass + 1;
  end;

  delete from public.site_utility_networks where id = v_network_id;
  return jsonb_build_object('passed_checks', v_pass, 'cleaned', true);
exception when others then
  begin
    delete from public.site_utility_networks where code like 'test-phase-d-ed-%';
  exception when others then null;
  end;
  return jsonb_build_object('passed_checks', v_pass, 'error', sqlerrm);
end;
$$;

select util_net_test.run_phase_d_editor() as phase_d_editor_results;
