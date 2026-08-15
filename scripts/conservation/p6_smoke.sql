select
  (select count(*) from meter_readings) as meter_readings,
  (select count(*) from meters where meter_kind = 'physical') as physical_meters,
  (select count(*) from conservation_feature_flags where enabled = true) as cons_flags_on,
  (select count(*) from platform_feature_flags where enabled = true) as p6_flags_on,
  (select to_regclass('public.external_data_sources') is not null) as has_sources,
  (select to_regclass('public.import_batches') is not null) as has_imports,
  (select to_regclass('public.ingest_readings_batch') is not null) as has_rpc_reg,
  (select exists(
     select 1 from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'ingest_readings_batch'
  )) as has_ingest_rpc,
  (select exists(select 1 from storage.buckets where id = 'import-files')) as has_import_bucket;
