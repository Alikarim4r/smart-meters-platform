-- =============================================================================
-- 072: Conservation opportunities (Phase 3)
-- Additive. Workflow only — no savings/tariffs/ROI/M&V.
-- Potential Excess ≠ Saving. Confirmed cause never auto-set here.
-- Explicit OR is_super_admin() / is_platform_owner() (062 gap).
-- =============================================================================

create table if not exists public.conservation_opportunities (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  meter_id uuid references public.meters (id) on delete set null,
  balance_group_id uuid references public.conservation_balance_groups (id) on delete set null,
  utility_type text not null,
  origin text not null default 'automatic',
  source_type text not null,
  source_fingerprint text not null,
  title text not null,
  description text not null default '',
  detected_period_start date not null,
  detected_period_end date not null,
  unit_code text,
  estimated_waste_quantity numeric(18, 4),
  -- Potential excess / quantity at risk — NEVER labeled Saving in app.
  confidence_score integer not null default 0,
  priority text not null default 'medium',
  status text not null default 'detected',
  possible_causes jsonb not null default '[]'::jsonb,
  suggested_investigations jsonb not null default '[]'::jsonb,
  -- Immutable detection snapshot (baseline/target/anomaly/balance context).
  source_snapshot jsonb not null default '{}'::jsonb,
  rule_version text not null default 'conservation_opportunity_v1',
  created_by uuid references auth.users (id),
  detected_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  resolution_reason text,
  dismissed_by uuid references auth.users (id),
  dismissed_at timestamptz,
  dismiss_reason text,
  dismiss_notes text,
  follow_up_start date,
  follow_up_end date,
  constraint conservation_opp_utility_check
    check (utility_type in ('water', 'electricity', 'cooling', 'other')),
  constraint conservation_opp_origin_check
    check (origin in ('automatic', 'manual')),
  constraint conservation_opp_source_type_check
    check (source_type in (
      'periodic_anomaly',
      'balance_difference',
      'actual_vs_target',
      'actual_vs_baseline',
      'cop_deterioration',
      'manual',
      'data_quality_conservation'
    )),
  constraint conservation_opp_priority_check
    check (priority in ('low', 'medium', 'high', 'critical')),
  constraint conservation_opp_status_check
    check (status in (
      'detected',
      'triaged',
      'under_investigation',
      'action_required',
      'monitoring',
      'resolved',
      'dismissed'
    )),
  constraint conservation_opp_period_check
    check (detected_period_end >= detected_period_start),
  constraint conservation_opp_confidence_check
    check (confidence_score >= 0 and confidence_score <= 100),
  constraint conservation_opp_title_nonempty
    check (length(trim(title)) > 0),
  constraint conservation_opp_fingerprint_nonempty
    check (length(trim(source_fingerprint)) > 0),
  constraint conservation_opp_dismiss_reason_check
    check (
      dismiss_reason is null
      or dismiss_reason in (
        'false_positive',
        'data_issue',
        'expected_operational_change',
        'duplicate',
        'no_action_required',
        'other'
      )
    )
);

comment on table public.conservation_opportunities is
  'Conservation opportunities (potential issues requiring investigation). Potential Excess ≠ Saving. No auto Confirmed Cause.';

comment on column public.conservation_opportunities.estimated_waste_quantity is
  'Potential excess / quantity at risk only — never Verified Saving.';

comment on column public.conservation_opportunities.source_snapshot is
  'Frozen detection context (periods, versions, values) — do not rewrite when baselines change.';

-- One open opportunity per fingerprint (dedupe). Closed/dismissed free the slot.
create unique index if not exists conservation_opp_open_fingerprint_uq
  on public.conservation_opportunities (site_id, source_fingerprint)
  where status not in ('resolved', 'dismissed');

create index if not exists conservation_opp_site_status_idx
  on public.conservation_opportunities (site_id, status);

create index if not exists conservation_opp_priority_idx
  on public.conservation_opportunities (site_id, priority);

create index if not exists conservation_opp_source_idx
  on public.conservation_opportunities (site_id, source_type);

create index if not exists conservation_opp_detected_idx
  on public.conservation_opportunities (site_id, detected_period_start, detected_period_end);

create trigger conservation_opp_set_updated_at
  before update on public.conservation_opportunities
  for each row execute function public.set_updated_at();

alter table public.conservation_opportunities enable row level security;

revoke all on table public.conservation_opportunities from anon, authenticated;
grant select, insert, update, delete on table public.conservation_opportunities to authenticated;

-- SELECT: site access
create policy "conservation_opp_select"
  on public.conservation_opportunities for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

-- INSERT: site_admin manage / super / owner (automatic generate + manual create)
create policy "conservation_opp_insert"
  on public.conservation_opportunities for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

-- UPDATE: site_admin manage / super / owner.
-- Technician may NOT resolve/dismiss/create; they work via investigation/action tables.
create policy "conservation_opp_update"
  on public.conservation_opportunities for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "conservation_opp_delete"
  on public.conservation_opportunities for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
      and status in ('detected', 'dismissed')
    )
  );
