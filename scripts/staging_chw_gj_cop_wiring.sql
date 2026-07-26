-- =============================================================================
-- Staging-only: reclassify CHW-LOOP-1/2/3 to BTU/GJ and wire Chiller Plant COP
-- Prerequisites: migrations 016 (gj enum) + 017 (catalog + admin_reclassify_meter) applied
-- Site: MOEHE HQ 22222222-2222-4222-8222-222222222222
-- Safe to re-run (idempotent clears + re-links COP members)
-- =============================================================================

-- Expect to be run as a role that can call admin_reclassify_meter (super_admin session)
-- or as postgres/service_role via SQL editor.

do $$
declare
  v_site uuid := '22222222-2222-4222-8222-222222222222';
  v_cop  uuid := '44444444-4444-4444-8444-444444444444';
  v_btu_cat uuid := 'c1111111-1111-4111-8111-111111111103';
  v_gj uuid := 'e1111111-1111-4111-8111-111111111305';
  v_src uuid := 'b1111111-1111-4111-8111-111111111301'; -- chilled_water (BTU)
  r record;
  v_lvp4 uuid;
  v_lvp5 uuid;
begin
  if not exists (select 1 from public.meter_units where id = v_gj) then
    raise exception 'GJ unit missing — apply migration 016 first';
  end if;

  for r in
    select id, meter_code,
      case meter_code
        when 'CHW-LOOP-1' then 'CHW-Loop 1 (Energy GJ)'
        when 'CHW-LOOP-2' then 'CHW-Loop 2 (Energy GJ)'
        when 'CHW-LOOP-3' then 'CHW-Loop 3 (Energy GJ)'
      end as name_en,
      case meter_code
        when 'CHW-LOOP-1' then 'حلقة تبريد 1 — طاقة (جيجاجول)'
        when 'CHW-LOOP-2' then 'حلقة تبريد 2 — طاقة (جيجاجول)'
        when 'CHW-LOOP-3' then 'حلقة تبريد 3 — طاقة (جيجاجول)'
      end as name_ar
    from public.meters
    where site_id = v_site
      and meter_code in ('CHW-LOOP-1', 'CHW-LOOP-2', 'CHW-LOOP-3')
  loop
    perform public.admin_reclassify_meter(
      r.id, v_btu_cat, v_src, v_gj, r.name_en, r.name_ar
    );

    update public.meters
    set is_active = true,
        include_in_dashboard = true,
        source = 'chilled_water'
    where id = r.id;
  end loop;

  -- Ensure COP group exists and describes the physical plant
  insert into public.cop_groups (id, site_id, name_en, name_ar, description, is_active)
  values (
    v_cop,
    v_site,
    'Chiller Plant COP',
    'معامل أداء محطة التبريد',
    '3 CHW energy loops (GJ) ÷ electrical panels LVP-4 + LVP-5 (kWh) serving four chillers.',
    true
  )
  on conflict (id) do update set
    description = excluded.description,
    name_en = excluded.name_en,
    name_ar = excluded.name_ar,
    is_active = true;

  delete from public.cop_group_btu_meters where cop_group_id = v_cop;
  delete from public.cop_group_electricity_meters where cop_group_id = v_cop;

  insert into public.cop_group_btu_meters (cop_group_id, meter_id, weight)
  select v_cop, id, 1
  from public.meters
  where site_id = v_site
    and meter_code in ('CHW-LOOP-1', 'CHW-LOOP-2', 'CHW-LOOP-3');

  select id into v_lvp4 from public.meters where site_id = v_site and meter_code = '1256361';
  select id into v_lvp5 from public.meters where site_id = v_site and meter_code = '1256362';

  if v_lvp4 is null or v_lvp5 is null then
    raise exception 'LVP-4 (1256361) and/or LVP-5 (1256362) not found';
  end if;

  insert into public.cop_group_electricity_meters (cop_group_id, meter_id, weight)
  values
    (v_cop, v_lvp4, 1),
    (v_cop, v_lvp5, 1);
end
$$;
