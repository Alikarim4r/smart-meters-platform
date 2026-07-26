-- =============================================================================
-- Migration: 033_site_utility_network_v2_schema.sql
-- Water utility network v2: Asset → Port → Connection + revisions + views.
-- Replaces 031 node/edge model as source of truth (031 kept deprecated, no dual-write).
-- Next migration number after 031. MOEHE HQ v1 = one member site; members support N sites.
-- =============================================================================

comment on table public.site_network_nodes is
  'DEPRECATED (031). Prefer site_utility_assets / revision_nodes. Kept for rollback/verification; no dual-write.';
comment on table public.site_network_edges is
  'DEPRECATED (031). Prefer site_utility_revision_connections. Kept for rollback/verification; no dual-write.';
comment on table public.site_network_viewport is
  'DEPRECATED (031). Prefer per-user local viewport + site_utility_view_nodes layout.';

-- ---------------------------------------------------------------------------
-- Networks + members + revisions
-- ---------------------------------------------------------------------------
create table if not exists public.site_utility_networks (
  id                     uuid primary key default gen_random_uuid(),
  category_id            uuid not null references public.meter_categories (id) on delete restrict,
  code                   text not null,
  name_en                text not null,
  name_ar                text not null,
  draft_revision_id      uuid,
  published_revision_id  uuid,
  is_active              boolean not null default true,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  created_by             uuid references public.profiles (id) on delete set null,
  updated_by             uuid references public.profiles (id) on delete set null,

  constraint site_utility_networks_code_unique unique (code),
  constraint site_utility_networks_code_not_empty check (char_length(trim(code)) > 0),
  constraint site_utility_networks_name_en_not_empty check (char_length(trim(name_en)) > 0)
);

create table if not exists public.site_utility_network_members (
  network_id  uuid not null references public.site_utility_networks (id) on delete cascade,
  site_id     uuid not null references public.sites (id) on delete restrict,
  created_at  timestamptz not null default now(),
  primary key (network_id, site_id)
);

create index if not exists site_utility_network_members_site_idx
  on public.site_utility_network_members (site_id);

create table if not exists public.site_utility_network_revisions (
  id                   uuid primary key default gen_random_uuid(),
  network_id           uuid not null references public.site_utility_networks (id) on delete cascade,
  status               text not null,
  lock_version         integer not null default 1,
  based_on_revision_id uuid references public.site_utility_network_revisions (id) on delete set null,
  published_at         timestamptz,
  published_by         uuid references public.profiles (id) on delete set null,
  created_at           timestamptz not null default now(),
  created_by           uuid references public.profiles (id) on delete set null,
  notes                text,

  constraint site_utility_network_revisions_status_check check (
    status in ('draft', 'published', 'archived')
  ),
  constraint site_utility_network_revisions_lock_positive check (lock_version >= 1)
);

create unique index if not exists site_utility_network_one_draft_uidx
  on public.site_utility_network_revisions (network_id)
  where status = 'draft';

alter table public.site_utility_networks
  drop constraint if exists site_utility_networks_draft_fk;
alter table public.site_utility_networks
  add constraint site_utility_networks_draft_fk
  foreign key (draft_revision_id)
  references public.site_utility_network_revisions (id)
  on delete set null;

alter table public.site_utility_networks
  drop constraint if exists site_utility_networks_published_fk;
alter table public.site_utility_networks
  add constraint site_utility_networks_published_fk
  foreign key (published_revision_id)
  references public.site_utility_network_revisions (id)
  on delete set null;

create index if not exists site_utility_network_revisions_network_idx
  on public.site_utility_network_revisions (network_id, status);

-- ---------------------------------------------------------------------------
-- Assets + ports (live entities; membership in revision via revision_nodes)
-- ---------------------------------------------------------------------------
create table if not exists public.site_utility_assets (
  id                 uuid primary key default gen_random_uuid(),
  site_id            uuid not null references public.sites (id) on delete cascade,
  facility_area_id   uuid references public.site_facility_areas (id) on delete set null,
  asset_type         text not null,
  service_type       text,
  name_en            text not null,
  name_ar            text not null,
  code               text not null,
  status             text not null default 'active',
  ref_meter_id       uuid references public.meters (id) on delete restrict,
  ref_tank_id        uuid references public.site_tanks (id) on delete restrict,
  meter_role         text,
  properties         jsonb not null default '{}'::jsonb,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  created_by         uuid references public.profiles (id) on delete set null,
  updated_by         uuid references public.profiles (id) on delete set null,

  constraint site_utility_assets_type_check check (
    asset_type in (
      'external_source', 'meter', 'tank', 'pump', 'filter', 'treatment_unit',
      'junction', 'consumer', 'discharge_point', 'tanker_loading', 'building_portal'
    )
  ),
  constraint site_utility_assets_status_check check (status in ('active', 'inactive')),
  constraint site_utility_assets_meter_role_check check (
    meter_role is null or meter_role in (
      'boundary', 'main', 'submeter', 'check', 'billing', 'process'
    )
  ),
  constraint site_utility_assets_ref_check check (
    (asset_type = 'meter' and ref_meter_id is not null and ref_tank_id is null)
    or (asset_type = 'tank' and ref_tank_id is not null and ref_meter_id is null)
    or (asset_type not in ('meter', 'tank') and ref_meter_id is null and ref_tank_id is null)
  ),
  constraint site_utility_assets_code_not_empty check (char_length(trim(code)) > 0),
  constraint site_utility_assets_name_en_not_empty check (char_length(trim(name_en)) > 0)
);

