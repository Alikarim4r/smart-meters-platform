-- =============================================================================
-- Meter place: bilingual (English + Arabic) within the site
-- Migration: 030_meter_place_bilingual.sql
-- =============================================================================

alter table public.meters
  add column if not exists location_en text;

alter table public.meters
  add column if not exists location_ar text;

-- Carry over any values entered in the single location column.
update public.meters
set location_en = nullif(trim(location), '')
where location_en is null
  and location is not null
  and trim(location) <> '';

comment on column public.meters.location_en is
  'Physical place of the meter within the site in English (e.g. Near the main gate). Not a city/address.';

comment on column public.meters.location_ar is
  'Physical place of the meter within the site in Arabic (e.g. بالقرب من البوابة الرئيسية). Not a city/address.';
