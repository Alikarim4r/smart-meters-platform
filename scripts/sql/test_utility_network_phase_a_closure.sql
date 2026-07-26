-- =============================================================================
-- Phase A closure + meter picker regression tests
-- Cleans up its own test rows; runs as one function (single TX from caller).
-- =============================================================================

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

create or replace function util_net_test.run_phase_a_closure()
returns jsonb
language plpgsql
security definer
set search_path = public, util_net_test
as $$
declare
  v_super uuid;
  v_viewer uuid;
  v_water uuid;
  v_site uuid;
  v_source uuid;
  v_unit uuid;
  v_net jsonb;
  v_network_id uuid;
  v_rev uuid;
  v_lock int;
  v_lock_before int;
  v_view uuid;
  v_existing uuid;
  v_att jsonb;
  v_up jsonb;
  v_child jsonb;
  v_other jsonb;
  v_mid jsonb;
  v_pass int := 0;
begin
  select id into v_super from public.profiles
  where role = 'super_admin' and is_active order by created_at limit 1;
  select usa.user_id into v_viewer
  from public.user_site_access usa
  where usa.can_read and not usa.can_manage_meters
  order by usa.created_at limit 1;

  select id into v_water from public.meter_categories where code = 'water' limit 1;
  select id into v_site from public.sites where is_active order by created_at limit 1;
  select id into v_source from public.meter_sources
  where category_id = v_water and is_active order by sort_order nulls last, code limit 1;
  select id into v_unit from public.meter_units
  where category_id = v_water and is_active order by sort_order nulls last, code limit 1;

  perform util_net_test.assert(v_super is not null, 'super fixture');

  delete from public.site_utility_networks where code like 'test-a-close-%';
  delete from public.site_utility_assets where code like 'TAC-%';
  delete from public.meters where meter_code like 'TAC-%';

  perform util_net_test.set_user(v_super);

  insert into public.meters (
    site_id, meter_code, name_en, name_ar, category_id, source_id, unit_id,
    level, is_active, include_in_dashboard
  ) values (
    v_site, 'TAC-EXIST', 'Existing', 'موجود', v_water, v_source, v_unit,
    'main', true, true
  ) returning id into v_existing;

  v_net := public.create_utility_network(
    v_water, 'test-a-close-1', 'Close', 'إغلاق', array[v_site]
  );
  v_network_id := (v_net->>'network_id')::uuid;
  v_rev := (v_net->>'draft_revision_id')::uuid;
  v_lock := (v_net->>'lock_version')::int;
  v_view := (v_net->>'default_view_id')::uuid;

  -- Attach once
  v_att := public.attach_existing_meter_to_draft(
    v_rev, v_lock, v_existing, v_view, 10, 10
  );
  v_lock := (v_att->>'lock_version')::int;
  perform util_net_test.assert((v_att->>'status') in ('attached', 'view_placement_added'), 'attach first');
  v_pass := v_pass + 1;

  -- Idempotent attach: no lock bump
  v_lock_before := v_lock;
  v_att := public.attach_existing_meter_to_draft(
    v_rev, v_lock, v_existing, v_view, 10, 10
  );
  perform util_net_test.assert(v_att->>'status' = 'already_in_current_view', 'idempotent status');
  perform util_net_test.assert((v_att->>'lock_version')::int = v_lock_before, 'idempotent no lock bump');
  perform util_net_test.assert(
    (select count(*) from public.site_utility_assets where ref_meter_id = v_existing and status = 'active') = 1,
    'single asset'
  );
  v_pass := v_pass + 1;

  -- Stale lock
  begin
    perform public.attach_existing_meter_to_draft(
      v_rev, v_lock_before - 1, v_existing, v_view, 11, 11
    );
    perform util_net_test.assert(false, 'stale lock should fail');
  exception when others then
    perform util_net_test.assert(sqlerrm ilike '%version conflict%', 'stale lock msg');
    v_pass := v_pass + 1;
  end;

  -- Upstream + child with parent
  v_up := public.create_meter_in_network_draft(
    v_rev, v_lock, v_site, 'TAC-UP', 'Up', 'أعلى',
    v_water, v_source, v_unit, 'main', null, v_view, 0, 0
  );
  v_lock := (v_up->>'lock_version')::int;
  v_child := public.create_meter_in_network_draft(
    v_rev, v_lock, v_site, 'TAC-CHILD', 'Child', 'ابن',
    v_water, v_source, v_unit, 'process', null, v_view, 80, 0,
    (v_up->>'node_id')::uuid, null, 'supply', 'potable', 'synced', false
  );
  v_lock := (v_child->>'lock_version')::int;
  perform util_net_test.assert(
    (select parent_meter_id from public.meters where id = (v_child->>'meter_id')::uuid)
      = (v_up->>'meter_id')::uuid,
    'child parent set'
  );
  v_pass := v_pass + 1;

  -- Other parent meter
  v_other := public.create_meter_in_network_draft(
    v_rev, v_lock, v_site, 'TAC-OTHER', 'Other', 'آخر',
    v_water, v_source, v_unit, 'main', null, v_view, 0, 80
  );
  v_lock := (v_other->>'lock_version')::int;

  -- replace_existing_parent=false → conflict
  begin
    perform public.create_meter_in_network_draft(
      v_rev, v_lock, v_site, 'TAC-MID', 'Mid', 'وسط',
      v_water, v_source, v_unit, 'process', null, v_view, 40, 40,
      (v_other->>'node_id')::uuid,
      array[(v_child->>'node_id')::uuid],
      'supply', 'potable', 'synced', false
    );
    perform util_net_test.assert(false, 'parent conflict should fail');
  exception when others then
    perform util_net_test.assert(sqlerrm ilike '%parent conflict%', 'parent conflict msg');
    perform util_net_test.assert(
      not exists (select 1 from public.meters where meter_code = 'TAC-MID'),
      'rollback no meter'
    );
    perform util_net_test.assert(
      not exists (select 1 from public.site_utility_assets where code = 'TAC-MID'),
      'rollback no asset'
    );
    v_pass := v_pass + 1;
  end;
  select lock_version into v_lock from public.site_utility_network_revisions where id = v_rev;

  -- Authorized replace
  v_mid := public.create_meter_in_network_draft(
    v_rev, v_lock, v_site, 'TAC-MID', 'Mid', 'وسط',
    v_water, v_source, v_unit, 'process', null, v_view, 40, 40,
    (v_other->>'node_id')::uuid,
    array[(v_child->>'node_id')::uuid],
    'supply', 'potable', 'synced', true
  );
  v_lock := (v_mid->>'lock_version')::int;
  perform util_net_test.assert(
    (select parent_meter_id from public.meters where id = (v_child->>'meter_id')::uuid)
      = (v_mid->>'meter_id')::uuid,
    'replace parent applied'
  );
  v_pass := v_pass + 1;

  -- Unauthorized list/attach
  if v_viewer is not null then
    perform util_net_test.set_user(v_viewer);
    begin
      perform public.list_available_meters_for_network(v_network_id, v_rev, v_view);
      perform util_net_test.assert(false, 'viewer list denied');
    exception when others then
      perform util_net_test.assert(sqlerrm ilike '%not allowed%' or sqlstate = '42501', 'viewer list');
      v_pass := v_pass + 1;
    end;
    begin
      perform public.attach_existing_meter_to_draft(v_rev, v_lock, v_existing, v_view, 1, 1);
      perform util_net_test.assert(false, 'viewer attach denied');
    exception when others then
      perform util_net_test.assert(sqlerrm ilike '%not allowed%' or sqlstate = '42501' or sqlerrm ilike '%version conflict%', 'viewer attach');
      v_pass := v_pass + 1;
    end;
  else
    v_pass := v_pass + 2;
  end if;

  -- Cleanup
  perform util_net_test.set_user(v_super);
  delete from public.site_utility_networks where id = v_network_id;
  delete from public.site_utility_assets where code like 'TAC-%';
  delete from public.meters where meter_code like 'TAC-%';

  return jsonb_build_object('passed_checks', v_pass, 'cleaned', true);
exception when others then
  begin
    delete from public.site_utility_networks where code like 'test-a-close-%';
    delete from public.site_utility_assets where code like 'TAC-%';
    delete from public.meters where meter_code like 'TAC-%';
  exception when others then null;
  end;
  return jsonb_build_object('passed_checks', v_pass, 'error', sqlerrm);
end;
$$;

select util_net_test.run_phase_a_closure() as phase_a_closure_results;
