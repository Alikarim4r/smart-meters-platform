-- =============================================================================
-- 087: Emission factors + carbon avoided (Phase 5) — optional layer
-- No hard-coded factors. Missing factor ⇒ Carbon Avoided = Not Available.
-- Verified Carbon Total uses Verified Saving only (never Estimated).
-- =============================================================================

create table if not exists public.emission_factors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  utility_or_fuel_type text not null,
  geography text not null default 'QA',
  factor numeric(18, 8) not null,
  unit_code text not null,
  co2e_unit text not null default 'kgCO2e',
  source text not null,
  effective_from date not null,
  effective_to date,
  status text not null default 'draft',
  notes text,
  created_by uuid references auth.users (id),
  approved_by uuid references auth.users (id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint emission_factors_type_check
    check (utility_or_fuel_type in (
      'grid_electricity',
      'diesel',
      'fuel',
      'water_related'
    )),
  constraint emission_factors_status_check
    check (status in ('draft', 'active', 'expired', 'superseded', 'archived')),
  constraint emission_factors_factor_positive
    check (factor > 0),
  constraint emission_factors_effective_check
    check (effective_to is null or effective_to >= effective_from),
  constraint emission_factors_source_nonempty
    check (length(trim(source)) > 0),
  constraint emission_factors_unit_nonempty
    check (length(trim(unit_code)) > 0)
);

comment on table public.emission_factors is
  'Versioned / effective-dated emission factors. Never invent a factor when missing.';

create table if not exists public.conservation_carbon_results (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  measurement_verification_id uuid
    references public.conservation_measurement_verifications (id) on delete set null,
  quantity_basis text not null,
  saving_quantity numeric(18, 4),
  emission_factor_id uuid references public.emission_factors (id) on delete restrict,
  factor_value_snapshot numeric(18, 8),
  factor_source_snapshot text,
  factor_effective_from_snapshot date,
  carbon_avoided numeric(18, 6),
  carbon_unit text,
  status text not null default 'not_available',
  lineage jsonb not null default '{}'::jsonb,
  warnings jsonb not null default '[]'::jsonb,
  calculated_at timestamptz not null default now(),
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  constraint conservation_carbon_basis_check
    check (quantity_basis in ('verified_saving', 'estimated_saving')),
  constraint conservation_carbon_status_check
    check (status in (
      'computed',
      'not_available',
      'expired_factor',
      'missing_factor',
      'stale'
    ))
);

comment on table public.conservation_carbon_results is
  'Carbon Avoided with bound factor snapshot. Official Verified Carbon Total = verified basis only.';

create index if not exists emission_factors_org_type_status_idx
  on public.emission_factors (organization_id, utility_or_fuel_type, status, effective_from);

create index if not exists conservation_carbon_site_status_idx
  on public.conservation_carbon_results (site_id, status);

create index if not exists conservation_carbon_mv_idx
  on public.conservation_carbon_results (measurement_verification_id)
  where measurement_verification_id is not null;

create trigger emission_factors_set_updated_at
  before update on public.emission_factors
  for each row execute function public.set_updated_at();

create or replace function public.emission_factors_approve_authority()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'active'
     and (
       tg_op = 'INSERT'
       or new.status is distinct from old.status
       or new.approved_by is distinct from old.approved_by
       or new.approved_at is distinct from old.approved_at
     ) then
    if not (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.user_can_manage_organization(new.organization_id)
    ) then
      raise exception
        'emission factor activation requires org manage / super_admin / platform_owner';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists emission_factors_approve_authority_trg
  on public.emission_factors;
create trigger emission_factors_approve_authority_trg
  before insert or update on public.emission_factors
  for each row execute function public.emission_factors_approve_authority();

alter table public.emission_factors enable row level security;
alter table public.conservation_carbon_results enable row level security;

revoke all on table public.emission_factors from anon, authenticated;
revoke all on table public.conservation_carbon_results from anon, authenticated;
grant select, insert, update, delete on table public.emission_factors to authenticated;
grant select, insert, update, delete on table public.conservation_carbon_results to authenticated;

create policy "emission_factors_select"
  on public.emission_factors for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or exists (
      select 1 from public.sites s
      where s.organization_id = emission_factors.organization_id
        and public.has_site_access(s.id)
    )
  );

create policy "emission_factors_insert"
  on public.emission_factors for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "emission_factors_update"
  on public.emission_factors for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "emission_factors_delete"
  on public.emission_factors for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "conservation_carbon_select"
  on public.conservation_carbon_results for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "conservation_carbon_insert"
  on public.conservation_carbon_results for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_carbon_update"
  on public.conservation_carbon_results for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_carbon_delete"
  on public.conservation_carbon_results for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );
