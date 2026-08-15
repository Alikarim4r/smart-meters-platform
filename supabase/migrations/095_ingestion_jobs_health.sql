-- =============================================================================
-- 095: Ingestion jobs, runs, dead-letter, source health snapshots
-- Idempotent jobs, bounded retries, no silent data loss.
-- =============================================================================

create table if not exists public.ingestion_jobs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  data_source_id uuid references public.external_data_sources (id) on delete set null,
  job_name text not null,
  source_type text not null,
  schedule_cron text,
  status text not null default 'idle',
  enabled boolean not null default false,
  last_run_at timestamptz,
  next_run_at timestamptz,
  last_success_at timestamptz,
  last_error_summary text,
  retry_count int not null default 0,
  max_retries int not null default 3,
  records_accepted_last int not null default 0,
  records_rejected_last int not null default 0,
  job_config jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ingestion_jobs_status_check
    check (status in ('idle', 'running', 'success', 'partial', 'failed', 'disabled')),
  constraint ingestion_jobs_name_nonempty
    check (length(trim(job_name)) > 0)
);

create unique index if not exists ingestion_jobs_org_name_uq
  on public.ingestion_jobs (organization_id, job_name);

create index if not exists ingestion_jobs_enabled_idx
  on public.ingestion_jobs (enabled, next_run_at)
  where enabled = true;

create trigger ingestion_jobs_set_updated_at
  before update on public.ingestion_jobs
  for each row execute function public.set_updated_at();

comment on table public.ingestion_jobs is
  'Scheduled/manual ingestion jobs. Feature-flag gated. Failures retain error records.';

-- Link meter_readings.ingestion_job_id
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'meter_readings_ingestion_job_id_fkey'
  ) then
    alter table public.meter_readings
      add constraint meter_readings_ingestion_job_id_fkey
      foreign key (ingestion_job_id) references public.ingestion_jobs (id)
      on delete set null;
  end if;
end $$;

create table if not exists public.ingestion_job_runs (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.ingestion_jobs (id) on delete cascade,
  run_key text not null,
  status text not null default 'started',
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  records_accepted int not null default 0,
  records_rejected int not null default 0,
  error_summary text,
  is_retry boolean not null default false,
  attempt_number int not null default 1,
  audit_payload jsonb not null default '{}'::jsonb,
  constraint ingestion_job_runs_status_check
    check (status in ('started', 'success', 'partial', 'failed', 'cancelled')),
  constraint ingestion_job_runs_job_run_key_uq unique (job_id, run_key)
);

create index if not exists ingestion_job_runs_job_idx
  on public.ingestion_job_runs (job_id, started_at desc);

comment on table public.ingestion_job_runs is
  'Per-run audit for ingestion jobs. run_key enforces idempotent execution.';

create table if not exists public.ingestion_dead_letters (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  job_id uuid references public.ingestion_jobs (id) on delete set null,
  job_run_id uuid references public.ingestion_job_runs (id) on delete set null,
  data_source_id uuid references public.external_data_sources (id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  error_code text,
  error_message text not null,
  retry_count int not null default 0,
  status text not null default 'open',
  resolved_at timestamptz,
  resolved_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint ingestion_dead_letters_status_check
    check (status in ('open', 'retried', 'discarded', 'resolved'))
);

create index if not exists ingestion_dead_letters_open_idx
  on public.ingestion_dead_letters (organization_id, status)
  where status = 'open';

comment on table public.ingestion_dead_letters is
  'Failed ingestion payloads retained for manual retry. No infinite auto-retry.';

create table if not exists public.source_health_snapshots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  data_source_id uuid not null references public.external_data_sources (id) on delete cascade,
  status text not null,
  last_data_timestamp timestamptz,
  expected_frequency text,
  delay_seconds int,
  records_received int not null default 0,
  error_details text,
  snapshot_at timestamptz not null default now(),
  constraint source_health_snapshots_status_check
    check (status in (
      'healthy', 'delayed', 'failed', 'never_synced', 'disabled', 'authentication_required'
    ))
);

create index if not exists source_health_snapshots_source_idx
  on public.source_health_snapshots (data_source_id, snapshot_at desc);

comment on table public.source_health_snapshots is
  'Point-in-time source health. Data Availability Alerts use this — not Equipment Fault.';

alter table public.ingestion_jobs enable row level security;
alter table public.ingestion_job_runs enable row level security;
alter table public.ingestion_dead_letters enable row level security;
alter table public.source_health_snapshots enable row level security;

revoke all on table public.ingestion_jobs from anon, authenticated;
revoke all on table public.ingestion_job_runs from anon, authenticated;
revoke all on table public.ingestion_dead_letters from anon, authenticated;
revoke all on table public.source_health_snapshots from anon, authenticated;

grant select, insert, update, delete on table public.ingestion_jobs to authenticated;
grant select, insert, update, delete on table public.ingestion_job_runs to authenticated;
grant select, insert, update, delete on table public.ingestion_dead_letters to authenticated;
grant select, insert, update, delete on table public.source_health_snapshots to authenticated;

create policy "ingestion_jobs_select"
  on public.ingestion_jobs for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "ingestion_jobs_write"
  on public.ingestion_jobs for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "ingestion_job_runs_select"
  on public.ingestion_job_runs for select to authenticated
  using (
    exists (
      select 1 from public.ingestion_jobs j
      where j.id = ingestion_job_runs.job_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(j.organization_id)
        )
    )
  );

create policy "ingestion_job_runs_write"
  on public.ingestion_job_runs for all to authenticated
  using (
    exists (
      select 1 from public.ingestion_jobs j
      where j.id = ingestion_job_runs.job_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(j.organization_id)
        )
    )
  )
  with check (
    exists (
      select 1 from public.ingestion_jobs j
      where j.id = ingestion_job_runs.job_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(j.organization_id)
        )
    )
  );

create policy "ingestion_dead_letters_select"
  on public.ingestion_dead_letters for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "ingestion_dead_letters_write"
  on public.ingestion_dead_letters for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "source_health_snapshots_select"
  on public.source_health_snapshots for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or exists (
      select 1 from public.external_data_sources d
      where d.id = source_health_snapshots.data_source_id
        and d.site_id is not null
        and public.has_site_access(d.site_id)
    )
  );

create policy "source_health_snapshots_write"
  on public.source_health_snapshots for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );
