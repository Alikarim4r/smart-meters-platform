-- =============================================================================
-- Migration: 023_org_templates_and_zone_hierarchy.sql
-- Phase 1 structure:
-- 1) organization_templates + template_site_types (Education / Awqaf / Custom)
-- 2) organizations.template_id (historical reference after copy)
-- 3) zones.parent_zone_id + zones.default_site_type_id
-- 4) Backfill default_site_type_id from legacy zones.site_type_id
-- 5) RPC admin_create_organization_from_template
-- =============================================================================

-- 1) Templates ----------------------------------------------------------------
create table if not exists public.organization_templates (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  name_en     text not null,
  name_ar     text not null,
  description text,
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint organization_templates_code_not_empty check (char_length(trim(code)) > 0),
  constraint organization_templates_name_en_not_empty check (char_length(trim(name_en)) > 0)
);

create table if not exists public.template_site_types (
  id          uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.organization_templates (id) on delete cascade,
  name_en     text not null,
  name_ar     text not null,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  constraint template_site_types_name_en_not_empty check (char_length(trim(name_en)) > 0),
  constraint template_site_types_template_name_en_unique unique (template_id, name_en)
);

create index if not exists template_site_types_template_idx
  on public.template_site_types (template_id, sort_order);

create trigger organization_templates_set_updated_at
  before update on public.organization_templates
  for each row execute function public.set_updated_at();

-- Seed templates
insert into public.organization_templates (id, code, name_en, name_ar, description, sort_order)
values
  ('a1000001-0001-4000-8000-000000000001', 'education', 'Education', 'التعليم',
   'Schools, kindergartens, nurseries, admin and training buildings', 10),
  ('a1000001-0001-4000-8000-000000000002', 'awqaf', 'Awqaf', 'الأوقاف',
   'Mosques, prayer halls, Quran centers, waqf properties', 20),
  ('a1000001-0001-4000-8000-000000000003', 'custom', 'Custom', 'مخصص',
   'No default site types — add types manually', 30)
on conflict (code) do nothing;

insert into public.template_site_types (template_id, name_en, name_ar, sort_order)
values
  ('a1000001-0001-4000-8000-000000000001', 'School', 'مدرسة', 10),
  ('a1000001-0001-4000-8000-000000000001', 'Nursery', 'حضانة', 20),
  ('a1000001-0001-4000-8000-000000000001', 'Kindergarten', 'روضة', 30),
  ('a1000001-0001-4000-8000-000000000001', 'Admin Building', 'مبنى إداري', 40),
  ('a1000001-0001-4000-8000-000000000001', 'Training Center', 'مركز تدريبي', 50),
  ('a1000001-0001-4000-8000-000000000002', 'Mosque', 'مسجد', 10),
  ('a1000001-0001-4000-8000-000000000002', 'Prayer Hall', 'مصلى', 20),
  ('a1000001-0001-4000-8000-000000000002', 'Quran Center', 'مركز تحفيظ', 30),
  ('a1000001-0001-4000-8000-000000000002', 'Awqaf Building', 'مبنى أوقاف', 40),
  ('a1000001-0001-4000-8000-000000000002', 'Waqf Property', 'عقار وقفي', 50)
on conflict (template_id, name_en) do nothing;

-- 2) organizations.template_id ------------------------------------------------
alter table public.organizations
  add column if not exists template_id uuid
    references public.organization_templates (id) on delete set null;

comment on column public.organizations.template_id is
  'Template chosen at creation (historical). Site types are copied, not linked.';

-- 3) Zone hierarchy + default suggested site type -----------------------------
alter table public.zones
  add column if not exists parent_zone_id uuid
    references public.zones (id) on delete restrict;

alter table public.zones
  add column if not exists default_site_type_id uuid
    references public.organization_site_types (id) on delete set null;

create index if not exists zones_parent_zone_id_idx on public.zones (parent_zone_id);
create index if not exists zones_default_site_type_id_idx on public.zones (default_site_type_id);

comment on column public.zones.parent_zone_id is
  'Optional parent zone for nested zones within the same organization.';
comment on column public.zones.default_site_type_id is
  'Suggested default site type when creating sites in this zone (not the zone kind).';

-- Backfill default from legacy site_type_id (do not drop site_type_id yet).
update public.zones
set default_site_type_id = site_type_id
where site_type_id is not null
  and default_site_type_id is null;

