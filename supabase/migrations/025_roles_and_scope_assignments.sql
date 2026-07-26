-- =============================================================================
-- Migration: 025_roles_and_scope_assignments.sql
-- Phase 3: dual-layer RBAC + inherited scopes (org / zone / site).
-- Keeps profiles.role and user_site_access; expands RLS helpers to honor scopes.
-- =============================================================================

-- 1) roles / permissions ------------------------------------------------------
create table if not exists public.roles (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  name_en     text not null,
  name_ar     text not null,
  is_system   boolean not null default true,
  is_active   boolean not null default true,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.permissions (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  name_en     text not null,
  name_ar     text not null,
  created_at  timestamptz not null default now()
);

create table if not exists public.role_permissions (
  role_id       uuid not null references public.roles (id) on delete cascade,
  permission_id uuid not null references public.permissions (id) on delete cascade,
  primary key (role_id, permission_id)
);

create table if not exists public.user_scope_assignments (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  role_id          uuid not null references public.roles (id) on delete restrict,
  organization_id  uuid references public.organizations (id) on delete cascade,
  zone_id          uuid references public.zones (id) on delete cascade,
  site_id          uuid references public.sites (id) on delete cascade,
  inherit_children boolean not null default true,
  status           text not null default 'active'
                   check (status in ('active', 'inactive', 'suspended')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint user_scope_assignments_one_scope check (
    (organization_id is not null)::int
    + (zone_id is not null)::int
    + (site_id is not null)::int = 1
  )
);

create index if not exists user_scope_assignments_user_idx
  on public.user_scope_assignments (user_id) where status = 'active';
create index if not exists user_scope_assignments_org_idx
  on public.user_scope_assignments (organization_id) where status = 'active';
create index if not exists user_scope_assignments_zone_idx
  on public.user_scope_assignments (zone_id) where status = 'active';
create index if not exists user_scope_assignments_site_idx
  on public.user_scope_assignments (site_id) where status = 'active';

create trigger user_scope_assignments_set_updated_at
  before update on public.user_scope_assignments
  for each row execute function public.set_updated_at();

-- 2) Seed roles & permissions -------------------------------------------------
insert into public.roles (code, name_en, name_ar, sort_order) values
  ('system_admin', 'System admin', 'مدير النظام', 10),
  ('org_admin', 'Organization admin', 'مدير الجهة', 20),
  ('zone_admin', 'Zone admin', 'مدير المنطقة', 30),
  ('site_admin', 'Site admin', 'مدير الموقع', 40),
  ('meter_manager', 'Meter manager', 'مسؤول العدادات', 50),
  ('reading_entry', 'Reading entry', 'مدخل قراءات', 60),
  ('auditor', 'Auditor', 'مدقق', 70),
  ('viewer', 'Viewer', 'مشاهد', 80),
  ('custom', 'Custom role', 'دور مخصص', 90)
on conflict (code) do nothing;

insert into public.permissions (code, name_en, name_ar) values
  ('view', 'View', 'عرض'),
  ('create', 'Create', 'إضافة'),
  ('update', 'Update', 'تعديل'),
  ('delete', 'Delete', 'حذف'),
  ('manage_users', 'Manage users', 'إدارة المستخدمين'),
  ('manage_site_types', 'Manage site types', 'إدارة أنواع المواقع'),
  ('manage_meters', 'Manage meters', 'إدارة العدادات'),
  ('enter_readings', 'Enter readings', 'إدخال القراءات'),
  ('correct_readings', 'Correct readings', 'تعديل القراءات'),
  ('approve_readings', 'Approve readings', 'اعتماد القراءات'),
  ('export_reports', 'Export reports', 'تصدير التقارير'),
  ('backdate_readings', 'Backdated entry', 'الدخول بتواريخ سابقة')
on conflict (code) do nothing;

-- role_permissions matrix (simplified)
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'system_admin'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'view','create','update','delete','manage_users','manage_site_types',
  'manage_meters','enter_readings','correct_readings','approve_readings',
  'export_reports','backdate_readings'
)
where r.code = 'org_admin'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'view','create','update','manage_meters','enter_readings',
  'correct_readings','export_reports'
)
where r.code in ('zone_admin', 'site_admin')
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('view','manage_meters','enter_readings')
where r.code = 'meter_manager'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('view','enter_readings')
where r.code = 'reading_entry'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('view','export_reports','correct_readings')
where r.code = 'auditor'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('view','export_reports')
where r.code = 'viewer'
on conflict do nothing;

-- 3) Migrate user_site_access → site scopes (no zone inference) --------------
insert into public.user_scope_assignments (
  user_id, role_id, site_id, inherit_children, status
)
select
  usa.user_id,
  coalesce(
    (select r.id from public.roles r where r.code = case usa.role
      when 'site_admin' then 'site_admin'
      when 'technician' then 'reading_entry'
      when 'viewer' then 'viewer'
      when 'super_admin' then 'system_admin'
      else 'viewer'
    end),
    (select id from public.roles where code = 'viewer' limit 1)
  ),
  usa.site_id,
  false,
  'active'
from public.user_site_access usa
where not exists (
  select 1 from public.user_scope_assignments s
  where s.user_id = usa.user_id and s.site_id = usa.site_id and s.status = 'active'
);

-- 4) Helper: does the user have an active scope covering this site? -----------
create or replace function public.user_has_scope_for_site(
  p_site_id uuid,
  p_permission text default 'view'
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_zone uuid;
  v_parent uuid;
begin
  if not public.is_approved_active_user() then
    return false;
  end if;

  if public.is_super_admin() then
    return true;
  end if;

  select organization_id, zone_id into v_org, v_zone
  from public.sites where id = p_site_id;
  if v_org is null then
    return false;
  end if;

  -- Direct site scope
  if exists (
    select 1
    from public.user_scope_assignments usa
    join public.role_permissions rp on rp.role_id = usa.role_id
    join public.permissions p on p.id = rp.permission_id
    where usa.user_id = auth.uid()
      and usa.status = 'active'
      and usa.site_id = p_site_id
      and p.code = p_permission
  ) then
    return true;
  end if;

  -- Organization scope (always covers all current/future sites in org)
  if exists (
    select 1
    from public.user_scope_assignments usa
    join public.role_permissions rp on rp.role_id = usa.role_id
    join public.permissions p on p.id = rp.permission_id
    where usa.user_id = auth.uid()
      and usa.status = 'active'
      and usa.organization_id = v_org
      and usa.inherit_children = true
      and p.code = p_permission
  ) then
    return true;
  end if;

  -- Zone scope (zone + descendant zones when inherit_children)
  if v_zone is not null then
    if exists (
      select 1
      from public.user_scope_assignments usa
      join public.role_permissions rp on rp.role_id = usa.role_id
      join public.permissions p on p.id = rp.permission_id
      where usa.user_id = auth.uid()
        and usa.status = 'active'
        and usa.zone_id = v_zone
        and p.code = p_permission
    ) then
      return true;
    end if;

    -- Walk parents: assignment on ancestor zone with inherit_children
    v_parent := v_zone;
    while v_parent is not null loop
      if exists (
        select 1
        from public.user_scope_assignments usa
        join public.role_permissions rp on rp.role_id = usa.role_id
        join public.permissions p on p.id = rp.permission_id
        where usa.user_id = auth.uid()
          and usa.status = 'active'
          and usa.zone_id = v_parent
          and usa.inherit_children = true
          and p.code = p_permission
      ) then
        return true;
      end if;
      select parent_zone_id into v_parent from public.zones where id = v_parent;
    end loop;
  end if;

  return false;
end;
$$;

-- 5) Expand existing RLS helpers (keep user_site_access as additional path) ---
create or replace function public.has_site_access(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or public.user_has_scope_for_site(p_site_id, 'view')
    or (
      public.is_approved_active_user()
      and exists (
        select 1 from public.user_site_access usa
        where usa.user_id = auth.uid()
          and usa.site_id = p_site_id
          and usa.can_read = true
      )
    );
$$;

create or replace function public.can_write_site(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or public.user_has_scope_for_site(p_site_id, 'enter_readings')
    or (
      public.is_approved_active_user()
      and exists (
        select 1 from public.user_site_access usa
        where usa.user_id = auth.uid()
          and usa.site_id = p_site_id
          and usa.can_write = true
          and usa.role in ('site_admin', 'technician')
      )
    );
$$;

create or replace function public.can_manage_site(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or public.user_has_scope_for_site(p_site_id, 'manage_meters')
    or (
      public.is_approved_active_user()
      and exists (
        select 1 from public.user_site_access usa
        where usa.user_id = auth.uid()
          and usa.site_id = p_site_id
          and usa.can_manage_meters = true
          and usa.role = 'site_admin'
      )
    );
$$;

-- 6) RLS on new tables --------------------------------------------------------
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_scope_assignments enable row level security;

create policy "roles_select" on public.roles for select to authenticated using (true);
create policy "permissions_select" on public.permissions for select to authenticated using (true);
create policy "role_permissions_select" on public.role_permissions for select to authenticated using (true);

create policy "roles_write" on public.roles for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());
create policy "permissions_write" on public.permissions for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());
create policy "role_permissions_write" on public.role_permissions for all to authenticated
  using (public.is_super_admin()) with check (public.is_super_admin());

create policy "user_scope_assignments_select" on public.user_scope_assignments
  for select to authenticated
  using (public.is_super_admin() or user_id = auth.uid());

create policy "user_scope_assignments_write" on public.user_scope_assignments
  for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

grant select on public.roles to authenticated;
grant select on public.permissions to authenticated;
grant select on public.role_permissions to authenticated;
grant select, insert, update, delete on public.roles to authenticated;
grant select, insert, update, delete on public.permissions to authenticated;
grant select, insert, update, delete on public.role_permissions to authenticated;
grant select, insert, update, delete on public.user_scope_assignments to authenticated;
