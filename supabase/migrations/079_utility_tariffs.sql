-- =============================================================================
-- 079: Utility tariffs (Phase 4) — versioned / effective-dated
-- No hard-coded rates in app. Missing tariff → Cost Avoided N/A (not 0).
-- =============================================================================

create table if not exists public.utility_tariffs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid references public.sites (id) on delete cascade,
  utility_type text not null,
  rate numeric(18, 6) not null,
  currency text not null default 'QAR',
  unit_code text not null,
  effective_from date not null,
  effective_to date,
  status text not null default 'active',
  source_notes text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint utility_tariffs_utility_check
    check (utility_type in ('water', 'electricity', 'cooling', 'other')),
  constraint utility_tariffs_rate_positive
    check (rate > 0),
  constraint utility_tariffs_currency_nonempty
    check (length(trim(currency)) > 0),
  constraint utility_tariffs_unit_nonempty
    check (length(trim(unit_code)) > 0),
  constraint utility_tariffs_status_check
    check (status in ('active', 'superseded', 'archived')),
  constraint utility_tariffs_effective_order
    check (effective_to is null or effective_to >= effective_from)
);

comment on table public.utility_tariffs is
  'Effective-dated utility tariffs. site_id null = org-wide. Never invent rates in Dart.';

create index if not exists utility_tariffs_lookup_idx
  on public.utility_tariffs (organization_id, utility_type, status, effective_from);

create index if not exists utility_tariffs_site_idx
  on public.utility_tariffs (site_id)
  where site_id is not null;

create trigger utility_tariffs_set_updated_at
  before update on public.utility_tariffs
  for each row execute function public.set_updated_at();

-- Bind tariff FK now that table exists.
alter table public.conservation_measurement_verifications
  drop constraint if exists conservation_mv_tariff_fk;
alter table public.conservation_measurement_verifications
  add constraint conservation_mv_tariff_fk
  foreign key (tariff_id) references public.utility_tariffs (id) on delete set null;

alter table public.utility_tariffs enable row level security;

revoke all on table public.utility_tariffs from anon, authenticated;
grant select, insert, update, delete on table public.utility_tariffs to authenticated;

create policy "utility_tariffs_select"
  on public.utility_tariffs for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null and public.has_site_access(site_id)
    )
    or (
      site_id is null
      and exists (
        select 1 from public.sites s
        where s.organization_id = utility_tariffs.organization_id
          and public.has_site_access(s.id)
      )
    )
  );

create policy "utility_tariffs_insert"
  on public.utility_tariffs for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
    or (
      site_id is null
      and public.current_user_role() = 'site_admin'::public.user_role
      and public.user_can_manage_organization(organization_id)
    )
  );

create policy "utility_tariffs_update"
  on public.utility_tariffs for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
    or (
      site_id is null
      and public.current_user_role() = 'site_admin'::public.user_role
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
      site_id is null
      and public.current_user_role() = 'site_admin'::public.user_role
      and public.user_can_manage_organization(organization_id)
    )
  );

create policy "utility_tariffs_delete"
  on public.utility_tariffs for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
      and status <> 'active'
    )
  );
