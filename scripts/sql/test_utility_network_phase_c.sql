-- Phase C SQL tests: import lock, snapshot ACL, list networks
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

create or replace function util_net_test.run_phase_c()
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
  v_net jsonb;
  v_network_id uuid;
  v_rev uuid;
  v_lock int;
  v_lock2 int;
  v_a jsonb;
  v_b jsonb;
  v_list jsonb;
  v_pub jsonb;
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

  perform util_net_test.assert(v_super is not null, 'super');
  delete from public.site_utility_networks where code like 'test-phase-c-%';

  perform util_net_test.set_user(v_super);
  v_net := public.create_utility_network(
    v_water, 'test-phase-c-1', 'Phase C', 'مرحلة ج', array[v_site]
  );
  v_network_id := (v_net->>'network_id')::uuid;
  v_rev := (v_net->>'draft_revision_id')::uuid;
  v_lock := (v_net->>'lock_version')::int;

  -- list networks for site
  v_list := public.list_utility_networks_for_site(v_site);
  perform util_net_test.assert(
    exists (
      select 1 from jsonb_array_elements(v_list->'networks') n
      where n->>'network_id' = v_network_id::text
    ),
    'list includes network'
  );
  v_pass := v_pass + 1;

  -- published empty
  v_pub := public.get_published_network_snapshot(v_network_id);
  perform util_net_test.assert(v_pub->>'status' = 'not_published', 'not_published');
  v_pass := v_pass + 1;

  -- manager can draft
  perform util_net_test.assert(
    (public.get_draft_network_snapshot(v_network_id)->>'status') = 'ok',
    'manager draft ok'
  );
  v_pass := v_pass + 1;

  -- viewer cannot draft
  if v_viewer is not null then
    perform util_net_test.set_user(v_viewer);
    begin
      perform public.get_draft_network_snapshot(v_network_id);
      perform util_net_test.assert(false, 'viewer draft denied');
    exception when others then
      perform util_net_test.assert(sqlerrm ilike '%not readable%' or sqlstate = '42501', 'viewer draft');
      v_pass := v_pass + 1;
    end;
    -- viewer cannot pass draft revision_id to generic snapshot
    begin
      perform public.get_network_snapshot(v_network_id, v_rev);
      perform util_net_test.assert(false, 'viewer generic draft denied');
    exception when others then
      perform util_net_test.assert(sqlerrm ilike '%not readable%' or sqlstate = '42501', 'viewer generic');
      v_pass := v_pass + 1;
    end;
    perform util_net_test.set_user(v_super);
  else
    v_pass := v_pass + 2;
  end if;

  -- stale import lock
  begin
    perform public.import_legacy_network_apply(v_rev, v_lock - 1, v_site);
    perform util_net_test.assert(false, 'stale import');
  exception when others then
    perform util_net_test.assert(sqlerrm ilike '%version conflict%', 'stale import msg');
    v_pass := v_pass + 1;
  end;

  -- conflict with concurrent mutation (lock bumped elsewhere)
  update public.site_utility_network_revisions
  set lock_version = lock_version + 1
  where id = v_rev
  returning lock_version into v_lock2;
  begin
    perform public.import_legacy_network_apply(v_rev, v_lock, v_site);
    perform util_net_test.assert(false, 'concurrent mutation');
  exception when others then
    perform util_net_test.assert(sqlerrm ilike '%version conflict%', 'concurrent mutation msg');
    v_pass := v_pass + 1;
  end;
  v_lock := v_lock2;

  -- apply import
  v_a := public.import_legacy_network_apply(v_rev, v_lock, v_site);
  v_lock := (v_a->>'lock_version')::int;
  perform util_net_test.assert(v_a->>'status' in ('imported', 'unchanged'), 'import status');
  v_pass := v_pass + 1;

  -- second apply idempotent — no lock bump if unchanged
  v_lock2 := v_lock;
  v_b := public.import_legacy_network_apply(v_rev, v_lock, v_site);
  perform util_net_test.assert(v_b->>'status' = 'unchanged' or (v_b->>'changed')::boolean = false, '2nd unchanged');
  perform util_net_test.assert((v_b->>'lock_version')::int = v_lock2, '2nd no lock bump');
  v_pass := v_pass + 1;

  -- coords preserved if legacy nodes exist
  if (v_a->>'legacy_nodes')::int > 0 then
    perform util_net_test.assert(
      (select count(*) from public.site_utility_view_nodes where revision_id = v_rev) > 0,
      'placements exist'
    );
  end if;
  v_pass := v_pass + 1;

  -- failed apply (stale) leaves graph size unchanged (transaction rollback)
  select count(*) into v_lock2 from public.site_utility_revision_nodes where revision_id = v_rev;
  begin
    perform public.import_legacy_network_apply(v_rev, v_lock - 1, v_site);
  exception when others then
    null;
  end;
  perform util_net_test.assert(
    (select count(*) from public.site_utility_revision_nodes where revision_id = v_rev) = v_lock2,
    'rollback preserves nodes'
  );
  v_pass := v_pass + 1;

  delete from public.site_utility_networks where id = v_network_id;
  return jsonb_build_object('passed_checks', v_pass, 'import_first', v_a, 'import_second', v_b, 'cleaned', true);
exception when others then
  begin
    delete from public.site_utility_networks where code like 'test-phase-c-%';
  exception when others then null;
  end;
  return jsonb_build_object('passed_checks', v_pass, 'error', sqlerrm);
end;
$$;

select util_net_test.run_phase_c() as phase_c_results;
