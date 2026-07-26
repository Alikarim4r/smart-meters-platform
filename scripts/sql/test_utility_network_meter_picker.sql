-- =============================================================================
-- Meter picker / attach / atomic create tests (Phase A extension)
-- Run after 032–038 applied on staging/local.
-- =============================================================================

create schema if not exists util_net_test;

create or replace function util_net_test.assert(p_cond boolean, p_msg text)
returns void
language plpgsql
as $$
begin
  if not coalesce(p_cond, false) then
    raise exception 'ASSERT FAIL: %', p_msg;
  end if;
end;
$$;

create or replace function util_net_test.set_user(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id::text, 'role', 'authenticated')::text,
    true
  );
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
end;
$$;

create or replace function util_net_test.run_meter_picker()
returns jsonb
language plpgsql
security definer
set search_path = public, util_net_test
as $$
declare
  v_super uuid;
  v_water uuid;
  v_site uuid;
  v_source uuid;
  v_unit uuid;
  v_net jsonb;
  v_network_id uuid;
  v_rev uuid;
  v_lock int;
  v_view uuid;
  v_existing uuid;
  v_list jsonb;
  v_att1 jsonb;
  v_att2 jsonb;
  v_up jsonb;
  v_new jsonb;
  v_par jsonb;
  v_seq jsonb;
  v_a jsonb;
  v_b jsonb;
  v_meters_before bigint;
  v_assets_before bigint;
  v_nodes_before bigint;
  v_pass int := 0;
  v_status text;
  v_fail_code text;
begin
  select id into v_super from public.profiles
  where role = 'super_admin' and is_active order by created_at limit 1;

  select id into v_water from public.meter_categories where code = 'water' limit 1;
  select id into v_site from public.sites where is_active order by created_at limit 1;
  select id into v_source from public.meter_sources
  where category_id = v_water and is_active order by sort_order nulls last, code limit 1;
  select id into v_unit from public.meter_units
  where category_id = v_water and is_active order by sort_order nulls last, code limit 1;

  perform util_net_test.assert(v_super is not null, 'super fixture');
  perform util_net_test.assert(v_site is not null and v_water is not null, 'site/category');

  delete from public.site_utility_networks where code like 'test-meter-picker-%';
  delete from public.site_utility_assets where code like 'TMP-%';
  delete from public.meters where meter_code like 'TMP-%';

  perform util_net_test.set_user(v_super);

  -- Seed an existing meter NOT yet in any network asset
  insert into public.meters (
    site_id, meter_code, name_en, name_ar, category_id, source_id, unit_id,
    level, is_active, include_in_dashboard
  ) values (
    v_site, 'TMP-EXIST', 'Existing', 'موجود', v_water, v_source, v_unit,
    'main', true, true
  ) returning id into v_existing;

  v_net := public.create_utility_network(
    v_water, 'test-meter-picker-1', 'Meter picker', 'منتقي', array[v_site]
  );
  v_network_id := (v_net->>'network_id')::uuid;
  v_rev := (v_net->>'draft_revision_id')::uuid;
  v_lock := (v_net->>'lock_version')::int;
  v_view := (v_net->>'default_view_id')::uuid;

  -- 1) list shows not_in_network
  v_list := public.list_available_meters_for_network(v_network_id, v_rev, v_view, v_site, 'TMP-EXIST', 50);
  select m->>'availability_status' into v_status
  from jsonb_array_elements(v_list->'meters') m
  where (m->>'meter_id')::uuid = v_existing;
  perform util_net_test.assert(v_status = 'not_in_network', '1 not_in_network');
  v_pass := v_pass + 1;

  -- 2) attach existing (no new meters row)
  select count(*) into v_meters_before from public.meters where id = v_existing;
  v_att1 := public.attach_existing_meter_to_draft(
    v_rev, v_lock, v_existing, v_view, 10, 10, 'main', null,
    null, null, 'supply', null, null
  );
  v_lock := (v_att1->>'lock_version')::int;
  perform util_net_test.assert((v_att1->>'created_asset')::boolean, '2 created asset once');
  perform util_net_test.assert((v_att1->>'created_node')::boolean, '2 created node once');
  perform util_net_test.assert(
    (select count(*) from public.meters where id = v_existing) = v_meters_before,
    '2 did not insert meters row'
  );
  v_pass := v_pass + 1;

  -- 3) list -> in_current_view
  v_list := public.list_available_meters_for_network(v_network_id, v_rev, v_view, null, 'TMP-EXIST', 50);
  select m->>'availability_status' into v_status
  from jsonb_array_elements(v_list->'meters') m
  where (m->>'meter_id')::uuid = v_existing;
  perform util_net_test.assert(v_status = 'in_current_view', '3 in_current_view');
  v_pass := v_pass + 1;

  -- 4) re-attach is idempotent (no duplicate asset/node)
  select count(*) into v_assets_before
  from public.site_utility_assets where ref_meter_id = v_existing and status = 'active';
  select count(*) into v_nodes_before
  from public.site_utility_revision_nodes
  where revision_id = v_rev and asset_id = (v_att1->>'asset_id')::uuid;

  v_att2 := public.attach_existing_meter_to_draft(
    v_rev, v_lock, v_existing, v_view, 20, 30, 'main', null,
    null, null, 'supply', null, null
  );
  v_lock := (v_att2->>'lock_version')::int;
  perform util_net_test.assert(not (v_att2->>'created_asset')::boolean, '4 no second asset');
  perform util_net_test.assert(not (v_att2->>'created_node')::boolean, '4 no second node');
  perform util_net_test.assert(
    (select count(*) from public.site_utility_assets where ref_meter_id = v_existing and status = 'active')
      = v_assets_before,
    '4 asset count stable'
  );
  perform util_net_test.assert(
    (select count(*) from public.site_utility_revision_nodes
     where revision_id = v_rev and asset_id = (v_att1->>'asset_id')::uuid) = v_nodes_before,
    '4 node count stable'
  );
  perform util_net_test.assert(
    (select pos_x from public.site_utility_view_nodes
     where revision_id = v_rev and view_id = v_view and node_id = (v_att1->>'node_id')::uuid) = 20,
    '4 view position updated'
  );
  v_pass := v_pass + 1;

  -- 5) remove from view only -> in_network_not_in_current_view
  delete from public.site_utility_view_nodes
  where revision_id = v_rev and view_id = v_view and node_id = (v_att1->>'node_id')::uuid;
  v_list := public.list_available_meters_for_network(v_network_id, v_rev, v_view, null, 'TMP-EXIST', 50);
  select m->>'availability_status' into v_status
  from jsonb_array_elements(v_list->'meters') m
  where (m->>'meter_id')::uuid = v_existing;
  perform util_net_test.assert(v_status = 'in_network_not_in_current_view', '5 not in view');
  v_pass := v_pass + 1;

  -- 6) sequential: upstream main + new child with parent sync
  v_up := public.create_meter_in_network_draft(
    v_rev, v_lock, v_site, 'TMP-UP', 'Up', 'أعلى',
    v_water, v_source, v_unit, 'main', null, v_view, 0, 0,
    null, null, 'supply', 'potable', 'synced'
  );
  v_lock := (v_up->>'lock_version')::int;
  v_seq := public.create_meter_in_network_draft(
    v_rev, v_lock, v_site, 'TMP-SEQ', 'Seq', 'متتال',
    v_water, v_source, v_unit, 'check', null, v_view, 100, 0,
    (v_up->>'node_id')::uuid, null, 'supply', 'potable', 'synced'
  );
  v_lock := (v_seq->>'lock_version')::int;
  perform util_net_test.assert(
    (select parent_meter_id from public.meters where id = (v_seq->>'meter_id')::uuid)
      = (v_up->>'meter_id')::uuid,
    '6 sequential parent_meter_id'
  );
  v_pass := v_pass + 1;

  -- 7) parallel downstream: one parent feeds two children
  v_par := public.create_meter_in_network_draft(
    v_rev, v_lock, v_site, 'TMP-PAR', 'Parent', 'أب',
    v_water, v_source, v_unit, 'main', null, v_view, 0, 80,
    null, null, 'supply', 'potable', null
  );
  v_lock := (v_par->>'lock_version')::int;
  v_a := public.create_meter_in_network_draft(
    v_rev, v_lock, v_site, 'TMP-A', 'A', 'أ',
    v_water, v_source, v_unit, 'process', null, v_view, 120, 40,
    null, null, 'supply', 'potable', null
  );
  v_lock := (v_a->>'lock_version')::int;
  v_b := public.create_meter_in_network_draft(
    v_rev, v_lock, v_site, 'TMP-B', 'B', 'ب',
    v_water, v_source, v_unit, 'process', null, v_view, 120, 120,
    null, null, 'supply', 'potable', null
  );
  v_lock := (v_b->>'lock_version')::int;

  -- Relink parent with two downstream via attach-style create already placed:
  -- use create with upstream null and then utility via create_meter that has downstream —
  -- create a junction-like third meter that feeds A and B from PAR using create_meter_in_network_draft
  -- Actually: attach doesn't recreate; call create_meter_in_network_draft for mid meter with upstream PAR and downstream [A,B]
  v_new := public.create_meter_in_network_draft(
    v_rev, v_lock, v_site, 'TMP-MID', 'Mid', 'وسط',
    v_water, v_source, v_unit, 'process', null, v_view, 60, 80,
    (v_par->>'node_id')::uuid,
    array[(v_a->>'node_id')::uuid, (v_b->>'node_id')::uuid],
    'supply', 'potable', 'synced'
  );
  v_lock := (v_new->>'lock_version')::int;
  perform util_net_test.assert(
    (select parent_meter_id from public.meters where id = (v_new->>'meter_id')::uuid)
      = (v_par->>'meter_id')::uuid,
    '7 mid parent = PAR'
  );
  perform util_net_test.assert(
    (select parent_meter_id from public.meters where id = (v_a->>'meter_id')::uuid)
      = (v_new->>'meter_id')::uuid,
    '7 A parent = MID'
  );
  perform util_net_test.assert(
    (select parent_meter_id from public.meters where id = (v_b->>'meter_id')::uuid)
      = (v_new->>'meter_id')::uuid,
    '7 B parent = MID'
  );
  perform util_net_test.assert(
    jsonb_array_length(v_new->'links'->'downstream_connection_ids') = 2,
    '7 two downstream connections'
  );
  v_pass := v_pass + 1;

  -- 8) rollback on failed link: invalid downstream node must not leave meter/asset
  select count(*) into v_meters_before from public.meters where meter_code = 'TMP-ROLL';
  begin
    perform public.create_meter_in_network_draft(
      v_rev, v_lock, v_site, 'TMP-ROLL', 'Roll', 'تراجع',
      v_water, v_source, v_unit, 'process', null, v_view, 200, 200,
      (v_par->>'node_id')::uuid,
      array[gen_random_uuid()],
      'supply', 'potable', 'synced'
    );
    perform util_net_test.assert(false, '8 should fail');
  exception when others then
    v_fail_code := sqlerrm;
    perform util_net_test.assert(
      (select count(*) from public.meters where meter_code = 'TMP-ROLL') = v_meters_before,
      '8 meters rolled back'
    );
    perform util_net_test.assert(
      not exists (select 1 from public.site_utility_assets where code = 'TMP-ROLL'),
      '8 assets rolled back'
    );
    v_pass := v_pass + 1;
  end;
  select lock_version into v_lock from public.site_utility_network_revisions where id = v_rev;

  -- 9) attach existing with upstream link
  v_att1 := public.attach_existing_meter_to_draft(
    v_rev, v_lock, v_existing, v_view, 10, 10, 'main', null,
    (v_up->>'node_id')::uuid, null, 'supply', 'potable', 'synced'
  );
  v_lock := (v_att1->>'lock_version')::int;
  perform util_net_test.assert(
    (select parent_meter_id from public.meters where id = v_existing)
      = (v_up->>'meter_id')::uuid
    or (v_att1->'links'->>'upstream_connection_id') is not null,
    '9 attach with upstream'
  );
  v_pass := v_pass + 1;

  return jsonb_build_object(
    'passed_checks', v_pass,
    'rollback_error_sample', v_fail_code,
    'network_id', v_network_id
  );
exception when others then
  return jsonb_build_object(
    'passed_checks', v_pass,
    'error', sqlerrm
  );
end;
$$;

select util_net_test.run_meter_picker() as meter_picker_results;
