# Staging Restore Runbook

**Purpose:** Prove that Staging backups can be restored to an **isolated** throwaway database.  
**Does NOT** restore over live Staging unless explicitly approved.

**Project:** `iqcxgtpcfhoapnklxdyl` (smart-meters-platform Staging)  
**Verified:** 2026-07-29 — restore drill **PASS** (protected row counts matched)

---

## Prerequisites

- Colima (or Docker Desktop) running  
- Docker credential helper fixed for Colima (no `docker-credential-desktop`)  
- `npx supabase` linked to Staging  
- `psql` client (PostgreSQL 17 recommended)  
- Official image `postgres:17` available locally  

Optional: Homebrew `postgresql@17` client tools.

---

## 1) Create a full backup

```bash
cd /path/to/smart-meters-platform
export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP_DIR="backups/staging_${STAMP}"
mkdir -p "$BACKUP_DIR"
echo "$BACKUP_DIR" > backups/LATEST_STAGING_BACKUP.txt

npx supabase db dump --linked -f "$BACKUP_DIR/schema.sql"
npx supabase db dump --linked --data-only -f "$BACKUP_DIR/data.sql"
npx supabase db dump --linked --role-only -f "$BACKUP_DIR/roles.sql" || true

npx supabase db query --linked \
  "select version from supabase_migrations.schema_migrations order by version;" \
  > "$BACKUP_DIR/schema_migrations_list.txt"

git rev-parse HEAD > "$BACKUP_DIR/GIT_REF.txt"
```

**Expected artifacts**

| File | Typical size (2026-07-29) |
|------|---------------------------|
| `schema.sql` | ~523 KB |
| `data.sql` | ~95 MB |
| `roles.sql` | small (optional) |

---

## 2) Restore drill (throwaway Docker Postgres)

```bash
export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
BACKUP_DIR=$(cat backups/LATEST_STAGING_BACKUP.txt | tr -d '\n')

docker rm -f conservation-restore-drill 2>/dev/null || true
docker run -d --name conservation-restore-drill \
  -e POSTGRES_PASSWORD=restore_drill \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=restore_drill \
  -p 5433:5432 \
  postgres:17

# wait until accepting connections
until PGPASSWORD=restore_drill psql -h 127.0.0.1 -p 5433 -U postgres -d restore_drill -c 'select 1' >/dev/null 2>&1; do sleep 1; done

# Minimal stubs (Supabase roles/schemas not fully present on plain Postgres)
PGPASSWORD=restore_drill psql -h 127.0.0.1 -p 5433 -U postgres -d restore_drill <<'SQL'
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE TABLE IF NOT EXISTS auth.users (id uuid PRIMARY KEY);
SQL

# Schema (ignore missing Supabase roles like anon/authenticated/service_role)
PGPASSWORD=restore_drill psql -h 127.0.0.1 -p 5433 -U postgres -d restore_drill \
  -v ON_ERROR_STOP=0 -f "$BACKUP_DIR/schema.sql" \
  > "$BACKUP_DIR/restore_schema.log" 2>&1

# Data (session_replication_role helps with FK ordering / circular FKs)
PGPASSWORD=restore_drill psql -h 127.0.0.1 -p 5433 -U postgres -d restore_drill \
  -v ON_ERROR_STOP=0 \
  -c "SET session_replication_role = replica;" \
  -f "$BACKUP_DIR/data.sql" \
  > "$BACKUP_DIR/restore_data.log" 2>&1
```

**Known acceptable errors on plain Postgres**

- Missing roles `anon` / `authenticated` / `service_role` (grants/RLS ownership)  
- Missing `storage.*` / some `auth.*` relations if those schemas were not fully created  

**Public app tables must still restore.**

---

## 3) Verify restore (required)

```bash
PGPASSWORD=restore_drill psql -h 127.0.0.1 -p 5433 -U postgres -d restore_drill -c "
select 'organizations' as m, count(*) from public.organizations
union all select 'zones', count(*) from public.zones
union all select 'sites', count(*) from public.sites
union all select 'meters', count(*) from public.meters
union all select 'meter_readings', count(*) from public.meter_readings
union all select 'reading_photos', count(*) from public.meter_readings
  where image_url is not null and length(trim(image_url)) > 0
union all select 'profiles', count(*) from public.profiles
union all select 'user_site_access', count(*) from public.user_site_access
union all select 'cop_groups', count(*) from public.cop_groups;
"
```

Compare to Staging snapshot / `docs/regression/REGRESSION_BASELINE_LATEST.json`.

**Pass criteria (2026-07-29 drill):** all protected public counts match Staging exactly  
(organizations=1, zones=8, sites=4, meters=35, meter_readings=43845, reading_photos=4, profiles=14, user_site_access=18, cop_groups=1, …).

---

## 4) Cleanup throwaway target

```bash
docker rm -f conservation-restore-drill
```

---

## 5) Emergency restore onto live Staging (LAST RESORT)

**Requires explicit product owner approval.** Destructive.

High-level only:

1. Take a **new** backup first (even if restoring an older one).  
2. Prefer Supabase Dashboard PITR / support path if available on the plan.  
3. If SQL restore is mandated: restore into a **new** Supabase project or branch, validate counts, then cut over — do **not** blindly `psql` a full dump onto production/staging without a written plan.  
4. Document the approved window and operators.

This runbook’s verified path is the **throwaway Docker drill**, not live overwrite.

---

## 6) Notes from verification (2026-07-29)

- `supabase db dump` needs Docker; Colima works after removing `credsStore: desktop` from `~/.docker/config.json`.  
- Direct IPv6 to `db.<ref>.supabase.co` may fail; CLI retries via IPv4 pooler.  
- Data dump warns about circular FKs; restore with `session_replication_role = replica` succeeds for public data.  
- `schema_migrations` on Staging currently lists versions through **055** (repo files exist through 062 — tracking gap noted in baseline report).  
- Backup directory: `backups/` is gitignored; keep copies outside the repo if long-term retention is required.
