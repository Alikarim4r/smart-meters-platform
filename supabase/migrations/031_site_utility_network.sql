-- =============================================================================
-- Site utility network (nodes + edges) for water topology planner
-- Migration: 031_site_utility_network.sql
-- =============================================================================

do $$ begin
  create type public.network_node_kind as enum (
    'meter',
    'tank',
    'tanker_discharge',
    'ground_drain'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.network_edge_kind as enum (
    'supply',
    'pour',
    'overflow',
    'discharge'
  );
exception when duplicate_object then null;
end $$;

create table if not exists public.site_network_nodes (
  id              uuid primary key default gen_random_uuid(),
  site_id         uuid not null references public.sites (id) on delete cascade,
  category_id     uuid not null references public.meter_categories (id) on delete restrict,
  kind            public.network_node_kind not null,
  ref_meter_id    uuid references public.meters (id) on delete cascade,
  ref_tank_id     uuid references public.site_tanks (id) on delete cascade,
  label_en        text,
  label_ar        text,
  pos_x           double precision not null default 0,
  pos_y           double precision not null default 0,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint site_network_nodes_meter_kind_check check (
    (kind = 'meter' and ref_meter_id is not null and ref_tank_id is null)
    or (kind = 'tank' and ref_tank_id is not null and ref_meter_id is null)
    or (kind in ('tanker_discharge', 'ground_drain')
        and ref_meter_id is null and ref_tank_id is null
        and char_length(trim(coalesce(label_en, ''))) > 0)
  )
);

create unique index if not exists site_network_nodes_site_cat_meter_uidx
  on public.site_network_nodes (site_id, category_id, ref_meter_id)
  where ref_meter_id is not null and is_active;

create unique index if not exists site_network_nodes_site_cat_tank_uidx
  on public.site_network_nodes (site_id, category_id, ref_tank_id)
  where ref_tank_id is not null and is_active;

create index if not exists site_network_nodes_site_cat_idx
  on public.site_network_nodes (site_id, category_id, is_active);

create table if not exists public.site_network_edges (
  id              uuid primary key default gen_random_uuid(),
  site_id         uuid not null references public.sites (id) on delete cascade,
  category_id     uuid not null references public.meter_categories (id) on delete restrict,
  from_node_id    uuid not null references public.site_network_nodes (id) on delete cascade,
  to_node_id      uuid not null references public.site_network_nodes (id) on delete cascade,
  edge_kind       public.network_edge_kind not null default 'supply',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint site_network_edges_no_self check (from_node_id <> to_node_id),
  constraint site_network_edges_unique unique (from_node_id, to_node_id, edge_kind)
);

create index if not exists site_network_edges_site_cat_idx
  on public.site_network_edges (site_id, category_id);

create table if not exists public.site_network_viewport (
  site_id         uuid not null references public.sites (id) on delete cascade,
  category_id     uuid not null references public.meter_categories (id) on delete cascade,
  scale           double precision not null default 1,
  offset_x        double precision not null default 0,
  offset_y        double precision not null default 0,
  updated_at      timestamptz not null default now(),
  primary key (site_id, category_id)
);

create or replace function public.set_site_network_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists site_network_nodes_set_updated_at on public.site_network_nodes;
create trigger site_network_nodes_set_updated_at
  before update on public.site_network_nodes
  for each row execute function public.set_site_network_updated_at();

drop trigger if exists site_network_edges_set_updated_at on public.site_network_edges;
create trigger site_network_edges_set_updated_at
  before update on public.site_network_edges
  for each row execute function public.set_site_network_updated_at();

-- Keep referenced meter/tank on the same site as the node.
create or replace function public.validate_site_network_node_refs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_site uuid;
begin
  if new.ref_meter_id is not null then
    select site_id into v_site from public.meters where id = new.ref_meter_id;
    if v_site is null or v_site <> new.site_id then
      raise exception 'Network meter node must reference a meter on the same site';
    end if;
  end if;
  if new.ref_tank_id is not null then
    select site_id into v_site from public.site_tanks where id = new.ref_tank_id;
    if v_site is null or v_site <> new.site_id then
      raise exception 'Network tank node must reference a tank on the same site';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists site_network_nodes_validate_refs on public.site_network_nodes;
create trigger site_network_nodes_validate_refs
  before insert or update on public.site_network_nodes
  for each row execute function public.validate_site_network_node_refs();

create or replace function public.validate_site_network_edge_sites()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_from record;
  v_to record;
begin
  select site_id, category_id into v_from
  from public.site_network_nodes where id = new.from_node_id;
  select site_id, category_id into v_to
  from public.site_network_nodes where id = new.to_node_id;
  if v_from is null or v_to is null then
    raise exception 'Network edge endpoints must exist';
  end if;
  if v_from.site_id <> new.site_id or v_to.site_id <> new.site_id then
    raise exception 'Network edge endpoints must belong to the edge site';
  end if;
  if v_from.category_id <> new.category_id or v_to.category_id <> new.category_id then
    raise exception 'Network edge endpoints must belong to the edge category';
  end if;
  return new;
end;
$$;

drop trigger if exists site_network_edges_validate_sites on public.site_network_edges;
create trigger site_network_edges_validate_sites
  before insert or update on public.site_network_edges
  for each row execute function public.validate_site_network_edge_sites();

alter table public.site_network_nodes enable row level security;
alter table public.site_network_edges enable row level security;
alter table public.site_network_viewport enable row level security;

drop policy if exists site_network_nodes_select on public.site_network_nodes;
create policy site_network_nodes_select
  on public.site_network_nodes for select to authenticated
  using (public.has_site_access(site_id));

drop policy if exists site_network_nodes_insert on public.site_network_nodes;
create policy site_network_nodes_insert
  on public.site_network_nodes for insert to authenticated
  with check (public.can_manage_site_meters(site_id));

drop policy if exists site_network_nodes_update on public.site_network_nodes;
create policy site_network_nodes_update
  on public.site_network_nodes for update to authenticated
  using (public.can_manage_site_meters(site_id))
  with check (public.can_manage_site_meters(site_id));

drop policy if exists site_network_nodes_delete on public.site_network_nodes;
create policy site_network_nodes_delete
  on public.site_network_nodes for delete to authenticated
  using (public.can_manage_site_meters(site_id));

drop policy if exists site_network_edges_select on public.site_network_edges;
create policy site_network_edges_select
  on public.site_network_edges for select to authenticated
  using (public.has_site_access(site_id));

drop policy if exists site_network_edges_insert on public.site_network_edges;
create policy site_network_edges_insert
  on public.site_network_edges for insert to authenticated
  with check (public.can_manage_site_meters(site_id));

drop policy if exists site_network_edges_update on public.site_network_edges;
create policy site_network_edges_update
  on public.site_network_edges for update to authenticated
  using (public.can_manage_site_meters(site_id))
  with check (public.can_manage_site_meters(site_id));

drop policy if exists site_network_edges_delete on public.site_network_edges;
create policy site_network_edges_delete
  on public.site_network_edges for delete to authenticated
  using (public.can_manage_site_meters(site_id));

drop policy if exists site_network_viewport_select on public.site_network_viewport;
create policy site_network_viewport_select
  on public.site_network_viewport for select to authenticated
  using (public.has_site_access(site_id));

drop policy if exists site_network_viewport_upsert on public.site_network_viewport;
create policy site_network_viewport_upsert
  on public.site_network_viewport for all to authenticated
  using (public.can_manage_site_meters(site_id))
  with check (public.can_manage_site_meters(site_id));

-- Import meters/tanks + existing parent/pour links into the network graph.
create or replace function public.import_site_utility_network(
  p_site_id uuid,
  p_category_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meter record;
  v_tank record;
  v_col int;
  v_row int;
  v_from uuid;
  v_to uuid;
  v_nodes int := 0;
  v_edges int := 0;
begin
  if not public.can_manage_site_meters(p_site_id) then
    raise exception 'Not allowed to manage meters for this site';
  end if;

  v_col := 0;
  for v_meter in
    select id, parent_meter_id, level
    from public.meters
    where site_id = p_site_id
      and category_id = p_category_id
      and is_active = true
    order by
      case level::text when 'main' then 0 when 'sub' then 1 else 2 end,
      sort_order,
      name_en
  loop
    insert into public.site_network_nodes (
      site_id, category_id, kind, ref_meter_id, pos_x, pos_y
    )
    select
      p_site_id,
      p_category_id,
      'meter',
      v_meter.id,
      (case v_meter.level::text
         when 'main' then 80
         when 'sub' then 320
         else 560
       end)::double precision,
      (80 + v_col * 110)::double precision
    where not exists (
      select 1 from public.site_network_nodes n
      where n.site_id = p_site_id
        and n.category_id = p_category_id
        and n.ref_meter_id = v_meter.id
        and n.is_active
    );
    v_col := v_col + 1;
  end loop;

  v_row := 0;
  for v_tank in
    select id from public.site_tanks
    where site_id = p_site_id and is_active = true
    order by name_en
  loop
    insert into public.site_network_nodes (
      site_id, category_id, kind, ref_tank_id, pos_x, pos_y
    )
    select
      p_site_id, p_category_id, 'tank', v_tank.id,
      800::double precision,
      (80 + v_row * 110)::double precision
    where not exists (
      select 1 from public.site_network_nodes n
      where n.site_id = p_site_id
        and n.category_id = p_category_id
        and n.ref_tank_id = v_tank.id
        and n.is_active
    );
    v_row := v_row + 1;
  end loop;

  select count(*) into v_nodes
  from public.site_network_nodes
  where site_id = p_site_id and category_id = p_category_id and is_active;

  -- Parent meter → child supply edges
  for v_meter in
    select id, parent_meter_id
    from public.meters
    where site_id = p_site_id
      and category_id = p_category_id
      and parent_meter_id is not null
      and is_active
  loop
    select id into v_from from public.site_network_nodes
    where site_id = p_site_id and category_id = p_category_id
      and ref_meter_id = v_meter.parent_meter_id and is_active
    limit 1;
    select id into v_to from public.site_network_nodes
    where site_id = p_site_id and category_id = p_category_id
      and ref_meter_id = v_meter.id and is_active
    limit 1;
    if v_from is not null and v_to is not null then
      insert into public.site_network_edges (
        site_id, category_id, from_node_id, to_node_id, edge_kind
      ) values (
        p_site_id, p_category_id, v_from, v_to, 'supply'
      )
      on conflict (from_node_id, to_node_id, edge_kind) do nothing;
    end if;
  end loop;

  -- Meter pour → tank edges
  for v_meter in
    select id, destination_tank_id
    from public.meters
    where site_id = p_site_id
      and category_id = p_category_id
      and pours_into_tank = true
      and destination_tank_id is not null
      and is_active
  loop
    select id into v_from from public.site_network_nodes
    where site_id = p_site_id and category_id = p_category_id
      and ref_meter_id = v_meter.id and is_active
    limit 1;
    select id into v_to from public.site_network_nodes
    where site_id = p_site_id and category_id = p_category_id
      and ref_tank_id = v_meter.destination_tank_id and is_active
    limit 1;
    if v_from is not null and v_to is not null then
      insert into public.site_network_edges (
        site_id, category_id, from_node_id, to_node_id, edge_kind
      ) values (
        p_site_id, p_category_id, v_from, v_to, 'pour'
      )
      on conflict (from_node_id, to_node_id, edge_kind) do nothing;
    end if;
  end loop;

  select count(*) into v_edges
  from public.site_network_edges
  where site_id = p_site_id and category_id = p_category_id;

  return jsonb_build_object('nodes', v_nodes, 'edges', v_edges);
end;
$$;

revoke all on function public.import_site_utility_network(uuid, uuid) from public;
grant execute on function public.import_site_utility_network(uuid, uuid) to authenticated;

comment on table public.site_network_nodes is
  'Canvas nodes for site utility network (meters, tanks, discharge points).';
comment on table public.site_network_edges is
  'Directed connections between network nodes.';
comment on function public.import_site_utility_network(uuid, uuid) is
  'Seed network nodes/edges from existing meters hierarchy and tank pours.';
