-- =============================================================================
-- Migration: 022_organization_site_types.sql
-- Per-organization custom site types (EN/AR), used by zones and sites so
-- types never mix across organizations. Replaces organizations.site_type and
-- zones.site_type enums. Sites keep the legacy site_type enum for dashboard
-- filters and gain site_type_id for the custom label.
-- =============================================================================

-- 1) Table -------------------------------------------------------------------
create table if not exists public.organization_site_types (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name_en         text not null,
  name_ar         text not null,
  is_active       boolean not null default true,
  sort_order      integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint organization_site_types_name_en_not_empty
    check (char_length(trim(name_en)) > 0),
  constraint organization_site_types_name_ar_not_empty
    check (char_length(trim(name_ar)) > 0),
  constraint organization_site_types_org_name_en_unique
    unique (organization_id, name_en)
);

create index if not exists organization_site_types_org_idx
  on public.organization_site_types (organization_id, sort_order, name_en);

comment on table public.organization_site_types is
  'Custom site types defined per organization (e.g. School / مدرسة).';

create trigger organization_site_types_set_updated_at
  before update on public.organization_site_types
  for each row execute function public.set_updated_at();

-- 2) Seed from existing enum usage -------------------------------------------
-- Helper: English / Arabic labels for the legacy enum.
create or replace function public._tmp_site_type_labels(p_type public.site_type)
returns table (name_en text, name_ar text)
language sql
immutable
as $$
  select
    case p_type
      when 'headquarters' then 'Headquarters'
      when 'school' then 'School'
      when 'kindergarten' then 'Kindergarten'
      when 'mosque' then 'Mosque'
      when 'office' then 'Office'
      when 'warehouse' then 'Warehouse'
      when 'training_center' then 'Training Center'
      else 'Other'
    end,
    case p_type
      when 'headquarters' then 'مقر رئيسي'
      when 'school' then 'مدرسة'
      when 'kindergarten' then 'روضة'
      when 'mosque' then 'مسجد'
      when 'office' then 'مكتب'
      when 'warehouse' then 'مستودع'
      when 'training_center' then 'مركز تدريب'
      else 'أخرى'
    end;
$$;

-- For every organization, create a type row for each distinct enum used by
-- its sites or zones (and the org's own previous default type).
insert into public.organization_site_types (organization_id, name_en, name_ar, sort_order)
select distinct
  org_id,
  labels.name_en,
  labels.name_ar,
  0
from (
  select s.organization_id as org_id, s.site_type as st
  from public.sites s
  union
  select z.organization_id, z.site_type
  from public.zones z
  where z.site_type is not null
  union
  select o.id, o.site_type
  from public.organizations o
  where o.site_type is not null
) usage
cross join lateral public._tmp_site_type_labels(usage.st) as labels
on conflict (organization_id, name_en) do nothing;

drop function public._tmp_site_type_labels(public.site_type);

-- 3) Wire zones + sites to the new table --------------------------------------
alter table public.zones
  add column if not exists site_type_id uuid
    references public.organization_site_types (id) on delete set null;

alter table public.sites
  add column if not exists site_type_id uuid
    references public.organization_site_types (id) on delete set null;

-- Backfill zones from enum → matching org type by English name.
update public.zones z
set site_type_id = t.id
from public.organization_site_types t
where z.site_type is not null
  and t.organization_id = z.organization_id
  and t.name_en = case z.site_type
    when 'headquarters' then 'Headquarters'
    when 'school' then 'School'
    when 'kindergarten' then 'Kindergarten'
    when 'mosque' then 'Mosque'
    when 'office' then 'Office'
    when 'warehouse' then 'Warehouse'
    when 'training_center' then 'Training Center'
    else 'Other'
  end;

-- Backfill sites.
update public.sites s
set site_type_id = t.id
from public.organization_site_types t
where t.organization_id = s.organization_id
  and t.name_en = case s.site_type
    when 'headquarters' then 'Headquarters'
    when 'school' then 'School'
    when 'kindergarten' then 'Kindergarten'
    when 'mosque' then 'Mosque'
    when 'office' then 'Office'
    when 'warehouse' then 'Warehouse'
    when 'training_center' then 'Training Center'
    else 'Other'
  end;

-- Drop legacy enum columns on organizations / zones.
alter table public.organizations drop column if exists site_type;
alter table public.zones drop column if exists site_type;

create index if not exists zones_site_type_id_idx on public.zones (site_type_id);
create index if not exists sites_site_type_id_idx on public.sites (site_type_id);

-- Guard: type must belong to the same organization as the zone/site.
create or replace function public.validate_org_site_type_ownership()
returns trigger
language plpgsql
as $$
declare
  v_type_org uuid;
  v_row_org uuid;
begin
  if new.site_type_id is null then
    return new;
  end if;

  select organization_id into v_type_org
  from public.organization_site_types
  where id = new.site_type_id;

  if v_type_org is null then
    raise exception 'Unknown organization site type';
  end if;

  if tg_table_name = 'zones' then
    v_row_org := new.organization_id;
  elsif tg_table_name = 'sites' then
    v_row_org := new.organization_id;
  else
    return new;
  end if;

  if v_type_org <> v_row_org then
    raise exception 'Site type does not belong to this organization';
  end if;

  return new;
end;
$$;

drop trigger if exists zones_validate_site_type_org on public.zones;
create trigger zones_validate_site_type_org
  before insert or update of site_type_id, organization_id on public.zones
  for each row execute function public.validate_org_site_type_ownership();

drop trigger if exists sites_validate_site_type_org on public.sites;
create trigger sites_validate_site_type_org
  before insert or update of site_type_id, organization_id on public.sites
  for each row execute function public.validate_org_site_type_ownership();

-- 4) RLS ---------------------------------------------------------------------
alter table public.organization_site_types enable row level security;

drop policy if exists "organization_site_types_select" on public.organization_site_types;
create policy "organization_site_types_select"
  on public.organization_site_types for select
  to authenticated
  using (
    public.is_super_admin()
    or exists (
      select 1 from public.organizations o
      where o.id = organization_id
    )
  );

drop policy if exists "organization_site_types_insert" on public.organization_site_types;
create policy "organization_site_types_insert"
  on public.organization_site_types for insert
  to authenticated
  with check (public.is_super_admin());

drop policy if exists "organization_site_types_update" on public.organization_site_types;
create policy "organization_site_types_update"
  on public.organization_site_types for update
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists "organization_site_types_delete" on public.organization_site_types;
create policy "organization_site_types_delete"
  on public.organization_site_types for delete
  to authenticated
  using (public.is_super_admin());

grant select, insert, update, delete on public.organization_site_types to authenticated;
