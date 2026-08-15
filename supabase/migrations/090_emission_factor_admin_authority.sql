-- =============================================================================
-- 090: Emission factor activation — admin roles only (Phase 5)
-- Technician with org update scope must not activate factors.
-- =============================================================================

create or replace function public.conservation_org_admin_for_emission(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or public.is_platform_owner()
    or exists (
      select 1
      from public.sites s
      where s.organization_id = p_org_id
        and public.conservation_site_admin_manages(s.id)
    );
$$;

create or replace function public.emission_factors_approve_authority()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'active'
     and (
       tg_op = 'INSERT'
       or new.status is distinct from old.status
       or new.approved_by is distinct from old.approved_by
       or new.approved_at is distinct from old.approved_at
     ) then
    if not public.conservation_org_admin_for_emission(new.organization_id) then
      raise exception
        'emission factor activation requires site_admin / super_admin / platform_owner';
    end if;
  end if;
  return new;
end;
$$;

drop policy if exists "emission_factors_insert" on public.emission_factors;
drop policy if exists "emission_factors_update" on public.emission_factors;
drop policy if exists "emission_factors_delete" on public.emission_factors;

create policy "emission_factors_insert"
  on public.emission_factors for insert to authenticated
  with check (public.conservation_org_admin_for_emission(organization_id));

create policy "emission_factors_update"
  on public.emission_factors for update to authenticated
  using (public.conservation_org_admin_for_emission(organization_id))
  with check (public.conservation_org_admin_for_emission(organization_id));

create policy "emission_factors_delete"
  on public.emission_factors for delete to authenticated
  using (public.conservation_org_admin_for_emission(organization_id));