create unique index if not exists site_utility_assets_site_code_uidx
  on public.site_utility_assets (site_id, code)
  where status = 'active';

create unique index if not exists site_utility_assets_meter_uidx
  on public.site_utility_assets (ref_meter_id)
  where ref_meter_id is not null and status = 'active';

create unique index if not exists site_utility_assets_tank_uidx
  on public.site_utility_assets (ref_tank_id)
  where ref_tank_id is not null and status = 'active';

create index if not exists site_utility_assets_site_type_idx
  on public.site_utility_assets (site_id, asset_type, status);

create table if not exists public.site_utility_asset_ports (
  id           uuid primary key default gen_random_uuid(),
  asset_id     uuid not null references public.site_utility_assets (id) on delete cascade,
  code         text not null,
  name_en      text not null,
  name_ar      text not null,
  direction    text not null,
  port_role    text not null,
  properties   jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint site_utility_asset_ports_direction_check check (
    direction in ('in', 'out', 'bidirectional')
  ),
  constraint site_utility_asset_ports_role_check check (
    port_role in (
      'inlet', 'outlet', 'product', 'reject', 'overflow',
      'washout', 'drain', 'emergency', 'tanker_transfer'
    )
  ),
  constraint site_utility_asset_ports_code_unique unique (asset_id, code)
);

create index if not exists site_utility_asset_ports_asset_idx
  on public.site_utility_asset_ports (asset_id);

-- ---------------------------------------------------------------------------
-- Revision graph: nodes + connections
-- ---------------------------------------------------------------------------
create table if not exists public.site_utility_revision_nodes (
  id               uuid primary key default gen_random_uuid(),
  revision_id      uuid not null references public.site_utility_network_revisions (id) on delete cascade,
  asset_id         uuid not null references public.site_utility_assets (id) on delete restrict,
  legacy_node_id   uuid,
  created_at       timestamptz not null default now(),

  constraint site_utility_revision_nodes_unique unique (revision_id, asset_id)
);

create index if not exists site_utility_revision_nodes_asset_idx
  on public.site_utility_revision_nodes (asset_id);

create unique index if not exists site_utility_revision_nodes_legacy_uidx
  on public.site_utility_revision_nodes (revision_id, legacy_node_id)
  where legacy_node_id is not null;

create table if not exists public.site_utility_revision_connections (
  id                  uuid primary key default gen_random_uuid(),
  revision_id         uuid not null references public.site_utility_network_revisions (id) on delete cascade,
  from_node_id        uuid not null references public.site_utility_revision_nodes (id) on delete cascade,
  from_port_id        uuid not null references public.site_utility_asset_ports (id) on delete restrict,
  to_node_id          uuid not null references public.site_utility_revision_nodes (id) on delete cascade,
  to_port_id          uuid not null references public.site_utility_asset_ports (id) on delete restrict,
  connection_kind     text not null,
  water_type          text,
  transport_mode      text not null default 'pipe',
  operating_mode      text not null default 'normal',
  priority            integer not null default 0,
  normally_open       boolean not null default true,
  is_consumptive      boolean not null default true,
  legacy_sync_status  text not null default 'graph_only',
  legacy_edge_id      uuid,
  properties          jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint site_utility_rev_conn_kind_check check (
    connection_kind in (
      'supply', 'transfer', 'overflow', 'washout', 'drain',
      'discharge', 'tanker_transport', 'bypass', 'recirculation'
    )
  ),
  constraint site_utility_rev_conn_transport_check check (
    transport_mode in ('pipe', 'tanker', 'open_drain', 'other')
  ),
  constraint site_utility_rev_conn_operating_check check (
    operating_mode in ('normal', 'standby', 'emergency', 'seasonal', 'maintenance')
  ),
  constraint site_utility_rev_conn_legacy_sync_check check (
    legacy_sync_status in ('synced', 'graph_only', 'conflict', 'unsupported')
  ),
  constraint site_utility_rev_conn_no_self check (from_node_id <> to_node_id),
  constraint site_utility_rev_conn_unique
    unique (revision_id, from_port_id, to_port_id, connection_kind)
);

