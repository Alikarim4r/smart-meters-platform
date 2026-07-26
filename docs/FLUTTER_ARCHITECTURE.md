# Flutter Architecture Plan

**Project:** smart-meters-platform  
**Status:** Phase 1G — configurable categories on staging; entry_app dynamic category picker  
**Last updated:** 2026-07-04

---

## 1. Overview

Three separate Flutter applications share a common Dart package for domain logic, Supabase integration, and UI components. This mirrors the legacy split (water app, electricity app, dashboard, admin) but consolidates shared code and uses a single Supabase backend.

```
smart-meters-platform/
├── packages/
│   └── smart_meters_core/          # Shared Dart package
├── apps/
│   ├── admin_app/
│   ├── entry_app/
│   └── dashboard_app/
└── supabase/
```

**Do not create these directories until schema is approved and SQL is executed.**

---

## 2. Applications

### 2.1 admin_app

**Users:** `super_admin`, `site_admin`

**Reading correction (admin only):**
- Date picker for backfill and corrections
- Edit/delete/restore readings for permitted sites
- **Required correction reason/note** on changes
- Audit history panel per meter/reading

**Responsibilities:**
- Organization CRUD (super_admin only)
- Site CRUD
- Meter CRUD with hierarchy editor (parent_meter_id)
- User management and site assignment
- COP group configuration
- Unit and source selection per category (from `meter_units` / `meter_sources`; super_admin manages catalog)

**Key screens:**
| Screen | Purpose |
|--------|---------|
| Login | Supabase Auth |
| Dashboard | Quick stats, navigation |
| **Pending users** | List `approval_status = pending`; approve / reject |
| **User detail** | Assign role, assign sites, suspend, remove site access |
| Organizations | List/create/edit (super_admin) |
| Sites | List/create/edit per org |
| Meters | CRUD, hierarchy map, category filter |
| Users | Profile list, site access assignment |
| COP Groups | Configure BTU ↔ electricity links |

**Reference from legacy:** `meters_admin_app/lib/features/admin/admin_screen.dart`, `admin_relationship_map.dart`

### 2.2 entry_app

**Users:** `technician` (primary), `site_admin` with write access for field entry if needed

**Access gate:** Implemented in `AuthGate` (`smart_meters_core`). Users with `approval_status != approved` or `is_active = false` never reach the entry flow. Dedicated status screens shown (see Section 4.1).

**Technician UI rules:**
- Date **fixed** to `current_business_date()` (Asia/Qatar) — **no date picker**
- **No edit** button after submit
- **No delete** button
- If today's reading exists: read-only with message *"Reading already submitted. Contact admin for correction."*
- Submit creates only; corrections require site admin

**Responsibilities:**
- Site selection (assigned sites only)
- Category selection from **active `meter_categories` that have meters at the selected site** (dynamic, not hardcoded)
- Meter list for site + category
- Cumulative reading entry by date
- Optional image upload to `meter-images` bucket
- Validation: previous reading, spike detection

**Key screens:**
| Screen | Purpose |
|--------|---------|
| Login | Supabase Auth |
| Site picker | Assigned sites |
| Category picker | Dynamic from `meter_categories` at site; system icons for water/electricity/btu/fuel; fallback for custom |
| Entry | Meter list + reading inputs + camera |
| Relationship map | Optional inline view (read-only) |

**Reference from legacy:** `water_readings_app` and `electricity_readings_app` entry screens

**Category UI (post-006):** Query `meter_categories` joined with meters at site. Use `icon` / `code` for known system categories; generic utility icon for unknown (e.g. steam). Do not hardcode three tabs only.

### 2.3 dashboard_app

**Users:** `viewer`, `site_admin`, `technician` (read-only dashboard)

**Important:** This is a **new production dashboard**. Do not copy the legacy `meters_dashboard_app` UI. Port calculation logic only.

**Responsibilities:**
- Site selection (assigned sites only)
- Dynamic category tabs based on site meters and COP configuration
- Professional layout: sidebar + top filter bar + KPI cards
- Data completeness indicators
- Consumption charts with period comparison
- Relationship map from `parent_meter_id` (including virtual meters when configured)
- Alerts for abnormal consumption and missing readings
- Reports and PDF/CSV export
- Reading audit log viewer (site_admin / super_admin only)

See **Section 6 — Professional Dashboard Design System** for full UI specification.

