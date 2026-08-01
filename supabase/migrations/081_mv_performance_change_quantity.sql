-- =============================================================================
-- 081: Preserve signed performance_change_quantity on M&V (Phase 4 hardening)
-- Additive column only. Verified Saving totals stay non-negative; signed change
-- remains reportable when consumption increased.
-- Does NOT rewrite 077–080.
-- =============================================================================

alter table public.conservation_measurement_verifications
  add column if not exists performance_change_quantity numeric(18, 4);

comment on column public.conservation_measurement_verifications.performance_change_quantity is
  'Signed performance change (reference − post). Positive=reduced consumption; negative=increased. Never rolled into Verified Savings Total when negative. Verified Saving stays max(0, change).';