create index if not exists site_utility_rev_conn_revision_idx
  on public.site_utility_revision_connections (revision_id);

-- Non-consumptive kinds default via trigger below.
create or replace function public.site_utility_connection_set_consumptive()
returns trigger
language plpgsql
as $$
begin
  if new.connection_kind in ('overflow', 'washout', 'drain', 'discharge') then
    new.is_consumptive := false;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists site_utility_rev_conn_consumptive on public.site_utility_revision_connections;
create trigger site_utility_rev_conn_consumptive
  before insert or update on public.site_utility_revision_connections
  for each row execute function public.site_utility_connection_set_consumptive();

-- ---------------------------------------------------------------------------
-- Views + placements (per revision)
-- ---------------------------------------------------------------------------
create table if not exists public.site_utility_network_views (
  id                 uuid primary key default gen_random_uuid(),
  network_id         uuid not null references public.site_utility_networks (id) on delete cascade,
  code               text not null,
  name_en            text not null,
  name_ar            text not null,
  view_kind          text not null,
  facility_area_id   uuid references public.site_facility_areas (id) on delete set null,
  sort_order         integer not null default 0,
  is_default         boolean not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint site_utility_network_views_kind_check check (
    view_kind in (
      'campus_overview', 'building', 'potable', 'tse_irrigation_rain',
      'ro_cooling', 'fire', 'custom'
    )
  ),
  constraint site_utility_network_views_code_unique unique (network_id, code)
);

create unique index if not exists site_utility_network_views_one_default_uidx
  on public.site_utility_network_views (network_id)
  where is_default;

create table if not exists public.site_utility_view_nodes (
  id            uuid primary key default gen_random_uuid(),
  revision_id   uuid not null references public.site_utility_network_revisions (id) on delete cascade,
  view_id       uuid not null references public.site_utility_network_views (id) on delete cascade,
  node_id       uuid not null references public.site_utility_revision_nodes (id) on delete cascade,
  pos_x         double precision not null default 0,
  pos_y         double precision not null default 0,
  width         double precision,
  height        double precision,
  collapsed     boolean not null default false,
  updated_at    timestamptz not null default now(),

  constraint site_utility_view_nodes_unique unique (revision_id, view_id, node_id)
);

create index if not exists site_utility_view_nodes_view_idx
  on public.site_utility_view_nodes (view_id, revision_id);

-- ---------------------------------------------------------------------------
-- Asset / area / meter-tank site integrity
-- ---------------------------------------------------------------------------
create or replace function public.validate_site_utility_asset_refs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_site uuid;
  v_area_site uuid;
begin
  if new.facility_area_id is not null then
    select site_id into v_area_site from public.site_facility_areas where id = new.facility_area_id;
    if v_area_site is null or v_area_site <> new.site_id then
      raise exception 'Asset facility_area must belong to the same site';
    end if;
  end if;

  if new.ref_meter_id is not null then
    select site_id into v_site from public.meters where id = new.ref_meter_id;
    if v_site is null or v_site <> new.site_id then
      raise exception 'Meter asset must reference a meter on the same site';
    end if;
  end if;

  if new.ref_tank_id is not null then
    select site_id into v_site from public.site_tanks where id = new.ref_tank_id;
    if v_site is null or v_site <> new.site_id then
      raise exception 'Tank asset must reference a tank on the same site';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists site_utility_assets_validate_refs on public.site_utility_assets;
create trigger site_utility_assets_validate_refs
  before insert or update on public.site_utility_assets
  for each row execute function public.validate_site_utility_asset_refs();

create or replace function public.validate_site_utility_connection_endpoints()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_from_rev uuid;
  v_to_rev uuid;
  v_from_asset uuid;
  v_to_asset uuid;
  v_from_port_asset uuid;
  v_to_port_asset uuid;
  v_from_dir text;
  v_to_dir text;
  v_from_role text;
  v_to_role text;
  v_from_type text;
  v_network uuid;
  v_from_site uuid;
  v_to_site uuid;
