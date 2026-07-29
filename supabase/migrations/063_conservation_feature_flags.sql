-- =============================================================================
-- 063: Conservation feature flags (P1A)
-- Additive only. Quality findings stay service-only in P1A (no snapshot table).
-- Does NOT alter existing tables, helpers, or RLS policies.
-- Explicit OR is_super_admin() / is_platform_owner() because Staging
-- has_site_access may not include super_admin (062 tracking gap).
-- All flags default enabled=false. No seed rows (missing row = OFF in app).
-- =============================================================================

create table if not exists public.conservation_feature_flags (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid references public.sites (id) on delete cascade,
  flag_key text not null,
  enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_feature_flags_key_nonempty
    check (length(trim(flag_key)) > 0)
);

-- Org/site consistency is enforced by FKs + app/repository (CHECK cannot
-- use subqueries in PostgreSQL).

-- Unique: one org-wide row per flag; one site row per flag.
create unique index if not exists conservation_feature_flags_org_wide_uq
  on public.conservation_feature_flags (organization_id, flag_key)
  where site_id is null;

create unique index if not exists conservation_feature_flags_site_uq
  on public.conservation_feature_flags (organization_id, site_id, flag_key)
  where site_id is not null;

create index if not exists conservation_feature_flags_org_idx
  on public.conservation_feature_flags (organization_id);

create index if not exists conservation_feature_flags_site_idx
  on public.conservation_feature_flags (site_id)
  where site_id is not null;

create index if not exists conservation_feature_flags_key_idx
  on public.conservation_feature_flags (flag_key);

comment on table public.conservation_feature_flags is
  'Conservation layer feature flags. Default OFF (enabled=false). site_id null = org-wide.';

comment on column public.conservation_feature_flags.enabled is
  'Must remain false until explicitly enabled after sub-phase approval.';

create trigger conservation_feature_flags_set_updated_at
  before update on public.conservation_feature_flags
  for each row execute function public.set_updated_at();

alter table public.conservation_feature_flags enable row level security;

revoke all on table public.conservation_feature_flags from anon;
revoke all on table public.conservation_feature_flags from authenticated;
grant select, insert, update, delete on table public.conservation_feature_flags to authenticated;

-- SELECT: site-scoped via has_site_access; org-wide if user can access any site in org.
-- Always allow super_admin / platform_owner explicitly (do not rely on has_site_access).
create policy "conservation_feature_flags_select"
  on public.conservation_feature_flags
  for select
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      site_id is not null
      and public.has_site_access(site_id)
    )
    or (
      site_id is null
      and exists (
        select 1
        from public.sites s
        where s.organization_id = conservation_feature_flags.organization_id
          and public.has_site_access(s.id)
      )
    )
  );

-- WRITE: site_admin only (plus super_admin / platform_owner).
-- Do NOT rely on can_manage_site alone — some technicians have manage_meters
-- scopes on Staging; feature flags must not be toggled by technicians.
create policy "conservation_feature_flags_insert"
  on public.conservation_feature_flags
  for insert
  to authenticated
  with check (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and site_id is not null
      and public.can_manage_site(site_id)
    )
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and site_id is null
      and public.user_can_manage_organization(organization_id)
    )
  );

create policy "conservation_feature_flags_update"
  on public.conservation_feature_flags
  for update
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and site_id is not null
      and public.can_manage_site(site_id)
    )
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and site_id is null
      and public.user_can_manage_organization(organization_id)
    )
  )
  with check (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and site_id is not null
      and public.can_manage_site(site_id)
    )
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and site_id is null
      and public.user_can_manage_organization(organization_id)
    )
  );

create policy "conservation_feature_flags_delete"
  on public.conservation_feature_flags
  for delete
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and site_id is not null
      and public.can_manage_site(site_id)
    )
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and site_id is null
      and public.user_can_manage_organization(organization_id)
    )
  );
