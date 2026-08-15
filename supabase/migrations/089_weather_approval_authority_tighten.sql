-- =============================================================================
-- 089: Tighten weather dataset approval authority (Phase 5 hardening)
-- Site-scoped weather approval: site_admin (USA manage) / super / owner only.
-- Does not rewrite 083; replaces function + policies additively.
-- =============================================================================

create or replace function public.conservation_weather_ds_approve_authority()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.status = 'approved'
       or new.approved_by is not null
       or new.approved_at is not null then
      if not (
        public.is_super_admin()
        or public.is_platform_owner()
        or (
          new.site_id is not null
          and public.conservation_site_admin_manages(new.site_id)
        )
      ) then
        raise exception
          'weather dataset approval requires site_admin / super_admin / platform_owner';
      end if;
    end if;
    return new;
  end if;

  if new.status is distinct from old.status
     or new.approved_by is distinct from old.approved_by
     or new.approved_at is distinct from old.approved_at then
    if new.status = 'approved'
       or new.approved_by is distinct from old.approved_by
       or new.approved_at is distinct from old.approved_at then
      if not (
        public.is_super_admin()
        or public.is_platform_owner()
        or (
          new.site_id is not null
          and public.conservation_site_admin_manages(new.site_id)
        )
      ) then
        raise exception
          'weather dataset approval requires site_admin / super_admin / platform_owner';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop policy if exists "conservation_weather_ds_insert"
  on public.conservation_weather_datasets;
drop policy if exists "conservation_weather_ds_update"
  on public.conservation_weather_datasets;
drop policy if exists "conservation_weather_ds_delete"
  on public.conservation_weather_datasets;

create policy "conservation_weather_ds_insert"
  on public.conservation_weather_datasets for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
  );

create policy "conservation_weather_ds_update"
  on public.conservation_weather_datasets for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
  );

create policy "conservation_weather_ds_delete"
  on public.conservation_weather_datasets for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
  );
