-- =============================================================================
-- 064: Conservation targets (P1C)
-- Additive only. Versioned targets — do not overwrite history.
-- Targets are separate from baselines (P1D).
-- Explicit OR is_super_admin() / is_platform_owner() (062 has_site_access gap).
-- No writes to meter_readings. No changes to existing helpers/RLS.
-- =============================================================================

create table if not exists public.conservation_targets (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  scope_type text not null,
  scope_id uuid,
  period_type text not null,
  period_start date not null,
  period_end date not null,
  target_value numeric(18, 4) not null,
  unit_code text not null,
  version integer not null default 1,
  status text not null default 'draft',
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_targets_scope_type_check
    check (scope_type in ('site', 'category', 'meter')),
  constraint conservation_targets_period_type_check
    check (period_type in ('monthly', 'annual')),
  constraint conservation_targets_status_check
    check (status in ('draft', 'active', 'archived')),
  constraint conservation_targets_period_order_check
    check (period_end >= period_start),
  constraint conservation_targets_value_positive_check
    check (target_value > 0),
  constraint conservation_targets_version_positive_check
    check (version >= 1),
  constraint conservation_targets_unit_nonempty
    check (length(trim(unit_code)) > 0),
  constraint conservation_targets_scope_id_check
    check (
      (scope_type = 'site' and scope_id is null)
      or (scope_type in ('category', 'meter') and scope_id is not null)
    )
);

comment on table public.conservation_targets is
  'Versioned conservation targets (monthly/annual). History is archived, never overwritten in place for active versions.';

comment on column public.conservation_targets.target_value is
  'Immutable for archived/active rows in app workflow — changes create a new version.';

create unique index if not exists conservation_targets_one_active_uq
  on public.conservation_targets (
    site_id,
    scope_type,
    coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid),
    period_type,
    period_start,
    unit_code
  )
  where status = 'active';

create index if not exists conservation_targets_site_idx
  on public.conservation_targets (site_id);

create index if not exists conservation_targets_period_idx
  on public.conservation_targets (site_id, period_type, period_start);

create index if not exists conservation_targets_status_idx
  on public.conservation_targets (status);

create trigger conservation_targets_set_updated_at
  before update on public.conservation_targets
  for each row execute function public.set_updated_at();

alter table public.conservation_targets enable row level security;

revoke all on table public.conservation_targets from anon;
revoke all on table public.conservation_targets from authenticated;
grant select, insert, update, delete on table public.conservation_targets to authenticated;

create policy "conservation_targets_select"
  on public.conservation_targets
  for select
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

-- WRITE: site_admin with manage + super_admin / platform_owner.
-- Technicians cannot manage targets even if can_manage_site is broad.
create policy "conservation_targets_insert"
  on public.conservation_targets
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

create policy "conservation_targets_update"
  on public.conservation_targets
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

create policy "conservation_targets_delete"
  on public.conservation_targets
  for delete
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      public.current_user_role() = 'site_admin'::public.user_role
      and public.can_manage_site(site_id)
      and status = 'draft'
    )
  );
