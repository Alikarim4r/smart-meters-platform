# Pre-production hardening — 2026-08-04

## Release boundary

- Branch: `hardening/pre-production-20260804`
- Pre-change checkpoint: `7fdac76`
- Rollback tag: `pre-production-hardening-20260804`
- Supabase Staging project: `iqcxgtpcfhoapnklxdyl`
- Production was not changed.
- Phase 7 and dependency upgrades remain deferred.

## Safety backups

Verified safety artifacts exist outside the repository:

- complete Git history bundle;
- pre-hardening working-tree source archive;
- PostgreSQL 17 custom-format dump taken immediately before the live migrations;
- PostgreSQL schema-only dump taken after the live migrations;
- exact pre/post counts for protected tables.

The Supabase project is on the Free Plan, which has no managed scheduled
backups. The manual pre-migration dump was validated with `pg_restore --list`
before any migration was applied.

## Completed hardening

1. Removed embedded staging/demo passwords and made validation credentials
   runtime-only.
2. Rotated the direct database password and stored the final value in macOS
   Keychain, not in the repository.
3. Rotated all four validation-account passwords, invalidated their prior
   sessions and refresh tokens, and stored the new values in Keychain.
4. Cleared analyzer diagnostics across Core, Dashboard, Entry, and Admin.
5. Isolated Entry offline drafts and caches by Supabase user and `APP_ENV`.
   Legacy unscoped drafts remain quarantined and are never synced.
6. Applied migration 115 to Staging:
   - effective organization/site reading policy on the server;
   - photo, business-date, late-reading, and Qatar cutoff enforcement;
   - reason-bearing admin correction RPC;
   - direct reading value/note corrections blocked for authenticated clients.
7. Applied migration 116 to Staging:
   - reversible archive metadata and immutable archive audit rows;
   - organization/site/zone/meter/network archive RPCs;
   - old `admin_force_delete_*` names converted to non-destructive wrappers;
   - readings, audit history, relationships, and network revisions preserved.
8. Applied migration 117 after the live hierarchy smoke test exposed a legacy
   validation edge case. Archive/status-only meter updates no longer revalidate
   unrelated legacy parent metadata; real hierarchy edits remain validated.
9. Fixed the validation-user setup script so a trigger-created profile is
   explicitly approved and activated on conflict.

## Staging evidence

Live database checks passed for:

- platform owner, super admin, site admin, technician, and viewer scopes;
- validation-account password login and immediate local logout;
- required-photo reading acceptance;
- missing-photo rejection;
- future-date rejection;
- authorized backdated reading acceptance;
- direct correction rejection;
- reason-bearing correction RPC and reading audit row;
- new archive RPC;
- legacy site, network, zone, and organization wrapper names;
- reactivation metadata clearing with immutable archive audit retained.

The 15 mutation smoke checks ran inside one PostgreSQL transaction and ended
with `ROLLBACK`. No smoke reading or archive row remained afterward.

Protected row counts before and after were unchanged:

| Table | Before | After |
|---|---:|---:|
| organizations | 1 | 1 |
| zones | 8 | 8 |
| sites | 4 | 4 |
| meters | 38 | 38 |
| meter_readings | 43,846 | 43,846 |
| reading_audit_logs | 167,444 | 167,444 |
| site_utility_networks | 7 | 7 |
| site_utility_network_revisions | 12 | 12 |

`profiles` and `user_site_access` each increased by one because the missing
technician validation account and its intended site assignment were created.

## Local verification

- Core: analyzer clean, 373 tests passed.
- Dashboard: analyzer clean, 77 tests passed.
- Entry: analyzer clean, 18 tests passed.
- Admin: analyzer clean, 21 tests passed.
- Total: 489 tests passed, zero failures.

No dependency versions were upgraded. Analyzer output only reported that newer
incompatible versions exist; the lockfiles remained unchanged.

## Migration history note

The live project previously ended at migration 101. Migration 114 already
existed locally but is unrelated to this hardening gate, so it was not applied
implicitly. Staging now records 115, 116, and 117. Review 114 separately before
the next CLI migration push because it is an out-of-order pending migration.

## Rollback rules

- Application rollback: return to tag `pre-production-hardening-20260804` or
  checkpoint commit `7fdac76`.
- Database rollback: restore the verified pre-migration custom dump into a new
  recovery project; do not overwrite Staging without an explicit incident
  decision.
- Offline data: do not delete Hive boxes. Legacy drafts are intentionally
  quarantined for explicit ownership recovery.
- Migration 115: prefer a forward fix for policy edge cases.
- Migrations 116–117: do not restore destructive force-delete bodies. Keep the
  safe archive wrappers even if an application UI is rolled back.
- Production promotion requires a separate, explicit decision.
