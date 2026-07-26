-- =============================================================================
-- Smart Meters Platform — Meter readings query performance
-- Migration: 011_meter_consumption_performance.sql
--
-- Problem: public.meter_daily_consumption runs LAG() over the full
-- meter_readings history. Large imports (e.g. MOEHE HQ ~44k rows) cause
-- statement timeouts (Postgres 57014) when the dashboard filters that view.
--
-- Dashboard clients now compute consumption from ranged meter_readings queries
-- plus a per-meter "previous reading" lookup. These indexes support that path.
-- =============================================================================

create index if not exists meter_readings_site_date_desc_idx
  on public.meter_readings (site_id, reading_date desc);

create index if not exists meter_readings_meter_date_desc_idx
  on public.meter_readings (meter_id, reading_date desc);
