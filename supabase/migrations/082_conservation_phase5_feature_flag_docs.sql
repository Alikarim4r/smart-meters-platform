-- =============================================================================
-- 082: Phase 5 feature flag documentation (keys only; never auto-enabled)
-- Flags are OFF when missing or enabled=false. No seed inserts.
-- Keys (Dart ConservationFeatureFlags):
--   weather_normalization, occupancy_normalization, saving_persistence,
--   carbon_accounting, portfolio_optimization, forecasting, recommendation_engine
-- =============================================================================

comment on table public.conservation_feature_flags is
  'Conservation feature flags. Missing row / enabled=false = OFF. '
  'Phase 5 keys: weather_normalization, occupancy_normalization, '
  'saving_persistence, carbon_accounting, portfolio_optimization, '
  'forecasting, recommendation_engine.';
