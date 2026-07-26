-- Phase D prep (close C): idempotent import dry-run + scoped 031 write freeze
-- Staging only. Does not delete 031. No dual-write. No Production apply implied.

-- ---------------------------------------------------------------------------
-- 1) Scoped legacy write cutover
-- ---------------------------------------------------------------------------
create table if not exists public.site_utility_legacy_cutover (
  network_id uuid not null references public.site_utility_networks(id) on delete cascade,
  site_id uuid not null references public.sites(id) on delete cascade,
  category_id uuid not null references public.meter_categories(id),
  legacy_write_status text not null default 'enabled'
    check (legacy_write_status in ('enabled', 'frozen')),
  frozen_at timestamptz,
  frozen_by uuid references public.profiles(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (network_id, site_id, category_id)
);

create index if not exists site_utility_legacy_cutover_site_cat_idx
  on public.site_utility_legacy_cutover (site_id, category_id)
  where legacy_write_status = 'frozen';

alter table public.site_utility_legacy_cutover enable row level security;

drop policy if exists site_utility_legacy_cutover_select on public.site_utility_legacy_cutover;
create policy site_utility_legacy_cutover_select
  on public.site_utility_legacy_cutover for select to authenticated
  using (
    public.is_super_admin()
    or public.has_site_access(site_id)
  );

create or replace function public.utility_legacy_writes_frozen(
  p_site_id uuid,
  p_category_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.site_utility_legacy_cutover c
    where c.site_id = p_site_id
      and c.category_id = p_category_id
      and c.legacy_write_status = 'frozen'
  );
$$;

create or replace function public.utility_assert_legacy_writes_allowed(
  p_site_id uuid,
  p_category_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.utility_legacy_writes_frozen(p_site_id, p_category_id) then
    raise exception 'Legacy 031 writes are frozen for this site/category after v2 cutover'
      using errcode = 'P0001';
  end if;
end;
$$;

create or replace function public.trg_block_frozen_legacy_network_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_site uuid;
  v_cat uuid;
begin
  if tg_op = 'DELETE' then
    v_site := old.site_id;
    v_cat := old.category_id;
  else
    v_site := new.site_id;
    v_cat := new.category_id;
  end if;
  perform public.utility_assert_legacy_writes_allowed(v_site, v_cat);
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists site_network_nodes_block_frozen on public.site_network_nodes;
create trigger site_network_nodes_block_frozen
  before insert or update or delete on public.site_network_nodes
  for each row execute function public.trg_block_frozen_legacy_network_write();

drop trigger if exists site_network_edges_block_frozen on public.site_network_edges;
create trigger site_network_edges_block_frozen
  before insert or update or delete on public.site_network_edges
  for each row execute function public.trg_block_frozen_legacy_network_write();

drop trigger if exists site_network_viewport_block_frozen on public.site_network_viewport;
create trigger site_network_viewport_block_frozen
  before insert or update or delete on public.site_network_viewport
  for each row execute function public.trg_block_frozen_legacy_network_write();

-- ---------------------------------------------------------------------------
-- 2) Connection match helpers for import plan idempotency
-- ---------------------------------------------------------------------------
create or replace function public.utility_legacy_edge_conn_kind(p_edge_kind text)
returns text
language sql
immutable
as $$
  select case p_edge_kind
    when 'pour' then 'transfer'
    when 'supply' then 'supply'
    when 'overflow' then 'overflow'
    when 'washout' then 'washout'
    when 'discharge' then 'discharge'
    else 'transfer'
  end;
$$;

-- Resolve whether a planned legacy edge already exists in a draft revision.
-- Match key: revision + from/to asset ports + connection_kind + optional legacy_edge_id.
create or replace function public.utility_legacy_connection_already_in_revision(
  p_revision_id uuid,
  p_legacy_edge_id uuid,
  p_from_legacy_node_id uuid,
  p_to_legacy_node_id uuid,
  p_edge_kind text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_conn_kind text := public.utility_legacy_edge_conn_kind(p_edge_kind);
  v_from_node uuid;
  v_to_node uuid;
  v_from_asset uuid;
  v_to_asset uuid;
  v_from_port uuid;
  v_to_port uuid;
begin
  if exists (
    select 1 from public.site_utility_revision_connections c
    where c.revision_id = p_revision_id
      and c.legacy_edge_id = p_legacy_edge_id
  ) then
    return true;
  end if;

  select id, asset_id into v_from_node, v_from_asset
  from public.site_utility_revision_nodes
  where revision_id = p_revision_id and legacy_node_id = p_from_legacy_node_id
  limit 1;
  select id, asset_id into v_to_node, v_to_asset
  from public.site_utility_revision_nodes
  where revision_id = p_revision_id and legacy_node_id = p_to_legacy_node_id
  limit 1;

  if v_from_node is null or v_to_node is null then
    return false;
  end if;

  if v_conn_kind = 'overflow' then
    select id into v_from_port from public.site_utility_asset_ports
    where asset_id = v_from_asset and port_role = 'overflow' limit 1;
  elsif v_conn_kind = 'washout' then
    select id into v_from_port from public.site_utility_asset_ports
    where asset_id = v_from_asset and port_role in ('washout', 'drain')
    order by case port_role when 'washout' then 0 else 1 end limit 1;
  elsif v_conn_kind = 'drain' then
    select id into v_from_port from public.site_utility_asset_ports
    where asset_id = v_from_asset and port_role = 'drain' limit 1;
  elsif v_conn_kind in ('discharge', 'tanker_transport') then
    select id into v_from_port from public.site_utility_asset_ports
    where asset_id = v_from_asset
      and port_role in ('tanker_transfer', 'outlet', 'drain', 'overflow')
    order by case port_role
      when 'tanker_transfer' then 0 when 'outlet' then 1 when 'drain' then 2 else 3
    end limit 1;
  else
    select id into v_from_port from public.site_utility_asset_ports
    where asset_id = v_from_asset and direction in ('out', 'bidirectional')
    order by case port_role
      when 'outlet' then 0 when 'product' then 1 when 'tanker_transfer' then 2 else 3
    end limit 1;
  end if;

  select id into v_to_port from public.site_utility_asset_ports
  where asset_id = v_to_asset and direction in ('in', 'bidirectional')
  order by case port_role when 'inlet' then 0 else 1 end
  limit 1;

  if v_from_port is null or v_to_port is null then
    return false;
  end if;

  return exists (
    select 1 from public.site_utility_revision_connections c
    where c.revision_id = p_revision_id
      and c.from_port_id = v_from_port
      and c.to_port_id = v_to_port
      and c.connection_kind = v_conn_kind
  );
end;
$$;

create or replace function public.utility_legacy_node_already_in_revision(
  p_revision_id uuid,
  p_legacy_node_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.site_utility_revision_nodes n
    where n.revision_id = p_revision_id
      and n.legacy_node_id = p_legacy_node_id
  );
$$;

-- ---------------------------------------------------------------------------
-- 3) Idempotent import plan (dry-run source of truth)
-- ---------------------------------------------------------------------------
create or replace function public.import_legacy_network_plan(
  p_site_id uuid,
  p_category_id uuid,
  p_network_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nodes int;
  v_edges int;
  v_existing_assets int := 0;
  v_actions jsonb := '[]'::jsonb;
  v_revision_id uuid;
  v_additions int := 0;
  v_updates int := 0;
  v_skipped int := 0;
  r record;
begin
  if not public.can_manage_site_meters(p_site_id) then
    raise exception 'Not allowed to manage meters for site' using errcode = '42501';
  end if;

  if p_network_id is not null then
    select draft_revision_id into v_revision_id
    from public.site_utility_networks
    where id = p_network_id;
  end if;

  select count(*) into v_nodes
  from public.site_network_nodes
  where site_id = p_site_id and category_id = p_category_id and is_active;

  select count(*) into v_edges
  from public.site_network_edges
  where site_id = p_site_id and category_id = p_category_id;

  for r in
    select n.*
    from public.site_network_nodes n
    where n.site_id = p_site_id and n.category_id = p_category_id and n.is_active
  loop
    if r.kind = 'meter' then
      if v_revision_id is not null
         and public.utility_legacy_node_already_in_revision(v_revision_id, r.id) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'already_in_revision',
          'legacy_node_id', r.id, 'kind', 'meter'
        ));
        v_skipped := v_skipped + 1;
        v_existing_assets := v_existing_assets + 1;
      elsif exists (
        select 1 from public.site_utility_assets a
        where a.ref_meter_id = r.ref_meter_id and a.status = 'active'
      ) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'meter_asset_exists',
          'legacy_node_id', r.id, 'kind', 'meter'
        ));
        v_skipped := v_skipped + 1;
        v_existing_assets := v_existing_assets + 1;
      else
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'add_meter_asset', 'legacy_node_id', r.id,
          'ref_meter_id', r.ref_meter_id, 'pos_x', r.pos_x, 'pos_y', r.pos_y
        ));
        v_additions := v_additions + 1;
      end if;
    elsif r.kind = 'tank' then
      if v_revision_id is not null
         and public.utility_legacy_node_already_in_revision(v_revision_id, r.id) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'already_in_revision',
          'legacy_node_id', r.id, 'kind', 'tank'
        ));
        v_skipped := v_skipped + 1;
        v_existing_assets := v_existing_assets + 1;
      elsif exists (
        select 1 from public.site_utility_assets a
        where a.ref_tank_id = r.ref_tank_id and a.status = 'active'
      ) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'tank_asset_exists',
          'legacy_node_id', r.id, 'kind', 'tank'
        ));
        v_skipped := v_skipped + 1;
        v_existing_assets := v_existing_assets + 1;
      else
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'add_tank_asset', 'legacy_node_id', r.id,
          'ref_tank_id', r.ref_tank_id, 'pos_x', r.pos_x, 'pos_y', r.pos_y
        ));
        v_additions := v_additions + 1;
      end if;
    elsif r.kind = 'tanker_discharge' then
      if v_revision_id is not null
         and public.utility_legacy_node_already_in_revision(v_revision_id, r.id) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'already_in_revision',
          'legacy_node_id', r.id, 'kind', 'tanker_loading'
        ));
        v_skipped := v_skipped + 1;
      else
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'add_tanker_loading', 'legacy_node_id', r.id,
          'label_en', r.label_en, 'label_ar', r.label_ar,
          'pos_x', r.pos_x, 'pos_y', r.pos_y
        ));
        v_additions := v_additions + 1;
      end if;
    elsif r.kind = 'ground_drain' then
      if v_revision_id is not null
         and public.utility_legacy_node_already_in_revision(v_revision_id, r.id) then
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'skipped', 'reason', 'already_in_revision',
          'legacy_node_id', r.id, 'kind', 'discharge_point'
        ));
        v_skipped := v_skipped + 1;
      else
        v_actions := v_actions || jsonb_build_array(jsonb_build_object(
          'action', 'add_discharge_point', 'legacy_node_id', r.id,
          'label_en', r.label_en, 'label_ar', r.label_ar,
          'pos_x', r.pos_x, 'pos_y', r.pos_y
        ));
        v_additions := v_additions + 1;
      end if;
    end if;
  end loop;

  for r in
    select e.*,
           fn.kind as from_kind, tn.kind as to_kind
    from public.site_network_edges e
    join public.site_network_nodes fn on fn.id = e.from_node_id
    join public.site_network_nodes tn on tn.id = e.to_node_id
    where e.site_id = p_site_id and e.category_id = p_category_id
  loop
    if v_revision_id is not null
       and public.utility_legacy_connection_already_in_revision(
         v_revision_id, r.id, r.from_node_id, r.to_node_id, r.edge_kind::text
       ) then
      v_actions := v_actions || jsonb_build_array(jsonb_build_object(
        'action', 'skipped',
        'reason', 'connection_exists',
        'legacy_edge_id', r.id,
        'from_legacy_node_id', r.from_node_id,
        'to_legacy_node_id', r.to_node_id,
        'edge_kind', r.edge_kind,
        'connection_kind', public.utility_legacy_edge_conn_kind(r.edge_kind::text),
        'match_key', 'revision+ports+kind[+legacy_edge_id]'
      ));
      v_skipped := v_skipped + 1;
    else
      v_actions := v_actions || jsonb_build_array(jsonb_build_object(
        'action', 'add_connection',
        'legacy_edge_id', r.id,
        'from_legacy_node_id', r.from_node_id,
        'to_legacy_node_id', r.to_node_id,
        'edge_kind', r.edge_kind,
        'connection_kind', public.utility_legacy_edge_conn_kind(r.edge_kind::text),
        'legacy_sync_status', case
          when r.from_kind = 'meter' and r.to_kind = 'meter' and r.edge_kind::text = 'supply'
            then 'synced'
          when r.from_kind = 'meter' and r.to_kind = 'tank' and r.edge_kind::text = 'pour'
            then 'synced'
          else 'graph_only'
        end,
        'match_key', 'revision+ports+kind[+legacy_edge_id]'
      ));
      v_additions := v_additions + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'site_id', p_site_id,
    'category_id', p_category_id,
    'network_id', p_network_id,
    'draft_revision_id', v_revision_id,
    'legacy_nodes', v_nodes,
    'legacy_edges', v_edges,
    'existing_mapped_assets', v_existing_assets,
    'additions', v_additions,
    'updates', v_updates,
    'skipped', v_skipped,
    'unchanged', v_skipped,
    'actions', v_actions
  );
