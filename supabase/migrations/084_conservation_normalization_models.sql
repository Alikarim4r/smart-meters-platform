-- =============================================================================
-- 084: Weather / occupancy normalization models (Phase 5)
-- Explainable methods only. Quality-gated. Versioned + approved.
-- =============================================================================

create table if not exists public.conservation_normalization_models (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid not null references public.sites (id) on delete cascade,
  utility_type text not null,
  weather_sensitive boolean not null default false,
  method text not null,
  training_period_start date not null,
  training_period_end date not null,
  dependent_variable text not null,
  weather_variables text[] not null default '{}',
  occupancy_variables text[] not null default '{}',
  weather_dataset_id uuid
    references public.conservation_weather_datasets (id) on delete set null,
  sample_count integer not null default 0,
  goodness_of_fit numeric(8, 6),
  confidence text not null default 'low',
  model_version integer not null default 1,
  coefficients jsonb not null default '{}'::jsonb,
  status text not null default 'draft',
  quality_gate_passed boolean not null default false,
  quality_gate_failures jsonb not null default '[]'::jsonb,
  warnings jsonb not null default '[]'::jsonb,
  calculated_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  approved_by uuid references auth.users (id),
  approved_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_norm_model_utility_check
    check (utility_type in ('water', 'electricity', 'cooling', 'other')),
  constraint conservation_norm_model_method_check
    check (method in (
      'degree_day',
      'simple_linear_regression',
      'weather_adjusted_baseline',
      'occupancy_adjusted_baseline',
      'operating_day_intensity'
    )),
  constraint conservation_norm_model_confidence_check
    check (confidence in ('high', 'medium', 'low', 'unreliable')),
  constraint conservation_norm_model_status_check
    check (status in ('draft', 'approved', 'rejected', 'superseded', 'archived')),
  constraint conservation_norm_model_period_check
    check (training_period_end >= training_period_start),
  constraint conservation_norm_model_version_positive
    check (model_version >= 1),
  constraint conservation_norm_model_sample_nonneg
    check (sample_count >= 0),
  constraint conservation_norm_model_approved_actor_check
    check (
      status <> 'approved'
      or (
        approved_by is not null
        and approved_at is not null
        and quality_gate_passed = true
      )
    )
);

comment on table public.conservation_normalization_models is
  'Explainable normalization models. Official use requires quality_gate_passed + approved. '
  'Weather methods only for weather-sensitive utilities (cooling electricity, CHW, HVAC).';

create table if not exists public.conservation_normalized_results (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  model_id uuid
    references public.conservation_normalization_models (id) on delete set null,
  utility_type text not null,
  period_start date not null,
  period_end date not null,
  actual_consumption numeric(18, 4) not null,
  normalized_consumption numeric(18, 4),
  weather_adjusted_baseline numeric(18, 4),
  occupancy_adjusted_baseline numeric(18, 4),
  intensity_value numeric(18, 6),
  intensity_unit text,
  capability_level text not null default 'A',
  unit_code text not null,
  status text not null default 'computed',
  reliability text not null default 'ok',
  lineage jsonb not null default '{}'::jsonb,
  warnings jsonb not null default '[]'::jsonb,
  calculated_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  constraint conservation_norm_result_utility_check
    check (utility_type in ('water', 'electricity', 'cooling', 'other')),
  constraint conservation_norm_result_capability_check
    check (capability_level in ('A', 'B', 'C')),
  constraint conservation_norm_result_status_check
    check (status in ('computed', 'not_reliable', 'not_available', 'stale')),
  constraint conservation_norm_result_reliability_check
    check (reliability in ('ok', 'low', 'unreliable', 'not_available')),
  constraint conservation_norm_result_period_check
    check (period_end >= period_start),
  constraint conservation_norm_result_unit_nonempty
    check (length(trim(unit_code)) > 0)
);

comment on table public.conservation_normalized_results is
  'Actual vs normalized consumption kept separate. Normalized never replaces operational actuals.';

create index if not exists conservation_norm_model_site_status_idx
  on public.conservation_normalization_models (site_id, status);

create index if not exists conservation_norm_model_org_idx
  on public.conservation_normalization_models (organization_id);

create index if not exists conservation_norm_result_site_period_idx
  on public.conservation_normalized_results (site_id, period_start, period_end);

create trigger conservation_norm_model_set_updated_at
  before update on public.conservation_normalization_models
  for each row execute function public.set_updated_at();

create or replace function public.conservation_norm_model_approve_authority()
returns trigger
language plpgsql
as $$
begin
  if (tg_op = 'INSERT' and new.status = 'approved')
     or (
       tg_op = 'UPDATE'
       and (
         new.status is distinct from old.status
         or new.approved_by is distinct from old.approved_by
         or new.approved_at is distinct from old.approved_at
       )
       and new.status = 'approved'
     ) then
    if not (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.conservation_site_admin_manages(new.site_id)
    ) then
      raise exception
        'normalization model approval requires site_admin / super_admin / platform_owner';
    end if;
    if new.quality_gate_passed is not true then
      raise exception
        'normalization model cannot be approved when quality gates failed (Normalization Not Reliable)';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists conservation_norm_model_approve_authority_trg
  on public.conservation_normalization_models;
create trigger conservation_norm_model_approve_authority_trg
  before insert or update on public.conservation_normalization_models
  for each row execute function public.conservation_norm_model_approve_authority();

alter table public.conservation_normalization_models enable row level security;
alter table public.conservation_normalized_results enable row level security;

revoke all on table public.conservation_normalization_models from anon, authenticated;
revoke all on table public.conservation_normalized_results from anon, authenticated;
grant select, insert, update, delete on table public.conservation_normalization_models to authenticated;
grant select, insert, update, delete on table public.conservation_normalized_results to authenticated;

create policy "conservation_norm_model_select"
  on public.conservation_normalization_models for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "conservation_norm_model_insert"
  on public.conservation_normalization_models for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_norm_model_update"
  on public.conservation_normalization_models for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_norm_model_delete"
  on public.conservation_normalization_models for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_norm_result_select"
  on public.conservation_normalized_results for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "conservation_norm_result_insert"
  on public.conservation_normalized_results for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_norm_result_update"
  on public.conservation_normalized_results for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_norm_result_delete"
  on public.conservation_normalized_results for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

-- Additive M&V methods for Phase 5 (do not rewrite 078).
alter table public.conservation_measurement_verifications
  drop constraint if exists conservation_mv_method_check;

alter table public.conservation_measurement_verifications
  add constraint conservation_mv_method_check
  check (verification_method in (
    'baseline_comparison',
    'before_after_period',
    'normalized_period_comparison',
    'weather_adjusted_baseline',
    'occupancy_adjusted_baseline'
  ));
