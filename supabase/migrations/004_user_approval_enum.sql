-- =============================================================================
-- Smart Meters Platform — User Approval enums (prerequisite)
-- Migration: 004_user_approval_enum.sql
-- Status: DRAFT — DO NOT EXECUTE until reviewed and approved
-- Depends on: 001_schema.sql
--
-- Must run BEFORE 005_user_approval.sql. PostgreSQL cannot use a newly added
-- enum value in the same transaction as ALTER TYPE ... ADD VALUE.
-- =============================================================================

create type public.approval_status as enum (
  'pending',
  'approved',
  'rejected',
  'suspended'
);

comment on type public.approval_status is
  'User lifecycle: pending (awaiting admin), approved (may access per role+site), rejected, suspended.';

-- Sign-up intent for technician applicants (role stays non-privileged until approval).
alter type public.user_role add value if not exists 'technician_request';