**Key screens:**
| Screen | Purpose |
|--------|---------|
| Login | Supabase Auth |
| Site picker | Assigned sites (sidebar or modal) |
| Dashboard shell | Sidebar nav + top filter bar |
| Water Dashboard | KPIs, charts, hierarchy, completeness |
| Electricity Dashboard | KPIs, charts, hierarchy, completeness |
| BTU Dashboard | Cooling energy consumption |
| COP Performance Dashboard | COP ratio, input/output, trends |
| Alerts | Spike and missing-data notifications |
| Reports | Export PDF/CSV |
| Audit log | Reading change history (admin roles) |

**Reference from legacy (logic only):** consumption calculator, unit converter — **not** dashboard_screen.dart layout.

---

## 3. Shared Package: smart_meters_core

### 3.1 Package structure

```
packages/smart_meters_core/
├── lib/
│   ├── smart_meters_core.dart       # Barrel export
│   ├── config/
│   │   └── supabase_config.dart     # URL, anon key (env-based)
│   ├── models/
│   │   ├── organization.dart
│   │   ├── site.dart
│   │   ├── meter.dart
│   │   ├── meter_reading.dart
│   │   ├── profile.dart
│   │   ├── user_site_access.dart
│   │   ├── cop_group.dart
│   │   ├── reading_audit_log.dart
│   │   └── enums.dart               # Mirrors Postgres enums
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── organization_repository.dart
│   │   ├── site_repository.dart
│   │   ├── meter_repository.dart
│   │   ├── reading_repository.dart
│   │   ├── reading_audit_repository.dart
│   │   ├── profile_repository.dart
│   │   ├── user_site_access_repository.dart
│   │   ├── cop_group_repository.dart
│   │   └── storage_repository.dart
│   ├── domain/
│   │   ├── meter_unit_converter.dart
│   │   ├── consumption_calculator.dart
│   │   ├── virtual_meter_calculator.dart
│   │   ├── cop_calculator.dart
│   │   └── meter_tree_builder.dart
│   ├── providers/                   # Riverpod providers (see Section 5)
│   │   ├── auth_provider.dart
│   │   ├── site_selection_provider.dart
│   │   ├── organization_provider.dart
│   │   ├── meter_category_provider.dart
│   │   ├── dashboard_filter_provider.dart
│   │   ├── permissions_provider.dart
│   │   ├── readings_provider.dart
│   │   ├── selected_time_grouping_provider.dart
│   │   ├── selected_chart_type_provider.dart
│   │   ├── selected_meters_for_comparison_provider.dart
│   │   ├── dashboard_comparison_provider.dart
│   │   ├── yearly_comparison_provider.dart
│   │   └── last30_days_provider.dart
│   ├── widgets/
│   │   ├── dashboard/
│   │   │   ├── dashboard_shell.dart
│   │   │   ├── sidebar_nav.dart
│   │   │   ├── top_filter_bar.dart
│   │   │   ├── kpi_card_grid.dart
│   │   │   ├── completeness_panel.dart
│   │   │   ├── consumption_chart.dart
│   │   │   ├── period_comparison_chart.dart
│   │   │   ├── alerts_panel.dart
│   │   │   └── relationship_map.dart
│   │   ├── site_picker.dart
│   │   └── category_picker.dart
│   ├── l10n/
│   │   └── app_strings.dart         # AR/EN
│   └── theme/
│       └── app_theme.dart
├── test/
│   ├── meter_unit_converter_test.dart
│   ├── consumption_calculator_test.dart
│   └── cop_calculator_test.dart
└── pubspec.yaml
```

### 3.2 Dependencies (planned)

| Package | Purpose |
|---------|---------|
| `supabase_flutter` | Auth, database, storage |
| `flutter_riverpod` | State management (decided) |
| `riverpod_annotation` + `riverpod_generator` | Code-generated providers (optional) |
| `freezed` + `json_serializable` | Immutable models |
| `intl` | Date/number formatting, AR/EN |
| `fl_chart` | Charts (legacy uses similar) |
| `image_picker` | Reading photos |
| `pdf` / `printing` | Report export |

### 3.3 Models

Dart models mirror Supabase tables. Use `@JsonKey` for snake_case column mapping.

```dart
// Implemented in smart_meters_core (006 read-path)
class MeterCategoryConfig {
  final String id;
  final String code;
  final String nameEn;
  final String? nameAr;
  final String baseUnitCode;
  final String? icon;
  final String? color;
  final bool supportsCopOutput;
  final bool supportsElectricInput;
  final bool isConsumptionCategory;
}

class MeterUnitConfig {
  final String id;
  final String categoryId;
  final String code;
  final String nameEn;
  final double unitToBaseFactor;
  final bool isBase;
}

class MeterSourceConfig {
  final String id;
  final String categoryId;
  final String code;
  final String nameEn;
}

class Meter {
  final String id;
  final String siteId;
  final String meterCode;
  final String nameEn;
  final String nameAr;
  final String categoryId;
  final String sourceId;
  final String unitId;
  final MeterCategoryConfig? categoryConfig;
  final MeterSourceConfig? sourceConfig;
  final MeterUnitConfig? unitConfig;
  // Legacy enum fields retained during transition:
  final MeterCategory category;
  final MeterSource source;
  final MeterUnit unit;
  final double unitToBaseFactor;
  final String baseUnit;
  // ...
}
```

`MeterCategory` / `MeterSource` / `MeterUnit` enums in `enums.dart` remain during transition; new code should prefer config models + FK IDs. Keep enums in sync with legacy Postgres enums until columns are dropped.

### 3.4 Repositories

Each repository wraps Supabase client calls with RLS-aware queries:

| Repository | Key methods |
|------------|-------------|
| `AuthRepository` | signIn, signOut, currentUser, sessionStream |
| `ProfileRepository` | getProfile, listPendingUsers (admin RPC) |
| `UserApprovalRepository` | approveUser, rejectUser, suspendUser (admin RPCs) |
| `SiteRepository` | getAssignedSites, getSiteById, create, update |
| `MeterRepository` | getBySiteAndCategory, getAvailableCategoriesForSite (from `meter_categories`), getTree, create, update |
| `MeterCatalogRepository` | getActiveCategories, getUnitsForCategory, getSourcesForCategory, getCategoriesForSite |
| `ReadingRepository` | getByMeterAndDateRange, upsertReading, getPreviousReading |
| `ReadingAuditRepository` | getBySite, getByMeter, getByReading (admin only) |
| `StorageRepository` | uploadMeterImage, getSignedUrl, buildPath |
| `CopGroupRepository` | getBySite, create, linkMeters |

**No anonymous auth.** All calls require authenticated session.

### 3.5 Domain logic (ported from legacy)

| Module | Legacy source | Changes |
|--------|---------------|---------|
| `MeterUnitConverter` | `lib/domain/meter_unit_converter.dart` | Use DB-stored factors; enum-driven |
| `ConsumptionCalculator` | `lib/domain/consumption_calculator.dart` | Query-based; supports virtual meters |
| `VirtualMeterCalculator` | New | `parent_minus_children`, `sum_children` |
| `CopCalculator` | New | Weighted sum of BTU/electricity deltas |
| `MeterTreeBuilder` | New (not legacy arrow map UI) | Build from `parent_meter_id`; v1 one-level |

**Normalization formula (unchanged):**
```
normalized = raw × unit_to_base_factor × meter_multiplier
consumption = max(0, today_normalized − yesterday_normalized)
```

**COP formula (new):**
```
cop(date) = Σ(btu_daily_consumption × weight) / Σ(electricity_daily_consumption × weight)
```

Guard against division by zero; show N/A when electricity input is 0.

---

## 4. Authentication Flow

```
App launch
  → Supabase.initialize(url, anonKey)
  → Check session
  → If no session → LoginScreen
  → If session → load profile
  → Approval gate (Section 4.1)
  → Route by role:
      admin_app:  super_admin | site_admin (approved + active)
      entry_app:  technician | site_admin (approved + active + site assigned)
      dashboard_app: viewer | site_admin | technician (approved + active + can_read)
```

Profile loaded from `profiles` table. Site list from `user_site_access` join `sites`. Super admin bypasses site filter.

### 4.1 Approval gate (all apps)

After sign-in, load `profiles` row (user can always read own profile). **Do not rely on UI alone** — RLS blocks data if approval fails.

| `approval_status` | `is_active` | entry_app | dashboard_app | admin_app |
|-------------------|-------------|-----------|---------------|-----------|
| `pending` | `false` | "Your account is pending admin approval." | Same message | N/A (not admin) |
| `rejected` | `false` | "Your account request was rejected." | Same | N/A |
| `suspended` | `false` | "Your account is suspended. Contact admin." | Same | N/A |
| `approved` | `true` | Continue if role + sites OK | Continue if role + sites OK | Continue if admin role |
| `approved` | `true`, no sites | "No sites assigned. Contact admin." | Same | — |

**Sign-up (future registration screen):**

```dart
// auth.signUp metadata — never send technician/super_admin as role
await supabase.auth.signUp(
  email: email,
  password: password,
  data: {
    'full_name': fullName,
    'requested_role': 'technician_request', // or omit for viewer applicant
  },
);
```

