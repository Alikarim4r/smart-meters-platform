-- =============================================================================
-- 085: Site operating calendar + occupancy profiles (Phase 5)
-- Additive side structure. Occupancy normalization = N/A without real data.
-- =============================================================================

create table if not exists public.site_operating_calendar (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  period_date date not null,
  operating_status text not null default 'operating',
  operating_hours numeric(6, 2),
  occupancy_factor numeric(8, 4),
  occupancy_count integer,
  holiday_event_type text,
  source text not null default 'manual',
  status text not null default 'draft',
  approved_by uuid references auth.users (id),
  approved_at timestamptz,
  notes text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_operating_calendar_status_op_check
    check (operating_status in (
      'operating', 'closed', 'holiday', 'event', 'partial', 'unknown'
    )),
  constraint site_operating_calendar_source_check
    check (source in (
      'manual', 'school_calendar', 'workdays', 'imported', 'approved_count'
    )),
  constraint site_operating_calendar_row_status_check
    check (status in ('draft', 'approved', 'rejected', 'archived')),
  constraint site_operating_calendar_hours_nonneg
    check (operating_hours is null or operating_hours >= 0),
  constraint site_operating_calendar_occ_factor_range
    check (
      occupancy_factor is null
      or (occupancy_factor >= 0 and occupancy_factor <= 2)
    ),
  constraint site_operating_calendar_uq
    unique (site_id, period_date)
);

comment on table public.site_operating_calendar is
  'Additive operating/occupancy calendar. Missing data ⇒ Occupancy Normalization Not Available.';

create table if not exists public.conservation_occupancy_profiles (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites (id) on delete cascade,
  label text not null,
  period_start date not null,
  period_end date not null,
  operating_days integer,
  average_occupancy numeric(12, 4),
  hours_of_operation numeric(10, 2),
  source text not null,
  status text not null default 'draft',
  approved_by uuid references auth.users (id),
  approved_at timestamptz,
  notes text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_occ_profile_period_check
    check (period_end >= period_start),
  constraint conservation_occ_profile_source_check
    check (source in (
      'approved_occupancy_count',
      'operating_days',
      'school_calendar',
      'workdays',
      'hours_of_operation',
      'events_holidays'
    )),
  constraint conservation_occ_profile_status_check
    check (status in ('draft', 'approved', 'rejected', 'archived')),
  constraint conservation_occ_profile_label_nonempty
    check (length(trim(label)) > 0)
);

comment on table public.conservation_occupancy_profiles is
  'Approved occupancy / operating profile aggregates for normalization.';

create index if not exists site_operating_calendar_site_date_idx
  on public.site_operating_calendar (site_id, period_date);

create index if not exists conservation_occ_profile_site_status_idx
  on public.conservation_occupancy_profiles (site_id, status);

create trigger site_operating_calendar_set_updated_at
  before update on public.site_operating_calendar
  for each row execute function public.set_updated_at();

create trigger conservation_occ_profile_set_updated_at
  before update on public.conservation_occupancy_profiles
  for each row execute function public.set_updated_at();

create or replace function public.site_operating_calendar_approve_authority()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'approved'
     and (
       tg_op = 'INSERT'
       or new.status is distinct from old.status
       or new.approved_by is distinct from old.approved_by
       or new.approved_at is distinct from old.approved_at
     ) then
    if not (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.conservation_site_admin_manages(new.site_id)
    ) then
      raise exception
        'operating calendar approval requires site_admin / super_admin / platform_owner';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists site_operating_calendar_approve_authority_trg
  on public.site_operating_calendar;
create trigger site_operating_calendar_approve_authority_trg
  before insert or update on public.site_operating_calendar
  for each row execute function public.site_operating_calendar_approve_authority();

create or replace function public.conservation_occ_profile_approve_authority()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'approved'
     and (
       tg_op = 'INSERT'
       or new.status is distinct from old.status
       or new.approved_by is distinct from old.approved_by
       or new.approved_at is distinct from old.approved_at
     ) then
    if not (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.conservation_site_admin_manages(new.site_id)
    ) then
      raise exception
        'occupancy profile approval requires site_admin / super_admin / platform_owner';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists conservation_occ_profile_approve_authority_trg
  on public.conservation_occupancy_profiles;
create trigger conservation_occ_profile_approve_authority_trg
  before insert or update on public.conservation_occupancy_profiles
  for each row execute function public.conservation_occ_profile_approve_authority();

alter table public.site_operating_calendar enable row level security;
alter table public.conservation_occupancy_profiles enable row level security;

revoke all on table public.site_operating_calendar from anon, authenticated;
revoke all on table public.conservation_occupancy_profiles from anon, authenticated;
grant select, insert, update, delete on table public.site_operating_calendar to authenticated;
grant select, insert, update, delete on table public.conservation_occupancy_profiles to authenticated;

create policy "site_operating_calendar_select"
  on public.site_operating_calendar for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "site_operating_calendar_insert"
  on public.site_operating_calendar for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "site_operating_calendar_update"
  on public.site_operating_calendar for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "site_operating_calendar_delete"
  on public.site_operating_calendar for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_occ_profile_select"
  on public.conservation_occupancy_profiles for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.has_site_access(site_id)
  );

create policy "conservation_occ_profile_insert"
  on public.conservation_occupancy_profiles for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_occ_profile_update"
  on public.conservation_occupancy_profiles for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

create policy "conservation_occ_profile_delete"
  on public.conservation_occupancy_profiles for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );
