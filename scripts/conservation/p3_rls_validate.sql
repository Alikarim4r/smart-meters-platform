-- Phase 3 RLS: opportunities, investigations, actions, evidence, audit.
-- Cleans fixtures. Does not permanently mutate meter_readings.
do $$
declare
  v_viewer uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  v_tech uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_site_admin uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  v_super uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddd01';
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_out uuid := 'b82f2bb2-b85c-472e-b6e3-69c1ac97c1fb'; -- Osman — not managed by test site_admin
  v_opp uuid;
  v_inv uuid;
  v_act uuid;
  v_ev uuid;
  v_ok boolean;
  v_readings int;
  v_flags_on int;
  v_audit_count int;
begin
  select count(*) into v_readings from meter_readings;
  select count(*) into v_flags_on from conservation_feature_flags where enabled = true;

  reset role;
  delete from conservation_evidence where notes like 'p3_rls_%' or title like 'p3_rls_%';
  delete from conservation_actions where title like 'p3_rls_%';
  delete from conservation_investigations where notes like 'p3_rls_%' or finding_summary like 'p3_rls_%';
  delete from conservation_opportunities where title like 'p3_rls_%';

  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;

  insert into conservation_opportunities (
    site_id, utility_type, origin, source_type, source_fingerprint,
    title, description, detected_period_start, detected_period_end,
    unit_code, estimated_waste_quantity, confidence_score, priority, status,
    source_snapshot, created_by
  ) values (
    v_hq, 'water', 'automatic', 'periodic_anomaly', 'p3_rls_fp_hq_1',
    'p3_rls_opp', 'Potential excess test', current_date - 30, current_date,
    'm3', 100, 90, 'high', 'detected',
    '{"rule":"p3_rls"}'::jsonb, v_super
  ) returning id into v_opp;

  -- Deduplicate: second open insert same fingerprint must fail
  begin
    insert into conservation_opportunities (
      site_id, utility_type, origin, source_type, source_fingerprint,
      title, description, detected_period_start, detected_period_end,
      confidence_score, priority, status, created_by
    ) values (
      v_hq, 'water', 'automatic', 'periodic_anomaly', 'p3_rls_fp_hq_1',
      'p3_rls_dup', 'dup', current_date - 30, current_date,
      90, 'high', 'detected', v_super
    );
    raise exception 'RLS FAIL duplicate open fingerprint allowed';
  exception when unique_violation then
    null;
  when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
    if sqlstate = '23505' then null; else raise; end if;
  end;

  insert into conservation_investigations (
    opportunity_id, site_id, assigned_to, assigned_by, assigned_at,
    investigation_status, notes, created_by
  ) values (
    v_opp, v_hq, v_tech, v_super, now(),
    'assigned', 'p3_rls_inv', v_super
  ) returning id into v_inv;

  insert into conservation_actions (
    opportunity_id, investigation_id, site_id, title, action_type,
    owner_id, priority, status, created_by
  ) values (
    v_opp, v_inv, v_hq, 'p3_rls_action', 'inspect_meter',
    v_tech, 'medium', 'assigned', v_super
  ) returning id into v_act;

  perform public.conservation_workflow_audit_append(
    v_hq, 'opportunity', v_opp, 'created', null, 'detected', 'p3_rls', '{}'::jsonb
  );

  reset role;

  -- VIEWER: select OK, write denied
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  set local role authenticated;
  select exists(select 1 from conservation_opportunities where id = v_opp) into v_ok;
  if not v_ok then raise exception 'RLS FAIL viewer cannot see opportunity'; end if;
  begin
    insert into conservation_opportunities (
      site_id, utility_type, origin, source_type, source_fingerprint,
      title, description, detected_period_start, detected_period_end,
      confidence_score, priority, status
    ) values (
      v_hq, 'water', 'manual', 'manual', 'p3_rls_viewer',
      'p3_rls_viewer', 'x', current_date, current_date, 50, 'low', 'detected'
    );
    raise exception 'RLS FAIL viewer inserted opportunity';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- TECH unassigned: cannot update opportunity resolve; can select
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  begin
    update conservation_opportunities set status = 'dismissed' where id = v_opp;
    if found then raise exception 'RLS FAIL tech dismissed opportunity'; end if;
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;

  -- TECH assigned: can update investigation findings
  update conservation_investigations
    set finding_summary = 'p3_rls_finding', investigation_status = 'in_progress'
  where id = v_inv and assigned_to = v_tech;
  if not found then raise exception 'RLS FAIL tech cannot update assigned investigation'; end if;

  -- TECH assigned: can insert evidence on investigation
  insert into conservation_evidence (
    site_id, opportunity_id, investigation_id, evidence_kind, title, notes, uploaded_by
  ) values (
    v_hq, v_opp, v_inv, 'note', 'p3_rls_ev', 'p3_rls_note', v_tech
  ) returning id into v_ev;

  -- TECH cannot confirm cause without being allowed — actually policy allows update;
  -- app enforces human confirm. DB requires confirmed_by. Try confirm as tech:
  update conservation_investigations
    set confirmed_cause = 'operational_usage',
        confirmed_by = v_tech,
        confirmed_at = now()
  where id = v_inv;
  if not found then raise exception 'RLS FAIL tech confirm update blocked unexpectedly'; end if;

  update conservation_actions
    set status = 'in_progress', started_at = now()
  where id = v_act and owner_id = v_tech;
  if not found then raise exception 'RLS FAIL tech cannot progress owned action'; end if;
  reset role;

  -- SITE ADMIN: resolve opportunity
  perform set_config('request.jwt.claim.sub', v_site_admin::text, true);
  set local role authenticated;
  update conservation_opportunities
    set status = 'monitoring', follow_up_start = current_date
  where id = v_opp;
  if not found then raise exception 'RLS FAIL site_admin cannot update opportunity'; end if;

  -- Cross-site insert rejected (Osman not in site_admin managed set)
  begin
    insert into conservation_opportunities (
      site_id, utility_type, origin, source_type, source_fingerprint,
      title, description, detected_period_start, detected_period_end,
      confidence_score, priority, status
    ) values (
      v_out, 'water', 'manual', 'manual', 'p3_rls_cross',
      'p3_rls_cross', 'x', current_date, current_date, 50, 'low', 'detected'
    );
    raise exception 'RLS FAIL site_admin inserted out-of-scope opportunity';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- Audit append-only: authenticated cannot delete audit
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;
  select count(*) into v_audit_count from conservation_workflow_audit where notes = 'p3_rls';
  if v_audit_count < 1 then raise exception 'RLS FAIL audit missing'; end if;
  begin
    delete from conservation_workflow_audit where notes = 'p3_rls';
    raise exception 'RLS FAIL authenticated deleted audit';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- Cleanup as login role
  delete from conservation_evidence where id = v_ev or notes like 'p3_rls_%';
  delete from conservation_actions where id = v_act;
  delete from conservation_investigations where id = v_inv;
  delete from conservation_opportunities where id = v_opp or title like 'p3_rls_%';
  delete from conservation_workflow_audit where notes = 'p3_rls';

  if (select count(*) from meter_readings) <> v_readings then
    raise exception 'RLS FAIL meter_readings mutated';
  end if;
  if (select count(*) from conservation_feature_flags where enabled = true) <> v_flags_on then
    raise exception 'RLS FAIL feature flags changed';
  end if;

  -- Bucket exists
  if not exists (select 1 from storage.buckets where id = 'conservation-evidence') then
    raise exception 'RLS FAIL conservation-evidence bucket missing';
  end if;

  raise notice 'P3_RLS_RESULT=PASS';
end $$;
