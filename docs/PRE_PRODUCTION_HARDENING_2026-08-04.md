# Pre-production hardening — 2026-08-04

## Release boundary

- Branch: `hardening/pre-production-20260804`
- Pre-change checkpoint: `7fdac76`
- Rollback tag: `pre-production-hardening-20260804`
- Phase 7: deferred; no Phase 7 implementation is part of this branch.
- Dependency upgrades: deferred. The only dependency manifest change is an
  explicit `supabase_flutter: ^2.9.1` declaration in Admin for a package it
  already imported and already resolved transitively.

## Safety backup

Verified local safety artifacts were created outside the repository:

- complete Git history bundle;
- working-tree source archive, including the pre-hardening untracked source;
- existing Staging database backup remains available under
  `backups/staging_20260729T172256Z/`.

A fresh live Staging database backup is still required immediately before
applying migrations 115–116. Do not apply them to production first.

## Completed changes

1. Removed embedded staging/demo passwords and made validation credentials
   runtime-only.
2. Cleared analyzer diagnostics across Core, Dashboard, Entry, and Admin.
3. Isolated Entry offline drafts and caches by Supabase user and `APP_ENV`.
   Legacy unscoped drafts are retained in quarantine and are never synced.
4. Added migration 115:
   - effective organization/site reading policy on the server;
   - photo, business-date, late-reading, and Qatar cutoff enforcement for
     technician inserts;
   - reason-bearing admin correction RPC;
   - direct reading value/note corrections blocked for authenticated clients.
5. Added migration 116:
   - reversible archive metadata and immutable archive audit rows;
   - organization/site/zone/meter/network archive RPCs;
   - old `admin_force_delete_*` names converted to non-destructive archive
     wrappers;
   - readings, reading audit history, relationships, and network revisions are
     preserved.

## Verification evidence

- PostgreSQL 16 syntax test for migration 115: pass.
- PostgreSQL 16 functional policy/correction test: pass.
- PostgreSQL 16 functional archive/legacy-wrapper test: pass.
- Core: analyzer clean, 373 tests passed.
- Dashboard: analyzer clean, 77 tests passed.
- Entry: analyzer clean, 18 tests passed.
- Admin: analyzer clean, 21 tests passed.
- Total: 489 tests passed, zero failures.

## Required Staging gate

The following work requires an authenticated Supabase owner session and is not
complete merely because local tests pass:

1. Rotate exposed validation/demo account passwords and invalidate old sessions.
2. Create a fresh database backup and record row counts before migration.
3. Apply migration 115, then 116, to Staging only.
4. Re-run role checks for platform owner, super admin, site admin, technician,
   and viewer.
5. Smoke-test:
   - required-photo reading;
   - missing-photo rejection;
   - future-date rejection;
   - authorized late reading;
   - correction with reason and audit row;
   - archive via both new and legacy RPC names;
   - unchanged reading/audit/network counts after archive.
6. Record post-migration counts and keep Phase 7/dependency upgrades frozen.

## Rollback rules

- Application rollback: return to tag `pre-production-hardening-20260804` or
  the verified checkpoint commit.
- Offline data: do not delete Hive boxes. Legacy drafts are intentionally
  quarantined for explicit ownership recovery.
- Migration 115: prefer a forward fix if Staging exposes a policy edge case.
- Migration 116: do **not** restore the former destructive force-delete
  function bodies. Keep the safe wrappers even if the Admin UI is rolled back.
- Production promotion is blocked until the full Staging gate above passes.
