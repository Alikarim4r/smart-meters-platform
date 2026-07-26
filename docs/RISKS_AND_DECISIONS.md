# Risks and Decisions

**Project:** smart-meters-platform  
**Status:** Phase 1D complete; approval workflow planned  
**Last updated:** 2026-07-04 (rev 4 — user approval)

---

## 1. Open Decisions (Require Approval)

### D1: Authentication method

| Option | Pros | Cons |
|--------|------|------|
| Email/password (Supabase Auth) | Simple, built-in | Password management overhead |
| SSO / SAML ( ministry IdP) | Enterprise-grade | Integration effort, IdP dependency |
| Magic link | No passwords | Email delivery dependency |

**Recommendation:** Start with email/password for development; plan SSO for production ministry deployment.

**Decision needed:** Which auth method for production?

---

### D2: Global role vs site role precedence

Current design: `profiles.role` is global ceiling; `user_site_access.role` can differ per site.

Example: A user with global `viewer` but site-specific `technician` — which wins?

**Recommendation:** Site access row role and flags take precedence at that site. Global role only matters for super_admin bypass and org-level admin screens.

**Decision needed:** Confirm site-level role overrides global role for site-scoped operations.

---

### D3: Virtual / residual meters — **DECIDED**

**Decision:** Schema supports virtual meters from v1 via `meter_kind` and `calculation_type`. Physical meters use `direct_reading`; virtual meters use `parent_minus_children`, `sum_children`, or `manual_adjustment`. No direct readings on virtual meters. Dashboard computes values at query time. UI deferred.

---

### D4: Group nodes and tank nodes — **PARTIALLY DECIDED**

**Decision:** Use `meter_kind = virtual` with appropriate `calculation_type` for calculated/residual meters. Display-only tank/group nodes can use `include_in_dashboard` convention or virtual meters in a later UI phase. No separate `meter_display_nodes` table in v1.

---

### D5: Meter hierarchy depth — **DECIDED**

**Decision:** v1 enforces **one-level hierarchy** — sub meters reference main meters only (same site, same category). Trigger `validate_meter_parent` rejects sub → sub. Multi-level with cycle prevention deferred to v2.

---

### D6: State management — **DECIDED**

**Decision:** **Riverpod** for all new Flutter apps. Legacy Provider apps remain frozen.

---

### D8: Reading audit log — **DECIDED**

**Decision:** `reading_audit_logs` table in v1. Triggers log create/update/delete; `admin_restore_meter_reading()` logs restore. super_admin and site_admin can read; technician and viewer have no access.

---

### D11: Technician approval and site assignment — **DECIDED (draft SQL pending review)**

**Decision:** Technicians require admin approval before any site/meter/reading access.

| Aspect | Choice |
|--------|--------|
| Approval states | `pending`, `approved`, `rejected`, `suspended` on `profiles.approval_status` |
| Sign-up defaults | `approval_status = pending`, `is_active = false`, role `viewer` or `technician_request` |
| Who approves | `super_admin` or `site_admin` only (via RPC) |
| Site assignment | Admin-only `user_site_access` INSERT; technician cannot self-assign |
| Enforcement | RLS helper `is_approved_active_user()` gates `has_site_access` / `can_write_site` |
| Audit | `user_approval_logs` table (draft) |

**Draft migration:** `supabase/migrations/004_user_approval.sql` — **not executed**.

**Bootstrap impact:** Existing staging validation users must be backfilled to `approved` + `is_active = true` when migration runs.

---

### D12: Configurable meter categories — **DECIDED (draft SQL pending review)**

**Decision:** Option B — admin-managed `meter_categories`, `meter_units`, `meter_sources` with FK columns on `meters`. Legacy enum columns retained during transition. COP uses `supports_cop_output` / `supports_electric_input` flags. v1 catalog CRUD: `super_admin` only via SQL/admin_app (later).

**Draft:** `006_configurable_meter_categories.sql`

---

### D7: kVAh handling

Legacy treats kVAh as 1:1 with kWh (approximate). Physically incorrect without power factor.

**Options:**
- Keep 1:1 with UI disclaimer (legacy parity)
- Add optional `power_factor` column on electricity meters
- Disallow kVAh for COP input meters

**Decision needed:** Add power factor support in v1?

---

### D8: Reading uniqueness and edits — **PARTIALLY DECIDED**

Schema: one reading per meter per date. Audit log tracks all changes. Restore via admin RPC.

**Still open:** Should technicians be able to delete readings, or only site_admin?

---

### D9: COP calculation period

COP uses daily consumption deltas. For partial months or missing days:

**Options:**
- Skip days with missing data
- Interpolate (not recommended for cumulative meters)
- Show N/A

**Recommendation:** Skip days where either BTU or electricity group lacks complete data.

**Decision needed:** Confirm COP skip behavior.

