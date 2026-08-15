-- =============================================================================
-- 076: Tighten Phase 3 write RLS to explicit user_site_access (site_admin)
-- Additive policy REPLACE only. Avoid org-wide manage_meters scope alone.
-- Technicians remain assignment-scoped. Super/owner unchanged.
-- =============================================================================

-- Helper: site_admin with explicit USA manage row for site (not org-wide scope alone).
create or replace function public.conservation_site_admin_manages(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_approved_active_user()
    and public.current_user_role() = 'site_admin'::public.user_role
    and exists (
      select 1 from public.user_site_access usa
      where usa.user_id = auth.uid()
        and usa.site_id = p_site_id
        and usa.role = 'site_admin'
        and usa.can_manage_meters = true
    );
$$;

revoke all on function public.conservation_site_admin_manages(uuid) from public;
grant execute on function public.conservation_site_admin_manages(uuid) to authenticated;

-- Opportunities
drop policy if exists "conservation_opp_insert" on public.conservation_opportunities;
create policy "conservation_opp_insert"
  on public.conservation_opportunities for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

drop policy if exists "conservation_opp_update" on public.conservation_opportunities;
create policy "conservation_opp_update"
  on public.conservation_opportunities for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

drop policy if exists "conservation_opp_delete" on public.conservation_opportunities;
create policy "conservation_opp_delete"
  on public.conservation_opportunities for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.conservation_site_admin_manages(site_id)
      and status in ('detected', 'dismissed')
    )
  );

-- Investigations
drop policy if exists "conservation_inv_insert" on public.conservation_investigations;
create policy "conservation_inv_insert"
  on public.conservation_investigations for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

drop policy if exists "conservation_inv_update" on public.conservation_investigations;
create policy "conservation_inv_update"
  on public.conservation_investigations for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
    or (
      public.current_user_role() = 'technician'::public.user_role
      and assigned_to = auth.uid()
      and public.has_site_access(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
    or (
      public.current_user_role() = 'technician'::public.user_role
      and assigned_to = auth.uid()
      and public.has_site_access(site_id)
    )
  );

drop policy if exists "conservation_inv_delete" on public.conservation_investigations;
create policy "conservation_inv_delete"
  on public.conservation_investigations for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.conservation_site_admin_manages(site_id)
      and investigation_status in ('open', 'cancelled')
    )
  );

-- Actions
drop policy if exists "conservation_action_insert" on public.conservation_actions;
create policy "conservation_action_insert"
  on public.conservation_actions for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

drop policy if exists "conservation_action_update" on public.conservation_actions;
create policy "conservation_action_update"
  on public.conservation_actions for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
    or (
      public.current_user_role() = 'technician'::public.user_role
      and owner_id = auth.uid()
      and public.has_site_access(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
    or (
      public.current_user_role() = 'technician'::public.user_role
      and owner_id = auth.uid()
      and public.has_site_access(site_id)
    )
  );

drop policy if exists "conservation_action_delete" on public.conservation_actions;
create policy "conservation_action_delete"
  on public.conservation_actions for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      public.conservation_site_admin_manages(site_id)
      and status in ('open', 'cancelled')
    )
  );

-- Evidence writes
drop policy if exists "conservation_evidence_insert" on public.conservation_evidence;
create policy "conservation_evidence_insert"
  on public.conservation_evidence for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
    or (
      public.current_user_role() = 'technician'::public.user_role
      and public.has_site_access(site_id)
      and (
        (
          investigation_id is not null
          and exists (
            select 1 from public.conservation_investigations i
            where i.id = investigation_id and i.assigned_to = auth.uid()
          )
        )
        or (
          action_id is not null
          and exists (
            select 1 from public.conservation_actions a
            where a.id = action_id and a.owner_id = auth.uid()
          )
        )
        or (
          opportunity_id is not null
          and exists (
            select 1 from public.conservation_investigations i
            where i.opportunity_id = opportunity_id and i.assigned_to = auth.uid()
          )
        )
      )
    )
  );

drop policy if exists "conservation_evidence_update" on public.conservation_evidence;
create policy "conservation_evidence_update"
  on public.conservation_evidence for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );

drop policy if exists "conservation_evidence_delete" on public.conservation_evidence;
create policy "conservation_evidence_delete"
  on public.conservation_evidence for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.conservation_site_admin_manages(site_id)
  );
