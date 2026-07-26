# Smart Meters Platform — Product Architecture

**Project:** smart-meters-platform  
**Backend:** Supabase  
**Status:** Phase 1G — `006` applied on staging; entry_app reads dynamic categories  
**Last updated:** 2026-07-04

---

## 1. Vision

Build a production-oriented, multi-site smart meters platform for ministry facilities: schools, buildings, headquarters, offices, kindergartens, training centers, warehouses, and other sites.

The platform replaces the frozen Firebase prototype (single-site MOEHE HQ) with a scalable Supabase-backed system supporting organizations, sites, role-based access, and optional BTU/COP features.

---

## 2. Scope Boundaries

| In scope (this project) | Out of scope (frozen legacy) |
|-------------------------|------------------------------|
| Multi-organization, multi-site | `water_readings_app` |
| Supabase Auth + RLS | `electricity_readings_app` |
| Water, electricity, BTU meters (+ configurable fuel and future categories) | `meters_dashboard_app` |
| COP calculation groups | `meters_admin_app` |
| Three new Flutter apps (later) | Firebase project `water-meters-system` |

**Do not modify legacy Firebase apps.** Reference only.

---

## 3. Actors and Roles

| Role | Scope | Capabilities |
|------|-------|--------------|
| `super_admin` | Global | Manage all organizations, sites, users, meters, readings, COP settings; approve/reject/suspend users |
| `site_admin` | Assigned sites | Manage meters, users, and COP groups for assigned sites; approve technicians for site assignment |
| `technician` | Assigned sites | Enter today's readings for assigned sites only (after admin approval) |
| `viewer` | Assigned sites | Read-only dashboard access for assigned sites |
| `technician_request` | None until approved | Sign-up role only; no site/meter/reading access until admin approves and assigns sites |

**Production rule:** No anonymous or unauthenticated access.

**Approval rule:** New sign-ups are **not** active immediately. They default to `approval_status = pending` and `is_active = false`. Only `super_admin` or `site_admin` can approve users, assign role, and assign sites. Technicians **cannot** self-assign sites.

Site assignment is stored in `user_site_access`. A user's global role (`profiles.role`) defines their ceiling; per-site flags refine what they can do at each site.

### 3.1 User approval lifecycle

| `approval_status` | `is_active` | Data access |
|-------------------|-------------|-------------|
| `pending` | `false` | Own profile only (status screen) |
| `rejected` | `false` | Own profile only |
| `suspended` | `false` | Own profile only |
| `approved` | `true` | Per role + `user_site_access` |

**New sign-up defaults** (via `handle_new_user`):

| Field | Default |
|-------|---------|
| `role` | `viewer` or `technician_request` (from sign-up metadata; never `technician`/`site_admin`/`super_admin`) |
| `approval_status` | `pending` |
| `is_active` | `false` |

**Technician becomes operational only when all are true:**

1. `approval_status = approved`
2. `is_active = true`
3. `role = technician`
4. At least one `user_site_access` row with `can_write = true`

**Admin actions** (via `admin_approve_user`, `admin_reject_user`, `admin_suspend_user` RPCs — draft in `004_user_approval.sql`):

- Approve → set role, mark approved/active, assign site(s)
- Reject → pending applicants only
- Suspend → revoke active access (keeps audit trail)
- Remove site access → delete `user_site_access` row (existing RLS; admin only)

See draft migration: `supabase/migrations/004_user_approval.sql` (not executed).

---

## 4. Core Domain Model

```
organizations
  └── sites
        ├── meters (water | electricity | btu)
        │     ├── meter_kind: physical | virtual
        │     ├── calculation_type: direct_reading | sum_children | parent_minus_children | manual_adjustment
        │     └── parent_meter_id → meters (same site, same category; v1: sub → main only)
        ├── meter_readings (physical / direct_reading only)
        ├── reading_audit_logs (append-only change history)
        └── cop_groups
              ├── cop_group_btu_meters
              └── cop_group_electricity_meters

profiles (auth.users)
  ├── approval_status: pending | approved | rejected | suspended
  ├── is_active (false until approved)
  └── user_site_access → sites
```

