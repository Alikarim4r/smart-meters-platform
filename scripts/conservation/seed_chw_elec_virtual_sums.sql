-- =============================================================================
-- Staging: virtual sum meters for MOEHE HQ cooling loops + electricity
-- Site: 22222222-2222-4222-8222-222222222222
-- Idempotent. Does NOT touch meter_readings.
--
-- Creates:
--   VM-CHW-LOOPS-SUM  = CHW-LOOP-1 + CHW-LOOP-2 + CHW-LOOP-3 (GJ)
--   VM-ELEC-ALL-SUM   = all active physical electricity meters (kWh)
-- =============================================================================

do $$
declare
  v_site uuid := '22222222-2222-4222-8222-222222222222';
  v_chw  uuid := 'a1111111-1111-4111-8111-1111111111e1';
  v_elec uuid := 'a1111111-1111-4111-8111-1111111111e2';
  v_sample_chw record;
  v_sample_elec record;
  r record;
begin
  select id, category_id, source_id, unit_id
    into v_sample_chw
  from public.meters
  where site_id = v_site and meter_code = 'CHW-LOOP-1' and is_active
  limit 1;
  if v_sample_chw.id is null then
    raise exception 'CHW-LOOP-1 not found on MOEHE HQ';
  end if;

  select m.id, m.category_id, m.source_id, m.unit_id
    into v_sample_elec
  from public.meters m
  join public.meter_categories mc on mc.id = m.category_id
  where m.site_id = v_site
    and mc.code = 'electricity'
    and coalesce(m.meter_kind, 'physical') = 'physical'
    and m.is_active
  order by m.meter_code
  limit 1;
  if v_sample_elec.id is null then
    raise exception 'No electricity meters on MOEHE HQ';
  end if;

  -- cleanup prior
  delete from public.conservation_virtual_meter_members
    where virtual_meter_id in (v_chw, v_elec);
  delete from public.meters
    where id in (v_chw, v_elec)
       or (site_id = v_site and meter_code in ('VM-CHW-LOOPS-SUM', 'VM-ELEC-ALL-SUM'));

  insert into public.meters (
    id, site_id, meter_code, name_en, name_ar,
    category_id, source_id, unit_id, level,
    meter_kind, calculation_type, meter_multiplier,
    is_active, include_in_dashboard, sort_order
  ) values (
    v_chw, v_site, 'VM-CHW-LOOPS-SUM',
    'Sum of CHW Loops 1–3', 'مجموع لوبات التبريد 1–3',
    v_sample_chw.category_id, v_sample_chw.source_id, v_sample_chw.unit_id,
    'main', 'virtual', 'sum_children', 1, true, true, 0
  );

  insert into public.meters (
    id, site_id, meter_code, name_en, name_ar,
    category_id, source_id, unit_id, level,
    meter_kind, calculation_type, meter_multiplier,
    is_active, include_in_dashboard, sort_order
  ) values (
    v_elec, v_site, 'VM-ELEC-ALL-SUM',
    'Sum of Electricity Meters', 'مجموع عدادات الكهرباء',
    v_sample_elec.category_id, v_sample_elec.source_id, v_sample_elec.unit_id,
    'main', 'virtual', 'sum_children', 1, true, true, 0
  );

  insert into public.conservation_virtual_meter_members (virtual_meter_id, member_meter_id)
  select v_chw, id
  from public.meters
  where site_id = v_site
    and meter_code in ('CHW-LOOP-1', 'CHW-LOOP-2', 'CHW-LOOP-3')
    and is_active;

  insert into public.conservation_virtual_meter_members (virtual_meter_id, member_meter_id)
  select v_elec, m.id
  from public.meters m
  join public.meter_categories mc on mc.id = m.category_id
  where m.site_id = v_site
    and mc.code = 'electricity'
    and coalesce(m.meter_kind, 'physical') = 'physical'
    and m.is_active;

  if (select count(*) from public.conservation_virtual_meter_members where virtual_meter_id = v_chw) <> 3 then
    raise exception 'Expected 3 CHW loop members';
  end if;
end
$$;
