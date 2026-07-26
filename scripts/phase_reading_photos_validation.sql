-- =============================================================================
-- Phase: Reading photos validation (DRAFT — run after 008 if executed)
-- Status: DRAFT — companion to 008_meter_reading_photos.sql
-- Current app uses meter_readings.image_url + meter-images bucket (003_storage.sql)
-- =============================================================================

-- When executed on staging, verify:
-- 1. Technician with site write access can upload to meter-images path
-- 2. Unassigned user cannot upload or read foreign site images
-- 3. meter_readings insert with image_url respects existing RLS
-- 4. Technician cannot update/delete synced readings (002_rls_policies.sql)
-- 5. Admin/site_admin can read image_url for managed sites

do $$ begin
  raise notice 'DRAFT: phase_reading_photos_validation.sql — execute after migration review';
end $$;
