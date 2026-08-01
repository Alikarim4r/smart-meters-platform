-- =============================================================================
-- 088: Portfolio summaries, forecasts, recommendations (Phase 5)
-- Precomputed / on-demand results — never recalculate entire portfolio on render.
-- =============================================================================

create table if not exists public.conservation_portfolio_summaries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  zone_id uuid references public.zones (id) on delete cascade,
  site_id uuid references public.sites (id) on delete cascade,
  scope_level text not null,
  period_start date,
  period_end date,
  verified_savings_total numeric(18, 4) not null default 0,
  cost_avoided_total numeric(18, 4),
  cost_currency text,
  carbon_avoided_total numeric(18, 6),
  carbon_unit text,
  open_opportunities integer not null default 0,
  actions_overdue integer not null default 0,
  verification_pending integer not null default 0,
  savings_not_sustained integer not null default 0,
  sites_above_target integer not null default 0,
  data_confidence_avg numeric(8, 4),
  priority_score numeric(12, 4),
  ranking_method text,
  ranking_explanations jsonb not null default '[]'::jsonb,
  metrics jsonb not null default '{}'::jsonb,
  lineage jsonb not null default '{}'::jsonb,
  refreshed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint conservation_portfolio_scope_check
    check (scope_level in ('organization', 'zone', 'site')),
  constraint conservation_portfolio_scope_shape_check
    check (
      (scope_level = 'organization' and zone_id is null and site_id is null)
      or (scope_level = 'zone' and zone_id is not null and site_id is null)
      or (scope_level = 'site' and site_id is not null)
    )
);

comment on table public.conservation_portfolio_summaries is
  'Cached portfolio aggregates. Verified totals use verified savings only. Refresh on demand/schedule.';

create unique index if not exists conservation_portfolio_org_uq
  on public.conservation_portfolio_summaries (organization_id)
  where scope_level = 'organization';

create unique index if not exists conservation_portfolio_zone_uq
  on public.conservation_portfolio_summaries (organization_id, zone_id)
  where scope_level = 'zone' and zone_id is not null;

create unique index if not exists conservation_portfolio_site_uq
  on public.conservation_portfolio_summaries (organization_id, site_id)
  where scope_level = 'site' and site_id is not null;

create index if not exists conservation_portfolio_org_refreshed_idx
  on public.conservation_portfolio_summaries (organization_id, refreshed_at desc);

create table if not exists public.conservation_forecast_results (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  utility_type text not null,
  forecast_horizon text not null,
  method text not null,
  history_length integer not null default 0,
  expected_value numeric(18, 4),
  expected_low numeric(18, 4),
  expected_high numeric(18, 4),
  target_value numeric(18, 4),
  expected_target_exceedance numeric(18, 4),
  expected_budget_impact numeric(18, 4),
  budget_currency text,
  confidence text not null default 'low',
  seasonality_handling text,
  uses_normalized boolean not null default false,
  status text not null default 'computed',
  warnings jsonb not null default '[]'::jsonb,
  lineage jsonb not null default '{}'::jsonb,
  calculated_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  constraint conservation_forecast_utility_check
    check (utility_type in ('water', 'electricity', 'cooling', 'other')),
  constraint conservation_forecast_horizon_check
    check (forecast_horizon in (
      'month_end', 'annual_target', 'annual_consumption', 'custom'
    )),
  constraint conservation_forecast_method_check
    check (method in (
      'run_rate',
      'seasonal_average',
      'rolling_average',
      'simple_trend',
      'normalized_trend',
      'insufficient_history'
    )),
  constraint conservation_forecast_confidence_check
    check (confidence in ('high', 'medium', 'low', 'insufficient')),
  constraint conservation_forecast_status_check
    check (status in ('computed', 'insufficient_history', 'not_available', 'stale'))
);

comment on table public.conservation_forecast_results is
  'Explainable periodic forecasts. Insufficient history ⇒ no invented number.';

create index if not exists conservation_forecast_site_horizon_idx
  on public.conservation_forecast_results (site_id, forecast_horizon, calculated_at desc);

create table if not exists public.conservation_recommendations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations (id) on delete cascade,
  site_id uuid references public.sites (id) on delete cascade,
  rule_key text not null,
  title text not null,
  rationale text not null,
  severity text not null default 'info',
  status text not null default 'open',
  related_entity_type text,
  related_entity_id uuid,
  explanation_factors jsonb not null default '[]'::jsonb,
  lineage jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_reco_severity_check
    check (severity in ('info', 'low', 'medium', 'high')),
  constraint conservation_reco_status_check
    check (status in ('open', 'acknowledged', 'dismissed', 'resolved')),
  constraint conservation_reco_title_nonempty
    check (length(trim(title)) > 0)
);

comment on table public.conservation_recommendations is
  'Rule-based recommendations only. No BMS control commands. AI limited to summarization elsewhere.';

create unique index if not exists conservation_reco_dedupe_idx
  on public.conservation_recommendations (site_id, rule_key, related_entity_id)
  where status = 'open' and site_id is not null;

create index if not exists conservation_reco_org_status_idx
  on public.conservation_recommendations (organization_id, status)
  where organization_id is not null;

create trigger conservation_reco_set_updated_at
  before update on public.conservation_recommendations
  for each row execute function public.set_updated_at();

alter table public.conservation_portfolio_summaries enable row level security;
alter table public.conservation_forecast_results enable row level security;
alter table public.conservation_recommendations enable row level security;

revoke all on table public.conservation_portfolio_summaries from anon, authenticated;
revoke all on table public.conservation_forecast_results from anon, authenticated;
revoke all on table public.conservation_recommendations from anon, authenticated;
grant select, insert, update, delete on table public.conservation_portfolio_summaries to authenticated;
grant select, insert, update, delete on table public.conservation_forecast_results to authenticated;
grant select, insert, update, delete on table public.conservation_recommendations to authenticated;

create policy "conservation_portfolio_select"
  on public.conservation_portfolio_summaries for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      site_id is not null and public.has_site_access(site_id)
    )
    or (
      zone_id is not null and exists (
        select 1 from public.sites s
        where s.zone_id = conservation_portfolio_summaries.zone_id
          and public.has_site_access(s.id)
      )
    )
  );

create policy "conservation_portfolio_write"
  on public.conservation_portfolio_summaries for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "conservation_forecast_select"
  on public.conservation_forecast_results for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "conservation_forecast_write"
  on public.conservation_forecast_results for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_reco_select"
  on public.conservation_recommendations for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null and public.has_site_access(site_id)
    )
    or (
      organization_id is not null
      and public.user_can_manage_organization(organization_id)
    )
  );

create policy "conservation_reco_write"
  on public.conservation_recommendations for all to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
    or (
      organization_id is not null
      and public.user_can_manage_organization(organization_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
    or (
      organization_id is not null
      and public.user_can_manage_organization(organization_id)
    )
  );
