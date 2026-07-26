-- =============================================================================
-- 056: Harden scope assignment — only platform owner may grant org super control
-- =============================================================================

create or replace function public.user_may_write_scope_assignment(
  p_organization_id uuid,
  p_zone_id uuid,
  p_site_id uuid,
  p_role_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  if not public.is_approved_active_user() then
    return false;
  end if;

  if public.is_platform_owner() then
    return true;
  end if;

  select code into v_code from public.roles where id = p_role_id;

  -- Non-owners may never grant system_admin / org_admin (super-admin org control).
  if v_code in ('system_admin', 'org_admin') then
    return false;
  end if;

  -- Organization-level writes: owner only (already returned true above).
  if p_organization_id is not null then
    return false;
  end if;

  if p_zone_id is not null then
    return public.user_can_manage_zone(p_zone_id);
  end if;

  if p_site_id is not null then
    return public.can_manage_site(p_site_id)
      or (
        exists (
          select 1 from public.sites s
          where s.id = p_site_id
            and s.zone_id is not null
            and public.user_can_manage_zone(s.zone_id)
        )
      )
      or (
        exists (
          select 1 from public.sites s
          where s.id = p_site_id
            and public.user_can_manage_organization(s.organization_id)
        )
      );
  end if;

  return false;
end;
$$;

grant execute on function public.user_may_write_scope_assignment(uuid, uuid, uuid, uuid)
  to authenticated;

drop policy if exists "user_scope_assignments_write" on public.user_scope_assignments;
create policy "user_scope_assignments_write"
  on public.user_scope_assignments for all
  to authenticated
  using (
    public.is_platform_owner()
    or (
      organization_id is not null
      and public.user_can_manage_organization(organization_id)
      and not exists (
        select 1 from public.roles r
        where r.id = role_id and r.code in ('system_admin', 'org_admin')
      )
    )
    or (
      zone_id is not null
      and public.user_can_manage_zone(zone_id)
    )
    or (
      site_id is not null
      and (
        public.can_manage_site(site_id)
        or exists (
          select 1 from public.sites s
          where s.id = site_id
            and (
              public.user_can_manage_organization(s.organization_id)
              or (
                s.zone_id is not null
                and public.user_can_manage_zone(s.zone_id)
              )
            )
        )
      )
    )
  )
  with check (
    public.user_may_write_scope_assignment(
      organization_id, zone_id, site_id, role_id
    )
  );

-- Enrich assignee RPC with scope ids + whether row is direct for the requested level.
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
  status text,
  organization_id uuid,
  zone_id uuid,
  site_id uuid,
  is_direct boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_scoped int;
  v_org uuid;
  v_zone uuid;
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
       or exists (
         select 1 from public.sites s
         where s.id = p_site_id
           and (
             public.user_can_manage_organization(s.organization_id)
             or (
               s.zone_id is not null
               and public.user_can_manage_zone(s.zone_id)
             )
           )
       )
     ) then
    raise exception 'Not authorized to list site assignees';
  end if;

  if p_zone_id is not null then
    select organization_id into v_org from public.zones where id = p_zone_id;
  elsif p_site_id is not null then
    select organization_id, zone_id into v_org, v_zone
    from public.sites where id = p_site_id;
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
    usa.status,
    usa.organization_id,
    usa.zone_id,
    usa.site_id,
    (
      (p_organization_id is not null and usa.organization_id = p_organization_id)
      or (p_zone_id is not null and usa.zone_id = p_zone_id)
      or (p_site_id is not null and usa.site_id = p_site_id)
    ) as is_direct
  from public.user_scope_assignments usa
  join public.profiles p on p.id = usa.user_id
  join public.roles r on r.id = usa.role_id
  where usa.status = 'active'
    and lower(trim(p.email)) <> all (array['alikarim4r@gmail.com'])
    and (
      (p_organization_id is not null and usa.organization_id = p_organization_id)
      or (p_zone_id is not null and usa.zone_id = p_zone_id)
      or (p_site_id is not null and usa.site_id = p_site_id)
      or (
        p_zone_id is not null
        and v_org is not null
        and usa.organization_id = v_org
      )
      or (
        p_site_id is not null
        and v_org is not null
        and usa.organization_id = v_org
      )
      or (
        p_site_id is not null
        and v_zone is not null
        and usa.zone_id = v_zone
      )
      or (
        p_zone_id is not null
        and exists (
          with recursive ancestors as (
            select id, parent_zone_id from public.zones where id = p_zone_id
            union all
            select z.id, z.parent_zone_id
            from public.zones z
            join ancestors a on z.id = a.parent_zone_id
          )
          select 1 from ancestors a
          where a.id = usa.zone_id
            and usa.inherit_children = true
            and a.id <> p_zone_id
        )
      )
      or (
        p_site_id is not null
        and v_zone is not null
        and exists (
          with recursive ancestors as (
            select id, parent_zone_id from public.zones where id = v_zone
            union all
            select z.id, z.parent_zone_id
            from public.zones z
            join ancestors a on z.id = a.parent_zone_id
          )
          select 1 from ancestors a
          where a.id = usa.zone_id
            and usa.inherit_children = true
        )
      )
    )
  order by coalesce(p.full_name, p.email);
end;
$$;
