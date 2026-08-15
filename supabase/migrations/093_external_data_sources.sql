-- =============================================================================
-- 093: External data sources, meter mapping, frequency, capability metadata
-- No BMS control columns. Secrets never stored in plaintext here.
-- =============================================================================

create table if not exists public.external_data_sources (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid references public.sites (id) on delete cascade,
  source_key text not null,
  display_name text not null,
  source_type text not null,
  adapter_kind text not null default 'generic',
  status text not null default 'never_synced',
  expected_frequency text,
  connection_config jsonb not null default '{}'::jsonb,
  mapping_config jsonb not null default '{}'::jsonb,
  -- Credential reference only (Vault/secret name). Never store raw API keys.
  secret_ref text,
  last_successful_sync_at timestamptz,
  last_error text,
  last_data_timestamp timestamptz,
  records_received_total bigint not null default 0,
  enabled boolean not null default false,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint external_data_sources_type_check
    check (source_type in (
      'csv_import', 'excel_import', 'api', 'smart_meter', 'bms', 'iot', 'ocr_photo', 'virtual'
    )),
  constraint external_data_sources_status_check
    check (status in (
      'healthy', 'delayed', 'failed', 'never_synced', 'disabled', 'authentication_required'
    )),
  constraint external_data_sources_frequency_check
    check (
      expected_frequency is null
      or expected_frequency in (
        'periodic_manual', 'monthly', 'weekly', 'daily', 'hourly', 'interval_15m', 'event_based'
      )
    ),
  constraint external_data_sources_key_nonempty
    check (length(trim(source_key)) > 0)
);

create unique index if not exists external_data_sources_org_key_uq
  on public.external_data_sources (organization_id, source_key);

create index if not exists external_data_sources_org_idx
  on public.external_data_sources (organization_id);

create index if not exists external_data_sources_site_idx
  on public.external_data_sources (site_id)
  where site_id is not null;

comment on table public.external_data_sources is
  'External/source configuration. Read-only ingestion readiness. No equipment control. Secrets via secret_ref only.';

comment on column public.external_data_sources.secret_ref is
  'Server-side secret name/path only. Never store plaintext credentials.';

create trigger external_data_sources_set_updated_at
  before update on public.external_data_sources
  for each row execute function public.set_updated_at();

-- Meter ↔ source mapping + data frequency classification
create table if not exists public.meter_source_mappings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid not null references public.sites (id) on delete cascade,
  meter_id uuid not null references public.meters (id) on delete cascade,
  data_source_id uuid references public.external_data_sources (id) on delete set null,
  external_meter_code text,
  data_frequency text not null default 'periodic_manual',
  source_priority int not null default 100,
  is_primary boolean not null default false,
  mapping_metadata jsonb not null default '{}'::jsonb,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meter_source_mappings_frequency_check
    check (data_frequency in (
      'periodic_manual', 'monthly', 'weekly', 'daily', 'hourly', 'interval_15m', 'event_based'
    ))
);

create unique index if not exists meter_source_mappings_meter_source_uq
  on public.meter_source_mappings (meter_id, data_source_id)
  where data_source_id is not null;

create index if not exists meter_source_mappings_meter_idx
  on public.meter_source_mappings (meter_id);

create index if not exists meter_source_mappings_site_idx
  on public.meter_source_mappings (site_id);

comment on table public.meter_source_mappings is
  'Maps meters to external sources and declares data frequency for capability gating.';

create trigger meter_source_mappings_set_updated_at
  before update on public.meter_source_mappings
  for each row execute function public.set_updated_at();

-- Capability matrix (metadata only; interval analytics may be documented without implementation)
create table if not exists public.data_capability_matrix (
  id uuid primary key default gen_random_uuid(),
  data_frequency text not null,
  capability_key text not null,
  supported boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  constraint data_capability_matrix_freq_check
    check (data_frequency in (
      'periodic_manual', 'monthly', 'weekly', 'daily', 'hourly', 'interval_15m', 'event_based'
    )),
  constraint data_capability_matrix_uq unique (data_frequency, capability_key)
);

comment on table public.data_capability_matrix is
  'Declares which analytics capabilities are available per data frequency. Phase 6 matrix only.';

insert into public.data_capability_matrix (data_frequency, capability_key, supported, notes)
values
  ('periodic_manual', 'period_comparisons', true, null),
  ('periodic_manual', 'targets', true, null),
  ('periodic_manual', 'baselines', true, null),
  ('periodic_manual', 'balance', true, null),
  ('periodic_manual', 'mv', true, null),
  ('periodic_manual', 'forecast', true, null),
  ('periodic_manual', 'load_profile', false, 'Requires interval data'),
  ('periodic_manual', 'night_flow', false, 'Requires interval data'),
  ('periodic_manual', 'peak_demand', false, 'Requires interval data'),
  ('periodic_manual', 'time_of_use', false, 'Requires interval data'),
  ('monthly', 'period_comparisons', true, null),
  ('monthly', 'targets', true, null),
  ('monthly', 'baselines', true, null),
  ('monthly', 'balance', true, null),
  ('monthly', 'mv', true, null),
  ('monthly', 'forecast', true, null),
  ('daily', 'period_comparisons', true, null),
  ('daily', 'targets', true, null),
  ('daily', 'baselines', true, null),
  ('daily', 'balance', true, null),
  ('daily', 'mv', true, null),
  ('daily', 'forecast', true, null),
  ('hourly', 'load_profile', true, 'Matrix readiness; analytics deferred'),
  ('hourly', 'peak_demand', true, 'Matrix readiness; analytics deferred'),
  ('interval_15m', 'load_profile', true, 'Matrix readiness; analytics deferred'),
  ('interval_15m', 'night_flow', true, 'Matrix readiness; analytics deferred'),
  ('interval_15m', 'peak_demand', true, 'Matrix readiness; analytics deferred'),
  ('interval_15m', 'time_of_use', true, 'Matrix readiness; analytics deferred')
on conflict (data_frequency, capability_key) do nothing;

alter table public.external_data_sources enable row level security;
alter table public.meter_source_mappings enable row level security;
alter table public.data_capability_matrix enable row level security;

revoke all on table public.external_data_sources from anon, authenticated;
revoke all on table public.meter_source_mappings from anon, authenticated;
revoke all on table public.data_capability_matrix from anon, authenticated;
grant select, insert, update, delete on table public.external_data_sources to authenticated;
grant select, insert, update, delete on table public.meter_source_mappings to authenticated;
grant select on table public.data_capability_matrix to authenticated;

create policy "external_data_sources_select"
  on public.external_data_sources for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      site_id is not null and public.has_site_access(site_id)
    )
    or exists (
      select 1 from public.sites s
      where s.organization_id = external_data_sources.organization_id
        and public.has_site_access(s.id)
    )
  );

create policy "external_data_sources_write"
  on public.external_data_sources for all to authenticated
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

create policy "meter_source_mappings_select"
  on public.meter_source_mappings for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "meter_source_mappings_write"
  on public.meter_source_mappings for all to authenticated
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

create policy "data_capability_matrix_select"
  on public.data_capability_matrix for select to authenticated
  using (true);