---

### D10: Supabase project region

**Decision needed:** Confirm Supabase project region (likely closest to Qatar — check available regions).

---

## 2. Technical Risks

### R1: RLS complexity and performance

**Risk:** Nested subqueries in RLS policies may slow dashboard queries at scale.

**Mitigation:**
- Index `user_site_access(user_id, site_id)`
- Consider materialized view for site access cache
- Load test with realistic site/user counts
- Use `explain analyze` on common queries

**Severity:** Medium

---

### R2: Cumulative reading rollback

**Risk:** If a reading is entered incorrectly and later corrected, all subsequent consumption deltas shift.

**Mitigation:**
- Spike detection warnings in entry_app (port from legacy)
- Admin ability to edit/delete readings with confirmation
- Document operational procedure for corrections

**Severity:** Medium

---

### R3: Unit change after readings exist — **MITIGATED**

**Risk:** Changing unit/category corrupts historical normalized values.

**Mitigation:** Database trigger `protect_meter_unit_integrity` blocks `category_id`, `source_id`, `unit_id`, and legacy unit/category fields after readings exist. meter_multiplier changes require admin RPC with justification.

**Severity:** Low (guarded in schema)

---

### R3b: meter_multiplier change side effects

**Risk:** Approved multiplier change recalculates all historical normalized values, shifting consumption history.

**Mitigation:** Require 10+ character justification note; admin RPC only; document operational procedure; consider warning in admin UI.

**Severity:** Medium (operational)

---

### R3c: Audit log volume

**Risk:** High-frequency reading updates generate large audit log tables.

**Mitigation:** Indexes on site_id + changed_at; partition or archive policy in v2; limit technician update frequency in app if needed.

**Severity:** Low initially

---

### R4: Parent meter cycle

**Risk:** Admin could create circular parent references.

**Mitigation:** Trigger validates parent; admin UI runs cycle detection (port from legacy).

**Severity:** Low (guarded in schema)

---

### R5: Image storage costs

**Risk:** Daily photos for every meter at every site grows storage quickly.

**Mitigation:**
- 10 MB file size limit
- JPEG compression in entry_app
- Optional: lifecycle policy for old images (future)

**Severity:** Low initially

---

### R6: Migration data loss

**Risk:** Firestore export misses documents or meter code mapping fails.

**Mitigation:**
- Pre-migration count audit
- Post-migration validation script
- Keep Firebase read-only archive
- `migration.meter_code_map` table

**Severity:** High during migration

---

### R7: Seed divergence (admin vs entry apps)

**Risk:** Legacy admin seed has different hierarchy than entry/dashboard seed.

**Mitigation:** Use `water_readings_app/seed_meters.dart` as canonical source.

**Severity:** Medium (known issue)

---

### R8: No offline support

**Risk:** Technicians at sites with poor connectivity cannot enter readings.

**Mitigation:**
- Defer offline to Phase 2
- Document connectivity requirement for v1

**Severity:** Medium (operational)

---

### R9: BTU/COP greenfield

**Risk:** No legacy reference for COP calculations; first implementation may not match facility expectations.

**Mitigation:**
- Validate COP formula with facilities team using sample data
- Start with simple 1:1 groups (seed data)
- Weight support for advanced cases from day one

**Severity:** Medium

---

### R10: Configurable categories dual-write drift

**Risk:** During transition, `meters.category_id` and legacy `meters.category` enum could diverge if clients write only one side; fuel and future categories have no legacy enum value until extended.

**Mitigation:**
- `sync_meter_legacy_from_config` trigger on `category_id` / `source_id` / `unit_id`
- Backfill + forced re-sync in `006`
- Flutter migrates to FK + config models; legacy enums read-only
- Prerequisite `ALTER TYPE meter_category ADD VALUE 'fuel'`
- Validation script checks factor sync and backfill completeness

**Severity:** Medium (transition only)

---

### R11: Pending users blocked from all data

**Risk:** If approval gate is UI-only, pending technicians could query sites via API.

**Mitigation:**
- `is_approved_active_user()` in all site-scoped RLS helpers (draft `004`)
- Flutter `ApprovalGate` for user messaging only
- Integration tests: pending user SELECT on sites/meters/readings returns 0 rows

**Severity:** High — must ship with migration

---

### R12: Staging / bootstrap user lockout

**Risk:** Applying `004_user_approval.sql` without backfill sets all profiles to `pending` default on new column, or breaks existing test users.

**Mitigation:**
- Migration includes bootstrap SQL comment block
- One-time UPDATE for known super_admin / validation accounts before enabling public sign-up
- Run approval tests on branch before staging merge

**Severity:** High (operational)

---

### R13: site_admin approval scope

**Risk:** site_admin approves technician for sites outside their management.

