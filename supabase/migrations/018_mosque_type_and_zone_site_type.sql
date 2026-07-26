-- =============================================================================
-- Migration: 018_mosque_type_and_zone_site_type.sql
-- 1) Add 'mosque' to site_type enum (schools, mosques, offices…).
-- 2) Zones may declare which site type they group (nullable = mixed zone).
--    Site forms default the site type from the selected zone.
-- NOTE: the new enum value is not referenced in this migration, so a single
-- transaction is safe.
-- =============================================================================

alter type public.site_type add value if not exists 'mosque';

alter table public.zones
  add column if not exists site_type public.site_type;

comment on column public.zones.site_type is
  'Optional: the kind of sites this zone groups (school, mosque…). Null = mixed.';
