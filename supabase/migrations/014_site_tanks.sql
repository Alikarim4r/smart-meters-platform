-- =============================================================================
-- Site tanks + meter destination tank
-- Migration: 014_site_tanks.sql
-- =============================================================================

create table if not exists public.site_tanks (
  id          uuid primary key default gen_random_uuid(),
  site_id     uuid not null references public.sites (id) on delete cascade,
  name_en     text not null,
  name_ar     text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint site_tanks_name_en_not_empty check (char_length(trim(name_en)) > 0),
  constraint site_tanks_site_name_unique unique (site_id, name_en)
);

create index if not exists site_tanks_site_id_idx
  on public.site_tanks (site_id, is_active);

comment on table public.site_tanks is
  'Named tanks/reservoirs at a site that meters may pour into.';

alter table public.meters
  add column if not exists destination_tank_id uuid
    references public.site_tanks (id) on delete set null;

alter table public.meters
  add column if not exists pours_into_tank boolean not null default false;

comment on column public.meters.destination_tank_id is
  'Optional tank this meter pours into (when pours_into_tank is true).';
comment on column public.meters.pours_into_tank is
  'When true, meter feeds a tank; destination_tank_id should be set.';

create or replace function public.set_site_tanks_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists site_tanks_set_updated_at on public.site_tanks;
create trigger site_tanks_set_updated_at
  before update on public.site_tanks
  for each row execute function public.set_site_tanks_updated_at();

alter table public.site_tanks enable row level security;

create policy "site_tanks_select"
  on public.site_tanks for select to authenticated
  using (public.has_site_access(site_id));

create policy "site_tanks_insert"
  on public.site_tanks for insert to authenticated
  with check (public.can_manage_site_meters(site_id));

create policy "site_tanks_update"
  on public.site_tanks for update to authenticated
  using (public.can_manage_site_meters(site_id))
  with check (public.can_manage_site_meters(site_id));

create policy "site_tanks_delete"
  on public.site_tanks for delete to authenticated
  using (
    public.is_super_admin()
    or public.can_manage_site(site_id)
  );