**Mitigation:**
- `admin_approve_user()` validates each `p_site_id` with `can_manage_site()`
- super_admin unrestricted
- Document ministry-wide pending queue vs per-site queue in admin UI (v1: ministry-wide list, assignment scoped)

**Severity:** Medium

---

### R10: Auth trigger timing

**Risk:** `handle_new_user` trigger on `auth.users` must be enabled after first admin is created manually.

**Mitigation:**
- Document bootstrap procedure
- First super_admin created via Supabase dashboard, role updated in profiles

**Severity:** Low

---

## 3. Security Risks

### S1: Anon key exposure in Flutter apps

**Risk:** Supabase anon key is in client apps; security relies entirely on RLS.

**Mitigation:**
- Comprehensive RLS testing
- No service role key in apps
- Enable Supabase Auth email confirmation in production

**Severity:** High — RLS must be correct

---

### S2: Storage path guessing

**Risk:** Predictable UUID paths could allow unauthorized access if RLS fails.

**Mitigation:**
- Storage policies validate org/site relationship
- Private bucket (signed URLs only)
- RLS tests for cross-site access denial

**Severity:** Medium

---

### S3: Super admin bootstrap

**Risk:** First user creation window before RLS is fully tested.

**Mitigation:**
- Apply RLS before any production data
- Test with non-privileged users first

**Severity:** Medium

---

## 4. Operational Risks

### O1: Multi-site rollout complexity

**Risk:** Ministry has hundreds of schools; onboarding each site is labor-intensive.

**Mitigation:**
- Bulk import tooling in admin_app (CSV)
- Site templates for common meter configurations

**Severity:** Medium (future)

---

### O2: Training and change management

**Risk:** Users accustomed to separate water/electricity apps.

**Mitigation:**
- Unified entry_app with category picker
- Training materials AR/EN
- Parallel run period with legacy

**Severity:** Medium

---

## 5. Decisions Already Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Backend | Supabase | User requirement |
| Legacy apps | Frozen, no changes | Stable prototype |
| Raw readings | Stored as entered | Legacy parity |
| Normalization | At write time via trigger | Consistent queries |
| Unit vs multiplier | Separate fields | Legacy bug fix |
| COP structure | 3 tables (groups + 2 junctions) | Supports simple and advanced |
| Storage bucket | `meter-images` private | Security |
| Flutter state | Riverpod | Complex auth, filters, async queries |
| Virtual meters | Schema in v1, UI deferred | Future WF/residual support |
| Hierarchy | One-level v1 | Simpler validation; multi-level in v2 |
| Reading audit | reading_audit_logs v1 | Compliance and correction traceability |
| Technician readings | Today only (Asia/Qatar) | No backdate/edit/delete by technicians |
| Unit integrity | DB trigger + admin RPC | Block unit/category; guarded multiplier |
| No anonymous auth | Production requirement | User requirement |
| Flutter apps | 3 apps + shared package | Role separation |
| Hierarchy key | `parent_meter_id` | User requirement |
| Technician approval | Admin gate before site access | Security + ministry onboarding control |
| User approval states | pending/approved/rejected/suspended | RLS-enforced lifecycle |
| Sign-up role | viewer or technician_request only | No privileged self-registration |
| No self-assign sites | user_site_access admin INSERT only | Prevents unauthorized building access |
| Meter categories | Configurable tables + FK on meters | Admin-managed fuel/gas/steam without enum migrations |
| COP eligibility | `supports_cop_output` / `supports_electric_input` flags | Decouples COP from hardcoded btu/electricity enums |
| Category config RLS | super_admin write; others read active | Ministry control; no anonymous catalog access |

---

## 6. Pre-Implementation Checklist

Before executing SQL:

- [x] Review and approve `001_schema.sql` (executed on staging)
- [x] Review and approve `002_rls_policies.sql` (executed on staging)
- [x] Review and approve `003_storage.sql` (executed on staging)
- [x] Review and approve `004_user_approval_enum.sql` + `005_user_approval.sql` (executed on staging)
- [x] **Review and approve `006_configurable_meter_categories.sql` (applied staging 2026-07-04)**
- [ ] Run prerequisite: `ALTER TYPE meter_category ADD VALUE 'fuel'` (separate transaction)
- [ ] Run `scripts/phase_configurable_categories_validation.sql` after 006
- [ ] Confirm Supabase project `smart-meters-platform` staging remains non-production
- [ ] Review and approve seed data
- [ ] Resolve remaining open decisions (D1 auth, D7 kVAh, D10 region, D8 technician delete)
- [ ] Confirm Supabase project `smart-meters-platform` is accessible
- [ ] Confirm target region and auth settings
- [ ] Agree on bootstrap super_admin procedure

---

## 7. Review Schedule

Revisit this document:
- Before SQL execution
- Before Flutter app development
- Before MOEHE HQ data migration
- Before production deployment
