-- 047: Force-delete meters must clear reading_audit_logs (ON DELETE RESTRICT)
-- and fully clean utility-network assets before deleting the meter row.

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
  -- Allow cleanup driven by admin_force_delete_meter (session GUC).
  if current_setting('app.force_delete_meter', true) = '1' then
    if tg_op = 'DELETE' then
      return old;
    end if;
  end if;

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

create or replace function public.admin_force_delete_meter(p_meter_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_site_id uuid;
  v_asset_ids uuid[];
begin
  select site_id into v_site_id from public.meters where id = p_meter_id;
  if v_site_id is null then
    return;
  end if;

  if not (public.is_super_admin() or public.can_manage_site(v_site_id)) then
    raise exception 'Not allowed to force-delete this meter';
  end if;

  perform set_config('app.force_delete_meter', '1', true);

  select coalesce(array_agg(id), '{}') into v_asset_ids
  from public.site_utility_assets
  where ref_meter_id = p_meter_id;

  if cardinality(v_asset_ids) > 0 then
    delete from public.site_utility_revision_connections c
    using public.site_utility_revision_nodes n
    where (c.from_node_id = n.id or c.to_node_id = n.id)
      and n.asset_id = any (v_asset_ids);

    delete from public.site_utility_view_nodes vn
    using public.site_utility_revision_nodes n
    where vn.node_id = n.id
      and n.asset_id = any (v_asset_ids);

    delete from public.site_utility_revision_nodes
    where asset_id = any (v_asset_ids);

    delete from public.site_utility_assets
    where id = any (v_asset_ids);
  end if;

  -- Legacy 031 graph (if present)
  if to_regclass('public.site_network_edges') is not null then
    execute $q$
      delete from public.site_network_edges e
      using public.site_network_nodes n
      where (e.from_node_id = n.id or e.to_node_id = n.id)
        and n.ref_meter_id = $1
    $q$ using p_meter_id;
  end if;
  if to_regclass('public.site_network_nodes') is not null then
    execute 'delete from public.site_network_nodes where ref_meter_id = $1'
      using p_meter_id;
  end if;

  update public.meters
  set parent_meter_id = null,
      level = 'main'
  where parent_meter_id = p_meter_id;

  delete from public.cop_group_btu_meters where meter_id = p_meter_id;
  delete from public.cop_group_electricity_meters where meter_id = p_meter_id;

  if to_regclass('public.reading_corrections') is not null then
    execute 'delete from public.reading_corrections where meter_id = $1'
      using p_meter_id;
  end if;

  -- Audit logs RESTRICT meter delete even when readings are already gone.
  delete from public.reading_audit_logs where meter_id = p_meter_id;

  delete from public.meter_readings where meter_id = p_meter_id;
  delete from public.meters where id = p_meter_id;
end;
$$;

revoke all on function public.admin_force_delete_meter(uuid) from public;
grant execute on function public.admin_force_delete_meter(uuid) to authenticated;

comment on function public.admin_force_delete_meter(uuid) is
  'Force-delete meter for super_admin or site managers, including audit logs and utility-network cleanup.';
