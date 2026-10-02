-- =============================================================================
-- Migration: 121_meter_rollover_safety.sql
-- Supersedes the 119 view logic. 119 treated EVERY negative delta on a meter
-- with rollover_capacity as a rollover (inventing consumption on corrections /
-- replacements), allowed non-positive capacities, and inner-joined meters
-- (rows vanished when the caller could not read the meter row).
--
-- Semantics (mirrored by packages/smart_meters_core/lib/domain/
-- cumulative_consumption.dart → classifyCumulativeDelta):
--   cap = rollover_capacity × unit_to_base_factor × meter_multiplier
--         (only when all three are > 0; normalized scale, like normalized_value)
--   first reading                        → 0,                     'first'
--   current ≥ previous                   → current − previous,    'normal'
--   current < previous AND cap present AND
--     cap×0.9 ≤ previous ≤ cap AND 0 ≤ current ≤ cap×0.1
--                                        → (cap − previous) + current, 'rollover'
--   other drop, |current| ≤ |previous|×0.1 → NULL, 'reset_or_replacement'
--   any other drop                       → NULL, 'correction_or_implausible_drop'
--
-- NULL daily_consumption means "unverifiable — excluded, never invented";
-- consumption_status always explains it. SUM() ignores those rows.
--
-- RLS: security_invoker stays on; meter_readings RLS filters rows. meters is
-- LEFT JOINed so readings never disappear; if the caller cannot read the
-- meter, cap is NULL and drops are reported unverifiable (fail-safe).
--
-- Performance: same window as before (partition by meter_id, ordered by the
-- unique (meter_id, reading_date) key) plus a PK lookup on meters. Filters on
-- meter_id push below the window; date/site filters cannot without changing
-- LAG results — dashboards use ranged meter_readings queries instead (011).
--
-- Non-destructive: constraint + view replacement only; no data changes.
-- Column order/types of 119 are preserved; consumption_status is appended.
-- =============================================================================

alter table public.meters
  add column if not exists rollover_capacity numeric(20, 6) default null;

alter table public.meters
  drop constraint if exists meters_rollover_capacity_positive;

-- Rejects 0, negatives and NaN (NaN sorts above every number in Postgres).
alter table public.meters
  add constraint meters_rollover_capacity_positive
  check (
    rollover_capacity is null
    or (rollover_capacity > 0 and rollover_capacity < 1e15)
  ) not valid;

alter table public.meters
  validate constraint meters_rollover_capacity_positive;

comment on column public.meters.rollover_capacity is
  'Raw register capacity at which the meter rolls over to 0 (e.g. 100000 for a 5-digit register). NULL = unknown; must be > 0. Only near-capacity drops are treated as rollovers.';

create or replace view public.meter_daily_consumption
with (security_invoker = true)
as
with ordered as (
  select
    r.meter_id,
    r.site_id,
    r.reading_date,
    r.normalized_value,
    lag(r.normalized_value) over (
      partition by r.meter_id order by r.reading_date
    ) as prev_normalized_value
  from public.meter_readings r
),
with_capacity as (
  select
    o.*,
    case
      when m.rollover_capacity > 0
        and m.unit_to_base_factor > 0
        and m.meter_multiplier > 0
      then m.rollover_capacity * m.unit_to_base_factor * m.meter_multiplier
    end as normalized_capacity
  from ordered o
  left join public.meters m on m.id = o.meter_id
),
classified as (
  select
    c.*,
    case
      when c.prev_normalized_value is null then 'first'
      when c.normalized_value >= c.prev_normalized_value then 'normal'
      when c.normalized_capacity is not null
        and c.prev_normalized_value <= c.normalized_capacity
        and c.prev_normalized_value >= c.normalized_capacity * 0.9
        and c.normalized_value >= 0
        and c.normalized_value <= c.normalized_capacity * 0.1
      then 'rollover'
      when abs(c.normalized_value) <= abs(c.prev_normalized_value) * 0.1
      then 'reset_or_replacement'
      else 'correction_or_implausible_drop'
    end as consumption_status
  from with_capacity c
)
select
  meter_id,
  site_id,
  reading_date,
  normalized_value,
  prev_normalized_value,
  (case consumption_status
    when 'first' then 0
    when 'normal' then normalized_value - prev_normalized_value
    when 'rollover' then
      greatest(0, (normalized_capacity - prev_normalized_value) + normalized_value)
    else null
  end)::numeric as daily_consumption,
  (consumption_status = 'rollover') as is_rollover,
  (consumption_status in ('reset_or_replacement', 'correction_or_implausible_drop'))
    as is_unverifiable,
  consumption_status
from classified;

comment on view public.meter_daily_consumption is
  'Daily consumption from cumulative normalized readings. First reading = 0. Plausible near-capacity rollovers are counted; any other drop yields NULL daily_consumption with consumption_status reset_or_replacement / correction_or_implausible_drop (never invented, never clamped).';

grant select on public.meter_daily_consumption to authenticated;
