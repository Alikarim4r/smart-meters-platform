insert into supabase_migrations.schema_migrations (version, name, statements)
values
  ('091', 'platform_feature_flags_phase6', array[]::text[]),
  ('092', 'reading_source_provenance', array[]::text[]),
  ('093', 'external_data_sources', array[]::text[]),
  ('094', 'import_batches_conflicts', array[]::text[]),
  ('095', 'ingestion_jobs_health', array[]::text[]),
  ('096', 'notifications_availability', array[]::text[]),
  ('097', 'automation_rules_ai_audit', array[]::text[]),
  ('098', 'import_storage_bucket', array[]::text[]),
  ('099', 'api_ingestion_rpc', array[]::text[]),
  ('100', 'ocr_readiness_meter_frequency', array[]::text[])
on conflict (version) do nothing;

select version, name from supabase_migrations.schema_migrations
where version::int >= 90
order by version;
