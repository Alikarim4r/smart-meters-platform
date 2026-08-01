-- =============================================================================
-- 083: Weather datasets (Phase 5) — additive. No hard-coded weather values.
-- Admin-approved imported / future API / manual datasets only.
-- =============================================================================

create table if not exists public.conservation_weather_datasets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  site_id uuid references public.sites (id) on delete cascade,
  location_label text not null,
  source text not null,
  source_ref text,
  period_start date not null,
  period_end date not null,
  quality text not null default 'unknown',
  status text not null default 'draft',
  imported_at timestamptz not null default now(),
  approved_by uuid references auth.users (id),
  approved_at timestamptz,
  notes text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conservation_weather_ds_source_check
    check (source in ('imported_monthly', 'manual_approved', 'api_future')),
  constraint conservation_weather_ds_quality_check
    check (quality in ('high', 'medium', 'low', 'unknown')),
  constraint conservation_weather_ds_status_check
    check (status in ('draft', 'approved', 'rejected', 'archived')),
  constraint conservation_weather_ds_period_check
    check (period_end >= period_start),
  constraint conservation_weather_ds_location_nonempty
    check (length(trim(location_label)) > 0),
  constraint conservation_weather_ds_approved_actor_check
    check (
      status <> 'approved'
      or (approved_by is not null and approved_at is not null)
    )
);

comment on table public.conservation_weather_datasets is
  'Versioned weather source metadata. Values live in conservation_weather_observations. '
  'Never invent HDD/CDD. Unapproved datasets must not drive official normalization.';

create table if not exists public.conservation_weather_observations (
  id uuid primary key default gen_random_uuid(),
  dataset_id uuid not null
    references public.conservation_weather_datasets (id) on delete cascade,
  period_start date not null,
  period_end date not null,
  hdd numeric(12, 4),
  cdd numeric(12, 4),
  mean_temp_c numeric(8, 3),
  extra jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint conservation_weather_obs_period_check
    check (period_end >= period_start),
  constraint conservation_weather_obs_has_vars_check
    check (hdd is not null or cdd is not null or mean_temp_c is not null)
);

comment on table public.conservation_weather_observations is
  'Period weather variables (HDD/CDD/mean temp). Bound to an approved dataset for use.';

create index if not exists conservation_weather_ds_org_status_idx
  on public.conservation_weather_datasets (organization_id, status);

create index if not exists conservation_weather_ds_site_idx
  on public.conservation_weather_datasets (site_id)
  where site_id is not null;

create index if not exists conservation_weather_obs_dataset_period_idx
  on public.conservation_weather_observations (dataset_id, period_start, period_end);

create trigger conservation_weather_ds_set_updated_at
  before update on public.conservation_weather_datasets
  for each row execute function public.set_updated_at();

-- Approval authority: site_admin (USA manage) / super / owner only.
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
        or public.user_can_manage_organization(new.organization_id)
      ) then
        raise exception
          'weather dataset approval requires site_admin / org manage / super_admin / platform_owner';
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
        or public.user_can_manage_organization(new.organization_id)
      ) then
        raise exception
          'weather dataset approval requires site_admin / org manage / super_admin / platform_owner';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists conservation_weather_ds_approve_authority_trg
  on public.conservation_weather_datasets;
create trigger conservation_weather_ds_approve_authority_trg
  before insert or update on public.conservation_weather_datasets
  for each row execute function public.conservation_weather_ds_approve_authority();

alter table public.conservation_weather_datasets enable row level security;
alter table public.conservation_weather_observations enable row level security;

revoke all on table public.conservation_weather_datasets from anon, authenticated;
revoke all on table public.conservation_weather_observations from anon, authenticated;
grant select, insert, update, delete on table public.conservation_weather_datasets to authenticated;
grant select, insert, update, delete on table public.conservation_weather_observations to authenticated;

create policy "conservation_weather_ds_select"
  on public.conservation_weather_datasets for select to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or exists (
      select 1 from public.sites s
      where s.organization_id = conservation_weather_datasets.organization_id
        and public.has_site_access(s.id)
    )
  );

create policy "conservation_weather_ds_insert"
  on public.conservation_weather_datasets for insert to authenticated
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
  );

create policy "conservation_weather_ds_update"
  on public.conservation_weather_datasets for update to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
  )
  with check (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      site_id is not null
      and public.conservation_site_admin_manages(site_id)
    )
  );

create policy "conservation_weather_ds_delete"
  on public.conservation_weather_datasets for delete to authenticated
  using (
    public.is_super_admin() or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
  );

create policy "conservation_weather_obs_select"
  on public.conservation_weather_observations for select to authenticated
  using (
    exists (
      select 1 from public.conservation_weather_datasets d
      where d.id = dataset_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(d.organization_id)
          or exists (
            select 1 from public.sites s
            where s.organization_id = d.organization_id
              and public.has_site_access(s.id)
          )
        )
    )
  );

create policy "conservation_weather_obs_insert"
  on public.conservation_weather_observations for insert to authenticated
  with check (
    exists (
      select 1 from public.conservation_weather_datasets d
      where d.id = dataset_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(d.organization_id)
          or (
            d.site_id is not null
            and public.conservation_site_admin_manages(d.site_id)
          )
        )
    )
  );

create policy "conservation_weather_obs_update"
  on public.conservation_weather_observations for update to authenticated
  using (
    exists (
      select 1 from public.conservation_weather_datasets d
      where d.id = dataset_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(d.organization_id)
          or (
            d.site_id is not null
            and public.conservation_site_admin_manages(d.site_id)
          )
        )
    )
  )
  with check (
    exists (
      select 1 from public.conservation_weather_datasets d
      where d.id = dataset_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(d.organization_id)
          or (
            d.site_id is not null
            and public.conservation_site_admin_manages(d.site_id)
          )
        )
    )
  );

create policy "conservation_weather_obs_delete"
  on public.conservation_weather_observations for delete to authenticated
  using (
    exists (
      select 1 from public.conservation_weather_datasets d
      where d.id = dataset_id
        and (
          public.is_super_admin() or public.is_platform_owner()
          or public.user_can_manage_organization(d.organization_id)
        )
    )
  );
