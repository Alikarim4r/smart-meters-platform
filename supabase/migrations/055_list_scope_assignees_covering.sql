-- =============================================================================
-- 055: List scope assignees including parent org/zone covering assignments
-- =============================================================================

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
    usa.status
  from public.user_scope_assignments usa
  join public.profiles p on p.id = usa.user_id
  join public.roles r on r.id = usa.role_id
  where usa.status = 'active'
    and (
      -- Exact match
      (p_organization_id is not null and usa.organization_id = p_organization_id)
      or (p_zone_id is not null and usa.zone_id = p_zone_id)
      or (p_site_id is not null and usa.site_id = p_site_id)
      -- Zone view: also show org-wide controllers
      or (
        p_zone_id is not null
        and v_org is not null
        and usa.organization_id = v_org
      )
      -- Site view: org controllers
      or (
        p_site_id is not null
        and v_org is not null
        and usa.organization_id = v_org
      )
      -- Site view: direct zone controllers
      or (
        p_site_id is not null
        and v_zone is not null
        and usa.zone_id = v_zone
      )
      -- Site/zone view: ancestor zones with inherit_children
      or (
        p_zone_id is not null
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
            select id, parent_zone_id
            from public.zones
            where id = v_zone
            union all
            select z.id, z.parent_zone_id
            from public.zones z
            join ancestors a on z.id = a.parent_zone_id
          )
          select 1
          from ancestors a
          where a.id = usa.zone_id
            and usa.inherit_children = true
        )
      )
    )
  order by coalesce(p.full_name, p.email);
end;
$$;
