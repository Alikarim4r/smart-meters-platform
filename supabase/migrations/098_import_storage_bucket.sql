-- =============================================================================
-- 098: Private import-files storage bucket (CSV/Excel)
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'import-files',
  'import-files',
  false,
  20971520,
  array[
    'text/csv',
    'text/plain',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/csv'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Path convention: {organization_id}/{site_id|org}/{batch_id}/{filename}
-- Bucket is private; no public URLs.

drop policy if exists "import_files_storage_select" on storage.objects;
create policy "import_files_storage_select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'import-files'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.user_can_manage_organization(public.storage_path_organization_id(name))
      or (
        public.storage_path_site_id(name) is not null
        and public.has_site_access(public.storage_path_site_id(name))
        and public.current_user_role() = 'site_admin'::public.user_role
      )
    )
  );

drop policy if exists "import_files_storage_insert" on storage.objects;
create policy "import_files_storage_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'import-files'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.user_can_manage_organization(public.storage_path_organization_id(name))
      or (
        public.storage_path_site_id(name) is not null
        and public.can_manage_site(public.storage_path_site_id(name))
        and public.current_user_role() = 'site_admin'::public.user_role
      )
    )
  );

drop policy if exists "import_files_storage_update" on storage.objects;
create policy "import_files_storage_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'import-files'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.user_can_manage_organization(public.storage_path_organization_id(name))
    )
  )
  with check (
    bucket_id = 'import-files'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.user_can_manage_organization(public.storage_path_organization_id(name))
    )
  );

drop policy if exists "import_files_storage_delete" on storage.objects;
create policy "import_files_storage_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'import-files'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.user_can_manage_organization(public.storage_path_organization_id(name))
    )
  );
