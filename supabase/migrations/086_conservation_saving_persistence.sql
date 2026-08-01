-- =============================================================================
-- 086: Saving persistence follow-up (Phase 5)
-- Original verified saving preserved. Persistence is additive analysis.
-- =============================================================================

create table if not exists public.conservation_saving_persistence (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  measurement_verification_id uuid not null
    references public.conservation_measurement_verifications (id) on delete restrict,
  follow_up_window text not null,
  follow_up_start date not null,
  follow_up_end date not null,
  expected_reference_consumption numeric(18, 4),
  actual_consumption numeric(18, 4),
  sustained_quantity numeric(18, 4),
  persistence_pct numeric(8, 4),
  data_completeness numeric(6, 4),
  confidence_score integer not null default 0,
  status text not null default 'insufficient_follow_up',
  reopen_opportunity_suggested boolean not null default false,
  reopen_suggestion_key text,
  warnings jsonb not null default '[]'::jsonb,
  lineage jsonb not null default '{}'::jsonb,
  calculated_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_persist_window_check
    check (follow_up_window in ('1m', '3m', '6m', '12m')),
  constraint conservation_persist_status_check
    check (status in (
      'verified',
      'sustained',
      'partially_sustained',
      'not_sustained',
      'insufficient_follow_up',
      'declining',
      'stale'
    )),
  constraint conservation_persist_period_check
    check (follow_up_end >= follow_up_start),
  constraint conservation_persist_confidence_check
    check (confidence_score >= 0 and confidence_score <= 100),
  constraint conservation_persist_uq
    unique (measurement_verification_id, follow_up_window, follow_up_start, follow_up_end)
);

comment on table public.conservation_saving_persistence is
  'Follow-up persistence of a Verified Saving. Does not alter or delete the original MV row. '
  'Windows 1/3/6/12 months applied only when data cadence supports them.';

create unique index if not exists conservation_persist_reopen_dedupe_idx
  on public.conservation_saving_persistence (site_id, reopen_suggestion_key)
  where reopen_opportunity_suggested = true
    and reopen_suggestion_key is not null;

create index if not exists conservation_persist_site_status_idx
  on public.conservation_saving_persistence (site_id, status);

create index if not exists conservation_persist_mv_idx
  on public.conservation_saving_persistence (measurement_verification_id);

create trigger conservation_persist_set_updated_at
  before update on public.conservation_saving_persistence
  for each row execute function public.set_updated_at();

alter table public.conservation_saving_persistence enable row level security;

revoke all on table public.conservation_saving_persistence from anon, authenticated;
grant select, insert, update, delete on table public.conservation_saving_persistence to authenticated;

create policy "conservation_persist_select"
  on public.conservation_saving_persistence for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "conservation_persist_insert"
  on public.conservation_saving_persistence for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_persist_update"
  on public.conservation_saving_persistence for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_persist_delete"
  on public.conservation_saving_persistence for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );
