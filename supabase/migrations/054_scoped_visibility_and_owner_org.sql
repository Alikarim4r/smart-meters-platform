-- =============================================================================
-- 054: Platform-owner-only org create + scoped visibility (no global super_admin)
-- =============================================================================
-- Rules:
--   - Only platform owner creates organizations.
--   - Platform owner sees all orgs / zones / sites.
--   - Super admin / admins see only scopes they are assigned (org/zone/site).
--   - Entry/Dashboard inherit the same has_site_access / list_* RPCs.
-- =============================================================================

-- 1) Global bypass: platform owner only (not bare super_admin) ----------------
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

  if public.is_platform_owner() then
    return true;
  end if;

  select organization_id, zone_id into v_org, v_zone
  from public.sites where id = p_site_id;
  if v_org is null then
    return false;
  end if;

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

  if exists (
    select 1
    from public.user_scope_assignments usa
    join public.role_permissions rp on rp.role_id = usa.role_id
    join public.permissions p on p.id = rp.permission_id
    where usa.user_id = auth.uid()
      and usa.status = 'active'
      and usa.organization_id = v_org
      and p.code = p_permission
  ) then
    return true;
  end if;

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

create or replace function public.has_site_access(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner()
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
  select public.is_platform_owner()
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
  select public.is_platform_owner()
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

-- 2) Org / zone manage helpers ------------------------------------------------
create or replace function public.user_can_manage_organization(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner()
    or (
      public.is_approved_active_user()
      and exists (
        select 1
        from public.user_scope_assignments usa
        join public.role_permissions rp on rp.role_id = usa.role_id
        join public.permissions p on p.id = rp.permission_id
        where usa.user_id = auth.uid()
          and usa.status = 'active'
          and usa.organization_id = p_org_id
          and p.code in ('update', 'manage_users', 'create', 'delete')
      )
    );
$$;

create or replace function public.user_can_manage_zone(p_zone_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner()
    or exists (
      select 1
      from public.zones z
      where z.id = p_zone_id
        and public.user_can_manage_organization(z.organization_id)
    )
    or (
      public.is_approved_active_user()
      and exists (
        select 1
        from public.user_scope_assignments usa
        join public.role_permissions rp on rp.role_id = usa.role_id
        join public.permissions p on p.id = rp.permission_id
        where usa.user_id = auth.uid()
          and usa.status = 'active'
          and usa.zone_id = p_zone_id
          and p.code in ('update', 'manage_users', 'create', 'manage_meters')
      )
    )
    or (
      -- Ancestor zone with inherit_children
      public.is_approved_active_user()
      and exists (
        with recursive ancestors as (
          select id, parent_zone_id
          from public.zones
          where id = p_zone_id
          union all
          select z.id, z.parent_zone_id
          from public.zones z
          join ancestors a on z.id = a.parent_zone_id
        )
        select 1
        from ancestors a
        join public.user_scope_assignments usa on usa.zone_id = a.id
        join public.role_permissions rp on rp.role_id = usa.role_id
        join public.permissions p on p.id = rp.permission_id
        where usa.user_id = auth.uid()
          and usa.status = 'active'
          and usa.inherit_children = true
          and a.id <> p_zone_id
          and p.code in ('update', 'manage_users', 'create', 'manage_meters')
      )
    );
$$;

grant execute on function public.user_can_manage_organization(uuid) to authenticated;
grant execute on function public.user_can_manage_zone(uuid) to authenticated;

-- 3) Zone visibility (scopes without requiring sites) -------------------------
create or replace function public.has_zone_access(p_zone_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner()
    or exists (
      select 1
      from public.zones z
      join public.user_scope_assignments usa
        on usa.organization_id = z.organization_id
      join public.role_permissions rp on rp.role_id = usa.role_id
      join public.permissions p on p.id = rp.permission_id
      where z.id = p_zone_id
        and usa.user_id = auth.uid()
        and usa.status = 'active'
        and p.code = 'view'
    )
    or exists (
      select 1
      from public.user_scope_assignments usa
      join public.role_permissions rp on rp.role_id = usa.role_id
      join public.permissions p on p.id = rp.permission_id
      where usa.user_id = auth.uid()
        and usa.status = 'active'
        and usa.zone_id = p_zone_id
        and p.code = 'view'
    )
    or exists (
      with recursive ancestors as (
        select id, parent_zone_id
        from public.zones
        where id = p_zone_id
        union all
        select z.id, z.parent_zone_id
        from public.zones z
        join ancestors a on z.id = a.parent_zone_id
      )
      select 1
      from ancestors a
      join public.user_scope_assignments usa on usa.zone_id = a.id
      join public.role_permissions rp on rp.role_id = usa.role_id
      join public.permissions p on p.id = rp.permission_id
      where usa.user_id = auth.uid()
        and usa.status = 'active'
        and usa.inherit_children = true
        and a.id <> p_zone_id
        and p.code = 'view'
    )
    or exists (
      select 1
      from public.sites s
      where s.zone_id = p_zone_id
        and public.has_site_access(s.id)
    );
$$;

comment on function public.has_zone_access is
  'True when caller is platform owner or has org/zone scope (or site) covering the zone.';

-- 4) Organizations visibility + write policies --------------------------------
drop policy if exists "organizations_select" on public.organizations;
create policy "organizations_select"
  on public.organizations for select
  to authenticated
  using (
    public.is_platform_owner()
    or exists (
      select 1
      from public.user_scope_assignments usa
      join public.role_permissions rp on rp.role_id = usa.role_id
      join public.permissions p on p.id = rp.permission_id
      where usa.user_id = auth.uid()
        and usa.status = 'active'
        and usa.organization_id = organizations.id
        and p.code = 'view'
    )
    or exists (
      select 1
      from public.zones z
      where z.organization_id = organizations.id
        and public.has_zone_access(z.id)
    )
    or exists (
      select 1
      from public.sites s
      where s.organization_id = organizations.id
        and public.has_site_access(s.id)
    )
  );

drop policy if exists "organizations_insert" on public.organizations;
create policy "organizations_insert"
  on public.organizations for insert
  to authenticated
  with check (public.is_platform_owner());

drop policy if exists "organizations_update" on public.organizations;
create policy "organizations_update"
  on public.organizations for update
  to authenticated
  using (public.user_can_manage_organization(id))
  with check (public.user_can_manage_organization(id));

drop policy if exists "organizations_delete" on public.organizations;
create policy "organizations_delete"
  on public.organizations for delete
  to authenticated
  using (public.is_platform_owner());

-- 5) Zones policies -----------------------------------------------------------
drop policy if exists "zones_select" on public.zones;
create policy "zones_select"
  on public.zones for select
  to authenticated
  using (public.has_zone_access(id));

drop policy if exists "zones_insert" on public.zones;
create policy "zones_insert"
  on public.zones for insert
  to authenticated
  with check (
    public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      parent_zone_id is not null
      and public.user_can_manage_zone(parent_zone_id)
    )
  );

drop policy if exists "zones_update" on public.zones;
create policy "zones_update"
  on public.zones for update
  to authenticated
  using (public.user_can_manage_zone(id))
  with check (public.user_can_manage_zone(id));

drop policy if exists "zones_delete" on public.zones;
create policy "zones_delete"
  on public.zones for delete
  to authenticated
  using (
    public.is_platform_owner()
    or public.user_can_manage_zone(id)
  );

-- 6) Sites insert/update for scoped managers ----------------------------------
drop policy if exists "sites_insert" on public.sites;
create policy "sites_insert"
  on public.sites for insert
  to authenticated
  with check (
    public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      zone_id is not null
      and public.user_can_manage_zone(zone_id)
    )
  );

drop policy if exists "sites_update" on public.sites;
create policy "sites_update"
  on public.sites for update
  to authenticated
  using (
    public.is_platform_owner()
    or public.can_manage_site(id)
    or public.user_can_manage_organization(organization_id)
    or (
      zone_id is not null
      and public.user_can_manage_zone(zone_id)
    )
  )
  with check (
    public.is_platform_owner()
    or public.can_manage_site(id)
    or public.user_can_manage_organization(organization_id)
    or (
      zone_id is not null
      and public.user_can_manage_zone(zone_id)
    )
  );

drop policy if exists "sites_delete" on public.sites;
create policy "sites_delete"
  on public.sites for delete
  to authenticated
  using (
    public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      zone_id is not null
      and public.user_can_manage_zone(zone_id)
    )
  );

-- 7) Scope assignment RLS: managers can read/write under their scope ----------
drop policy if exists "user_scope_assignments_select" on public.user_scope_assignments;
create policy "user_scope_assignments_select"
  on public.user_scope_assignments for select
  to authenticated
  using (
    public.is_platform_owner()
    or user_id = auth.uid()
    or (
      organization_id is not null
      and public.user_can_manage_organization(organization_id)
    )
    or (
      zone_id is not null
      and public.user_can_manage_zone(zone_id)
    )
    or (
      site_id is not null
      and public.can_manage_site(site_id)
    )
  );

drop policy if exists "user_scope_assignments_write" on public.user_scope_assignments;
create policy "user_scope_assignments_write"
  on public.user_scope_assignments for all
  to authenticated
  using (
    public.is_platform_owner()
    or (
      organization_id is not null
      and public.user_can_manage_organization(organization_id)
    )
    or (
      zone_id is not null
      and public.user_can_manage_zone(zone_id)
    )
    or (
      site_id is not null
      and public.can_manage_site(site_id)
    )
  )
  with check (
    public.is_platform_owner()
    or (
      organization_id is not null
      and public.user_can_manage_organization(organization_id)
    )
    or (
      zone_id is not null
      and public.user_can_manage_zone(zone_id)
    )
    or (
      site_id is not null
      and public.can_manage_site(site_id)
    )
  );

-- 8) RPC: list assignees at a control scope -----------------------------------
create or replace function public.list_scope_assignees_at(
  p_organization_id uuid default null,
  p_zone_id uuid default null,
  p_site_id uuid default null
)
returns table (
  assignment_id uuid,
  user_id uuid,
  email text,
  full_name text,
  profile_role text,
  scope_role_code text,
  scope_role_name_en text,
  scope_role_name_ar text,
  inherit_children boolean,
  status text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_scoped int;
begin
  v_scoped :=
    (p_organization_id is not null)::int
    + (p_zone_id is not null)::int
    + (p_site_id is not null)::int;
  if v_scoped <> 1 then
    raise exception 'Exactly one of organization, zone, or site is required';
  end if;

  if not public.is_approved_active_user() then
    raise exception 'Not authorized';
  end if;

  if p_organization_id is not null
     and not (
       public.is_platform_owner()
       or public.user_can_manage_organization(p_organization_id)
     ) then
    raise exception 'Not authorized to list organization assignees';
  end if;

  if p_zone_id is not null
     and not (
       public.is_platform_owner()
       or public.user_can_manage_zone(p_zone_id)
     ) then
    raise exception 'Not authorized to list zone assignees';
  end if;

  if p_site_id is not null
     and not (
       public.is_platform_owner()
       or public.can_manage_site(p_site_id)
     ) then
    raise exception 'Not authorized to list site assignees';
  end if;

  return query
  select
    usa.id,
    usa.user_id,
    p.email,
    p.full_name,
    p.role::text,
    r.code,
    r.name_en,
    r.name_ar,
    usa.inherit_children,
    usa.status
  from public.user_scope_assignments usa
  join public.profiles p on p.id = usa.user_id
  join public.roles r on r.id = usa.role_id
  where usa.status = 'active'
    and (
      (p_organization_id is not null and usa.organization_id = p_organization_id)
      or (p_zone_id is not null and usa.zone_id = p_zone_id)
      or (p_site_id is not null and usa.site_id = p_site_id)
    )
  order by coalesce(p.full_name, p.email);
end;
$$;

revoke all on function public.list_scope_assignees_at(uuid, uuid, uuid) from public;
grant execute on function public.list_scope_assignees_at(uuid, uuid, uuid) to authenticated;

drop policy if exists "organization_site_types_select" on public.organization_site_types;
create policy "organization_site_types_select"
  on public.organization_site_types for select
  to authenticated
  using (
    public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or exists (
      select 1 from public.organizations o
      where o.id = organization_site_types.organization_id
    )
  );

drop policy if exists "organization_site_types_insert" on public.organization_site_types;
create policy "organization_site_types_insert"
  on public.organization_site_types for insert
  to authenticated
  with check (
    public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

drop policy if exists "organization_site_types_update" on public.organization_site_types;
create policy "organization_site_types_update"
  on public.organization_site_types for update
  to authenticated
  using (
    public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  )
  with check (
    public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

drop policy if exists "organization_site_types_delete" on public.organization_site_types;
create policy "organization_site_types_delete"
  on public.organization_site_types for delete
  to authenticated
  using (
    public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

-- 9) Gate org-from-template RPC to platform owner -----------------------------
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
  if not public.is_platform_owner() then
    raise exception 'Only platform owner can create organizations';
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
