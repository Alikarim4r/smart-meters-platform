-- pgTAP: meter_daily_consumption rollover safety (migrations 119 + 121).
-- Fixtures use gen_random_uuid() so they never collide with existing data;
-- everything runs inside a transaction that is rolled back.
begin;
select plan(29);

create temp table fx (name text primary key, id uuid not null default gen_random_uuid()) on commit drop;
insert into fx (name) values
  ('org'), ('site'),
  ('m_nocap'), ('m_cap'), ('m_midcap'), ('m_scaled'), ('m_edge_in'), ('m_edge_out');

insert into public.organizations (id, name_en, name_ar)
select id, 'rollover-test-' || id::text, 'rollover-test-' || id::text from fx where name = 'org';

insert into public.sites (id, organization_id, name_en, name_ar)
select s.id, o.id, 'rollover-site-' || s.id::text, 'rollover-site-' || s.id::text
from fx s, fx o where s.name = 'site' and o.name = 'org';

-- name, unit, meter_multiplier, rollover_capacity (raw)
-- unit_to_base_factor is NOT caller-supplied: meters triggers derive it from
-- the unit catalog (meter_units), e.g. water 'm3' → 1, 'liter' → 0.001.
insert into public.meters (
  id, site_id, meter_code, name_en, name_ar, category, unit,
  base_unit, meter_multiplier, rollover_capacity
)
select m.id, s.id, 'RT-' || m.id::text, m.name, m.name, 'water', v.unit::public.meter_unit,
       'm3', v.mult, v.cap
from (values
  ('m_nocap',    'm3',    1::numeric, null::numeric),
  ('m_cap',      'm3',    1::numeric, 10000::numeric),
  ('m_midcap',   'm3',    1::numeric, 10000::numeric),
  ('m_scaled',   'liter', 2::numeric, 10000::numeric),
  ('m_edge_in',  'm3',    1::numeric, 1000::numeric),
  ('m_edge_out', 'm3',    1::numeric, 1000::numeric)
) as v(name, unit, mult, cap)
join fx m on m.name = v.name
join fx s on s.name = 'site';

-- normalized_value is recomputed by trigger (raw × factor × multiplier).
insert into public.meter_readings (site_id, meter_id, reading_date, raw_value, normalized_value)
select s.id, m.id, v.d::date, v.raw, 0
from (values
  ('m_nocap',    '2023-01-01', 9990::numeric),
  ('m_nocap',    '2023-01-02', 10::numeric),     -- drop, no capacity → reset/replacement
  ('m_cap',      '2023-01-01', 9990::numeric),
  ('m_cap',      '2023-01-02', 10::numeric),     -- plausible rollover → 20
  ('m_cap',      '2023-01-03', 15::numeric),     -- normal → 5
  ('m_cap',      '2023-01-04', 12::numeric),     -- small drop → correction
  ('m_midcap',   '2023-01-01', 5000::numeric),
  ('m_midcap',   '2023-01-02', 10::numeric),     -- capacity set but prev not near top
  ('m_scaled',   '2023-01-01', 9990::numeric),   -- 9990 L × 0.001 × 2 = 19.98 m3
  ('m_scaled',   '2023-01-02', 10::numeric),     -- 0.02 m3; cap 10000 × 0.001 × 2 = 20 → 0.04
  ('m_edge_in',  '2023-01-01', 900::numeric),    -- exactly cap × 0.9
  ('m_edge_in',  '2023-01-02', 50::numeric),     -- rollover → 150
  ('m_edge_out', '2023-01-01', 899::numeric),    -- just below cap × 0.9
  ('m_edge_out', '2023-01-02', 50::numeric)      -- not a rollover
) as v(name, d, raw)
join fx m on m.name = v.name
join fx s on s.name = 'site';

create temp view dc as
select f.name, c.reading_date, c.daily_consumption, c.is_rollover,
       c.is_unverifiable, c.consumption_status
from public.meter_daily_consumption c
join fx f on f.id = c.meter_id;

-- First reading
select is((select daily_consumption from dc where name = 'm_nocap' and reading_date = '2023-01-01'),
  0::numeric, 'first reading yields 0');
select is((select consumption_status from dc where name = 'm_nocap' and reading_date = '2023-01-01'),
  'first', 'first reading status');

-- No capacity: never invent consumption
select is((select daily_consumption from dc where name = 'm_nocap' and reading_date = '2023-01-02'),
  null::numeric, 'drop without capacity is NULL (not invented, not clamped)');
select is((select consumption_status from dc where name = 'm_nocap' and reading_date = '2023-01-02'),
  'reset_or_replacement', 'drop to near zero without capacity = reset/replacement');
