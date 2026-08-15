-- =============================================================================
-- 067: Site conservation profiles (Phase 2)
-- Additive only. Does NOT alter public.sites.
-- Supports benchmarking / intensity (m², occupancy, peer group).
-- Explicit OR is_super_admin() / is_platform_owner() (062 has_site_access gap).
-- =============================================================================

create table if not exists public.site_conservation_profiles (
  site_id uuid primary key references public.sites (id) on delete cascade,
  floor_area_m2 numeric(18, 4),
  occupancy_count integer,
  peer_group text,
  profile_notes text,
  updated_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_conservation_profiles_area_positive
    check (floor_area_m2 is null or floor_area_m2 > 0),
  constraint site_conservation_profiles_occupancy_nonneg
    check (occupancy_count is null or occupancy_count >= 0),
  constraint site_conservation_profiles_peer_group_check
    check (
      peer_group is null
      or peer_group in (
        'school',
        'office',
        'administrative',
        'large_site',
        'small_site',
        'other'
      )
    )
);

comment on table public.site_conservation_profiles is
  'Additive conservation metadata for benchmarking. Missing area/occupancy → Normalization Data Missing (never invent).';

create index if not exists site_conservation_profiles_peer_idx
  on public.site_conservation_profiles (peer_group)
  where peer_group is not null;

create trigger site_conservation_profiles_set_updated_at
  before update on public.site_conservation_profiles
  for each row execute function public.set_updated_at();

alter table public.site_conservation_profiles enable row level security;

revoke all on table public.site_conservation_profiles from anon;
revoke all on table public.site_conservation_profiles from authenticated;
grant select, insert, update, delete on table public.site_conservation_profiles to authenticated;

create policy "site_conservation_profiles_select"
  on public.site_conservation_profiles
  for select
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "site_conservation_profiles_insert"
  on public.site_conservation_profiles
  for insert
  to authenticated
  with check (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "site_conservation_profiles_update"
  on public.site_conservation_profiles
  for update
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  )
  with check (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );

create policy "site_conservation_profiles_delete"
  on public.site_conservation_profiles
  for delete
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
    )
  );