begin
  select revision_id, asset_id into v_from_rev, v_from_asset
  from public.site_utility_revision_nodes where id = new.from_node_id;
  select revision_id, asset_id into v_to_rev, v_to_asset
  from public.site_utility_revision_nodes where id = new.to_node_id;

  if v_from_rev is null or v_to_rev is null then
    raise exception 'Connection endpoints must exist';
  end if;
  if v_from_rev <> new.revision_id or v_to_rev <> new.revision_id then
    raise exception 'Connection endpoints must belong to the same revision';
  end if;

  select asset_id, direction, port_role
    into v_from_port_asset, v_from_dir, v_from_role
  from public.site_utility_asset_ports where id = new.from_port_id;
  select asset_id, direction, port_role
    into v_to_port_asset, v_to_dir, v_to_role
  from public.site_utility_asset_ports where id = new.to_port_id;

  if v_from_port_asset is distinct from v_from_asset
     or v_to_port_asset is distinct from v_to_asset then
    raise exception 'Ports must belong to the connection endpoint assets';
  end if;

  if v_from_dir = 'in' then
    raise exception 'Source port does not allow outflow';
  end if;
  if v_to_dir = 'out' then
    raise exception 'Destination port does not allow inflow';
  end if;

  select asset_type, site_id into v_from_type, v_from_site
  from public.site_utility_assets where id = v_from_asset;
  select site_id into v_to_site from public.site_utility_assets where id = v_to_asset;

  if v_from_type in ('discharge_point') then
    raise exception 'Connections cannot leave a discharge_point';
  end if;

  select network_id into v_network
  from public.site_utility_network_revisions where id = new.revision_id;

  if not exists (
    select 1 from public.site_utility_network_members m
    where m.network_id = v_network and m.site_id = v_from_site
  ) or not exists (
    select 1 from public.site_utility_network_members m
    where m.network_id = v_network and m.site_id = v_to_site
  ) then
    raise exception 'Connection asset sites must be network members';
  end if;

  if new.connection_kind = 'overflow' and v_from_role is distinct from 'overflow' then
    raise exception
      'Overflow connections must leave an overflow port (got port % role %)',
      new.from_port_id, v_from_role;
  end if;
  if new.connection_kind = 'washout'
     and coalesce(v_from_role, '') not in ('washout', 'drain') then
    raise exception
      'Washout connections must leave a washout or drain port (got %)',
      v_from_role;
  end if;
  if v_from_role = 'product' and v_to_role = 'reject' then
    raise exception 'Cannot connect product port as reject path';
  end if;
  if v_from_role = 'reject' and v_to_role = 'product' then
    raise exception 'Cannot connect reject port as product path';
  end if;

  return new;
end;
$$;

drop trigger if exists site_utility_rev_conn_validate on public.site_utility_revision_connections;
create trigger site_utility_rev_conn_validate
  before insert or update on public.site_utility_revision_connections
  for each row execute function public.validate_site_utility_connection_endpoints();

-- Published revision immutability
create or replace function public.prevent_published_revision_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_rev uuid;
begin
  if tg_table_name = 'site_utility_network_revisions' then
    if tg_op = 'DELETE' then
      if old.status = 'published'
         and exists (
           select 1 from public.site_utility_networks n where n.id = old.network_id
         ) then
        raise exception 'Published revision is immutable';
      end if;
      return old;
    end if;
    if old.status = 'published' and (
         new.status is distinct from old.status
      or new.lock_version is distinct from old.lock_version
      or new.network_id is distinct from old.network_id
      or new.based_on_revision_id is distinct from old.based_on_revision_id
      or new.notes is distinct from old.notes
    ) then
      raise exception 'Published revision is immutable';
    end if;
    return new;
  end if;

  v_rev := coalesce(new.revision_id, old.revision_id);
  select status into v_status
  from public.site_utility_network_revisions where id = v_rev;

  if v_status is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    raise exception 'Revision not found for utility network content';
  end if;

  if v_status = 'published' then
    raise exception 'Published revision content is immutable';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists site_utility_revisions_immutable on public.site_utility_network_revisions;
create trigger site_utility_revisions_immutable
  before update or delete on public.site_utility_network_revisions
  for each row execute function public.prevent_published_revision_mutation();

drop trigger if exists site_utility_rev_nodes_immutable on public.site_utility_revision_nodes;
create trigger site_utility_rev_nodes_immutable
  before insert or update or delete on public.site_utility_revision_nodes
  for each row execute function public.prevent_published_revision_mutation();

drop trigger if exists site_utility_rev_conn_immutable on public.site_utility_revision_connections;
create trigger site_utility_rev_conn_immutable
  before insert or update or delete on public.site_utility_revision_connections
  for each row execute function public.prevent_published_revision_mutation();

drop trigger if exists site_utility_view_nodes_immutable on public.site_utility_view_nodes;
create trigger site_utility_view_nodes_immutable
  before insert or update or delete on public.site_utility_view_nodes
  for each row execute function public.prevent_published_revision_mutation();

comment on table public.site_utility_networks is
  'Utility networks (v1 water). May span one or more member sites.';
comment on table public.site_utility_assets is
  'Physical/logical assets (meters, tanks, RO, drains…). Topology source of truth with ports.';
comment on table public.site_utility_revision_connections is
  'Directed port-to-port connections within a network revision.';
comment on column public.site_utility_revision_connections.is_consumptive is
  'False for overflow/washout/drain/discharge — not normal consumption.';
comment on column public.site_utility_assets.meter_role is
  'Analytical role for meters (boundary/main/submeter/check/billing/process). Not auto-summed.';
