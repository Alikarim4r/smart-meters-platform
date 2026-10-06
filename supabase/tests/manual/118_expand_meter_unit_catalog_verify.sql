-- =============================================================================
-- VERIFY after running 118_expand_meter_unit_catalog.sql
-- Paste in SQL Editor — expect ≥10 units per category.
-- =============================================================================

select c.code as category, count(*) as active_units
from public.meter_units u
join public.meter_categories c on c.id = u.category_id
where u.is_active
group by c.code
order by c.code;

select mst.code as measurement, count(*) as units
from public.measurement_units mu
join public.measurement_types mst on mst.id = mu.measurement_type_id
where mst.code in ('volume', 'active_energy', 'thermal_energy')
group by mst.code
order by mst.code;

-- Sample water labels (should include Cubic decimetre)
select code, name_en, unit_to_base_factor
from public.meter_units
where category_id = 'c1111111-1111-4111-8111-111111111101'
  and is_active
order by sort_order, name_en;

-- Optional: record migration (ignore if table/layout differs)
insert into supabase_migrations.schema_migrations (version)
values ('20260807011800')
on conflict do nothing;
