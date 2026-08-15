# Backlog — Migration History Reconciliation 056–062

**ID:** `MIGRATION_HISTORY_RECONCILIATION_056_062`  
**Status:** Documented only — **do not repair inside Conservation Phase 1**  
**Opened:** 2026-07-29 (during Conservation preflight / P1A)  
**Environment:** Staging `iqcxgtpcfhoapnklxdyl`

---

## Summary

Staging `supabase_migrations.schema_migrations` max version after P1A is **063**, with **055** still the previous tracked version. Versions **056–062 have no tracking rows**, while several objects from those files appear live (applied outside the tracker) and at least one intended change from 062 is **not** fully reflected.

This is **tracking drift + possible partial schema drift**. It is **not** fixed by Conservation P1A.

---

## Per-file findings (preflight probe)

| Migration file | In repo on branch | `schema_migrations` | Live probe |
|----------------|-------------------|---------------------|------------|
| `056_harden_scope_assignment_hierarchy.sql` | Yes | Missing | `user_may_write_scope_assignment` **not found** → **likely not applied** |
| `057_technician_scope_enter_readings.sql` | Yes | Missing | `is_technician_only_for_site` **present** → applied outside tracker |
| `058_ensure_own_pending_profile.sql` | Not on this branch (was untracked/stashed) | Missing | not fully inventoried |
| `059_report_logos.sql` | Not on this branch | Missing | `report-logos` bucket + `policy_settings.report_logo_secondary_path` **present** |
| `060_scoped_report_logos.sql` | Yes | Missing | `sites.report_logo_path` / `zones.report_logo_path` **present** |
| `061_atomic_approve_require_sites.sql` | Yes | Missing | `admin_approve_user(uuid,user_role,uuid[],text)` **present** |
| `062_super_admin_visibility_and_list_readings.sql` | Yes | Missing | `admin_list_site_readings` **present**; **`has_site_access` does NOT include `is_super_admin()`** → **partial / incomplete** vs file |

Artifacts: `docs/regression/migrations_056_062_objects.txt`, `docs/regression/migrations_056_062_tracking.txt`, `docs/regression/PREFLIGHT_GATE_REPORT.md`.

---

## Explicit non-actions (until separate approval)

Do **not**:

- Re-run 056–062 on Staging
- Manually insert version rows for 056–062 into `schema_migrations`
- Modify `has_site_access` or other live helpers solely to reconcile history
- Alter existing RLS policies on core tables for “history cleanup”

---

## Conservation P1A mitigation (already done)

Migration **063** RLS for `conservation_feature_flags` uses **explicit**:

`has_site_access(...) OR is_super_admin() OR is_platform_owner()`

so super_admin is not blocked by the 062 gap. Helpers were **not** modified.

---

## Suggested future work (separate report + approval)

1. Diff each 056–062 file against live catalog (functions, policies, columns, buckets).  
2. Produce a reconciliation plan: apply missing statements vs. mark applied vs. rewrite forward-fix migrations.  
3. Decide whether to backfill `schema_migrations` **only after** live schema matches intended definitions.  
4. Re-test admin corrections / super_admin site visibility after any `has_site_access` repair.

**Stop rule:** If this gap becomes a direct blocker for a Conservation sub-phase, stop that sub-phase and escalate — do not silently “fix” history inside Conservation.
