-- =============================================================================
-- 078: Conservation measurement & verification / savings (Phase 4)
-- Potential Excess ≠ Estimated Saving ≠ Verified Saving.
-- Additive. No meter_readings changes. No IPMVP/weather regression.
-- =============================================================================

create table if not exists public.conservation_measurement_verifications (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  opportunity_id uuid not null
    references public.conservation_opportunities (id) on delete restrict,
  action_id uuid references public.conservation_actions (id) on delete set null,
  baseline_id uuid not null
    references public.conservation_baselines (id) on delete restrict,
  target_id uuid references public.conservation_targets (id) on delete set null,
  meter_id uuid references public.meters (id) on delete set null,
  balance_group_id uuid
    references public.conservation_balance_groups (id) on delete set null,
  utility_type text not null,
  verification_method text not null,
  calculation_version integer not null default 1,
  supersedes_id uuid
    references public.conservation_measurement_verifications (id) on delete set null,
  pre_period_start date not null,
  pre_period_end date not null,
  post_period_start date not null,
  post_period_end date not null,
  baseline_value numeric(18, 4) not null,
  actual_post_value numeric(18, 4),
  adjusted_baseline_value numeric(18, 4),
  estimated_saving_quantity numeric(18, 4),
  verified_saving_quantity numeric(18, 4),
  unit_code text not null,
  data_completeness numeric(6, 4),
  confidence_score integer not null default 0,
  status text not null default 'draft',
  stale_reason text,
  needs_recalculation boolean not null default false,
  tariff_id uuid,
  cost_avoided numeric(18, 4),
  cost_currency text,
  calculation_meta jsonb not null default '{}'::jsonb,
  evidence_ids jsonb not null default '[]'::jsonb,
  calculated_at timestamptz not null default now(),
  estimated_at timestamptz,
  verified_by uuid references auth.users (id),
  verified_at timestamptz,
  rejected_by uuid references auth.users (id),
  rejected_at timestamptz,
  rejection_reason text,
  notes text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_mv_utility_check
    check (utility_type in ('water', 'electricity', 'cooling', 'other')),
  constraint conservation_mv_method_check
    check (verification_method in (
      'baseline_comparison',
      'before_after_period',
      'normalized_period_comparison'
    )),
  constraint conservation_mv_status_check
    check (status in (
      'draft',
      'estimated',
      'verification_pending',
      'verified',
      'rejected',
      'superseded',
      'archived'
    )),
  constraint conservation_mv_period_pre_check
    check (pre_period_end >= pre_period_start),
  constraint conservation_mv_period_post_check
    check (post_period_end >= post_period_start),
  constraint conservation_mv_confidence_check
    check (confidence_score >= 0 and confidence_score <= 100),
  constraint conservation_mv_version_positive
    check (calculation_version >= 1),
  constraint conservation_mv_unit_nonempty
    check (length(trim(unit_code)) > 0),
  -- Verified requires human verifier + timestamp + quantity set (may be 0).
  constraint conservation_mv_verified_actor_check
    check (
      status <> 'verified'
      or (
        verified_by is not null
        and verified_at is not null
        and verified_saving_quantity is not null
      )
    )
);

comment on table public.conservation_measurement_verifications is
  'M&V records. Estimated Saving ≠ Verified Saving. Potential Excess stays on Opportunity.';

comment on column public.conservation_measurement_verifications.estimated_saving_quantity is
  'Estimated only — not official until verified status + gates + human approval.';

comment on column public.conservation_measurement_verifications.verified_saving_quantity is
  'Official verified quantity after gates + human approval. May be 0. Negative outcomes stay non-positive.';

comment on column public.conservation_measurement_verifications.baseline_id is
  'Bound baseline version at calculation time — do not silently retarget to newer baseline.';

create index if not exists conservation_mv_site_status_idx
  on public.conservation_measurement_verifications (site_id, status);

create index if not exists conservation_mv_opp_idx
  on public.conservation_measurement_verifications (opportunity_id);

create index if not exists conservation_mv_action_idx
  on public.conservation_measurement_verifications (action_id)
  where action_id is not null;

create index if not exists conservation_mv_baseline_idx
  on public.conservation_measurement_verifications (baseline_id);

create index if not exists conservation_mv_meter_post_idx
  on public.conservation_measurement_verifications (meter_id, post_period_start, post_period_end)
  where meter_id is not null and status = 'verified';

create index if not exists conservation_mv_version_idx
  on public.conservation_measurement_verifications (opportunity_id, calculation_version);

create trigger conservation_mv_set_updated_at
  before update on public.conservation_measurement_verifications
  for each row execute function public.set_updated_at();

-- Block draft → verified shortcut.
create or replace function public.conservation_mv_transition_guard()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE'
     and old.status = 'draft'
     and new.status = 'verified' then
    raise exception
      'conservation_mv: draft → verified not allowed; estimate + verification_pending + gates first';
  end if;
  if tg_op = 'UPDATE'
     and new.status = 'verified'
     and old.status not in ('verification_pending', 'estimated') then
    if old.status <> 'verified' then
      raise exception
        'conservation_mv: verified only from verification_pending (or estimated→pending→verified)';
    end if;
  end if;
  -- Tighten: verified only from verification_pending
  if tg_op = 'UPDATE'
     and new.status = 'verified'
     and old.status is distinct from 'verified'
     and old.status <> 'verification_pending' then
    raise exception
      'conservation_mv: verified requires prior verification_pending status';
  end if;
  return new;
end;
$$;

drop trigger if exists conservation_mv_transition_guard_trg
  on public.conservation_measurement_verifications;
create trigger conservation_mv_transition_guard_trg
  before update on public.conservation_measurement_verifications
  for each row execute function public.conservation_mv_transition_guard();

alter table public.conservation_measurement_verifications enable row level security;

revoke all on table public.conservation_measurement_verifications from anon, authenticated;
grant select, insert, update, delete on table public.conservation_measurement_verifications to authenticated;

create policy "conservation_mv_select"
  on public.conservation_measurement_verifications for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "conservation_mv_insert"
  on public.conservation_measurement_verifications for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_mv_update"
  on public.conservation_measurement_verifications for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_mv_delete"
  on public.conservation_measurement_verifications for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.conservation_site_admin_manages(site_id)
      and status in ('draft', 'rejected', 'archived')
    )
  );

-- Verify authority: only site_admin/super/owner may set verified_* fields (trigger).
create or replace function public.conservation_mv_verify_authority()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.status = 'verified'
     and old.status is distinct from 'verified' then
    if not (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.conservation_site_admin_manages(new.site_id)
    ) then
      raise exception 'Verified Saving requires site_admin / super_admin / platform_owner';
    end if;
    if new.verified_by is null or new.verified_at is null then
      raise exception 'Verified Saving requires verified_by and verified_at';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists conservation_mv_verify_authority_trg
  on public.conservation_measurement_verifications;
create trigger conservation_mv_verify_authority_trg
  before update on public.conservation_measurement_verifications
  for each row execute function public.conservation_mv_verify_authority();