**Technician access (enforced in RLS, not UI only):**

| Resource | Rule |
|----------|------|
| Sites | Assigned sites only (`user_site_access` + `has_site_access`) |
| Meters | Meters in assigned sites only |
| Readings | Read assigned sites; create today-only for assigned sites |
| Unassigned buildings | No visibility |
| Edit/delete readings | Admins only (unchanged) |

### 4.1 Organizations

Top-level tenant boundary. Example: Ministry of Education and Higher Education (MOEHE).

### 4.2 Sites

Physical locations under an organization: headquarters, school, kindergarten, office, warehouse, training center, or other.

### 4.3 Meters

Each meter belongs to exactly one site and one **category**. Categories are **admin-configurable** via `meter_categories` (draft migration `006_configurable_meter_categories.sql`). Legacy Postgres enums (`meter_category`, `meter_source`, `meter_unit`) remain during transition for backward compatibility.

| Category (system seed) | Purpose | Base unit |
|------------------------|---------|-----------|
| `water` | Domestic, TSE, RO, tanker, irrigation | m³ |
| `electricity` | Grid, generator, solar, UPS | kWh |
| `btu` | Chilled water, cooling energy, AHU, CRAC | kWh thermal |
| `fuel` | Diesel, petrol, gas oil | liter |

Future categories (e.g. gas, steam, compressed air) are added by `super_admin` without schema changes.

**Configurable reference tables:**

| Table | Purpose |
|-------|---------|
| `meter_categories` | Category code, labels, base unit, icon/color, COP flags |
| `meter_units` | Allowed units per category with `unit_to_base_factor` |
| `meter_sources` | Allowed sources per category (Kahramaa, diesel, chilled water, …) |

**Meters FK columns (preferred after migration):** `category_id`, `source_id`, `unit_id`.  
**Legacy columns (transition):** `category`, `source`, `unit`, `unit_to_base_factor`, `base_unit` — synced from FK refs via trigger; do not drop until Flutter/admin fully migrated.

**COP category flags** on `meter_categories`:

| Flag | Usage |
|------|-------|
| `supports_cop_output` | BTU/cooling meters linkable as COP output |
| `supports_electric_input` | Electricity meters linkable as COP input |
| `is_consumption_category` | Shown in entry/dashboard consumption flows |

**Level:** `main` or `sub`. Sub meters reference a parent via `parent_meter_id` (same site, same category).

**v1 hierarchy:** One-level only — sub meters may reference main meters only. Multi-level hierarchy deferred to v2.

**Kind and calculation:**
| Field | Values | v1 usage |
|-------|--------|----------|
| `meter_kind` | `physical`, `virtual` | All seeded meters are physical |
| `calculation_type` | `direct_reading`, `sum_children`, `parent_minus_children`, `manual_adjustment` | Physical meters use `direct_reading`; virtual meters use calculated types |

Virtual meters (e.g. legacy WF residual) store configuration in `meters` but receive no direct readings. Values computed at dashboard query time. UI for virtual meter setup deferred; schema is ready.

**Source/type** varies by category (e.g. Kahramaa, TSE, chilled water, generator).

**Units:** Raw readings stored as entered. Normalization uses:

```
normalized_value = raw_value × unit_to_base_factor × meter_multiplier
```

- `unit_to_base_factor` — unit conversion only
- `meter_multiplier` — CT ratio, pulse factor, calibration (never mixed with unit conversion)

### 4.4 Meter Readings

One row per meter per reading date (`unique(meter_id, reading_date)`). Cumulative raw value as entered. `normalized_value` computed at write time. Optional image and note.

Only `physical` meters with `calculation_type = direct_reading` accept readings. Virtual and calculated meters are excluded at the database level.

**Business date:** Technician submissions use `current_business_date()` = `(timezone('Asia/Qatar', now()))::date`.

#### Technician rules (entry_app)

| Rule | Enforcement |
|------|-------------|
| Create readings for **today only** (Qatar date) | RLS + trigger |
| No past or future dates | RLS + trigger |
| No update after save | RLS + trigger |
| No delete or restore | RLS + trigger |
| No change to `entered_by` or `reading_date` | RLS + trigger |
| Assigned sites, active physical meters only | RLS + trigger |

#### Admin rules (admin_app)

| Role | Permissions |
|------|-------------|
| `super_admin` | Create/update/delete/restore for any site; backfill past dates |
| `site_admin` | Same for assigned sites only |
| All admin corrections | Audit-logged in `reading_audit_logs`; correction note required for restore |

### 4.5 Reading Audit Logs

Every create, update, delete, and restore action on `meter_readings` is logged to `reading_audit_logs` via SECURITY DEFINER triggers. The log captures old/new values for raw reading, normalized value, date, and image URL, plus `changed_by` and `changed_at`.

| Role | Audit access |
|------|--------------|
| `super_admin` | Read all |
| `site_admin` | Read for assigned sites |
| `technician` | No access (v1) |
| `viewer` | No access |

Clients cannot insert audit rows directly. Restore uses `admin_restore_meter_reading()` RPC.

### 4.6 Unit Integrity Protection

Once a meter has readings, the database blocks changes to:
- `category_id`, `source_id`, `unit_id`
- `unit`, `unit_to_base_factor`, `base_unit`, `category` (legacy)

**Preferred source of truth after migration:** `unit_id` → `meter_units.unit_to_base_factor`; `category_id` → `meter_categories.base_unit_code`. Legacy factor columns are derived via `sync_meter_legacy_from_config` trigger.

`meter_multiplier` changes after readings exist require `admin_update_meter_multiplier()` with a minimum 10-character justification note and site_admin or super_admin role. All normalized readings are recalculated after an approved multiplier change.

To change unit or category after readings exist: create a new meter row and migrate forward — do not alter the existing meter.

### 4.7 Meter category configuration (RLS)

| Role | `meter_categories` / `meter_units` / `meter_sources` |
|------|--------------------------------------------------------|
| `super_admin` | Full CRUD |
| `site_admin` | Read active (+ inactive for admin visibility) |
| `technician`, `viewer` | Read active only (for display and entry) |
| Anonymous | No access |

### 4.8 COP Groups

Optional per-site configuration linking **cooling output** meters to **electricity input** meters.

COP meter eligibility uses `meter_categories` flags (not hardcoded enums only):
- Output side: `supports_cop_output = true` (system `btu` category)
- Input side: `supports_electric_input = true` (system `electricity` category)

```
COP = Σ(BTU cooling output, normalized) / Σ(electricity input, normalized)
```

Weights on junction tables support proportional allocation in advanced groups.

---

## 5. Application Architecture

Three Flutter apps (to be built after schema approval):

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   admin_app     │  │   entry_app     │  │  dashboard_app  │
│                 │  │                 │  │                 │
│ Orgs, sites,    │  │ Site → category │  │ Site → dynamic  │
│ meters, users,  │  │ → meters →      │  │ categories,     │
│ COP groups      │  │ raw reading +   │  │ charts, COP,    │
│                 │  │ image upload    │  │ relationship map│
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │     Supabase      │
                    │  Auth + Postgres  │
                    │  RLS + Storage    │
                    └───────────────────┘
