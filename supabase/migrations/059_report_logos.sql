-- =============================================================================
-- Migration: 059_report_logos.sql
-- Org report logos: owner primary (top-right) + admin secondary (top-left).
-- Slot aspect ~ 4cm x 2cm (2:1). Empty = blank space in PDF (no box).
-- =============================================================================

alter table public.policy_settings
  add column if not exists report_logo_primary_path text,
  add column if not exists report_logo_secondary_path text;

comment on column public.policy_settings.report_logo_primary_path is
  'Owner-only org logo (report top-right). Storage path in report-logos bucket.';
comment on column public.policy_settings.report_logo_secondary_path is
  'Admin org/site logo (report top-left). Storage path in report-logos bucket.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'report-logos',
  'report-logos',
  false,
  5242880,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do nothing;

drop policy if exists report_logos_select on storage.objects;
create policy report_logos_select
  on storage.objects for select
  using (
    bucket_id = 'report-logos'
    and public.is_approved_active_user()
  );

drop policy if exists report_logos_insert on storage.objects;
create policy report_logos_insert
  on storage.objects for insert
  with check (
    bucket_id = 'report-logos'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.is_approved_active_user()
    )
  );

drop policy if exists report_logos_update on storage.objects;
create policy report_logos_update
  on storage.objects for update
  using (
    bucket_id = 'report-logos'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.is_approved_active_user()
    )
  );

drop policy if exists report_logos_delete on storage.objects;
create policy report_logos_delete
  on storage.objects for delete
  using (
    bucket_id = 'report-logos'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.is_approved_active_user()
    )
  );