-- Parent must belong to the same organization; no self-parent; no cycles.
create or replace function public.validate_zone_parent()
returns trigger
language plpgsql
as $$
declare
  v_walk uuid;
  v_parent_org uuid;
begin
  if new.parent_zone_id is null then
    return new;
  end if;

  if new.parent_zone_id = new.id then
    raise exception 'Zone cannot be its own parent';
  end if;

  select organization_id into v_parent_org
  from public.zones
  where id = new.parent_zone_id;

  if v_parent_org is null then
    raise exception 'Parent zone not found';
  end if;

  if v_parent_org <> new.organization_id then
    raise exception 'Parent zone must belong to the same organization';
  end if;

  -- Walk ancestors to detect cycles.
  v_walk := new.parent_zone_id;
  while v_walk is not null loop
    if v_walk = new.id then
      raise exception 'Zone parent would create a cycle';
    end if;
    select parent_zone_id into v_walk from public.zones where id = v_walk;
  end loop;

  return new;
end;
$$;

drop trigger if exists zones_validate_parent on public.zones;
create trigger zones_validate_parent
  before insert or update of parent_zone_id, organization_id on public.zones
  for each row execute function public.validate_zone_parent();

-- default_site_type must belong to the zone's organization.
create or replace function public.validate_zone_default_site_type()
returns trigger
language plpgsql
as $$
declare
  v_type_org uuid;
begin
  if new.default_site_type_id is null then
    return new;
  end if;

  select organization_id into v_type_org
  from public.organization_site_types
  where id = new.default_site_type_id;

  if v_type_org is null then
    raise exception 'Unknown organization site type';
  end if;

  if v_type_org <> new.organization_id then
    raise exception 'Default site type does not belong to this organization';
  end if;

  return new;
end;
$$;

drop trigger if exists zones_validate_default_site_type on public.zones;
create trigger zones_validate_default_site_type
  before insert or update of default_site_type_id, organization_id on public.zones
  for each row execute function public.validate_zone_default_site_type();

-- 4) Create org from template (copy site types) -------------------------------
create or replace function public.admin_create_organization_from_template(
  p_name_en text,
  p_name_ar text,
  p_template_id uuid,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_row record;
begin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can create organizations';
  end if;

  if coalesce(length(trim(p_name_en)), 0) = 0
     or coalesce(length(trim(p_name_ar)), 0) = 0 then
    raise exception 'Organization names are required';
  end if;

  if p_template_id is not null
     and not exists (
       select 1 from public.organization_templates t
       where t.id = p_template_id and t.is_active
     ) then
    raise exception 'Template not found or inactive';
  end if;

  insert into public.organizations (name_en, name_ar, is_active, template_id)
  values (trim(p_name_en), trim(p_name_ar), coalesce(p_is_active, true), p_template_id)
  returning id into v_org_id;

  if p_template_id is not null then
    for v_row in
      select name_en, name_ar, sort_order
      from public.template_site_types
      where template_id = p_template_id
      order by sort_order, name_en
    loop
      insert into public.organization_site_types (
        organization_id, name_en, name_ar, sort_order, is_active
      )
      values (v_org_id, v_row.name_en, v_row.name_ar, v_row.sort_order, true)
      on conflict (organization_id, name_en) do nothing;
    end loop;
  end if;

  return v_org_id;
end;
$$;

revoke all on function public.admin_create_organization_from_template(text, text, uuid, boolean)
  from public;
grant execute on function public.admin_create_organization_from_template(text, text, uuid, boolean)
  to authenticated;

-- 5) RLS for templates (read all authenticated; write super_admin) ------------
alter table public.organization_templates enable row level security;
alter table public.template_site_types enable row level security;

drop policy if exists "organization_templates_select" on public.organization_templates;
create policy "organization_templates_select"
  on public.organization_templates for select
  to authenticated
  using (true);

drop policy if exists "organization_templates_write" on public.organization_templates;
create policy "organization_templates_write"
  on public.organization_templates for all
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists "template_site_types_select" on public.template_site_types;
create policy "template_site_types_select"
  on public.template_site_types for select
  to authenticated
  using (true);

drop policy if exists "template_site_types_write" on public.template_site_types;
create policy "template_site_types_write"
  on public.template_site_types for all
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

grant select on public.organization_templates to authenticated;
grant select, insert, update, delete on public.organization_templates to authenticated;
grant select on public.template_site_types to authenticated;
grant select, insert, update, delete on public.template_site_types to authenticated;