end;
$$;

create or replace function public.import_legacy_network_dry_run(
  p_site_id uuid,
  p_category_id uuid,
  p_network_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.import_legacy_network_plan(p_site_id, p_category_id, p_network_id)
    || jsonb_build_object('dry_run', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Finalize cutover (freeze 031 writes for network members site+category)
-- ---------------------------------------------------------------------------
create or replace function public.finalize_legacy_network_cutover(
  p_network_id uuid,
  p_site_id uuid,
  p_confirm boolean default false,
  p_notes text default null,
  p_acknowledge_validation_errors boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_net public.site_utility_networks;
  v_member record;
  v_rev uuid;
  v_validation jsonb;
  v_reconcile jsonb;
  v_errors int;
  v_nodes int;
  v_legacy int;
begin
  if not coalesce(p_confirm, false) then
    raise exception 'Cutover requires explicit confirmation (p_confirm=true)';
  end if;

  select * into v_net from public.site_utility_networks where id = p_network_id;
  if v_net.id is null then
    raise exception 'Network not found';
  end if;

  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = p_network_id and site_id = p_site_id
  ) then
    raise exception 'Site is not a member of this network';
  end if;

  for v_member in
    select site_id from public.site_utility_network_members where network_id = p_network_id
  loop
    if not public.can_manage_site_meters(v_member.site_id) then
      raise exception 'Not allowed to manage all network member sites' using errcode = '42501';
    end if;
  end loop;

  v_rev := v_net.draft_revision_id;
  if v_rev is null then
    raise exception 'Network has no draft revision';
  end if;

  select count(*) into v_nodes
  from public.site_utility_revision_nodes where revision_id = v_rev;
  select count(*) into v_legacy
  from public.site_network_nodes
  where site_id = p_site_id and category_id = v_net.category_id and is_active;

  if v_nodes < 1 then
    raise exception 'Import has not produced draft nodes; cutover refused';
  end if;

  v_validation := public.validate_network_draft(v_rev);
  v_errors := jsonb_array_length(coalesce(v_validation->'errors', '[]'::jsonb));
  if v_errors > 0 and not coalesce(p_acknowledge_validation_errors, false) then
    raise exception 'Draft has validation errors; cutover refused (pass p_acknowledge_validation_errors=true to proceed after review)';
  end if;

  begin
    v_reconcile := public.reconcile_legacy_network(p_network_id, v_rev);
  exception when others then
    v_reconcile := jsonb_build_object('status', 'unavailable', 'diffs', '[]'::jsonb, 'message', sqlerrm);
  end;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(v_reconcile->'diffs', '[]'::jsonb)) d
    where d->>'type' in ('parent_meter_mismatch', 'destination_tank_mismatch')
  ) then
    raise exception 'Critical legacy conflicts remain; cutover refused';
  end if;

  insert into public.site_utility_legacy_cutover (
    network_id, site_id, category_id, legacy_write_status, frozen_at, frozen_by, notes, updated_at
  ) values (
    p_network_id, p_site_id, v_net.category_id, 'frozen', now(), v_uid, p_notes, now()
  )
  on conflict (network_id, site_id, category_id) do update
    set legacy_write_status = 'frozen',
        frozen_at = now(),
        frozen_by = excluded.frozen_by,
        notes = coalesce(excluded.notes, site_utility_legacy_cutover.notes),
        updated_at = now();

  return jsonb_build_object(
    'status', 'frozen',
    'network_id', p_network_id,
    'site_id', p_site_id,
    'category_id', v_net.category_id,
    'legacy_write_status', 'frozen',
    'draft_nodes', v_nodes,
    'legacy_nodes', v_legacy,
    'validation', v_validation,
    'validation_errors_acknowledged', coalesce(p_acknowledge_validation_errors, false),
    'reconcile', v_reconcile
  );
