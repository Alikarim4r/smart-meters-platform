-- =============================================================================
-- Migration: 032_site_facility_areas.sql
-- Physical facility hierarchy within a site (campus / building / plant_room…).
-- Shared across water, electricity, BTU — not water-specific.
-- Does NOT reuse administrative `zones` (RLS/geo scopes).
-- =============================================================================

create table if not exists public.site_facility_areas (
  id              uuid primary key default gen_random_uuid(),
  site_id         uuid not null references public.sites (id) on delete cascade,
  parent_area_id  uuid references public.site_facility_areas (id) on delete restrict,
  area_type       text not null,
  code            text not null,
  name_en         text not null,
  name_ar         text not null,
  sort_order      integer not null default 0,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint site_facility_areas_type_check check (
    area_type in (
      'campus', 'building', 'floor', 'zone',
      'plant_room', 'outdoor', 'common'
    )
  ),
  constraint site_facility_areas_code_not_empty check (char_length(trim(code)) > 0),
  constraint site_facility_areas_name_en_not_empty check (char_length(trim(name_en)) > 0),
  constraint site_facility_areas_name_ar_not_empty check (char_length(trim(name_ar)) > 0),
  constraint site_facility_areas_site_code_unique unique (site_id, code)
);

create index if not exists site_facility_areas_site_idx
  on public.site_facility_areas (site_id, is_active, sort_order);

create index if not exists site_facility_areas_parent_idx
  on public.site_facility_areas (parent_area_id);

create or replace function public.set_site_facility_areas_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists site_facility_areas_set_updated_at on public.site_facility_areas;
create trigger site_facility_areas_set_updated_at
  before update on public.site_facility_areas
  for each row execute function public.set_site_facility_areas_updated_at();

-- Same-site parent + no self-parent + no cycles.
create or replace function public.validate_site_facility_area_tree()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_walk uuid;
  v_parent_site uuid;
  v_guard int := 0;
begin
  if new.parent_area_id is null then
    return new;
  end if;

  if new.parent_area_id = new.id then
    raise exception 'Facility area cannot be its own parent';
  end if;

  select site_id into v_parent_site
  from public.site_facility_areas
  where id = new.parent_area_id;

  if v_parent_site is null then
    raise exception 'Facility area parent does not exist';
  end if;
  if v_parent_site <> new.site_id then
    raise exception 'Facility area parent must belong to the same site';
  end if;

  v_walk := new.parent_area_id;
  while v_walk is not null loop
    v_guard := v_guard + 1;
    if v_guard > 64 then
      raise exception 'Facility area hierarchy too deep or cyclic';
    end if;
    if v_walk = new.id then
      raise exception 'Facility area hierarchy cycle detected';
    end if;
    select parent_area_id into v_walk
    from public.site_facility_areas
    where id = v_walk;
  end loop;

  return new;
end;
$$;

drop trigger if exists site_facility_areas_validate_tree on public.site_facility_areas;
create trigger site_facility_areas_validate_tree
  before insert or update on public.site_facility_areas
  for each row execute function public.validate_site_facility_area_tree();

alter table public.site_facility_areas enable row level security;

drop policy if exists site_facility_areas_select on public.site_facility_areas;
create policy site_facility_areas_select
  on public.site_facility_areas for select to authenticated
  using (public.has_site_access(site_id));

drop policy if exists site_facility_areas_insert on public.site_facility_areas;
create policy site_facility_areas_insert
  on public.site_facility_areas for insert to authenticated
  with check (public.can_manage_site_meters(site_id));

drop policy if exists site_facility_areas_update on public.site_facility_areas;
create policy site_facility_areas_update
  on public.site_facility_areas for update to authenticated
  using (public.can_manage_site_meters(site_id))
  with check (public.can_manage_site_meters(site_id));

drop policy if exists site_facility_areas_delete on public.site_facility_areas;
create policy site_facility_areas_delete
  on public.site_facility_areas for delete to authenticated
  using (public.can_manage_site_meters(site_id));

comment on table public.site_facility_areas is
  'Physical areas inside a site (campus/building/plant_room…). Not administrative zones.';
