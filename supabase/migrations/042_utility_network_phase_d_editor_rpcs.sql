-- =============================================================================
-- Migration: 042_utility_network_phase_d_editor_rpcs.sql
-- Phase D editor RPCs: tank picker/attach/create, asset/port/connection edits,
-- view management, placement/revision removal. Lock-aware; no 031 dual-write.
-- =============================================================================

-- Soft-archive status for generic assets removed from a revision.
alter table public.site_utility_assets
  drop constraint if exists site_utility_assets_status_check;

alter table public.site_utility_assets
  add constraint site_utility_assets_status_check
  check (status in ('active', 'inactive', 'archived'));

-- ---------------------------------------------------------------------------
-- Default ports: tank aux includes emergency + tanker_transfer
-- ---------------------------------------------------------------------------
create or replace function public.utility_default_ports_for_asset(
  p_asset_id uuid,
  p_asset_type text,
  p_include_tank_aux boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_asset_type = 'meter' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'outlet', 'Outlet', 'مخرج', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type = 'tank' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'outlet', 'Outlet', 'مخرج', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
    if p_include_tank_aux then
      insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
      values
        (p_asset_id, 'overflow', 'Overflow', 'فيض', 'out', 'overflow'),
        (p_asset_id, 'washout', 'Washout', 'تنظيف', 'out', 'washout'),
        (p_asset_id, 'drain', 'Drain', 'صرف', 'out', 'drain'),
        (p_asset_id, 'emergency', 'Emergency', 'طوارئ', 'out', 'emergency'),
        (p_asset_id, 'tanker_transfer', 'Tanker transfer', 'نقل تانكر', 'out', 'tanker_transfer')
      on conflict (asset_id, code) do nothing;
    end if;
  elsif p_asset_type = 'treatment_unit' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'product', 'Product', 'منتج', 'out', 'product'),
      (p_asset_id, 'reject', 'Reject', 'مرفوض', 'out', 'reject')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type in ('filter', 'pump') then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'outlet', 'Outlet', 'مخرج', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type = 'external_source' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values (p_asset_id, 'outlet', 'Outlet', 'مخرج', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type in ('discharge_point', 'consumer') then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type = 'tanker_loading' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'tanker_transfer', 'Tanker transfer', 'نقل تانكر', 'out', 'tanker_transfer')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type = 'junction' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'in_1', 'In 1', 'مدخل 1', 'in', 'inlet'),
      (p_asset_id, 'out_1', 'Out 1', 'مخرج 1', 'out', 'outlet'),
      (p_asset_id, 'out_2', 'Out 2', 'مخرج 2', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
  elsif p_asset_type = 'building_portal' then
    insert into public.site_utility_asset_ports (asset_id, code, name_en, name_ar, direction, port_role)
    values
      (p_asset_id, 'inlet', 'Inlet', 'مدخل', 'in', 'inlet'),
      (p_asset_id, 'outlet', 'Outlet', 'مخرج', 'out', 'outlet')
    on conflict (asset_id, code) do nothing;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- List tanks available for network editor (member sites only).
-- status: not_in_network | in_network_not_in_current_view | in_current_view
-- ---------------------------------------------------------------------------
create or replace function public.list_available_tanks_for_network(
  p_network_id uuid,
  p_revision_id uuid default null,
  p_view_id uuid default null,
  p_site_id uuid default null,
  p_search text default null,
  p_limit integer default 200
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev_id uuid;
  v_view_id uuid;
  v_rows jsonb;
begin
  if not public.can_manage_utility_network(p_network_id) then
    raise exception 'Not allowed to manage this utility network' using errcode = '42501';
  end if;

  if not exists (select 1 from public.site_utility_networks where id = p_network_id) then
    raise exception 'Network not found';
  end if;

  if p_revision_id is not null then
    v_rev_id := p_revision_id;
    if not exists (
      select 1 from public.site_utility_network_revisions
      where id = v_rev_id and network_id = p_network_id
    ) then
      raise exception 'Revision does not belong to network';
    end if;
  else
    select draft_revision_id into v_rev_id
    from public.site_utility_networks where id = p_network_id;
    if v_rev_id is null then
      select id into v_rev_id
      from public.site_utility_network_revisions
      where network_id = p_network_id and status = 'draft'
      order by created_at desc
      limit 1;
    end if;
  end if;

  v_view_id := p_view_id;
  if v_view_id is null then
    select id into v_view_id
    from public.site_utility_network_views
    where network_id = p_network_id and is_default
    limit 1;
  end if;

  if p_site_id is not null and not exists (
    select 1 from public.site_utility_network_members
    where network_id = p_network_id and site_id = p_site_id
  ) then
    raise exception 'Site is not a member of this network';
  end if;

  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.name_en), '[]'::jsonb)
  into v_rows
  from (
    select
      t.id as tank_id,
      t.site_id,
      t.name_en,
      t.name_ar,
      t.is_active,
      a.id as asset_id,
      a.code as asset_code,
      a.service_type,
      a.facility_area_id,
      rn.id as node_id,
      case
        when rn.id is null then 'not_in_network'
        when v_view_id is not null and exists (
          select 1 from public.site_utility_view_nodes vn
          where vn.revision_id = v_rev_id
            and vn.view_id = v_view_id
            and vn.node_id = rn.id
        ) then 'in_current_view'
        when rn.id is not null then 'in_network_not_in_current_view'
        else 'not_in_network'
      end as availability_status
    from public.site_tanks t
    join public.site_utility_network_members mem
      on mem.network_id = p_network_id and mem.site_id = t.site_id
    left join public.site_utility_assets a
      on a.ref_tank_id = t.id and a.status = 'active'
    left join public.site_utility_revision_nodes rn
      on rn.revision_id = v_rev_id and rn.asset_id = a.id
    where t.is_active
      and (p_site_id is null or t.site_id = p_site_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or coalesce(t.name_en, '') ilike '%' || trim(p_search) || '%'
        or coalesce(t.name_ar, '') ilike '%' || trim(p_search) || '%'
        or coalesce(a.code, '') ilike '%' || trim(p_search) || '%'
      )
    order by t.name_en
    limit greatest(1, least(coalesce(p_limit, 200), 1000))
  ) x;

  return jsonb_build_object(
    'network_id', p_network_id,
    'revision_id', v_rev_id,
    'view_id', v_view_id,
    'tanks', coalesce(v_rows, '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Attach existing tank: reuse site_tanks; upsert asset + revision node + view.
-- ---------------------------------------------------------------------------
create or replace function public.attach_existing_tank_to_draft(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_tank_id uuid,
  p_view_id uuid default null,
  p_pos_x double precision default 0,
  p_pos_y double precision default 0,
  p_facility_area_id uuid default null,
  p_include_aux_ports boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev public.site_utility_network_revisions;
  v_tank public.site_tanks;
  v_asset public.site_utility_assets;
  v_node public.site_utility_revision_nodes;
  v_view_node_id uuid;
  v_had_view boolean := false;
  v_created_asset boolean := false;
  v_created_node boolean := false;
  v_code text;
begin
  v_rev := public.utility_check_draft_lock(p_revision_id, p_expected_lock_version);

  select * into v_tank from public.site_tanks where id = p_tank_id;
  if v_tank.id is null then
    raise exception 'Tank not found';
  end if;
  if not coalesce(v_tank.is_active, false) then
    raise exception 'Tank is inactive';
  end if;
  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = v_rev.network_id and site_id = v_tank.site_id
  ) then
    raise exception 'Tank site is not a member of this network';
  end if;

  select * into v_asset
  from public.site_utility_assets
  where ref_tank_id = p_tank_id and status = 'active'
  limit 1;

  if v_asset.id is not null then
    select * into v_node
    from public.site_utility_revision_nodes
    where revision_id = p_revision_id and asset_id = v_asset.id;
  end if;

  if v_node.id is not null and p_view_id is not null then
    select id into v_view_node_id
    from public.site_utility_view_nodes
    where revision_id = p_revision_id
      and view_id = p_view_id
      and node_id = v_node.id;
    v_had_view := v_view_node_id is not null;
  end if;

  if v_node.id is not null
     and p_view_id is not null
     and v_had_view
     and exists (
       select 1 from public.site_utility_view_nodes vn
       where vn.id = v_view_node_id
         and vn.pos_x is not distinct from p_pos_x
         and vn.pos_y is not distinct from p_pos_y
     ) then
    return jsonb_build_object(
      'status', 'already_in_current_view',
      'tank_id', v_tank.id,
      'asset_id', v_asset.id,
      'node_id', v_node.id,
      'view_node_id', v_view_node_id,
      'created_asset', false,
      'created_node', false,
      'lock_version', v_rev.lock_version
    );
  end if;

  v_rev := public.utility_bump_draft_lock(p_revision_id);

  if v_asset.id is null then
    v_code := 'tank-' || substr(v_tank.id::text, 1, 8);
    insert into public.site_utility_assets (
      site_id, facility_area_id, asset_type, name_en, name_ar, code,
      ref_tank_id, created_by, updated_by
    ) values (
      v_tank.site_id, p_facility_area_id, 'tank',
      v_tank.name_en, coalesce(v_tank.name_ar, v_tank.name_en), v_code,
      v_tank.id, v_uid, v_uid
    ) returning * into v_asset;
    v_created_asset := true;
    perform public.utility_default_ports_for_asset(
      v_asset.id, 'tank', coalesce(p_include_aux_ports, true)
    );
  else
    if v_asset.site_id is distinct from v_tank.site_id then
      raise exception 'Existing tank asset site mismatch';
    end if;
    perform public.utility_default_ports_for_asset(
      v_asset.id, 'tank', coalesce(p_include_aux_ports, true)
    );
    if p_facility_area_id is not null
       and v_asset.facility_area_id is distinct from p_facility_area_id then
      update public.site_utility_assets
      set facility_area_id = p_facility_area_id, updated_by = v_uid, updated_at = now()
      where id = v_asset.id
      returning * into v_asset;
    end if;
  end if;

  if v_node.id is null then
    insert into public.site_utility_revision_nodes (revision_id, asset_id)
    values (p_revision_id, v_asset.id)
    returning * into v_node;
    v_created_node := true;
  end if;

  if p_view_id is not null then
    if not exists (
      select 1 from public.site_utility_network_views
      where id = p_view_id and network_id = v_rev.network_id
    ) then
      raise exception 'View does not belong to this network';
    end if;
    insert into public.site_utility_view_nodes (
      revision_id, view_id, node_id, pos_x, pos_y
    ) values (p_revision_id, p_view_id, v_node.id, p_pos_x, p_pos_y)
    on conflict (revision_id, view_id, node_id) do update
      set pos_x = excluded.pos_x,
          pos_y = excluded.pos_y,
          updated_at = now()
    returning id into v_view_node_id;
  end if;

  return jsonb_build_object(
    'status', case
      when v_created_asset or v_created_node then 'attached'
      when p_view_id is not null and not v_had_view then 'view_placement_added'
      when p_view_id is not null then 'view_placement_updated'
      else 'attached'
    end,
    'tank_id', v_tank.id,
    'asset_id', v_asset.id,
    'node_id', v_node.id,
    'view_node_id', v_view_node_id,
    'created_asset', v_created_asset,
    'created_node', v_created_node,
    'ports', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'code', p.code, 'direction', p.direction, 'port_role', p.port_role
      ) order by p.code), '[]'::jsonb)
      from public.site_utility_asset_ports p where p.asset_id = v_asset.id
    ),
    'lock_version', v_rev.lock_version
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Atomic create new tank in draft (+ optional view placement).
-- ---------------------------------------------------------------------------
create or replace function public.create_tank_in_network_draft(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_site_id uuid,
  p_name_en text,
  p_name_ar text,
  p_code text default null,
  p_service_type text default null,
  p_facility_area_id uuid default null,
  p_include_aux_ports boolean default true,
  p_view_id uuid default null,
  p_pos_x double precision default 0,
  p_pos_y double precision default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev public.site_utility_network_revisions;
  v_tank public.site_tanks;
  v_asset public.site_utility_assets;
  v_node public.site_utility_revision_nodes;
  v_name_en text := trim(p_name_en);
  v_name_ar text := coalesce(nullif(trim(p_name_ar), ''), trim(p_name_en));
  v_code text;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if v_name_en is null or v_name_en = '' then
    raise exception 'Tank English name is required';
  end if;

  if not exists (
    select 1 from public.site_utility_network_members
    where network_id = v_rev.network_id and site_id = p_site_id
  ) then
    raise exception 'Asset site is not a member of this network';
  end if;
  if not public.can_manage_site_meters(p_site_id) then
    raise exception 'Not allowed to manage tanks for site' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.site_tanks
    where site_id = p_site_id and name_en = v_name_en
  ) then
    raise exception 'Tank name already exists for site';
  end if;

  insert into public.site_tanks (site_id, name_en, name_ar, is_active)
  values (p_site_id, v_name_en, v_name_ar, true)
  returning * into v_tank;

  v_code := coalesce(nullif(trim(p_code), ''), 'tank-' || substr(v_tank.id::text, 1, 8));

  insert into public.site_utility_assets (
    site_id, facility_area_id, asset_type, service_type, name_en, name_ar,
    code, ref_tank_id, created_by, updated_by
  ) values (
    p_site_id, p_facility_area_id, 'tank', p_service_type,
    v_tank.name_en, coalesce(v_tank.name_ar, v_tank.name_en), v_code,
    v_tank.id, v_uid, v_uid
  ) returning * into v_asset;

  perform public.utility_default_ports_for_asset(
    v_asset.id, 'tank', coalesce(p_include_aux_ports, true)
  );

  insert into public.site_utility_revision_nodes (revision_id, asset_id)
  values (p_revision_id, v_asset.id)
  returning * into v_node;

  if p_view_id is not null then
    if not exists (
      select 1 from public.site_utility_network_views
      where id = p_view_id and network_id = v_rev.network_id
    ) then
      raise exception 'View does not belong to this network';
    end if;
    insert into public.site_utility_view_nodes (
      revision_id, view_id, node_id, pos_x, pos_y
    ) values (p_revision_id, p_view_id, v_node.id, p_pos_x, p_pos_y);
  end if;

  return jsonb_build_object(
    'status', 'created',
    'tank_id', v_tank.id,
    'asset_id', v_asset.id,
    'node_id', v_node.id,
    'ports', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'code', p.code, 'direction', p.direction, 'port_role', p.port_role
      ) order by p.code), '[]'::jsonb)
      from public.site_utility_asset_ports p where p.asset_id = v_asset.id
    ),
    'lock_version', v_rev.lock_version
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Update asset metadata (must be in the draft revision).
-- ---------------------------------------------------------------------------
create or replace function public.update_asset(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_asset_id uuid,
  p_code text default null,
  p_name_en text default null,
  p_name_ar text default null,
  p_service_type text default null,
  p_facility_area_id uuid default null,
  p_properties jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev public.site_utility_network_revisions;
  v_asset public.site_utility_assets;
  v_code text;
  v_name_en text;
  v_name_ar text;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if not exists (
    select 1 from public.site_utility_revision_nodes
    where revision_id = p_revision_id and asset_id = p_asset_id
  ) then
    raise exception 'Asset is not in this revision';
  end if;

  select * into v_asset from public.site_utility_assets where id = p_asset_id;
  if v_asset.id is null then
    raise exception 'Asset not found';
  end if;
  if v_asset.status = 'archived' then
    raise exception 'Cannot update archived asset';
  end if;

  v_code := coalesce(nullif(trim(p_code), ''), v_asset.code);
  v_name_en := coalesce(nullif(trim(p_name_en), ''), v_asset.name_en);
  v_name_ar := case
    when p_name_ar is null then v_asset.name_ar
    when nullif(trim(p_name_ar), '') is null then v_name_en
    else trim(p_name_ar)
  end;

  update public.site_utility_assets
  set
    code = v_code,
    name_en = v_name_en,
    name_ar = v_name_ar,
    service_type = case
      when p_service_type is null then service_type
      when trim(p_service_type) = '' then null
      else trim(p_service_type)
    end,
    facility_area_id = coalesce(p_facility_area_id, facility_area_id),
    properties = coalesce(p_properties, properties),
    updated_by = v_uid,
    updated_at = now()
  where id = p_asset_id
  returning * into v_asset;

  return jsonb_build_object(
    'asset_id', v_asset.id,
    'code', v_asset.code,
    'name_en', v_asset.name_en,
    'name_ar', v_asset.name_ar,
    'service_type', v_asset.service_type,
    'facility_area_id', v_asset.facility_area_id,
    'properties', v_asset.properties,
    'lock_version', v_rev.lock_version
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Port CRUD
-- ---------------------------------------------------------------------------
create or replace function public.add_asset_port(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_asset_id uuid,
  p_code text,
  p_name_en text,
  p_name_ar text,
  p_direction text,
  p_port_role text,
  p_properties jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_port public.site_utility_asset_ports;
  v_code text := trim(p_code);
  v_name_en text := trim(p_name_en);
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if not exists (
    select 1 from public.site_utility_revision_nodes
    where revision_id = p_revision_id and asset_id = p_asset_id
  ) then
    raise exception 'Asset is not in this revision';
  end if;
  if v_code is null or v_code = '' then
    raise exception 'Port code is required';
  end if;
  if v_name_en is null or v_name_en = '' then
    raise exception 'Port English name is required';
  end if;

  insert into public.site_utility_asset_ports (
    asset_id, code, name_en, name_ar, direction, port_role, properties
  ) values (
    p_asset_id, v_code, v_name_en,
    coalesce(nullif(trim(p_name_ar), ''), v_name_en),
    p_direction, p_port_role, coalesce(p_properties, '{}'::jsonb)
  ) returning * into v_port;

  return jsonb_build_object(
    'port_id', v_port.id,
    'asset_id', v_port.asset_id,
    'code', v_port.code,
    'direction', v_port.direction,
    'port_role', v_port.port_role,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.update_asset_port(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_port_id uuid,
  p_code text default null,
  p_name_en text default null,
  p_name_ar text default null,
  p_direction text default null,
  p_port_role text default null,
  p_properties jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_port public.site_utility_asset_ports;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  select p.* into v_port
  from public.site_utility_asset_ports p
  join public.site_utility_revision_nodes n
    on n.asset_id = p.asset_id and n.revision_id = p_revision_id
  where p.id = p_port_id;

  if v_port.id is null then
    raise exception 'Port not found in this revision';
  end if;

  update public.site_utility_asset_ports
  set
    code = coalesce(nullif(trim(p_code), ''), code),
    name_en = coalesce(nullif(trim(p_name_en), ''), name_en),
    name_ar = case
      when p_name_ar is null then name_ar
      when nullif(trim(p_name_ar), '') is null then coalesce(nullif(trim(p_name_en), ''), name_en)
      else trim(p_name_ar)
    end,
    direction = coalesce(p_direction, direction),
    port_role = coalesce(p_port_role, port_role),
    properties = coalesce(p_properties, properties),
    updated_at = now()
  where id = p_port_id
  returning * into v_port;

  return jsonb_build_object(
    'port_id', v_port.id,
    'asset_id', v_port.asset_id,
    'code', v_port.code,
    'direction', v_port.direction,
    'port_role', v_port.port_role,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.remove_asset_port(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_port_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_port public.site_utility_asset_ports;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  select p.* into v_port
  from public.site_utility_asset_ports p
  join public.site_utility_revision_nodes n
    on n.asset_id = p.asset_id and n.revision_id = p_revision_id
  where p.id = p_port_id;

  if v_port.id is null then
    raise exception 'Port not found in this revision';
  end if;

  if exists (
    select 1 from public.site_utility_revision_connections c
    where c.from_port_id = p_port_id or c.to_port_id = p_port_id
  ) then
    raise exception 'Cannot remove port that still has connections';
  end if;

  delete from public.site_utility_asset_ports where id = p_port_id;

  return jsonb_build_object(
    'removed', true,
    'port_id', p_port_id,
    'lock_version', v_rev.lock_version
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Update connection fields (refuse silent break of synced legacy).
-- ---------------------------------------------------------------------------
create or replace function public.update_connection(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_connection_id uuid,
  p_connection_kind text default null,
  p_water_type text default null,
  p_transport_mode text default null,
  p_operating_mode text default null,
  p_priority integer default null,
  p_normally_open boolean default null,
  p_properties jsonb default null,
  p_legacy_sync_status text default null,
  p_allow_break_legacy_sync boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_conn public.site_utility_revision_connections;
  v_new_kind text;
  v_new_sync text;
  v_breaking boolean := false;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  select * into v_conn
  from public.site_utility_revision_connections
  where id = p_connection_id and revision_id = p_revision_id;

  if v_conn.id is null then
    raise exception 'Connection not found';
  end if;

  v_new_kind := coalesce(p_connection_kind, v_conn.connection_kind);
  v_new_sync := coalesce(p_legacy_sync_status, v_conn.legacy_sync_status);

  if v_conn.legacy_sync_status = 'synced' then
    if v_new_kind is distinct from v_conn.connection_kind then
      v_breaking := true;
    end if;
    if v_new_sync is distinct from 'synced' then
      v_breaking := true;
    end if;
    if p_water_type is not null and p_water_type is distinct from v_conn.water_type then
      v_breaking := true;
    end if;
    if v_breaking and not coalesce(p_allow_break_legacy_sync, false) then
      raise exception
        'Refusing to break synced legacy connection without allow_break_legacy_sync=true'
        using errcode = '23514';
    end if;
  end if;

  update public.site_utility_revision_connections
  set
    connection_kind = v_new_kind,
    water_type = case
      when p_water_type is null then water_type
      when trim(p_water_type) = '' then null
      else trim(p_water_type)
    end,
    transport_mode = coalesce(p_transport_mode, transport_mode),
    operating_mode = coalesce(p_operating_mode, operating_mode),
    priority = coalesce(p_priority, priority),
    normally_open = coalesce(p_normally_open, normally_open),
    properties = coalesce(p_properties, properties),
    legacy_sync_status = v_new_sync,
    updated_at = now()
  where id = p_connection_id
  returning * into v_conn;

  return jsonb_build_object(
    'connection_id', v_conn.id,
    'connection_kind', v_conn.connection_kind,
    'water_type', v_conn.water_type,
    'transport_mode', v_conn.transport_mode,
    'operating_mode', v_conn.operating_mode,
    'priority', v_conn.priority,
    'normally_open', v_conn.normally_open,
    'legacy_sync_status', v_conn.legacy_sync_status,
    'is_consumptive', v_conn.is_consumptive,
    'lock_version', v_rev.lock_version
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Remove placement from a view only (asset/node remain).
-- ---------------------------------------------------------------------------
create or replace function public.remove_asset_from_view(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_view_id uuid,
  p_node_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_deleted int;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if not exists (
    select 1 from public.site_utility_network_views
    where id = p_view_id and network_id = v_rev.network_id
  ) then
    raise exception 'View does not belong to this network';
  end if;
  if not exists (
    select 1 from public.site_utility_revision_nodes
    where id = p_node_id and revision_id = p_revision_id
  ) then
    raise exception 'Node is not in this revision';
  end if;

  delete from public.site_utility_view_nodes
  where revision_id = p_revision_id
    and view_id = p_view_id
    and node_id = p_node_id;
  get diagnostics v_deleted = row_count;

  return jsonb_build_object(
    'removed', v_deleted > 0,
    'view_id', p_view_id,
    'node_id', p_node_id,
    'lock_version', v_rev.lock_version
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Remove asset from revision (refuse if connections). Soft-archive generics.
-- Never deletes meters / site_tanks rows.
-- ---------------------------------------------------------------------------
create or replace function public.remove_asset_from_revision(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_node_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.utility_require_auth();
  v_rev public.site_utility_network_revisions;
  v_node public.site_utility_revision_nodes;
  v_asset public.site_utility_assets;
  v_archived boolean := false;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  select * into v_node
  from public.site_utility_revision_nodes
  where id = p_node_id and revision_id = p_revision_id;

  if v_node.id is null then
    raise exception 'Node is not in this revision';
  end if;

  select * into v_asset from public.site_utility_assets where id = v_node.asset_id;

  if exists (
    select 1 from public.site_utility_revision_connections c
    where c.revision_id = p_revision_id
      and (c.from_node_id = p_node_id or c.to_node_id = p_node_id)
  ) then
    raise exception 'Cannot remove asset from revision while connections exist';
  end if;

  -- Placements cascade via FK on node delete; remove node first.
  delete from public.site_utility_revision_nodes where id = p_node_id;

  -- Soft-archive generic (non meter/tank) assets only.
  if v_asset.asset_type not in ('meter', 'tank')
     and v_asset.ref_meter_id is null
     and v_asset.ref_tank_id is null then
    update public.site_utility_assets
    set status = 'archived', updated_by = v_uid, updated_at = now()
    where id = v_asset.id
      and status = 'active';
    v_archived := found;
  end if;

  return jsonb_build_object(
    'removed', true,
    'node_id', p_node_id,
    'asset_id', v_asset.id,
    'asset_type', v_asset.asset_type,
    'archived_asset', v_archived,
    'lock_version', v_rev.lock_version
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Network view management (caller-provided names; no hard-coded buildings).
-- ---------------------------------------------------------------------------
create or replace function public.create_network_view(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_code text,
  p_name_en text,
  p_name_ar text,
  p_view_kind text,
  p_facility_area_id uuid default null,
  p_sort_order integer default 0,
  p_is_default boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_view public.site_utility_network_views;
  v_code text := trim(p_code);
  v_name_en text := trim(p_name_en);
  v_name_ar text := coalesce(nullif(trim(p_name_ar), ''), trim(p_name_en));
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  if v_code is null or v_code = '' then
    raise exception 'View code is required';
  end if;
  if v_name_en is null or v_name_en = '' then
    raise exception 'View English name is required';
  end if;

  if coalesce(p_is_default, false) then
    update public.site_utility_network_views
    set is_default = false, updated_at = now()
    where network_id = v_rev.network_id and is_default;
  end if;

  insert into public.site_utility_network_views (
    network_id, code, name_en, name_ar, view_kind,
    facility_area_id, sort_order, is_default
  ) values (
    v_rev.network_id, v_code, v_name_en, v_name_ar, p_view_kind,
    p_facility_area_id, coalesce(p_sort_order, 0), coalesce(p_is_default, false)
  ) returning * into v_view;

  return jsonb_build_object(
    'view_id', v_view.id,
    'network_id', v_view.network_id,
    'code', v_view.code,
    'name_en', v_view.name_en,
    'view_kind', v_view.view_kind,
    'is_default', v_view.is_default,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.update_network_view(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_view_id uuid,
  p_code text default null,
  p_name_en text default null,
  p_name_ar text default null,
  p_view_kind text default null,
  p_facility_area_id uuid default null,
  p_sort_order integer default null,
  p_is_default boolean default null,
  p_clear_facility_area boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_view public.site_utility_network_views;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  select * into v_view
  from public.site_utility_network_views
  where id = p_view_id and network_id = v_rev.network_id;

  if v_view.id is null then
    raise exception 'View does not belong to this network';
  end if;

  if coalesce(p_is_default, false) and not v_view.is_default then
    update public.site_utility_network_views
    set is_default = false, updated_at = now()
    where network_id = v_rev.network_id and is_default and id is distinct from p_view_id;
  end if;

  if p_is_default is false and v_view.is_default then
    raise exception 'Cannot unset default without promoting another view';
  end if;

  update public.site_utility_network_views
  set
    code = coalesce(nullif(trim(p_code), ''), code),
    name_en = coalesce(nullif(trim(p_name_en), ''), name_en),
    name_ar = case
      when p_name_ar is null then name_ar
      when nullif(trim(p_name_ar), '') is null then coalesce(nullif(trim(p_name_en), ''), name_en)
      else trim(p_name_ar)
    end,
    view_kind = coalesce(p_view_kind, view_kind),
    facility_area_id = case
      when p_clear_facility_area then null
      when p_facility_area_id is not null then p_facility_area_id
      else facility_area_id
    end,
    sort_order = coalesce(p_sort_order, sort_order),
    is_default = coalesce(p_is_default, is_default),
    updated_at = now()
  where id = p_view_id
  returning * into v_view;

  return jsonb_build_object(
    'view_id', v_view.id,
    'code', v_view.code,
    'name_en', v_view.name_en,
    'view_kind', v_view.view_kind,
    'facility_area_id', v_view.facility_area_id,
    'is_default', v_view.is_default,
    'lock_version', v_rev.lock_version
  );
end;
$$;

create or replace function public.delete_network_view(
  p_revision_id uuid,
  p_expected_lock_version integer,
  p_view_id uuid,
  p_replacement_default_view_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rev public.site_utility_network_revisions;
  v_view public.site_utility_network_views;
  v_replacement public.site_utility_network_views;
begin
  v_rev := public.utility_assert_draft_lock(p_revision_id, p_expected_lock_version);

  select * into v_view
  from public.site_utility_network_views
  where id = p_view_id and network_id = v_rev.network_id;

  if v_view.id is null then
    raise exception 'View does not belong to this network';
  end if;

  if v_view.is_default then
    if p_replacement_default_view_id is null then
      raise exception 'Cannot delete default campus/view without a replacement';
    end if;
    if p_replacement_default_view_id = p_view_id then
      raise exception 'Replacement default view must be different';
    end if;

    select * into v_replacement
    from public.site_utility_network_views
    where id = p_replacement_default_view_id and network_id = v_rev.network_id;

    if v_replacement.id is null then
      raise exception 'Replacement default view does not belong to this network';
    end if;

    update public.site_utility_network_views
    set is_default = false, updated_at = now()
    where id = p_view_id;

    update public.site_utility_network_views
    set is_default = true, updated_at = now()
    where id = p_replacement_default_view_id;
  end if;

  -- Placements for this view cascade via FK; assets/nodes are preserved.
  delete from public.site_utility_network_views where id = p_view_id;

  return jsonb_build_object(
    'deleted', true,
    'view_id', p_view_id,
    'new_default_view_id', p_replacement_default_view_id,
    'lock_version', v_rev.lock_version
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
revoke all on function public.list_available_tanks_for_network(uuid, uuid, uuid, uuid, text, integer) from public;
revoke all on function public.attach_existing_tank_to_draft(uuid, integer, uuid, uuid, double precision, double precision, uuid, boolean) from public;
revoke all on function public.create_tank_in_network_draft(uuid, integer, uuid, text, text, text, text, uuid, boolean, uuid, double precision, double precision) from public;
revoke all on function public.update_asset(uuid, integer, uuid, text, text, text, text, uuid, jsonb) from public;
revoke all on function public.add_asset_port(uuid, integer, uuid, text, text, text, text, text, jsonb) from public;
revoke all on function public.update_asset_port(uuid, integer, uuid, text, text, text, text, text, jsonb) from public;
revoke all on function public.remove_asset_port(uuid, integer, uuid) from public;
revoke all on function public.update_connection(uuid, integer, uuid, text, text, text, text, integer, boolean, jsonb, text, boolean) from public;
revoke all on function public.remove_asset_from_view(uuid, integer, uuid, uuid) from public;
revoke all on function public.remove_asset_from_revision(uuid, integer, uuid) from public;
revoke all on function public.create_network_view(uuid, integer, text, text, text, text, uuid, integer, boolean) from public;
revoke all on function public.update_network_view(uuid, integer, uuid, text, text, text, text, uuid, integer, boolean, boolean) from public;
revoke all on function public.delete_network_view(uuid, integer, uuid, uuid) from public;

grant execute on function public.list_available_tanks_for_network(uuid, uuid, uuid, uuid, text, integer) to authenticated;
grant execute on function public.attach_existing_tank_to_draft(uuid, integer, uuid, uuid, double precision, double precision, uuid, boolean) to authenticated;
grant execute on function public.create_tank_in_network_draft(uuid, integer, uuid, text, text, text, text, uuid, boolean, uuid, double precision, double precision) to authenticated;
grant execute on function public.update_asset(uuid, integer, uuid, text, text, text, text, uuid, jsonb) to authenticated;
grant execute on function public.add_asset_port(uuid, integer, uuid, text, text, text, text, text, jsonb) to authenticated;
grant execute on function public.update_asset_port(uuid, integer, uuid, text, text, text, text, text, jsonb) to authenticated;
grant execute on function public.remove_asset_port(uuid, integer, uuid) to authenticated;
grant execute on function public.update_connection(uuid, integer, uuid, text, text, text, text, integer, boolean, jsonb, text, boolean) to authenticated;
grant execute on function public.remove_asset_from_view(uuid, integer, uuid, uuid) to authenticated;
grant execute on function public.remove_asset_from_revision(uuid, integer, uuid) to authenticated;
grant execute on function public.create_network_view(uuid, integer, text, text, text, text, uuid, integer, boolean) to authenticated;
grant execute on function public.update_network_view(uuid, integer, uuid, text, text, text, text, uuid, integer, boolean, boolean) to authenticated;
grant execute on function public.delete_network_view(uuid, integer, uuid, uuid) to authenticated;

comment on function public.list_available_tanks_for_network is
  'Editor tank picker: site_tanks on member sites with availability_status for draft+view.';
comment on function public.attach_existing_tank_to_draft is
  'Place an existing site_tanks row into draft (reuse asset/node; already_in_current_view no lock bump).';
comment on function public.create_tank_in_network_draft is
  'Atomic new site_tanks + tank asset + default ports + node + optional view placement.';
comment on function public.update_asset is
  'Update asset metadata on a draft revision (lock-aware).';
comment on function public.remove_asset_from_revision is
  'Detach node from draft; refuse if connections; soft-archive generic assets; never delete meters/tanks.';
comment on function public.delete_network_view is
  'Delete a network view; refuses default without replacement_default_view_id.';
