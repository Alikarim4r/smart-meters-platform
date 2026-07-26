-- =============================================================================
-- Add sub_sub to meter_level enum (must commit before use in constraints)
-- Migration: 012_meter_level_sub_sub_enum.sql
-- =============================================================================

alter type public.meter_level add value if not exists 'sub_sub';
