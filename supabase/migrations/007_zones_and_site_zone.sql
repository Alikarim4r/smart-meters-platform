-- =============================================================================
-- Smart Meters Platform — Zones and Site Zone Assignment
-- Migration: 007_zones_and_site_zone.sql
-- Depends on: 001_schema, 002_rls, 005_user_approval
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. zones table
-- -----------------------------------------------------------------------------

create table public.zones (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  code            text not null,
  name_en         text not null,
  name_ar         text,
  description     text,
  is_active       boolean not null default true,
  sort_order      integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint zones_organization_code_unique unique (organization_id, code),
  constraint zones_code_not_empty check (char_length(trim(code)) > 0),
  constraint zones_name_en_not_empty check (char_length(trim(name_en)) > 0),
  constraint zones_code_format check (code ~ '^[a-z][a-z0-9_]*$')
);

create index zones_organization_id_idx on public.zones (organization_id);
create index zones_organization_active_idx on public.zones (organization_id, is_active);
create index zones_organization_sort_idx on public.zones (organization_id, sort_order);

comment on table public.zones is
  'Optional geographic or administrative zones within an organization. Sites may have zone_id null (no zone).';

-- -----------------------------------------------------------------------------
-- 2. sites.zone_id
-- -----------------------------------------------------------------------------

alter table public.sites
  add column zone_id uuid references public.zones (id) on delete set null;

create index sites_zone_id_idx on public.sites (zone_id);

comment on column public.sites.zone_id is
  'Optional zone assignment. Null means the site has no zone (e.g. headquarters).';

-- -----------------------------------------------------------------------------
-- 3. updated_at trigger
-- -----------------------------------------------------------------------------

create trigger zones_set_updated_at
  before update on public.zones
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 4. RLS helper — zone visible only via assigned site access
-- -----------------------------------------------------------------------------

create or replace function public.has_zone_access(p_zone_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or (
      public.is_approved_active_user()
      and exists (
        select 1
        from public.sites s
        join public.user_site_access usa on usa.site_id = s.id
        join public.profiles p on p.id = usa.user_id
        where s.zone_id = p_zone_id
          and usa.user_id = auth.uid()
          and usa.can_read = true
          and p.approval_status = 'approved'
          and p.is_active = true
      )
    );
$$;

comment on function public.has_zone_access is
  'True when caller is super_admin or has user_site_access to a site in the zone.';

-- -----------------------------------------------------------------------------
-- 5. RLS on zones
-- -----------------------------------------------------------------------------

alter table public.zones enable row level security;

drop policy if exists "zones_select" on public.zones;
create policy "zones_select"
  on public.zones for select
  to authenticated
  using (public.is_super_admin() or public.has_zone_access(id));

drop policy if exists "zones_insert" on public.zones;
create policy "zones_insert"
  on public.zones for insert
  to authenticated
  with check (public.is_super_admin());

drop policy if exists "zones_update" on public.zones;
create policy "zones_update"
  on public.zones for update
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists "zones_delete" on public.zones;
create policy "zones_delete"
  on public.zones for delete
  to authenticated
  using (public.is_super_admin());

grant select, insert, update, delete on public.zones to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Seed sample zones (MOEHE organization)
-- -----------------------------------------------------------------------------

insert into public.zones (
  id, organization_id, code, name_en, name_ar, description, is_active, sort_order
)
values
  (
    'd1111111-1111-4111-8111-111111111101',
    '11111111-1111-4111-8111-111111111111',
    'north_zone',
    'North Zone',
    'المنطقة الشمالية',
    'Northern schools and facilities',
    true,
    1
  ),
  (
    'd1111111-1111-4111-8111-111111111102',
    '11111111-1111-4111-8111-111111111111',
    'south_zone',
    'South Zone',
    'المنطقة الجنوبية',
    'Southern schools and facilities',
    true,
    2
  ),
  (
    'd1111111-1111-4111-8111-111111111103',
    '11111111-1111-4111-8111-111111111111',
    'central_zone',
    'Central Zone',
    'المنطقة الوسطى',
    'Central schools and facilities',
    true,
    3
  ),
  (
    'd1111111-1111-4111-8111-111111111104',
    '11111111-1111-4111-8111-111111111111',
    'west_zone',
    'West Zone',
    'المنطقة الغربية',
    'Western schools and facilities',
    true,
    4
  )
on conflict (organization_id, code) do update
set
  name_en = excluded.name_en,
  name_ar = excluded.name_ar,
  description = excluded.description,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

-- MOEHE HQ remains without a zone (zone_id null by design).

-- Assign Test School A to North Zone when present (safe optional backfill).
update public.sites
set zone_id = 'd1111111-1111-4111-8111-111111111101'
where name_en = 'Test School A'
  and organization_id = '11111111-1111-4111-8111-111111111111'
  and zone_id is null;
