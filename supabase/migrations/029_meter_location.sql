-- =============================================================================
-- Meter physical location (where the meter is installed within the site)
-- Migration: 029_meter_location.sql
-- =============================================================================

alter table public.meters
  add column if not exists location text;

comment on column public.meters.location is
  'Physical place of the meter within the site (e.g. near the main gate). Not a city/address.';