```

See [FLUTTER_ARCHITECTURE.md](./FLUTTER_ARCHITECTURE.md) for app-level detail. State management uses **Riverpod** (not Provider).

---

## 5.1 Professional Dashboard Design System

The new `dashboard_app` must **not** copy the legacy Firebase prototype UI. It is a greenfield, production-grade dashboard.

### Layout

- Modern responsive layout (mobile, tablet, desktop/web)
- Persistent **sidebar** for navigation and site context
- **Top filter bar**: site selector, dynamic category tabs (+ COP when groups exist), date range, time grouping, chart type, meter multi-select, compare-with-previous-period

### Shared dashboard modules

| Module | Purpose |
|--------|---------|
| KPI cards | Total consumption, average daily, peak day, period comparison |
| Data completeness | Meters with missing readings, overdue entry dates |
| Meter relationship map | Dynamic tree from `parent_meter_id` |
| Charts | See time views and chart types below |
| Period comparison | Current vs previous period |
| Alerts | Abnormal consumption spikes, missing data |
| Export | PDF and CSV export |

### Time views (daily readings — not hourly)

The dashboard is based on **daily cumulative readings**, not hourly live data.

| View | Behavior |
|------|----------|
| **Weekly** | Grouped weekly consumption |
| **Monthly** | Monthly consumption totals |
| **Last 30 Days** | Daily consumption for the rolling 30-day window |
| **Yearly** | Year-over-year compare (e.g. 2024 vs 2025 vs 2026) |

### Chart types

Line, bar, stacked bar, area, donut, horizontal ranking, comparison chart.

### Meter comparison

Users select two or more meters (or COP groups) to compare on the same chart.

| Category | Examples |
|----------|----------|
| Water | Main Kahramaa vs TSE; Building A vs Building B |
| Electricity | Main LV Panel vs Chiller Panel; Generator vs Kahramaa |
| BTU | BTU-01 vs BTU-02; Chiller Plant vs AHU; by location |
| COP | COP Group 1 vs Group 2; current year vs previous year |

### Category dashboards (tabs shown only when configured)

### Design principles

- Visually polished, smooth transitions, production-ready
- Bilingual AR/EN with RTL support
- Reference legacy for **calculation logic only**, not UI layout or styling
- Use a cohesive design system (typography, spacing, color tokens) defined in shared package theme

---

## 6. Workflows

### 6.1 Admin App

1. Create organization
2. Add site (type, location, bilingual names)
3. Add meters under site:
   - Select category from `meter_categories` (active; includes fuel and future types)
   - Select source and unit from category-scoped `meter_sources` / `meter_units`
   - Select level (main / sub)
   - If sub: pick parent from same site + category
   - Set meter_multiplier if needed
4. Assign users to sites with role and permission flags
5. Define COP groups (optional, when site has cooling + electricity meters):
   - Name and description
   - Link output meters (`supports_cop_output`) with weights
   - Link input meters (`supports_electric_input`) with weights

### 6.2 Entry App

1. Login (Supabase Auth)
2. List assigned sites only
3. Select site → select category from **active categories that have meters at this site** (not hardcoded Water/Electricity/BTU only)
4. List meters for site + category (active, entry-eligible)
5. **Technician:** date fixed to today's Qatar business date — no date picker
6. Enter cumulative raw reading; optionally upload image
7. If today's reading exists: show **read-only submitted** state with message: *"Reading already submitted. Contact admin for correction."*
8. No edit or delete buttons for technicians
9. System computes `normalized_value`; no manual COP entry

### 6.3 Dashboard App

1. Login
2. List assigned sites only
3. Select site
4. Show tabs/sections dynamically from `meter_categories` present at site (+ COP tab only when COP groups exist)
5. **Daily readings only** — no hourly/live charts
6. Time views: Weekly, Monthly, Last 30 Days, Yearly (year-over-year compare)
7. Chart types: line, bar, stacked bar, area, donut, horizontal ranking, comparison
8. Multi-meter comparison within category
9. Relationship map from `parent_meter_id`
10. Consumption = day-over-day delta of cumulative readings (normalized)
11. COP charts from configured groups

---

## 7. Consumption Calculation

Readings are **cumulative** (same as legacy). Daily consumption:

```
consumption(date) = max(0, reading(date) − reading(date − 1))
```

Both values normalized before subtraction. First reading for a meter produces no consumption (baseline only).

### Virtual / Residual Meters (Legacy WF)

The legacy system computed virtual meter `WF` (Water Features) as main Kahramaa minus sub-meters. The new schema supports this via:

```
meter_kind = virtual
calculation_type = parent_minus_children
parent_meter_id = <main meter>
```

Consumption computed at dashboard query time: `max(0, parent_daily − Σ children_daily)`. No UI in v1; schema and domain calculator ready. See seed file for commented WF example.

---

## 8. Unit System

### Water (base: m³)

| Unit | Factor to m³ |
|------|--------------|
| m³ | 1 |
| liter | 0.001 |
| dm³ | 0.001 |
| gallon | 0.00378541 |

### Electricity (base: kWh)

| Unit | Factor to kWh | Notes |
|------|---------------|-------|
| kWh | 1 | |
| MWh | 1000 | |
| Wh | 0.001 | |
| kVAh | 1 | Approximate; not physically equivalent without power factor |

### BTU / Cooling (base: kWh thermal)

| Unit | Factor to kWh thermal |
|------|----------------------|
| kWh thermal | 1 |
| BTU | 0.000293071 |
| ton-hour | 3.51685 |
| RT-hour | 3.51685 |

Unit factors are stored on each meter at creation time (from enum lookup). **Changes blocked by database trigger after readings exist.** See section 4.6.

---

## 9. Storage

**Bucket:** `meter-images` (private)

**Path pattern:**
```
{organization_id}/{site_id}/{meter_category}/{reading_date}/{meter_id}.jpg
```

Images linked via `meter_readings.image_url`. Upload restricted to technicians and site admins for assigned sites.

See `supabase/migrations/003_storage.sql`.

---

## 10. Security Model

- Supabase Auth (email/password or SSO — TBD)
- Row Level Security on all tables including `reading_audit_logs`
- Storage policies on `meter-images`
- `profiles` synced from `auth.users` via trigger
- **User approval gate:** `is_approved_active_user()` required for all site/meter/reading access (draft `004_user_approval.sql`)
- Pending/rejected/suspended users may read **own profile only** (for status messaging)
- No self-assignment: `user_site_access` INSERT restricted to `super_admin` / `site_admin` for managed sites
- No public anon policies in production

See `supabase/migrations/002_rls_policies.sql` and draft `004_user_approval.sql`.

---

## 11. Data Migration from Legacy

The Firebase prototype stored:
- Meters in SharedPreferences (local)
- Readings in Firestore date-keyed documents
- Images in Firebase Storage

Migration plan: [LEGACY_FIREBASE_MIGRATION_PLAN.md](./LEGACY_FIREBASE_MIGRATION_PLAN.md)

---

## 12. Implementation Phases

| Phase | Deliverable | Status |
|-------|-------------|--------|
| 0 | Planning docs + SQL drafts | Done |
| 1A–1B | Schema + RLS + staging bootstrap | Done |
| 1C–1D | Flutter scaffold + entry_app MVP | Done |
| 1E | User approval migration + admin pending-users UI | **Planned** (draft `004_user_approval.sql`) |
| 2 | dashboard_app read views | Planned |
| 3 | admin_app CRUD + user approval screens | Planned |
| 4 | MOEHE HQ data migration from Firebase | Planned |
| 5 | Production hardening | Planned |

---

## 13. Related Documents

| Document | Purpose |
|----------|---------|
| [FLUTTER_ARCHITECTURE.md](./FLUTTER_ARCHITECTURE.md) | App structure and shared packages |
| [LEGACY_FIREBASE_MIGRATION_PLAN.md](./LEGACY_FIREBASE_MIGRATION_PLAN.md) | Firebase → Supabase migration |
| [RISKS_AND_DECISIONS.md](./RISKS_AND_DECISIONS.md) | Open decisions and risks |
| `supabase/migrations/001_schema.sql` | Table and enum definitions |
| `supabase/migrations/002_rls_policies.sql` | Row Level Security |
| `supabase/migrations/003_storage.sql` | Storage bucket and policies |
| `supabase/seed/001_seed_moehe_hq.sql` | Sample MOEHE HQ data |
