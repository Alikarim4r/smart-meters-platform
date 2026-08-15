-- =============================================================================
-- 094: Import batches, rows, conflicts, retention policy metadata
-- Preview/validate before accept. Idempotent via fingerprint + external ids.
-- =============================================================================

create table if not exists public.import_batches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid references public.sites (id) on delete set null,
  data_source_id uuid references public.external_data_sources (id) on delete set null,
  source_type text not null,
  file_name text,
  storage_path text,
  file_fingerprint text not null,
  status text not null default 'preview',
  column_mapping jsonb not null default '{}'::jsonb,
  partial_acceptance boolean not null default true,
  rows_total int not null default 0,
  rows_accepted int not null default 0,
  rows_rejected int not null default 0,
  rows_duplicated int not null default 0,
  error_summary text,
  dry_run boolean not null default true,
  imported_by uuid references public.profiles (id) on delete set null,
  committed_at timestamptz,
  reversed_at timestamptz,
  reversed_by uuid references public.profiles (id) on delete set null,
  reverse_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint import_batches_source_check
    check (source_type in ('csv_import', 'excel_import')),
  constraint import_batches_status_check
    check (status in (
      'preview', 'validated', 'committing', 'committed', 'partial',
      'failed', 'reversed', 'cancelled'
    ))
);

create unique index if not exists import_batches_org_fingerprint_committed_uq
  on public.import_batches (organization_id, file_fingerprint)
  where status in ('committed', 'partial') and reversed_at is null;

create index if not exists import_batches_org_idx
  on public.import_batches (organization_id);

create index if not exists import_batches_status_idx
  on public.import_batches (status);

comment on table public.import_batches is
  'CSV/Excel import batches. No direct write without preview/validation. Idempotent fingerprint.';

create trigger import_batches_set_updated_at
  before update on public.import_batches
  for each row execute function public.set_updated_at();

-- FK from meter_readings.import_batch_id once batches exist
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'meter_readings_import_batch_id_fkey'
  ) then
    alter table public.meter_readings
      add constraint meter_readings_import_batch_id_fkey
      foreign key (import_batch_id) references public.import_batches (id)
      on delete set null;
  end if;
end $$;

create table if not exists public.import_batch_rows (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.import_batches (id) on delete cascade,
  row_number int not null,
  raw_payload jsonb not null default '{}'::jsonb,
  resolved_meter_id uuid references public.meters (id) on delete set null,
  resolved_site_id uuid references public.sites (id) on delete set null,
  reading_date date,
  raw_value numeric(20, 6),
  unit_code text,
  external_reading_id text,
  status text not null default 'pending',
  error_code text,
  error_message text,
  created_reading_id uuid references public.meter_readings (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint import_batch_rows_status_check
    check (status in (
      'pending', 'accepted', 'rejected', 'duplicated', 'reversed'
    )),
  constraint import_batch_rows_batch_row_uq unique (batch_id, row_number)
);

create index if not exists import_batch_rows_batch_idx
  on public.import_batch_rows (batch_id);

create index if not exists import_batch_rows_status_idx
  on public.import_batch_rows (batch_id, status);

comment on table public.import_batch_rows is
  'Per-row validation/result for import batches. Supports partial acceptance.';

-- Source conflicts requiring human review (no silent overwrite)
create table if not exists public.reading_source_conflicts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid not null references public.sites (id) on delete cascade,
  meter_id uuid not null references public.meters (id) on delete cascade,
  reading_date date not null,
  existing_reading_id uuid references public.meter_readings (id) on delete set null,
  incoming_source text not null,
  incoming_raw_value numeric(20, 6),
  incoming_payload jsonb not null default '{}'::jsonb,
  existing_raw_value numeric(20, 6),
  existing_source text,
  conflict_kind text not null,
  status text not null default 'pending_review',
  canonical_reading_id uuid references public.meter_readings (id) on delete set null,
  resolved_by uuid references public.profiles (id) on delete set null,
  resolved_at timestamptz,
  resolution_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reading_source_conflicts_kind_check
    check (conflict_kind in (
      'duplicate_identical', 'differing_values', 'source_priority', 'manual_vs_automated'
    )),
  constraint reading_source_conflicts_status_check
    check (status in (
      'pending_review', 'keep_existing', 'accept_incoming', 'retain_both', 'cancelled'
    ))
);

create index if not exists reading_source_conflicts_pending_idx
  on public.reading_source_conflicts (site_id, status)
  where status = 'pending_review';

create trigger reading_source_conflicts_set_updated_at
  before update on public.reading_source_conflicts
  for each row execute function public.set_updated_at();

comment on table public.reading_source_conflicts is
  'Conflicts between sources for same meter/date. No silent overwrite. Human review required.';

-- Retention policy metadata only (no automatic delete)
create table if not exists public.data_retention_policies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  policy_key text not null,
  target_table text not null,
  retention_days int,
  archive_after_days int,
  enabled boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint data_retention_policies_uq unique (organization_id, policy_key)
);

comment on table public.data_retention_policies is
  'Retention metadata only. Phase 6 never auto-deletes readings. Future archive needs separate approval.';

create trigger data_retention_policies_set_updated_at
  before update on public.data_retention_policies
  for each row execute function public.set_updated_at();

alter table public.import_batches enable row level security;
alter table public.import_batch_rows enable row level security;
alter table public.reading_source_conflicts enable row level security;
alter table public.data_retention_policies enable row level security;

revoke all on table public.import_batches from anon, authenticated;
revoke all on table public.import_batch_rows from anon, authenticated;
revoke all on table public.reading_source_conflicts from anon, authenticated;
revoke all on table public.data_retention_policies from anon, authenticated;

grant select, insert, update, delete on table public.import_batches to authenticated;
grant select, insert, update, delete on table public.import_batch_rows to authenticated;
grant select, insert, update, delete on table public.reading_source_conflicts to authenticated;
grant select, insert, update, delete on table public.data_retention_policies to authenticated;

create policy "import_batches_select"
  on public.import_batches for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (site_id is not null and public.has_site_access(site_id))
  );

create policy "import_batches_write"
  on public.import_batches for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      site_id is not null
      and public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      site_id is not null
      and public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "import_batch_rows_select"
  on public.import_batch_rows for select to authenticated
  using (
    exists (
      select 1 from public.import_batches b
      where b.id = import_batch_rows.batch_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(b.organization_id)
          or (b.site_id is not null and public.has_site_access(b.site_id))
        )
    )
  );

create policy "import_batch_rows_write"
  on public.import_batch_rows for all to authenticated
  using (
    exists (
      select 1 from public.import_batches b
      where b.id = import_batch_rows.batch_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(b.organization_id)
          or (
            b.site_id is not null
            and public.current_user_role() = 'site_admin'::public.user_role
            and public.can_manage_site(b.site_id)
          )
        )
    )
  )
  with check (
    exists (
      select 1 from public.import_batches b
      where b.id = import_batch_rows.batch_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(b.organization_id)
          or (
            b.site_id is not null
            and public.current_user_role() = 'site_admin'::public.user_role
            and public.can_manage_site(b.site_id)
          )
        )
    )
  );

create policy "reading_source_conflicts_select"
  on public.reading_source_conflicts for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "reading_source_conflicts_write"
  on public.reading_source_conflicts for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "data_retention_policies_select"
  on public.data_retention_policies for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "data_retention_policies_write"
  on public.data_retention_policies for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );
