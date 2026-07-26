# Phase 1A — SQL Validation Runbook

**Status:** Rev 3 — technician restrictions applied; re-run validation after local reset  
**Last updated:** 2026-07-03

---

## Environment check (this machine)

| Requirement | Status |
|-------------|--------|
| Supabase CLI (`npx supabase`) | Available (v2.109.0 via npx) |
| Docker Desktop | **Not available** — `supabase start` cannot run |
| `psql` | Not installed |

**Conclusion:** Local Supabase validation cannot run until Docker Desktop is installed and running.

---

## Option A — Local Supabase (recommended after Docker install)

### Prerequisites

1. Install [Docker Desktop](https://docs.docker.com/desktop/)
2. Start Docker Desktop
3. From project root:

```bash
cd /Users/ali-laptop/Downloads/smart-meters-platform
npx supabase start
```

### Apply migrations (in order)

**Method 1 — psql (recommended until migrations are renamed):**

Supabase CLI `db reset` runs every file in `supabase/migrations/`. Until files are renamed to timestamped names **only**, use psql directly:

```bash
DB="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

psql "$DB" -f supabase/migrations/001_schema.sql
psql "$DB" -f supabase/migrations/002_rls_policies.sql
psql "$DB" -f supabase/migrations/003_storage.sql
psql "$DB" -f supabase/seed/001_seed_moehe_hq.sql
psql "$DB" -f scripts/phase1a_validation.sql
```

Local credentials are the default Supabase local stack (`postgres` / `postgres` on port `54322`). These are **local only** — not production secrets.

### Run validation

```bash
psql "$DB" -f scripts/phase1a_setup_test_users.sql   # creates test auth users (local only)
psql "$DB" -f scripts/phase1a_validation.sql
```

---

## Option B — Supabase hosted staging (SQL Editor)

Use project **`smart-meters-platform`** staging branch or a **disposable branch** — not production.

### Before you run

- [ ] Confirm this is **staging**, not production
- [ ] Create a Supabase **branch** or use a fresh staging project if possible
- [ ] Do **not** paste service role keys into chat or commits

### Execution order (SQL Editor → New query)

Run each file **in full**, one at a time. Wait for success before the next.

| Step | File | Notes |
|------|------|-------|
| 1 | `supabase/migrations/001_schema.sql` | ~860 lines; creates schema |
| 2 | `supabase/migrations/002_rls_policies.sql` | RLS + admin RPCs |
| 3 | `supabase/migrations/003_storage.sql` | Storage bucket + policies |
| 4 | `supabase/seed/001_seed_moehe_hq.sql` | MOEHE HQ sample data |
| 5 | `scripts/phase1a_setup_test_users.sql` | Test users for RLS (staging only) |
| 6 | `scripts/phase1a_validation.sql` | Automated checks + test inserts |

### Create test auth users (Dashboard)

If `phase1a_setup_test_users.sql` fails on hosted (auth schema restrictions), create users manually:

| Email | Password | Profile role | Site access |
|-------|----------|--------------|-------------|
| `test-super-admin@validation.local` | (staging only) | `super_admin` | — |
| `test-site-admin@validation.local` | (staging only) | `site_admin` | MOEHE HQ, all manage flags |
| `test-technician@validation.local` | (staging only) | `technician` | MOEHE HQ, can_read + can_write |
| `test-viewer@validation.local` | (staging only) | `viewer` | MOEHE HQ, can_read only |

Then update profiles and run the site access inserts from `phase1a_setup_test_users.sql`.

### Rollback (staging only)

If validation fails and you need a clean slate on a branch:

```sql
-- DESTRUCTIVE — staging/disposable only
drop schema public cascade;
create schema public;
grant all on schema public to postgres;
grant all on schema public to public;
```

Then re-run migrations from step 1.

---

## Option C — Confirm and ask agent to re-run

Reply with one of:

1. **"Docker ready"** — agent will run Option A locally
2. **"Run on staging"** — confirm staging project URL/branch; agent runs via linked CLI (you provide `supabase link` interactively or run SQL yourself)
3. **"Manual only"** — you run SQL Editor steps yourself using this doc + validation script

---

## Files involved

| File | Purpose |
|------|---------|
| `supabase/migrations/001_schema.sql` | Schema, triggers, audit, view |
| `supabase/migrations/002_rls_policies.sql` | RLS policies, admin RPCs |
| `supabase/migrations/003_storage.sql` | `meter-images` bucket |
| `supabase/seed/001_seed_moehe_hq.sql` | Sample org/site/meters/COP |
| `scripts/phase1a_setup_test_users.sql` | Test users for RLS |
| `scripts/phase1a_validation.sql` | Validation test suite |

---

## What Phase 1A does NOT include

- Flutter apps
- Legacy Firebase changes
- Production data migration
- Service role key exposure
- Permanent production deployment

---

## After validation succeeds

Phase 1B (pending your approval):
- Enable `handle_new_user` trigger on staging
- Create real super_admin bootstrap user
- Link Supabase CLI to staging project
- Document connection config for Flutter (still no app creation)
