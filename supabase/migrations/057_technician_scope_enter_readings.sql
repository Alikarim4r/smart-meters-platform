-- =============================================================================
-- 057: Technicians with scope enter_readings may insert (not only user_site_access)
-- =============================================================================

create or replace function public.is_technician_only_for_site(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_approved_active_user()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role = 'technician'
        and p.approval_status = 'approved'
        and p.is_active = true
    )
    and not public.is_super_admin()
    and not public.is_platform_owner()
    and not public.can_manage_site(p_site_id)
    and (
      -- Legacy row-level site access
      exists (
        select 1
        from public.user_site_access usa
        where usa.user_id = auth.uid()
          and usa.site_id = p_site_id
          and usa.role = 'technician'
          and usa.can_write = true
      )
      -- Scoped RBAC: reading_entry / enter_readings covering this site
      or public.user_has_scope_for_site(p_site_id, 'enter_readings')
    );
$$;

comment on function public.is_technician_only_for_site(uuid) is
  'True for approved technicians who can write the site via user_site_access or enter_readings scope.';
