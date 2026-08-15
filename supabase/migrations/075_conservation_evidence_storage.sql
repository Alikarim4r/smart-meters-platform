-- =============================================================================
-- 075: conservation-evidence storage bucket (Phase 3)
-- Private. Path: {organization_id}/{site_id}/opportunities/{opportunity_id}/...
-- Does not alter meter-images bucket or reading photo policies.
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'conservation-evidence',
  'conservation-evidence',
  false,
  10485760,
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Reuse storage_path_organization_id / storage_path_site_id from 003.

drop policy if exists "conservation_evidence_storage_select" on storage.objects;
create policy "conservation_evidence_storage_select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'conservation-evidence'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or public.has_site_access(public.storage_path_site_id(name))
    )
  );

drop policy if exists "conservation_evidence_storage_insert" on storage.objects;
create policy "conservation_evidence_storage_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'conservation-evidence'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or (
        public.current_user_role() = 'site_admin'::public.user_role
        and public.can_manage_site(public.storage_path_site_id(name))
      )
      or (
        public.current_user_role() = 'technician'::public.user_role
        and public.has_site_access(public.storage_path_site_id(name))
      )
    )
  );

drop policy if exists "conservation_evidence_storage_update" on storage.objects;
create policy "conservation_evidence_storage_update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'conservation-evidence'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or (
        public.current_user_role() = 'site_admin'::public.user_role
        and public.can_manage_site(public.storage_path_site_id(name))
      )
    )
  );

drop policy if exists "conservation_evidence_storage_delete" on storage.objects;
create policy "conservation_evidence_storage_delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'conservation-evidence'
    and (
      public.is_super_admin()
      or public.is_platform_owner()
      or (
        public.current_user_role() = 'site_admin'::public.user_role
        and public.can_manage_site(public.storage_path_site_id(name))
      )
    )
  );
