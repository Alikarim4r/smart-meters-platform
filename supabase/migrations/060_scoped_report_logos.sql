-- =============================================================================
-- Migration: 060_scoped_report_logos.sql
-- Site/zone secondary (top-left) logos + slot size note 6cm × 2cm.
-- Resolution: site logo → zone logo → org secondary → blank.
-- =============================================================================

alter table public.sites
  add column if not exists report_logo_path text;

alter table public.zones
  add column if not exists report_logo_path text;

comment on column public.sites.report_logo_path is
  'Site-specific report logo (PDF top-left). Storage path in report-logos bucket.';
comment on column public.zones.report_logo_path is
  'Zone-level report logo (PDF top-left fallback). Storage path in report-logos bucket.';

comment on column public.policy_settings.report_logo_secondary_path is
  'Org default top-left logo (6cm × 2cm). Overridden by zone/site logos when set.';
