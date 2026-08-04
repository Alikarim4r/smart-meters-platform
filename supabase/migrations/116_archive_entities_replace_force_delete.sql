-- =============================================================================
-- 116: Replace destructive force-delete RPCs with reversible archival.
--
-- Existing rows, readings, audit history, relationships, and utility-network
-- revisions are preserved. Legacy RPC names remain as safe compatibility
-- wrappers so older clients cannot invoke the former destructive behavior.
-- =============================================================================

alter table public.organizations
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid
    references public.profiles (id) on delete set null,
  add column if not exists archive_reason text;

alter table public.zones
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid
    references public.profiles (id) on delete set null,
  add column if not exists archive_reason text;

alter table public.sites
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid
    references public.profiles (id) on delete set null,
  add column if not exists archive_reason text;

alter table public.meters
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid
    references public.profiles (id) on delete set null,
  add column if not exists archive_reason text;

alter table public.site_utility_networks
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid
    references public.profiles (id) on delete set null,
  add column if not exists archive_reason text;

create table if not exists public.entity_archive_audit_logs (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  organization_id uuid references public.organizations (id) on delete set null,
  site_id uuid references public.sites (id) on delete set null,
  archived_by uuid references public.profiles (id) on delete set null,
  archived_at timestamptz not null default now(),
  reason text not null,
  metadata jsonb not null default '{}'::jsonb,
  constraint entity_archive_audit_entity_type_check check (
    entity_type in (
      'organization',
      'zone',
      'site',
      'meter',
      'utility_network'
    )
  ),
  constraint entity_archive_audit_reason_check
    check (char_length(trim(reason)) >= 5)
);

create index if not exists entity_archive_audit_entity_idx
  on public.entity_archive_audit_logs (entity_type, entity_id);
create index if not exists entity_archive_audit_site_idx
  on public.entity_archive_audit_logs (site_id, archived_at desc)
  where site_id is not null;
create index if not exists entity_archive_audit_org_idx
  on public.entity_archive_audit_logs (organization_id, archived_at desc)
  where organization_id is not null;

alter table public.entity_archive_audit_logs enable row level security;
revoke insert, update, delete on public.entity_archive_audit_logs
  from anon, authenticated;
grant select on public.entity_archive_audit_logs to authenticated;

create policy "entity_archive_audit_logs_select"
  on public.entity_archive_audit_logs for select
  to authenticated
  using (
    public.is_super_admin()
    or public.is_platform_owner()
    or (
      site_id is not null
      and public.can_manage_site(site_id)
    )
  );

-- Reactivation through the existing Admin forms clears archive metadata while
-- the immutable archive audit row remains available.
create or replace function public.clear_archive_metadata_on_reactivate()
returns trigger
language plpgsql
as $$
begin
  if new.is_active = true and old.is_active = false then
    new.archived_at := null;
    new.archived_by := null;
    new.archive_reason := null;
  end if;
  return new;
end;
$$;

drop trigger if exists organizations_clear_archive_on_reactivate
  on public.organizations;
create trigger organizations_clear_archive_on_reactivate
  before update of is_active on public.organizations
  for each row execute function public.clear_archive_metadata_on_reactivate();

drop trigger if exists zones_clear_archive_on_reactivate on public.zones;
create trigger zones_clear_archive_on_reactivate
  before update of is_active on public.zones
  for each row execute function public.clear_archive_metadata_on_reactivate();

drop trigger if exists sites_clear_archive_on_reactivate on public.sites;
create trigger sites_clear_archive_on_reactivate
  before update of is_active on public.sites
  for each row execute function public.clear_archive_metadata_on_reactivate();

drop trigger if exists meters_clear_archive_on_reactivate on public.meters;
create trigger meters_clear_archive_on_reactivate
  before update of is_active on public.meters
  for each row execute function public.clear_archive_metadata_on_reactivate();

drop trigger if exists utility_networks_clear_archive_on_reactivate
  on public.site_utility_networks;
create trigger utility_networks_clear_archive_on_reactivate
  before update of is_active on public.site_utility_networks
  for each row execute function public.clear_archive_metadata_on_reactivate();

revoke all on function public.clear_archive_metadata_on_reactivate()
  from public, anon, authenticated;

