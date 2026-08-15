-- =============================================================================
-- 091: Phase 6 feature flag documentation (keys only; never auto-enabled)
-- =============================================================================

comment on table public.conservation_feature_flags is
  'Conservation + platform optional flags. Missing row / enabled=false = OFF. '
  'Phase 5 keys: weather_normalization, occupancy_normalization, saving_persistence, '
  'carbon_accounting, portfolio_optimization, forecasting, recommendation_engine. '
  'Phase 6 keys (also usable via same table or platform_feature_flags if added): '
  'unified_ingestion, file_import, api_ingestion, smart_meter_sources, bms_sources, '
  'ingestion_jobs, source_health, notification_center, automation_rules, '
  'ai_assistant, ocr_readiness.';

-- Dedicated platform feature flags table (additive; same OFF semantics).
create table if not exists public.platform_feature_flags (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid references public.sites (id) on delete cascade,
  flag_key text not null,
  enabled boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint platform_feature_flags_key_nonempty
    check (length(trim(flag_key)) > 0)
);

create unique index if not exists platform_feature_flags_org_wide_uq
  on public.platform_feature_flags (organization_id, flag_key)
  where site_id is null;

create unique index if not exists platform_feature_flags_site_uq
  on public.platform_feature_flags (organization_id, site_id, flag_key)
  where site_id is not null;

comment on table public.platform_feature_flags is
  'Platform/integration feature flags. Missing row or enabled=false = OFF. Never auto-enabled.';

create trigger platform_feature_flags_set_updated_at
  before update on public.platform_feature_flags
  for each row execute function public.set_updated_at();

alter table public.platform_feature_flags enable row level security;
revoke all on table public.platform_feature_flags from anon, authenticated;
grant select, insert, update, delete on table public.platform_feature_flags to authenticated;

create policy "platform_feature_flags_select"
  on public.platform_feature_flags for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or exists (
      select 1 from public.sites s
      where s.organization_id = platform_feature_flags.organization_id
        and public.has_site_access(s.id)
    )
  );

create policy "platform_feature_flags_write"
  on public.platform_feature_flags for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );
