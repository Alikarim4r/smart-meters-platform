-- =============================================================================
-- 092: Reading source / provenance (Phase 6) — additive; no bulk rewrite.
-- Historical NULL source_type treated as 'legacy' by application policy.
-- =============================================================================

alter table public.meter_readings
  add column if not exists reading_source text,
  add column if not exists source_system text,
  add column if not exists external_reading_id text,
  add column if not exists ingestion_job_id uuid,
  add column if not exists source_timestamp timestamptz,
  add column if not exists received_at timestamptz,
  add column if not exists source_quality text,
  add column if not exists source_metadata jsonb not null default '{}'::jsonb,
  add column if not exists import_batch_id uuid,
  add column if not exists original_raw_value numeric(20, 6),
  add column if not exists original_unit_code text,
  add column if not exists is_canonical boolean not null default true;

-- Soft check when source present (NULL = legacy historical).
alter table public.meter_readings
  drop constraint if exists meter_readings_reading_source_check;
alter table public.meter_readings
  add constraint meter_readings_reading_source_check
  check (
    reading_source is null
    or reading_source in (
      'manual',
      'manual_photo',
      'csv_import',
      'excel_import',
      'api',
      'smart_meter',
      'bms',
      'iot',
      'virtual',
      'legacy',
      'ocr_photo'
    )
  );

alter table public.meter_readings
  drop constraint if exists meter_readings_source_quality_check;
alter table public.meter_readings
  add constraint meter_readings_source_quality_check
  check (
    source_quality is null
    or source_quality in ('high', 'medium', 'low', 'unknown', 'suspect')
  );

comment on column public.meter_readings.reading_source is
  'Ingestion source type. NULL on historical rows = application treats as legacy/manual. No bulk backfill required.';

comment on column public.meter_readings.is_canonical is
  'Accepted/canonical reading for meter+date analytics. Original rows preserved; conflicts resolved via review.';

create unique index if not exists meter_readings_external_id_uq
  on public.meter_readings (source_system, external_reading_id)
  where external_reading_id is not null and source_system is not null;

create index if not exists meter_readings_import_batch_idx
  on public.meter_readings (import_batch_id)
  where import_batch_id is not null;

create index if not exists meter_readings_source_idx
  on public.meter_readings (reading_source)
  where reading_source is not null;

-- Future high-volume interval store (not used by mechanical daily unique path).
create table if not exists public.meter_interval_readings (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete restrict,
  meter_id uuid not null references public.meters (id) on delete restrict,
  period_start timestamptz not null,
  period_end timestamptz not null,
  raw_value numeric(20, 6) not null,
  normalized_value numeric(20, 6) not null,
  unit_code text,
  reading_source text not null,
  source_system text,
  external_reading_id text,
  ingestion_job_id uuid,
  source_quality text,
  source_metadata jsonb not null default '{}'::jsonb,
  received_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint meter_interval_period_check check (period_end > period_start),
  constraint meter_interval_source_check
    check (reading_source in (
      'api', 'smart_meter', 'bms', 'iot', 'csv_import', 'excel_import'
    ))
);

create unique index if not exists meter_interval_external_uq
  on public.meter_interval_readings (source_system, external_reading_id)
  where external_reading_id is not null and source_system is not null;

create index if not exists meter_interval_meter_period_idx
  on public.meter_interval_readings (meter_id, period_start, period_end);

comment on table public.meter_interval_readings is
  'Additive high-frequency interval store. Mechanical/daily readings stay in meter_readings. No automatic backfill.';

alter table public.meter_interval_readings enable row level security;
revoke all on table public.meter_interval_readings from anon, authenticated;
grant select, insert, update, delete on table public.meter_interval_readings to authenticated;

create policy "meter_interval_readings_select"
  on public.meter_interval_readings for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "meter_interval_readings_insert"
  on public.meter_interval_readings for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.can_manage_site(site_id)
  );

create policy "meter_interval_readings_update"
  on public.meter_interval_readings for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.can_manage_site(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.can_manage_site(site_id)
  );

create policy "meter_interval_readings_delete"
  on public.meter_interval_readings for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.can_manage_site(site_id)
  );