create or replace function public.admin_archive_meter(
  p_meter_id uuid,
  p_reason text default 'Archived from Admin app'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_site_id uuid;
  v_organization_id uuid;
  v_reason text := trim(coalesce(p_reason, ''));
  v_affected integer;
begin
  if char_length(v_reason) < 5 then
    raise exception 'Archive reason must contain at least 5 characters';
  end if;

  select m.site_id, s.organization_id
  into v_site_id, v_organization_id
  from public.meters m
  join public.sites s on s.id = m.site_id
  where m.id = p_meter_id;

  if not found then
    return;
  end if;

  if not (
    public.is_super_admin()
    or public.is_platform_owner()
    or public.can_manage_site(v_site_id)
  ) then
    raise exception 'Not allowed to archive this meter';
  end if;

  with recursive meter_tree as (
    select id from public.meters where id = p_meter_id
    union all
    select child.id
    from public.meters child
    join meter_tree parent on child.parent_meter_id = parent.id
  )
  update public.meters m
  set is_active = false,
      include_in_dashboard = false,
      archived_at = now(),
      archived_by = auth.uid(),
      archive_reason = v_reason
  where m.id in (select id from meter_tree);

  get diagnostics v_affected = row_count;

  insert into public.entity_archive_audit_logs (
    entity_type,
    entity_id,
    organization_id,
    site_id,
    archived_by,
    reason,
    metadata
  ) values (
    'meter',
    p_meter_id,
    v_organization_id,
    v_site_id,
    auth.uid(),
    v_reason,
    jsonb_build_object('affected_meter_count', v_affected)
  );
end;
$$;

create or replace function public.admin_archive_site(
  p_site_id uuid,
  p_reason text default 'Archived from Admin app'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_organization_id uuid;
  v_reason text := trim(coalesce(p_reason, ''));
  v_affected integer;
begin
  if char_length(v_reason) < 5 then
    raise exception 'Archive reason must contain at least 5 characters';
  end if;

  select organization_id into v_organization_id
  from public.sites
  where id = p_site_id;

  if not found then
    return;
  end if;

  if not (
    public.is_super_admin()
    or public.is_platform_owner()
    or public.can_manage_site(p_site_id)
  ) then
    raise exception 'Not allowed to archive this site';
  end if;

  update public.meters
  set is_active = false,
      include_in_dashboard = false,
      archived_at = now(),
      archived_by = auth.uid(),
      archive_reason = v_reason
  where site_id = p_site_id;

  get diagnostics v_affected = row_count;

  update public.sites
  set is_active = false,
      archived_at = now(),
      archived_by = auth.uid(),
      archive_reason = v_reason
  where id = p_site_id;

  insert into public.entity_archive_audit_logs (
    entity_type,
    entity_id,
    organization_id,
    site_id,
    archived_by,
    reason,
    metadata
  ) values (
    'site',
    p_site_id,
    v_organization_id,
    p_site_id,
    auth.uid(),
    v_reason,
    jsonb_build_object('affected_meter_count', v_affected)
  );
end;
$$;

create or replace function public.admin_archive_zone(
  p_zone_id uuid,
  p_reason text default 'Archived from Admin app'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_organization_id uuid;
  v_reason text := trim(coalesce(p_reason, ''));
  v_affected integer;
begin
  if char_length(v_reason) < 5 then
    raise exception 'Archive reason must contain at least 5 characters';
  end if;

  select organization_id into v_organization_id
  from public.zones
  where id = p_zone_id;

  if not found then
    return;
  end if;

  if not (public.is_super_admin() or public.is_platform_owner()) then
    raise exception 'Only super_admin can archive zones';
  end if;

  with recursive zone_tree as (
    select id from public.zones where id = p_zone_id
    union all
    select child.id
    from public.zones child
    join zone_tree parent on child.parent_zone_id = parent.id
  )
  update public.zones z
  set is_active = false,
      archived_at = now(),
      archived_by = auth.uid(),
      archive_reason = v_reason
  where z.id in (select id from zone_tree);

  get diagnostics v_affected = row_count;

  insert into public.entity_archive_audit_logs (
    entity_type,
    entity_id,
    organization_id,
    archived_by,
    reason,
    metadata
  ) values (
    'zone',
    p_zone_id,
    v_organization_id,
    auth.uid(),
    v_reason,
    jsonb_build_object('affected_zone_count', v_affected)
  );
end;
$$;

create or replace function public.admin_archive_organization(
  p_organization_id uuid,
  p_reason text default 'Archived from Admin app'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := trim(coalesce(p_reason, ''));
  v_site_count integer;
  v_meter_count integer;
  v_zone_count integer;
begin
  if char_length(v_reason) < 5 then
    raise exception 'Archive reason must contain at least 5 characters';
  end if;

  if not exists (
    select 1 from public.organizations where id = p_organization_id
  ) then
    return;
  end if;

  if not (public.is_super_admin() or public.is_platform_owner()) then
    raise exception 'Only super_admin can archive organizations';
  end if;

  update public.meters m
  set is_active = false,
      include_in_dashboard = false,
      archived_at = now(),
      archived_by = auth.uid(),
      archive_reason = v_reason
  from public.sites s
  where m.site_id = s.id
    and s.organization_id = p_organization_id;

  get diagnostics v_meter_count = row_count;

  update public.sites
  set is_active = false,
      archived_at = now(),
      archived_by = auth.uid(),
      archive_reason = v_reason
  where organization_id = p_organization_id;

  get diagnostics v_site_count = row_count;

  update public.zones
  set is_active = false,
      archived_at = now(),
      archived_by = auth.uid(),
      archive_reason = v_reason
  where organization_id = p_organization_id;

  get diagnostics v_zone_count = row_count;

  update public.organizations
  set is_active = false,
      archived_at = now(),
      archived_by = auth.uid(),
      archive_reason = v_reason
  where id = p_organization_id;

  insert into public.entity_archive_audit_logs (
    entity_type,
    entity_id,
    organization_id,
    archived_by,
    reason,
    metadata
  ) values (
    'organization',
    p_organization_id,
    p_organization_id,
    auth.uid(),
    v_reason,
    jsonb_build_object(
      'affected_site_count', v_site_count,
      'affected_meter_count', v_meter_count,
      'affected_zone_count', v_zone_count
    )
  );
end;
$$;

create or replace function public.admin_archive_utility_network(
  p_network_id uuid,
  p_reason text default 'Archived from Admin app'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := trim(coalesce(p_reason, ''));
  v_organization_id uuid;
  v_site_id uuid;
begin
  if char_length(v_reason) < 5 then
    raise exception 'Archive reason must contain at least 5 characters';
  end if;

  select s.organization_id, s.id
  into v_organization_id, v_site_id
  from public.site_utility_network_members member
  join public.sites s on s.id = member.site_id
  where member.network_id = p_network_id
  order by s.id
  limit 1;

  if not exists (
    select 1 from public.site_utility_networks where id = p_network_id
  ) then
    return;
  end if;

  if not (
    public.is_super_admin()
    or public.is_platform_owner()
    or public.can_manage_utility_network(p_network_id)
  ) then
    raise exception 'Not allowed to archive this utility network';
  end if;

  update public.site_utility_networks
  set is_active = false,
      archived_at = now(),
      archived_by = auth.uid(),
      archive_reason = v_reason
  where id = p_network_id;

  insert into public.entity_archive_audit_logs (
    entity_type,
    entity_id,
    organization_id,
    site_id,
    archived_by,
    reason
  ) values (
    'utility_network',
    p_network_id,
    v_organization_id,
    v_site_id,
    auth.uid(),
    v_reason
  );
end;
$$;

revoke all on function public.admin_archive_meter(uuid, text) from public;
revoke all on function public.admin_archive_site(uuid, text) from public;
revoke all on function public.admin_archive_zone(uuid, text) from public;
revoke all on function public.admin_archive_organization(uuid, text) from public;
revoke all on function public.admin_archive_utility_network(uuid, text)
  from public;
grant execute on function public.admin_archive_meter(uuid, text)
  to authenticated;
grant execute on function public.admin_archive_site(uuid, text)
  to authenticated;
grant execute on function public.admin_archive_zone(uuid, text)
  to authenticated;
grant execute on function public.admin_archive_organization(uuid, text)
  to authenticated;
grant execute on function public.admin_archive_utility_network(uuid, text)
  to authenticated;

-- Safe compatibility wrappers: despite their legacy names, these never delete.
create or replace function public.admin_force_delete_meter(p_meter_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.admin_archive_meter(
    p_meter_id,
    'Legacy force-delete request converted to archive'
  );
end;
$$;

create or replace function public.admin_force_delete_site(p_site_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.admin_archive_site(
    p_site_id,
    'Legacy force-delete request converted to archive'
  );
end;
$$;

create or replace function public.admin_force_delete_zone(p_zone_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.admin_archive_zone(
    p_zone_id,
    'Legacy force-delete request converted to archive'
  );
end;
$$;

create or replace function public.admin_force_delete_organization(
  p_organization_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.admin_archive_organization(
    p_organization_id,
    'Legacy force-delete request converted to archive'
  );
end;
$$;

create or replace function public.admin_force_delete_utility_network(
  p_network_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.admin_archive_utility_network(
    p_network_id,
    'Legacy force-delete request converted to archive'
  );
end;
$$;

revoke all on function public.admin_force_delete_meter(uuid) from public;
revoke all on function public.admin_force_delete_site(uuid) from public;
revoke all on function public.admin_force_delete_zone(uuid) from public;
revoke all on function public.admin_force_delete_organization(uuid) from public;
revoke all on function public.admin_force_delete_utility_network(uuid)
  from public;
grant execute on function public.admin_force_delete_meter(uuid)
  to authenticated;
grant execute on function public.admin_force_delete_site(uuid)
  to authenticated;
grant execute on function public.admin_force_delete_zone(uuid)
  to authenticated;
grant execute on function public.admin_force_delete_organization(uuid)
  to authenticated;
grant execute on function public.admin_force_delete_utility_network(uuid)
  to authenticated;

comment on function public.admin_force_delete_meter(uuid) is
  'Compatibility wrapper: archives without deleting readings or audit history.';
comment on function public.admin_force_delete_site(uuid) is
  'Compatibility wrapper: archives site/meters without deleting data.';
comment on function public.admin_force_delete_zone(uuid) is
  'Compatibility wrapper: archives the zone tree without deleting data.';
comment on function public.admin_force_delete_organization(uuid) is
  'Compatibility wrapper: archives the organization hierarchy without deleting data.';
comment on function public.admin_force_delete_utility_network(uuid) is
  'Compatibility wrapper: archives the utility network and preserves revisions.';