select ok((select is_unverifiable from dc where name = 'm_nocap' and reading_date = '2023-01-02'),
  'unverifiable flag set');
select ok(not (select is_rollover from dc where name = 'm_nocap' and reading_date = '2023-01-02'),
  'rollover flag not set without capacity');

-- Plausible rollover
select is((select daily_consumption from dc where name = 'm_cap' and reading_date = '2023-01-02'),
  20::numeric, 'near-capacity rollover = (10000 − 9990) + 10');
select ok((select is_rollover from dc where name = 'm_cap' and reading_date = '2023-01-02'),
  'rollover flag set');
select ok(not (select is_unverifiable from dc where name = 'm_cap' and reading_date = '2023-01-02'),
  'rollover is not unverifiable');
select is((select daily_consumption from dc where name = 'm_cap' and reading_date = '2023-01-03'),
  5::numeric, 'normal increase after rollover');
select is((select consumption_status from dc where name = 'm_cap' and reading_date = '2023-01-03'),
  'normal', 'normal status');

-- Correction on a capacity meter is NOT a rollover
select is((select daily_consumption from dc where name = 'm_cap' and reading_date = '2023-01-04'),
  null::numeric, 'small drop on capacity meter is NULL');
select is((select consumption_status from dc where name = 'm_cap' and reading_date = '2023-01-04'),
  'correction_or_implausible_drop', 'small drop = correction/implausible');

-- Replacement on a capacity meter (prev far from capacity) is NOT a rollover
select is((select daily_consumption from dc where name = 'm_midcap' and reading_date = '2023-01-02'),
  null::numeric, 'mid-register drop to ~0 is NULL even with capacity');
select is((select consumption_status from dc where name = 'm_midcap' and reading_date = '2023-01-02'),
  'reset_or_replacement', 'mid-register drop = reset/replacement');

-- Scaling: capacity normalized by factor × multiplier, exact numeric precision
select is((select m.unit_to_base_factor from public.meters m join fx f on f.id = m.id where f.name = 'm_scaled'),
  0.001::numeric, 'fixture premise: catalog factor for water liter is 0.001');
select is((select r.normalized_value from public.meter_readings r join fx f on f.id = r.meter_id
           where f.name = 'm_scaled' and r.reading_date = '2023-01-01'),
  19.98::numeric, 'normalized_value = raw × catalog factor × multiplier');
select is((select daily_consumption from dc where name = 'm_scaled' and reading_date = '2023-01-02'),
  0.04::numeric, 'rollover uses capacity × factor × multiplier (20 − 19.98 + 0.02)');
select ok((select is_rollover from dc where name = 'm_scaled' and reading_date = '2023-01-02'),
  'scaled rollover flagged');

-- Edge of the near-capacity window
select is((select daily_consumption from dc where name = 'm_edge_in' and reading_date = '2023-01-02'),
  150::numeric, 'prev exactly at cap × 0.9 is accepted as rollover');
select is((select consumption_status from dc where name = 'm_edge_out' and reading_date = '2023-01-02'),
  'reset_or_replacement', 'prev just below cap × 0.9 is not a rollover');
select is((select daily_consumption from dc where name = 'm_edge_out' and reading_date = '2023-01-02'),
  null::numeric, 'non-rollover edge drop is NULL');

-- SUM ignores unverifiable rows (excluded, never invented)
select is((select sum(daily_consumption) from dc where name = 'm_cap'),
  25::numeric, 'sum over capacity meter = 0 + 20 + 5 (correction excluded)');

-- View contract
select ok((select 'security_invoker=true' = any (c.reloptions)
           from pg_class c where c.oid = 'public.meter_daily_consumption'::regclass),
  'view keeps security_invoker');
select has_column('public', 'meter_daily_consumption', 'consumption_status',
  'view exposes consumption_status');

-- CHECK constraint: capacity must be positive and finite
select throws_ok(
  format($q$update public.meters set rollover_capacity = 0 where id = %L$q$,
         (select id from fx where name = 'm_cap')),
  '23514', null, 'zero capacity rejected');
select throws_ok(
  format($q$update public.meters set rollover_capacity = -100 where id = %L$q$,
         (select id from fx where name = 'm_cap')),
  '23514', null, 'negative capacity rejected');
select throws_ok(
  format($q$update public.meters set rollover_capacity = 'NaN' where id = %L$q$,
         (select id from fx where name = 'm_cap')),
  '23514', null, 'NaN capacity rejected');
select lives_ok(
  format($q$update public.meters set rollover_capacity = null where id = %L$q$,
         (select id from fx where name = 'm_cap')),
  'NULL capacity allowed');

select * from finish();
rollback;