`handle_new_user` sets `approval_status = pending`, `is_active = false`. No site rows created.

### 4.2 Admin approval flow (admin_app — planned)

```
Pending users list
  → Select user
  → Approve:
       call admin_approve_user(userId, role: technician, siteIds: [...])
  → Reject:
       call admin_reject_user(userId, note)
  → Suspend:
       call admin_suspend_user(userId, note)
  → Remove site:
       delete user_site_access row (admin RLS)
```

**Rules:**

- `super_admin`: approve any user; assign any site
- `site_admin`: approve/reject pending users; assign only sites they `can_manage_site`
- Technicians cannot call approval RPCs or insert `user_site_access` for themselves

### 4.3 Profile model (implemented)

`ApprovalStatus` enum and extended `Profile` in `packages/smart_meters_core/lib/models/`.  
`AuthGate` in `app_bootstrap.dart` handles approval status, role gate, and optional `SiteAccessRequirement` (read/write).

---

## 5. State Management (Riverpod)

**Decision:** Use **Riverpod** for all new apps. The platform has complex cross-cutting state that benefits from composable, testable providers:

| Provider | Scope | Responsibility |
|----------|-------|----------------|
| `authProvider` | Global | Session, profile, sign-in/out, approval status |
| `approvalGateProvider` | Global | Derived UI state: pending / rejected / suspended / no-sites |
| `permissionsProvider` | Global | Role + site access flags derived from profile |
| `assignedSitesProvider` | Global | Sites user can access |
| `selectedOrganizationProvider` | Global (admin) | Current org context |
| `selectedSiteProvider` | Per-app | Active site; persisted in session |
| `selectedCategoryProvider` | Entry/dashboard | water / electricity / btu |
| `dashboardFilterProvider` | Dashboard | Site, category, date range |
| `selectedTimeGroupingProvider` | Dashboard | Weekly / Monthly / Last 30 Days / Yearly |
| `selectedChartTypeProvider` | Dashboard | Line, bar, stacked bar, area, donut, ranking, comparison |
| `selectedMetersForComparisonProvider` | Dashboard | Multi-select meters for overlay charts |
| `dashboardComparisonProvider` | Dashboard | Current vs previous period |
| `yearlyComparisonProvider` | Dashboard | 2024 vs 2025 vs 2026 year-over-year |
| `last30DaysProvider` | Dashboard | Rolling 30-day daily series |
| `metersProvider` | Scoped to site+category | Meter list + tree |
| `readingsProvider` | Scoped to site+date range | Async readings fetch |
| `copGroupsProvider` | Scoped to site | COP configuration |
| `dashboardKpiProvider` | Scoped to filters | Computed KPIs |
| `alertsProvider` | Scoped to site | Missing data, spikes |
| `auditLogsProvider` | Admin | Reading audit trail |

```dart
// Example pattern (not implemented yet)
@riverpod
class SelectedSite extends _$SelectedSite {
  @override
  Site? build() => null;

  void select(Site site) => state = site;
  void clear() => state = null;
}

@riverpod
Future<List<Site>> assignedSites(AssignedSitesRef ref) async {
  final auth = ref.watch(authProvider);
  return ref.read(siteRepositoryProvider).getAssignedSites(auth.userId);
}
```

**Why not Provider:** Legacy apps used Provider, but the new platform combines auth, org/site/category selection, dashboard filters, permissions, async Supabase queries, and report generation — Riverpod's async and family providers reduce boilerplate and improve testability.

Each app wraps root in `ProviderScope`. Shared providers live in `smart_meters_core`; app-specific providers in each app's `lib/providers/`.

---

## 6. Professional Dashboard Design System

The `dashboard_app` is a greenfield production UI. **Do not replicate** the legacy prototype layout, arrow styling, or screen structure.

### 6.1 Shell layout

```
┌──────────┬──────────────────────────────────────────────────────┐
│          │  Top filter bar                                       │
│          │  [Site ▼] [Category ▼] [Date range ▼] [Grouping: Weekly|Monthly|30d|Yearly ▼]   │
│  [Chart type ▼] [Meters ▼ multi-select] [Compare prev period □]                  │
│ Sidebar  ├──────────────────────────────────────────────────────┤
│          │  Category tabs (dynamic)                              │
│ • Water  │  [Water] [Electricity] [BTU] [COP]                   │
│ • Elec   ├──────────────────────────────────────────────────────┤
│ • BTU    │  KPI cards row                                        │
│ • COP    │  [Total] [Avg daily] [Peak] [vs prev period]           │
│ • Alerts │  [Completeness %]                                      │
│ • Reports├──────────────────────────────────────────────────────┤
│          │  Main content area                                    │
│          │  Charts + relationship map + tables                   │
└──────────┴──────────────────────────────────────────────────────┘
```

