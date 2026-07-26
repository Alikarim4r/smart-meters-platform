-- =============================================================================
-- Smart Meters Platform — Storage Setup
-- Migration: 003_storage.sql
-- Status: DRAFT — DO NOT EXECUTE without approval
-- Depends on: 001_schema.sql, 002_rls_policies.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Bucket: meter-images (private)
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'meter-images',
  'meter-images',
  false,
  10485760,  -- 10 MB
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- -----------------------------------------------------------------------------
-- Path convention
-- {organization_id}/{site_id}/{meter_category}/{reading_date}/{meter_id}.jpg
--
-- Example:
-- a1b2c3d4-.../e5f6g7h8-.../water/2026-07-03/m9n0o1p2-....jpg
-- -----------------------------------------------------------------------------

-- Extract organization_id from path (first segment)
create or replace function public.storage_path_organization_id(path text)
returns uuid
language sql
immutable
as $$
  select nullif(split_part(path, '/', 1), '')::uuid;
$$;

-- Extract site_id from path (second segment)
create or replace function public.storage_path_site_id(path text)
returns uuid
language sql
immutable
as $$
  select nullif(split_part(path, '/', 2), '')::uuid;
$$;

-- Verify path site belongs to path organization
create or replace function public.storage_path_valid(path text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.sites s
    where s.id = public.storage_path_site_id(path)
      and s.organization_id = public.storage_path_organization_id(path)
  );
$$;

-- -----------------------------------------------------------------------------
-- Storage RLS policies on storage.objects
-- -----------------------------------------------------------------------------

-- SELECT: users with site access can view images for their sites
create policy "meter_images_select"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'meter-images'
    and public.storage_path_valid(name)
    and (
      public.is_super_admin()
      or public.has_site_access(public.storage_path_site_id(name))
    )
  );

-- INSERT: technicians and site admins with write access
create policy "meter_images_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'meter-images'
    and public.storage_path_valid(name)
    and public.can_write_site(public.storage_path_site_id(name))
  );

-- UPDATE: same as insert (replace image for same path)
create policy "meter_images_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'meter-images'
    and public.storage_path_valid(name)
    and public.can_write_site(public.storage_path_site_id(name))
  )
  with check (
    bucket_id = 'meter-images'
    and public.storage_path_valid(name)
    and public.can_write_site(public.storage_path_site_id(name))
  );

-- DELETE: site admins and super_admin only
create policy "meter_images_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'meter-images'
    and public.storage_path_valid(name)
    and (
      public.is_super_admin()
      or public.can_manage_site(public.storage_path_site_id(name))
    )
  );

-- -----------------------------------------------------------------------------
-- Helper: build storage path (for client reference — also in Flutter shared pkg)
-- -----------------------------------------------------------------------------

create or replace function public.build_meter_image_path(
  p_organization_id uuid,
  p_site_id uuid,
  p_meter_category public.meter_category,
  p_reading_date date,
  p_meter_id uuid,
  p_extension text default 'jpg'
)
returns text
language sql
immutable
as $$
  select format(
    '%s/%s/%s/%s/%s.%s',
    p_organization_id,
    p_site_id,
    p_meter_category,
    p_reading_date,
    p_meter_id,
    p_extension
  );
$$;

comment on function public.build_meter_image_path is
  'Returns storage object path for a meter reading image. Use with meter-images bucket.';
