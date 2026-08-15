-- =============================================================================
-- 100: OCR readiness metadata + meter data frequency helper columns
-- OCR never auto-confirms readings.
-- =============================================================================

alter table public.meters
  add column if not exists data_frequency text,
  add column if not exists ocr_enabled boolean not null default false;

alter table public.meters
  drop constraint if exists meters_data_frequency_check;
alter table public.meters
  add constraint meters_data_frequency_check
  check (
    data_frequency is null
    or data_frequency in (
      'periodic_manual', 'monthly', 'weekly', 'daily', 'hourly', 'interval_15m', 'event_based'
    )
  );

comment on column public.meters.data_frequency is
  'Optional frequency classification for capability gating. NULL = treat as periodic_manual.';

comment on column public.meters.ocr_enabled is
  'OCR readiness flag only. Extracted values are Suggested Reading requiring human confirm.';

create table if not exists public.ocr_reading_suggestions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid not null references public.sites (id) on delete cascade,
  meter_id uuid not null references public.meters (id) on delete cascade,
  photo_path text,
  suggested_raw_value numeric(20, 6),
  confidence numeric(5, 4),
  status text not null default 'pending_confirm',
  confirmed_reading_id uuid references public.meter_readings (id) on delete set null,
  confirmed_by uuid references public.profiles (id) on delete set null,
  confirmed_at timestamptz,
  rejected_reason text,
  source_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ocr_reading_suggestions_status_check
    check (status in ('pending_confirm', 'confirmed', 'rejected', 'expired')),
  constraint ocr_reading_suggestions_confidence_check
    check (confidence is null or (confidence >= 0 and confidence <= 1))
);

create index if not exists ocr_reading_suggestions_pending_idx
  on public.ocr_reading_suggestions (site_id, status)
  where status = 'pending_confirm';

create trigger ocr_reading_suggestions_set_updated_at
  before update on public.ocr_reading_suggestions
  for each row execute function public.set_updated_at();

comment on table public.ocr_reading_suggestions is
  'OCR Suggested Reading → Human Confirm → Saved. Never auto-accepted as verified reading.';

alter table public.ocr_reading_suggestions enable row level security;
revoke all on table public.ocr_reading_suggestions from anon, authenticated;
grant select, insert, update, delete on table public.ocr_reading_suggestions to authenticated;

create policy "ocr_reading_suggestions_select"
  on public.ocr_reading_suggestions for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "ocr_reading_suggestions_write"
  on public.ocr_reading_suggestions for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.can_manage_site(site_id)
    or (
      public.current_user_role() = 'technician'::public.user_role
      and public.has_site_access(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.can_manage_site(site_id)
    or (
      public.current_user_role() = 'technician'::public.user_role
      and public.has_site_access(site_id)
    )
  );
