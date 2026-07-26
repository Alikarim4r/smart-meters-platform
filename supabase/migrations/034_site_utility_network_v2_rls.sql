-- =============================================================================
-- Migration: 034_site_utility_network_v2_rls.sql
-- Permission helpers + RLS for utility network v2.
-- Edit: super_admin OR can_manage_site_meters for EVERY member site.
-- Full snapshot read: has_site_access for EVERY member site (no partial leak).
-- Draft read/write: manage only. Published content readable with full-member access.
-- =============================================================================

create or replace function public.can_manage_utility_network(p_network_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or (
      exists (
        select 1 from public.site_utility_network_members m
        where m.network_id = p_network_id
      )
      and not exists (
        select 1
        from public.site_utility_network_members m
        where m.network_id = p_network_id
          and not public.can_manage_site_meters(m.site_id)
      )
    );
$$;

-- Full published snapshot: access to all member sites (v1; no implicit multi-site leak).
create or replace function public.can_read_utility_network_snapshot(p_network_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or public.can_manage_utility_network(p_network_id)
    or (
      exists (
        select 1 from public.site_utility_network_members m
        where m.network_id = p_network_id
      )
      and not exists (
        select 1
        from public.site_utility_network_members m
        where m.network_id = p_network_id
          and not public.has_site_access(m.site_id)
      )
    );
$$;

create or replace function public.can_read_utility_revision(p_revision_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.site_utility_network_revisions r
    join public.site_utility_networks n on n.id = r.network_id
    where r.id = p_revision_id
      and (
        (r.status = 'published'
          and n.published_revision_id = r.id
          and public.can_read_utility_network_snapshot(r.network_id))
        or (r.status = 'draft' and public.can_manage_utility_network(r.network_id))
        or (r.status = 'archived' and public.can_manage_utility_network(r.network_id))
      )
  );
$$;

-- Enable RLS
alter table public.site_utility_networks enable row level security;
alter table public.site_utility_network_members enable row level security;
alter table public.site_utility_network_revisions enable row level security;
alter table public.site_utility_assets enable row level security;
alter table public.site_utility_asset_ports enable row level security;
alter table public.site_utility_revision_nodes enable row level security;
alter table public.site_utility_revision_connections enable row level security;
alter table public.site_utility_network_views enable row level security;
alter table public.site_utility_view_nodes enable row level security;

-- Networks
drop policy if exists site_utility_networks_select on public.site_utility_networks;
create policy site_utility_networks_select
  on public.site_utility_networks for select to authenticated
  using (
    public.can_read_utility_network_snapshot(id)
    or public.can_manage_utility_network(id)
  );

drop policy if exists site_utility_networks_write on public.site_utility_networks;
create policy site_utility_networks_write
  on public.site_utility_networks for all to authenticated
  using (public.can_manage_utility_network(id) or public.is_super_admin())
  with check (public.is_super_admin() or public.can_manage_utility_network(id));

-- Members: readable with snapshot access; writable by managers
drop policy if exists site_utility_network_members_select on public.site_utility_network_members;
create policy site_utility_network_members_select
  on public.site_utility_network_members for select to authenticated
  using (
    public.can_read_utility_network_snapshot(network_id)
    or public.can_manage_utility_network(network_id)
    or public.has_site_access(site_id)
  );

drop policy if exists site_utility_network_members_write on public.site_utility_network_members;
create policy site_utility_network_members_write
  on public.site_utility_network_members for all to authenticated
  using (public.can_manage_utility_network(network_id) or public.is_super_admin())
  with check (public.can_manage_utility_network(network_id) or public.is_super_admin());

-- Revisions: draft only for managers; published for snapshot readers
drop policy if exists site_utility_network_revisions_select on public.site_utility_network_revisions;
create policy site_utility_network_revisions_select
  on public.site_utility_network_revisions for select to authenticated
  using (public.can_read_utility_revision(id));

drop policy if exists site_utility_network_revisions_write on public.site_utility_network_revisions;
create policy site_utility_network_revisions_write
  on public.site_utility_network_revisions for all to authenticated
  using (
    status = 'draft'
    and public.can_manage_utility_network(network_id)
  )
  with check (
    status in ('draft', 'published', 'archived')
    and public.can_manage_utility_network(network_id)
  );

-- Assets / ports: site-scoped
drop policy if exists site_utility_assets_select on public.site_utility_assets;
create policy site_utility_assets_select
  on public.site_utility_assets for select to authenticated
  using (public.has_site_access(site_id));

drop policy if exists site_utility_assets_write on public.site_utility_assets;
create policy site_utility_assets_write
  on public.site_utility_assets for all to authenticated
  using (public.can_manage_site_meters(site_id))
  with check (public.can_manage_site_meters(site_id));

drop policy if exists site_utility_asset_ports_select on public.site_utility_asset_ports;
create policy site_utility_asset_ports_select
  on public.site_utility_asset_ports for select to authenticated
  using (
    exists (
      select 1 from public.site_utility_assets a
      where a.id = asset_id and public.has_site_access(a.site_id)
    )
  );

drop policy if exists site_utility_asset_ports_write on public.site_utility_asset_ports;
create policy site_utility_asset_ports_write
  on public.site_utility_asset_ports for all to authenticated
  using (
    exists (
      select 1 from public.site_utility_assets a
      where a.id = asset_id and public.can_manage_site_meters(a.site_id)
    )
  )
  with check (
    exists (
      select 1 from public.site_utility_assets a
      where a.id = asset_id and public.can_manage_site_meters(a.site_id)
    )
  );

-- Revision graph content
drop policy if exists site_utility_revision_nodes_select on public.site_utility_revision_nodes;
create policy site_utility_revision_nodes_select
  on public.site_utility_revision_nodes for select to authenticated
  using (public.can_read_utility_revision(revision_id));

drop policy if exists site_utility_revision_nodes_write on public.site_utility_revision_nodes;
create policy site_utility_revision_nodes_write
  on public.site_utility_revision_nodes for all to authenticated
  using (
    exists (
      select 1 from public.site_utility_network_revisions r
      where r.id = revision_id
        and r.status = 'draft'
        and public.can_manage_utility_network(r.network_id)
    )
  )
  with check (
    exists (
      select 1 from public.site_utility_network_revisions r
      where r.id = revision_id
        and r.status = 'draft'
        and public.can_manage_utility_network(r.network_id)
    )
  );

drop policy if exists site_utility_revision_connections_select on public.site_utility_revision_connections;
create policy site_utility_revision_connections_select
  on public.site_utility_revision_connections for select to authenticated
  using (public.can_read_utility_revision(revision_id));

drop policy if exists site_utility_revision_connections_write on public.site_utility_revision_connections;
create policy site_utility_revision_connections_write
  on public.site_utility_revision_connections for all to authenticated
  using (
    exists (
      select 1 from public.site_utility_network_revisions r
      where r.id = revision_id
        and r.status = 'draft'
        and public.can_manage_utility_network(r.network_id)
    )
  )
  with check (
    exists (
      select 1 from public.site_utility_network_revisions r
      where r.id = revision_id
        and r.status = 'draft'
        and public.can_manage_utility_network(r.network_id)
    )
  );

drop policy if exists site_utility_network_views_select on public.site_utility_network_views;
create policy site_utility_network_views_select
  on public.site_utility_network_views for select to authenticated
  using (
    public.can_read_utility_network_snapshot(network_id)
    or public.can_manage_utility_network(network_id)
  );

drop policy if exists site_utility_network_views_write on public.site_utility_network_views;
create policy site_utility_network_views_write
  on public.site_utility_network_views for all to authenticated
  using (public.can_manage_utility_network(network_id))
  with check (public.can_manage_utility_network(network_id));

drop policy if exists site_utility_view_nodes_select on public.site_utility_view_nodes;
create policy site_utility_view_nodes_select
  on public.site_utility_view_nodes for select to authenticated
  using (public.can_read_utility_revision(revision_id));

drop policy if exists site_utility_view_nodes_write on public.site_utility_view_nodes;
create policy site_utility_view_nodes_write
  on public.site_utility_view_nodes for all to authenticated
  using (
    exists (
      select 1 from public.site_utility_network_revisions r
      where r.id = revision_id
        and r.status = 'draft'
        and public.can_manage_utility_network(r.network_id)
    )
  )
  with check (
    exists (
      select 1 from public.site_utility_network_revisions r
      where r.id = revision_id
        and r.status = 'draft'
        and public.can_manage_utility_network(r.network_id)
    )
  );

grant execute on function public.can_manage_utility_network(uuid) to authenticated;
grant execute on function public.can_read_utility_network_snapshot(uuid) to authenticated;
grant execute on function public.can_read_utility_revision(uuid) to authenticated;

comment on function public.can_manage_utility_network(uuid) is
  'Edit network if super_admin or can_manage_site_meters for every member site.';
comment on function public.can_read_utility_network_snapshot(uuid) is
  'Full snapshot requires has_site_access on every member site (no partial multi-site leak).';