### 6.2 Time views (daily readings — not hourly)

No hourly or live charts. All views derive from **daily cumulative readings**.

| View | Data shape |
|------|------------|
| **Weekly** | Consumption grouped by week |
| **Monthly** | Monthly totals |
| **Last 30 Days** | One bar/point per day for rolling 30 days |
| **Yearly** | Year-over-year series (2024 vs 2025 vs 2026) |

### 6.3 Chart types

Line, bar, stacked bar, area, donut, horizontal ranking, comparison chart (multi-series).

### 6.4 Meter comparison

`selectedMetersForComparisonProvider` drives overlay charts. Examples:

- Water: Main Kahramaa vs TSE; Building A vs Building B
- Electricity: Main LV Panel vs Chiller Panel
- BTU: BTU-01 vs BTU-02; Chiller Plant vs AHU
- COP: Group 1 vs Group 2; this year vs last year

### 6.5 Shared components

- **KPI cards** — large numeric summaries with trend arrows
- **Data completeness panel** — meters missing readings for selected range
- **Relationship map** — modern node/edge diagram (not legacy arrow paths)
- **Charts** — fl_chart; type from `selectedChartTypeProvider`; grouping from `selectedTimeGroupingProvider`
- **Period comparison** — `dashboardComparisonProvider` / `yearlyComparisonProvider`
- **Alerts panel** — spike warnings, missing entry reminders
- **Export** — PDF report builder, CSV download

### 6.4 Design tokens

Define in `smart_meters_core/theme/`:
- Color palette (primary, surface, alert, success)
- Typography scale (headline, body, KPI numbers)
- Spacing grid (4/8/16/24/32)
- Border radius, elevation
- Dark mode support
- RTL layout mirroring for Arabic

### 6.5 Responsive breakpoints

| Breakpoint | Layout |
|------------|--------|
| Mobile (<600) | Collapsible sidebar drawer; stacked KPIs |
| Tablet (600–1024) | Narrow sidebar; 2-column KPI grid |
| Desktop (>1024) | Full sidebar + multi-column dashboard |

---

## 7. Localization

- Arabic (AR) and English (EN)
- RTL support for Arabic
- Bilingual meter/site names from DB (`name_en`, `name_ar`)
- Port strings from legacy `app_strings.dart`

---

## 8. Platform Targets

| App | Android | iOS | Web | Desktop |
|-----|---------|-----|-----|---------|
| admin_app | ✓ | ✓ | ✓ | Optional |
| entry_app | ✓ | ✓ | — | — |
| dashboard_app | ✓ | ✓ | ✓ | Optional |

Entry app prioritizes mobile (camera for reading photos).

---

## 9. Environment Configuration

Each app uses `--dart-define` or `.env` (via `flutter_dotenv`):

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
```

**Do not commit keys.** Use CI secrets for builds.

---

## 10. Testing Strategy

| Layer | Approach |
|-------|----------|
| Unit | Domain calculators, unit converter, tree builder |
| Repository | Mock Supabase client |
| Widget | Dashboard shell, KPI cards, site picker |
| Provider | Riverpod provider unit tests with overrides |
| Integration | Against Supabase local (supabase start) or staging |

Port integration test patterns from legacy `README-INTEGRATION-TESTS.md`.

---

## 11. Build Order (after SQL approval)

1. Create `packages/smart_meters_core` with models + enums
2. Add repositories with Supabase client
3. Port domain logic from legacy
4. Build `entry_app` first (simplest, validates readings flow)
5. Build `dashboard_app` (read-only, validates COP)
6. Build `admin_app` (full CRUD)
7. Migrate MOEHE HQ data from Firebase

---

## 12. Legacy App Mapping

| Legacy app | New app | Notes |
|------------|---------|-------|
| water_readings_app | entry_app | Unified; category = water |
| electricity_readings_app | entry_app | Unified; category = electricity |
| meters_dashboard_app | dashboard_app | **New UI**; logic only from legacy |
| meters_admin_app | admin_app | + orgs, sites, users, COP |

---

## 13. Not in Initial Flutter Scope

- Virtual meter admin UI (schema ready; calculator in domain layer)
- Offline/sync mode
- Push notifications
- Biometric login
- Multi-factor auth (unless Supabase Auth config adds it)
- Shared Flutter package published to pub.dev

These can be added in later phases.
