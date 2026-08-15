-- =============================================================================
-- 065: Conservation versioned baselines (P1D)
-- Additive only. History is never overwritten for approved rows.
-- Targets remain separate (064). No savings/opportunities/balance/tariffs.
-- Explicit OR is_super_admin() / is_platform_owner() (062 has_site_access gap).
-- No writes to meter_readings. No changes to existing helpers/RLS.
-- =============================================================================

create table if not exists public.conservation_baselines (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  scope_type text not null,
  scope_id uuid,
  utility_code text,
  version_number integer not null,
  label text not null default '',
  reference_period_start date not null,
  reference_period_end date not null,
  calculation_method text not null,
  baseline_value numeric(18, 4) not null,
  unit_code text not null,
  status text not null default 'draft',
  valid_from date,
  valid_to date,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_by uuid references auth.users (id),
  approved_at timestamptz,
  notes text,
  -- Preview / quality snapshot stored with draft/approved (audit-friendly).
  data_completeness numeric(6, 4),
  confidence_score integer,
  boundary_quality text,
  calculation_meta jsonb not null default '{}'::jsonb,
  constraint conservation_baselines_scope_type_check
    check (scope_type in ('site', 'category', 'meter')),
  constraint conservation_baselines_method_check
    check (calculation_method in ('total_period', 'average_daily', 'custom_fixed')),
  constraint conservation_baselines_status_check
    check (status in ('draft', 'approved', 'superseded', 'archived')),
  constraint conservation_baselines_period_order_check
    check (reference_period_end >= reference_period_start),
  constraint conservation_baselines_value_nonnegative_check
    check (baseline_value >= 0),
  constraint conservation_baselines_version_positive_check
    check (version_number >= 1),
  constraint conservation_baselines_unit_nonempty
    check (length(trim(unit_code)) > 0),
  constraint conservation_baselines_scope_id_check
    check (
      (scope_type = 'site' and scope_id is null)
      or (scope_type in ('category', 'meter') and scope_id is not null)
    ),
  constraint conservation_baselines_boundary_quality_check
    check (
      boundary_quality is null
      or boundary_quality in (
        'exact_pre_period',
        'first_in_period_fallback',
        'insufficient',
        'not_applicable'
      )
    ),
  constraint conservation_baselines_valid_range_check
    check (valid_to is null or valid_from is null or valid_to >= valid_from)
);

comment on table public.conservation_baselines is
  'Versioned conservation baselines (reference performance). Separate from targets. Approved rows are immutable; changes create a new version.';

comment on column public.conservation_baselines.baseline_value is
  'Immutable once status is approved/superseded/archived — amend via new version only.';

comment on column public.conservation_baselines.boundary_quality is
  'exact_pre_period | first_in_period_fallback | insufficient | not_applicable (custom_fixed).';

-- Transaction-safe version uniqueness per operational key.
create unique index if not exists conservation_baselines_version_uq
  on public.conservation_baselines (
    site_id,
    scope_type,
    coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid),
    unit_code,
    version_number
  );

-- At most one currently approved baseline per operational key.
create unique index if not exists conservation_baselines_one_approved_uq
  on public.conservation_baselines (
    site_id,
    scope_type,
    coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid),
    unit_code
  )
  where status = 'approved';

create index if not exists conservation_baselines_site_idx
  on public.conservation_baselines (site_id);

create index if not exists conservation_baselines_status_idx
  on public.conservation_baselines (site_id, status);

create index if not exists conservation_baselines_approved_lookup_idx
  on public.conservation_baselines (site_id, scope_type, unit_code)
  where status = 'approved';

create trigger conservation_baselines_set_updated_at
  before update on public.conservation_baselines
  for each row execute function public.set_updated_at();

-- Immutability: approved / superseded / archived cannot change core fields.
create or replace function public.conservation_baselines_enforce_immutability()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and old.status in ('approved', 'superseded', 'archived') then
    -- Allowed lifecycle transitions only (status / validity / audit).
    if new.baseline_value is distinct from old.baseline_value
       or new.reference_period_start is distinct from old.reference_period_start
       or new.reference_period_end is distinct from old.reference_period_end
       or new.calculation_method is distinct from old.calculation_method
       or new.unit_code is distinct from old.unit_code
       or new.scope_type is distinct from old.scope_type
       or new.scope_id is distinct from old.scope_id
       or new.site_id is distinct from old.site_id
       or new.version_number is distinct from old.version_number
       or new.utility_code is distinct from old.utility_code
    then
      raise exception
        'conservation_baselines: core fields immutable after leave-draft (status=%)',
        old.status;
    end if;

    -- Status transition whitelist from approved/superseded/archived.
    if new.status is distinct from old.status then
      if not (
        (old.status = 'approved' and new.status in ('superseded', 'archived'))
        or (old.status = 'superseded' and new.status = 'archived')
        or (old.status = 'archived' and new.status = 'archived')
      ) then
        raise exception
          'conservation_baselines: illegal status transition % → %',
          old.status, new.status;
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists conservation_baselines_immutability_trg
  on public.conservation_baselines;
create trigger conservation_baselines_immutability_trg
  before update on public.conservation_baselines
  for each row execute function public.conservation_baselines_enforce_immutability();

-- Allocate next version_number under row lock on sibling key (race-safe).
create or replace function public.conservation_baselines_next_version(
  p_site_id uuid,
  p_scope_type text,
  p_scope_id uuid,
  p_unit_code text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next integer;
begin
  -- Serialize allocators for the same operational key.
  perform pg_advisory_xact_lock(
    hashtextextended(
      coalesce(p_site_id::text, '') || '|' ||
      coalesce(p_scope_type, '') || '|' ||
      coalesce(p_scope_id::text, '') || '|' ||
      coalesce(p_unit_code, ''),
      0
    )
  );

  select coalesce(max(version_number), 0) + 1
    into v_next
  from public.conservation_baselines
  where site_id = p_site_id
    and scope_type = p_scope_type
    and unit_code = p_unit_code
    and (
      (p_scope_id is null and scope_id is null)
      or scope_id = p_scope_id
    );

  return v_next;
end;
$$;

revoke all on function public.conservation_baselines_next_version(uuid, text, uuid, text)
  from public;
grant execute on function public.conservation_baselines_next_version(uuid, text, uuid, text)
  to authenticated;

alter table public.conservation_baselines enable row level security;

revoke all on table public.conservation_baselines from anon;
revoke all on table public.conservation_baselines from authenticated;
grant select, insert, update, delete on table public.conservation_baselines to authenticated;

create policy "conservation_baselines_select"
  on public.conservation_baselines
  for select
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

-- Draft create: site_admin+manage / super_admin / platform_owner.
-- Technicians cannot write even if can_manage_site is broad on Staging.
create policy "conservation_baselines_insert"
  on public.conservation_baselines
  for insert
  to authenticated
  with check (
    status = 'draft'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or (
        public.current_user_role() = 'site_admin'::public.user_role
        and public.can_manage_site(site_id)
      )
    )
  );

-- Update: same writers. Service layer separates Edit Draft vs Approve.
create policy "conservation_baselines_update"
  on public.conservation_baselines
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

-- Hard delete drafts only (approved history is soft-archived / superseded).
create policy "conservation_baselines_delete"
  on public.conservation_baselines
  for delete
  to authenticated
  using (
    status = 'draft'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or (
        public.current_user_role() = 'site_admin'::public.user_role
        and public.can_manage_site(site_id)
      )
    )
  );
