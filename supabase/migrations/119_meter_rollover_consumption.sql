-- =============================================================================
-- Migration: 119_meter_rollover_consumption.sql
-- Description: Add rollover capacity to meters and handle it safely in the
--              daily consumption view without silently losing consumption.
-- =============================================================================

-- 1. Add rollover capacity configuration to meters
alter table public.meters
add column rollover_capacity numeric(20, 6) default null;

comment on column public.meters.rollover_capacity is 'The raw reading capacity at which the meter resets to 0 (e.g. 100000 for a 5-digit mechanical meter).';

-- 2. Update meter_daily_consumption view to handle rollovers and replacements safely
create or replace view public.meter_daily_consumption
with (security_invoker = true)
as
with ranked_readings as (
  select
    r.meter_id,
    r.site_id,
    r.reading_date,
    r.normalized_value,
    -- We need to look up meter factors to compute normalized rollover
    m.unit_to_base_factor,
    m.meter_multiplier,
    m.rollover_capacity,
    lag(r.normalized_value) over (
      partition by r.meter_id order by r.reading_date
    ) as prev_normalized_value
  from public.meter_readings r
  join public.meters m on m.id = r.meter_id
)
select
  meter_id,
  site_id,
  reading_date,
  normalized_value,
  prev_normalized_value,
  case
    -- First reading yields 0
    when prev_normalized_value is null then 
      0::numeric
    -- Normal increasing consumption
    when normalized_value >= prev_normalized_value then
      normalized_value - prev_normalized_value
    -- Negative delta (rollover or replacement boundary)
    else
      case
        -- If rollover capacity is configured, calculate rolled-over consumption safely
        when rollover_capacity is not null then
          -- Capacity must be multiplied by factors to match normalized scale
          ((rollover_capacity * unit_to_base_factor * meter_multiplier) - prev_normalized_value) + normalized_value
        -- Unverifiable negative delta: Do not invent consumption or silently clamp to 0. 
        -- Expose as NULL to indicate an anomaly/unverifiable transition.
        else
          null::numeric
      end
  end as daily_consumption,
  -- Expose transition flags explicitly
  case
    when prev_normalized_value is not null and normalized_value < prev_normalized_value and rollover_capacity is not null then true
    else false
  end as is_rollover,
  case
    when prev_normalized_value is not null and normalized_value < prev_normalized_value and rollover_capacity is null then true
    else false
  end as is_unverifiable
from ranked_readings;

comment on view public.meter_daily_consumption is
  'Computed daily consumption from cumulative normalized readings. Exposes unverifiable negative deltas as NULL rather than silently clamping to 0.';