end;
$$;

create or replace function public.get_legacy_write_status(
  p_site_id uuid,
  p_category_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row public.site_utility_legacy_cutover;
begin
  if not public.has_site_access(p_site_id) and not public.is_super_admin() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  select * into v_row
  from public.site_utility_legacy_cutover
  where site_id = p_site_id and category_id = p_category_id
    and legacy_write_status = 'frozen'
  order by frozen_at desc nulls last
  limit 1;

  if v_row.network_id is null then
    return jsonb_build_object(
      'site_id', p_site_id,
      'category_id', p_category_id,
      'legacy_write_status', 'enabled'
    );
  end if;
  return jsonb_build_object(
    'site_id', p_site_id,
    'category_id', p_category_id,
    'network_id', v_row.network_id,
    'legacy_write_status', v_row.legacy_write_status,
    'frozen_at', v_row.frozen_at,
    'frozen_by', v_row.frozen_by,
    'notes', v_row.notes
  );
end;
$$;

revoke all on function public.utility_legacy_writes_frozen(uuid, uuid) from public;
revoke all on function public.utility_assert_legacy_writes_allowed(uuid, uuid) from public;
revoke all on function public.utility_legacy_edge_conn_kind(text) from public;
revoke all on function public.utility_legacy_connection_already_in_revision(uuid, uuid, uuid, uuid, text) from public;
revoke all on function public.utility_legacy_node_already_in_revision(uuid, uuid) from public;
revoke all on function public.finalize_legacy_network_cutover(uuid, uuid, boolean, text) from public;
revoke all on function public.finalize_legacy_network_cutover(uuid, uuid, boolean, text, boolean) from public;
revoke all on function public.get_legacy_write_status(uuid, uuid) from public;

grant execute on function public.utility_legacy_writes_frozen(uuid, uuid) to authenticated;
grant execute on function public.finalize_legacy_network_cutover(uuid, uuid, boolean, text, boolean) to authenticated;
grant execute on function public.get_legacy_write_status(uuid, uuid) to authenticated;
-- import plan / dry_run already granted in 036
