-- P1E RLS + virtual reading rejection + members isolation
do $$
declare
  v_viewer uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4';
  v_tech uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_site_admin uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  v_super uuid := 'dddddddd-dddd-4ddd-8ddd-dddddddddd01';
  v_hq uuid := '22222222-2222-4222-8222-222222222222';
  v_ali uuid := 'e61ac413-2634-46d5-b8dd-f0b5f2f28875';
  v_physical uuid;
  v_virtual uuid;
  v_ok boolean;
  v_updated int;
  v_targets int;
  v_baselines int;
  v_readings int;
begin
  select count(*) into v_targets from conservation_targets;
  select count(*) into v_baselines from conservation_baselines;
  select count(*) into v_readings from meter_readings;

  -- Pick an existing HQ physical meter for parent/member tests
  select id into v_physical
  from meters
  where site_id = v_hq and meter_kind = 'physical' and calculation_type = 'direct_reading'
  limit 1;
  if v_physical is null then
    raise exception 'SETUP FAIL: no physical HQ meter';
  end if;

  delete from meters where meter_code like 'p1e_vm_%';

  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;

  insert into meters (
    site_id, meter_code, name_en, name_ar, category_id, source_id, unit_id,
    level, parent_meter_id, meter_kind, calculation_type, meter_multiplier,
    is_active, include_in_dashboard, sort_order, category, source, unit
  )
  select
    m.site_id, 'p1e_vm_sum', 'P1E VM', 'P1E VM', m.category_id, m.source_id, m.unit_id,
    'main', null, 'virtual', 'sum_children', 1,
    true, false, 9999, m.category, m.source, m.unit
  from meters m where m.id = v_physical
  returning id into v_virtual;

  insert into conservation_virtual_meter_members (virtual_meter_id, member_meter_id)
  values (v_virtual, v_physical);

  -- Virtual cannot receive readings
  begin
    insert into meter_readings (site_id, meter_id, reading_date, reading_value, normalized_value)
    values (v_hq, v_virtual, current_date, 1, 1);
    raise exception 'RLS FAIL virtual accepted reading';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;

  reset role;

  -- VIEWER: can see HQ virtual members; cannot insert
  perform set_config('request.jwt.claim.sub', v_viewer::text, true);
  set local role authenticated;
  select exists(
    select 1 from conservation_virtual_meter_members where virtual_meter_id = v_virtual
  ) into v_ok;
  if not v_ok then raise exception 'RLS FAIL viewer cannot see HQ vm members'; end if;
  begin
    insert into conservation_virtual_meter_members (virtual_meter_id, member_meter_id)
    values (v_virtual, v_physical);
    raise exception 'RLS FAIL viewer inserted member';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- TECH: no write
  perform set_config('request.jwt.claim.sub', v_tech::text, true);
  set local role authenticated;
  delete from conservation_virtual_meter_members where virtual_meter_id = v_virtual;
  get diagnostics v_updated = row_count;
  if v_updated > 0 then raise exception 'RLS FAIL tech deleted members'; end if;
  reset role;

  -- SITE ADMIN: manage HQ; cannot touch Ali site
  perform set_config('request.jwt.claim.sub', v_site_admin::text, true);
  set local role authenticated;
  -- delete+reinsert OK on HQ
  delete from conservation_virtual_meter_members where virtual_meter_id = v_virtual;
  insert into conservation_virtual_meter_members (virtual_meter_id, member_meter_id)
  values (v_virtual, v_physical);

  -- Cross-site member rejected by trigger
  begin
    insert into conservation_virtual_meter_members (virtual_meter_id, member_meter_id)
    select v_virtual, id from meters where site_id = v_ali and meter_kind='physical' limit 1;
    raise exception 'RLS FAIL cross-site member allowed';
  exception when others then
    if sqlerrm like 'RLS FAIL%' then raise; end if;
  end;
  reset role;

  -- Cycle trigger on parent_meter_id
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  set local role authenticated;
  begin
    update meters set parent_meter_id = id where id = v_physical;
    raise exception 'FAIL self-parent allowed';
  exception when others then
    if sqlerrm like 'FAIL self-parent%' then raise; end if;
  end;
  reset role;

  -- Cleanup virtual only (physical untouched)
  delete from meters where id = v_virtual;

  if (select count(*) from conservation_targets) <> v_targets then
    raise exception 'FAIL targets mutated';
  end if;
  if (select count(*) from conservation_baselines) <> v_baselines then
    raise exception 'FAIL baselines mutated';
  end if;
  if (select count(*) from meter_readings) <> v_readings then
    raise exception 'FAIL readings mutated';
  end if;
  if exists(select 1 from conservation_feature_flags where enabled) then
    raise exception 'FAIL flag enabled';
  end if;

  raise notice 'P1E_RLS_RESULT=PASS';
end;
$$;

select 'P1E_RLS_RESULT=PASS' as result,
       (select count(*) from meters where meter_kind='virtual') as virtual_meters,
       (select count(*) from conservation_virtual_meter_members) as members,
       (select count(*) from meter_readings) as readings,
       (select coalesce(bool_or(enabled),false) from conservation_feature_flags) as any_flag;
