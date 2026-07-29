-- Phase 2 RLS: profiles, balance groups/members, classifications + audit.
-- Does not mutate meter_readings permanently; cleans up test rows.
do $$
declare
  v_viewer uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  v_tech uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_site_admin uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  v_super uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddd01';
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_ali uuid := 'e61ac413-2634-46d5-b8dd-f0b5f2f28875';
  v_physical uuid;
  v_physical2 uuid;
  v_group uuid;
  v_class uuid;
  v_ok boolean;
  v_readings int;
  v_flags_on int;
begin
  select count(*) into v_readings from meter_readings;
  select count(*) into v_flags_on from conservation_feature_flags where enabled = true;

  select id into v_physical
  from meters
  where site_id = v_hq and meter_kind = 'physical' and calculation_type = 'direct_reading'
  order by meter_code
  limit 1;
  select id into v_physical2
  from meters
  where site_id = v_hq and meter_kind = 'physical' and calculation_type = 'direct_reading'
    and id <> v_physical
  order by meter_code
  limit 1;
  if v_physical is null or v_physical2 is null then
    raise exception 'SETUP FAIL: need ≥2 physical HQ meters';
  end if;

  -- Cleanup prior P2 RLS fixtures (as login role — audit has no DELETE for authenticated)
  reset role;
  delete from conservation_balance_classifications where notes like 'p2_rls_%';
  delete from conservation_balance_group_members
  where balance_group_id in (
    select id from conservation_balance_groups where name like 'p2_rls_%'
  );
  delete from conservation_balance_groups where name like 'p2_rls_%';
  delete from site_conservation_profiles where profile_notes like 'p2_rls_%';

  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;

  insert into site_conservation_profiles (site_id, floor_area_m2, peer_group, profile_notes)
  values (v_hq, 1000, 'school', 'p2_rls_profile')
  on conflict (site_id) do update
    set floor_area_m2 = excluded.floor_area_m2,
        peer_group = excluded.peer_group,
        profile_notes = excluded.profile_notes;

  insert into conservation_balance_groups (
    site_id, name, utility_code, unit_code, main_meter_id, status
  ) values (
    v_hq, 'p2_rls_water', 'water', 'm3', v_physical, 'active'
  ) returning id into v_group;

  insert into conservation_balance_group_members (balance_group_id, member_meter_id)
  values (v_group, v_physical2);

  insert into conservation_balance_classifications (
    site_id, balance_group_id, period_start, period_end,
    classification, notes, classified_by
  ) values (
    v_hq, v_group, current_date - 30, current_date,
    'unknown', 'p2_rls_class', v_super
  ) returning id into v_class;

  reset role;

  -- VIEWER: select OK, write denied
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  set local role authenticated;
  select exists(select 1 from conservation_balance_groups where id = v_group) into v_ok;
  if not v_ok then raise exception 'RLS FAIL viewer cannot see HQ balance group'; end if;
  select exists(select 1 from site_conservation_profiles where site_id = v_hq) into v_ok;
  if not v_ok then raise exception 'RLS FAIL viewer cannot see HQ profile'; end if;
  select exists(
    select 1 from conservation_balance_classification_audit where classification_id = v_class
  ) into v_ok;
  if not v_ok then raise exception 'RLS FAIL viewer cannot see classification audit'; end if;
  begin
    insert into conservation_balance_groups (
      site_id, name, utility_code, unit_code, main_meter_id, status
    ) values (v_hq, 'p2_rls_viewer', 'water', 'm3', v_physical, 'draft');
    raise exception 'RLS FAIL viewer inserted balance group';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  begin
    update conservation_balance_classifications
      set classification = 'suspected_leak'
    where id = v_class;
    if found then raise exception 'RLS FAIL viewer updated classification'; end if;
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- TECH: no write on conservation admin tables
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  begin
    update site_conservation_profiles
      set occupancy_count = 99
    where site_id = v_hq and profile_notes like 'p2_rls_%';
    if found then raise exception 'RLS FAIL tech updated profile'; end if;
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  begin
    insert into conservation_balance_group_members (balance_group_id, member_meter_id)
    values (v_group, v_physical);
    raise exception 'RLS FAIL tech inserted member';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- SITE ADMIN: can manage HQ
  perform set_config('request.jwt.claim.sub', v_site_admin::text, true);
  set local role authenticated;
  update conservation_balance_classifications
    set classification = 'timing_alignment_difference',
        notes = 'p2_rls_class_updated',
        classified_by = v_site_admin
  where id = v_class;
  if not found then raise exception 'RLS FAIL site_admin cannot update classification'; end if;

  -- Cross-site write rejected (Ali site)
  begin
    insert into conservation_balance_groups (
      site_id, name, utility_code, unit_code, main_meter_id, status
    ) values (v_ali, 'p2_rls_cross', 'water', 'm3', v_physical, 'draft');
    raise exception 'RLS FAIL site_admin inserted cross-site group';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- SUPER: verify audit then cleanup as login role (audit SELECT-only for authenticated)
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;
  select exists(
    select 1 from conservation_balance_classification_audit
    where classification_id = v_class
      and previous_classification = 'unknown'
      and new_classification = 'timing_alignment_difference'
  ) into v_ok;
  if not v_ok then raise exception 'RLS FAIL audit trail missing after update'; end if;
  reset role;

  delete from conservation_balance_classifications where id = v_class;
  delete from conservation_balance_group_members where balance_group_id = v_group;
  delete from conservation_balance_groups where id = v_group;
  delete from site_conservation_profiles
  where site_id = v_hq and profile_notes like 'p2_rls_%';

  if (select count(*) from meter_readings) <> v_readings then
    raise exception 'RLS FAIL meter_readings mutated';
  end if;
  if (select count(*) from conservation_feature_flags where enabled = true) <> v_flags_on then
    raise exception 'RLS FAIL feature flags changed';
  end if;

  raise notice 'P2_RLS_RESULT=PASS';
end $$;
