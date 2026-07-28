-- =============================================================================
-- 062: Restore super_admin site visibility for admin reads/corrections
-- =============================================================================
-- Migration 054 removed is_super_admin() from has_site_access, so approved
-- super_admins without scopes saw empty sites/readings in Admin Corrections.
-- Platform owner already bypassed; this restores super_admin read visibility.
-- =============================================================================

create or replace function public.has_site_access(p_site_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner()
    or public.is_super_admin()
    or public.user_has_scope_for_site(p_site_id, 'view')
    or (
      public.is_approved_active_user()
      and exists (
        select 1 from public.user_site_access usa
        where usa.user_id = auth.uid()
          and usa.site_id = p_site_id
          and usa.can_read = true
      )
    );
$$;

comment on function public.has_site_access(uuid) is
  'True for platform owner, super_admin, scoped view permission, or user_site_access.can_read.';

-- Admin helper: list readings for a site without fragile PostgREST embeds.
create or replace function public.admin_list_site_readings(
  p_site_id uuid,
  p_from_date date default null,
  p_to_date date default null,
  p_limit int default 200
)
returns table (
  reading_id uuid,
  site_id uuid,
  site_name text,
  zone_id uuid,
  zone_name text,
  meter_id uuid,
  meter_name text,
  meter_code text,
  category_id uuid,
  category_name text,
  unit_label text,
  reading_date date,
  raw_value numeric,
  normalized_value numeric,
  note text,
  image_storage_path text,
  entered_by_name text,
  entered_by_email text,
  entered_at timestamptz,
  is_corrected boolean
)
language plpgsql
stable
security definer
set search_path = public
set row_security = off
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not (
    public.is_platform_owner()
    or public.is_super_admin()
    or public.is_admin_for_site(p_site_id)
    or public.has_site_access(p_site_id)
  ) then
    raise exception 'Not allowed to list readings for this site';
  end if;

  return query
  select
    mr.id,
    mr.site_id,
    coalesce(s.name_en, 'Site')::text,
    s.zone_id,
    coalesce(z.name_en, 'No Zone')::text,
    mr.meter_id,
    coalesce(m.name_en, 'Unknown meter')::text,
    coalesce(m.meter_code, mr.meter_id::text)::text,
    m.category_id,
    coalesce(mc.name_en, m.category::text, 'Category')::text,
    coalesce(mu.name_en, m.unit::text, '')::text,
    mr.reading_date,
    mr.raw_value,
    mr.normalized_value,
    mr.note,
    mr.image_storage_path,
    p.full_name,
    p.email,
    mr.entered_at,
    exists (
      select 1
      from public.reading_audit_logs al
      where al.reading_id = mr.id
        and al.action = 'update'
    )
  from public.meter_readings mr
  join public.sites s on s.id = mr.site_id
  left join public.zones z on z.id = s.zone_id
  left join public.meters m on m.id = mr.meter_id
  left join public.meter_categories mc on mc.id = m.category_id
  left join public.meter_units mu on mu.id = m.unit_id
  left join public.profiles p on p.id = mr.entered_by
  where mr.site_id = p_site_id
    and (p_from_date is null or mr.reading_date >= p_from_date)
    and (p_to_date is null or mr.reading_date <= p_to_date)
  order by mr.reading_date desc, mr.entered_at desc
  limit greatest(1, least(coalesce(p_limit, 200), 1000));
end;
$$;

revoke all on function public.admin_list_site_readings(uuid, date, date, int) from public;
grant execute on function public.admin_list_site_readings(uuid, date, date, int) to authenticated;
