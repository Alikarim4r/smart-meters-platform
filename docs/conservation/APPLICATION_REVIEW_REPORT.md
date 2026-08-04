# Staging Application Review Report — Phases 1–6

**Date (UTC):** 2026-08-01  
**Branch:** `feature/conservation-management`  
**Environment:** Staging Supabase `iqcxgtpcfhoapnklxdyl`  
**Phase 7:** Not started. No Phase 7 plan created.

---

## Git HEAD used for review

```text
git rev-parse HEAD
6978865d424ed0087d32ecece0526b4cb1e76b04
```

### Last three commits

```text
6978865 docs: add Staging Application Review report and demo/flag scripts
40425d1 fix(dashboard): restore UtilitySystemPanel import and motif asset path
4bffdc1 docs: restore Phase 5 baseline SHA and set tip HEAD in Phase 6 report
```

No Phase 7 implementation commits present.

**Note:** HEAD includes a small build-unblock fix discovered during this review (`UtilitySystemPanel` import + motif asset path). Review scripts/demo SQL remain uncommitted local artifacts under `scripts/conservation/app_review_*` unless committed later.

---

## Devices / platforms

| Platform | Status |
|----------|--------|
| **Admin App** | macOS desktop (`flutter run -d macos`) — **launched** against Staging |
| **Dashboard App** | macOS desktop — **launched** after build fix |
| **Entry App** | Android phone — **not available** (`adb devices` empty) |
| Screenshots | **Not captured** — `screencapture` failed (`could not create image from display`; no GUI capture permission in agent environment) |

---

## Admin App status

| Check | Result |
|-------|--------|
| Staging config (`SUPABASE_URL` / anon key / `APP_ENV=staging`) | OK |
| Build / launch on macOS | **PASS** — `Meter Admin.app` built; Flutter VM running |
| Supabase init | **PASS** — `Supabase init completed` + session refresh |
| Foreground via `open` | Warning only (`Failed to foreground app; open returned 1`) — app still running |
| Missing motif asset (pre-fix) | Soft error in log: gray pattern asset missing → fixed to use shipped `meter_line_art_pattern_md.png` |
| Interactive click-through of every conservation screen | **Partial** — agent environment cannot drive macOS UI / take screenshots; data layer seeded for UI to render when operator walks screens |

**Admin destinations intended for operator walkthrough (with Review 6+7 flags ON + demo data):**

Sites · Targets · Baselines · Virtual Meters · Balance Groups · Site Conservation Profile · Opportunities · Investigations · Actions · Evidence · M&V · Tariffs · Portfolio · Data & Integrations · Import Center · Source Health · Automation Rules · Notifications

Automation Rules / Smart Meter / BMS / API / AI were **not** enabled operationally (per brief).

---

## Dashboard App status

| Check | Result |
|-------|--------|
| Initial build | **FAIL** — missing imports `UtilitySystemPanel`, `SiteReportsPanel` |
| Fix applied | **PASS** — imports restored; committed as `40425d1` |
| Motif asset | Soft fail → path fallback; committed in same fix |
| Relaunch | **PASS** — `Smart Meters.app` built; Supabase init completed |
| Review 0 (flags OFF) behavior | Not separately re-launched after flags enabled; operator should toggle Review 0 script then restart if visual OFF baseline needed |
| Conservation section + advanced cards | Flags Review 1–6 enabled in DB; demo M&V/forecast/portfolio rows present for UI |

---

## Entry Android status

**Incomplete — STOP condition for full product review.**

`adb devices` returned no devices.

### Required phone connection steps

1. On the Android phone: **Settings → About phone → tap Build number 7×** to enable Developer options.
2. **Settings → Developer options → USB debugging = ON** (and “Wireless debugging” if using Wi‑Fi).
3. Connect USB cable to the MacBook (or pair wirelessly).
4. Accept the **“Allow USB debugging?”** prompt on the phone.
5. On MacBook run:
   ```bash
   adb devices
   ```
   Expect a device id with state `device` (not `unauthorized`).
6. Then install/run Entry against Staging:
   ```bash
   cd /Users/ali-laptop/Downloads/smart-meters-platform
   set -a && source .env.local && set +a
   ./scripts/run_staging_app.sh entry -d <device_id>
   ```
7. Verify manually: Login → Site/Meter → Manual reading → Photo → Offline queue → Sync → Corrections; with `unified_ingestion` ON, Source badge; with flags OFF, baseline UI unchanged.

Until step 6–7 succeed on a physical phone, Entry Android review is **not complete**.

---

## Feature Flags sequence

| Review | Flags | Applied on Staging? |
|--------|-------|---------------------|
| **0** | All OFF | Yes (start) |
| **1** | `conservation_module`, `data_quality`, `period_compare` | Yes |
| **2** | + `targets`, `baseline`, `virtual_meters` | Yes |
| **3** | + balance / benchmark / anomalies / COP | Yes |
| **4** | + opportunities / investigations / actions / evidence | Yes |
| **5** | + savings / cost_roi / reports | Yes |
| **6** | + weather / occupancy / persistence / carbon / portfolio / forecast / reco | Yes |
| **7** | platform: `unified_ingestion`, `file_import`, `source_health`, `notification_center` | Yes |

**Not enabled (as required):** `smart_meter_sources`, `bms_sources`, `api_ingestion`, `automation_rules`, `ai_assistant`, `ocr_readiness`, `ingestion_jobs`.

Scripts: `scripts/conservation/app_review_flags_review0.sql` … `review7.sql`.

---

## Demo Data created

**Tag:** `APP_REVIEW_DEMO` / `app_review_demo*`  
**Scope:** Org `11111111-1111-4111-8111-111111111111` · Site **MOEHE HQ** `22222222-2222-4222-8222-222222222222`  
**Seed:** `scripts/conservation/app_review_demo_seed.sql`  
**Cleanup:** `scripts/conservation/app_review_demo_cleanup.sql` (ready; **not executed** — data retained for operator UI walkthrough)

| Entity | Count |
|--------|------:|
| Target (sentinel `999001`) | 1 |
| Approved Baseline | 1 |
| Virtual Meter `APP_REVIEW_DEMO_VM` | 1 |
| Balance Group | 1 |
| Opportunity | 1 |
| Investigation | 1 |
| Action | 1 |
| Evidence | 1 |
| Estimated M&V | 1 |
| Verified M&V | 1 |
| Tariff | 1 |
| Persistence | 1 |
| Emission factor | 1 |
| Carbon result | 1 |
| Forecast | 1 |
| Import preview batch (+ rows) | 1 |
| Site conservation profile update | 1 |
| **meter_readings** | **43845 unchanged** |
| Physical meters | **35 unchanged** |

Anomalies: no persisted anomaly table row — Opportunity uses `periodic_anomaly` source type for UI workflow demo.

---

## Screenshots inventory

| ID | Expected | Status |
|----|----------|--------|
| Admin launch / Sites / Conservation screens | Planned | **Not captured** (Admin interactive still Pending) |
| Dashboard Conservation (macOS operator walkthrough) | Planned | **Captured** — see [APPLICATION_REVIEW_OPERATOR_ADDENDUM.md](./APPLICATION_REVIEW_OPERATOR_ADDENDUM.md) + `screenshots/operator-visual-review-2026-08-01/` |
| Entry Android flows | Planned | **Blocked / Pending** (device review not completed for final gate) |

Operator Dashboard visual result: **PASS WITH UX FINDINGS** (documented in Operator Addendum). Phase 7 UX backlog recorded there — **not implemented**.

---

## UX observations

- Admin launches to Staging; branding motif previously threw a soft asset exception (gray PNG missing) — mitigated with fallback to existing MD asset.
- Dashboard build was broken by missing panel imports (likely drift during Phase merges) — fixed as review blocker only; **not** a UX redesign.
- **2026-08-01 operator visual (Dashboard Conservation):** layout whitespace, EN/AR mix, number formatting, RTL dates, unrealistic demo %, long single-page IA — full list in Operator Addendum (Phase 7 backlog only).
- Data & Integrations hub remains flag-gated; with Review 7 ON, Import Center / Source Health tiles appear when corresponding flags are on.
- Automation / AI / BMS not shown as operational (correct).

---

## Navigation observations

- Conservation Admin entry points remain under Site detail / advanced tools (not a new primary sidebar takeover) — aligns with “simple by default”.
- Dashboard Conservation section is flag-gated via `conservationSectionVisibleProvider`.
- Entry Source badge only when `unified_ingestion` ON (code path present; Android not verified).

---

## Performance / loading observations

- Admin/Dashboard macOS cold build: multi-minute (pods + compile) — expected for debug.
- Runtime: Supabase init + auth refresh succeeded without API crash in logs.
- No full performance profiling performed.
- **Recommendation (Phase 7):** measure Conservation panel query fan-out when many flags ON; ensure flags OFF adds no extra queries on Entry home.

---

## Empty states

- Before demo seed, Conservation tables were largely empty — UIs would show empty/gate messages.
- After seed + flags ON, lists should show at least one demo row per seeded entity.
- Import Center without `file_import` shows gated empty copy in hub.

---

## Errors and RLS issues

| Issue | Severity | Action |
|-------|----------|--------|
| Dashboard missing `UtilitySystemPanel` / `SiteReportsPanel` imports | Blocker | **Fixed** (`40425d1`) |
| Missing `meter_line_art_pattern_gray.png` | Soft | **Fixed** (fallback path) |
| `screencapture` / app foreground failures in agent env | Env limit | Documented; not an app defect |
| Emission factor insert required JWT for activate trigger during seed | Seed only | Handled in seed script |
| No RLS failures observed in seed/smoke for protected metrics | OK | — |

---

## Mobile issues

- No Android device connected → Entry review incomplete.
- Connection steps listed above.

---

## Recommended Phase 7 UX / performance fixes (do not implement now)

1. Dedicated gray motif asset or remove gray reference cleanly.
2. Operator QA checklist automation (integration/screenshot tests) for Conservation screens.
3. Dashboard Conservation loading: skeleton vs spinner consistency; avoid N+1 when many flags ON.
4. Admin Site detail conservation link density — progressive disclosure polish.
5. Import Center: full commit UX after preview (currently preview-first by design).
6. Source Health dashboard card wiring when `source_health` ON (widget exists; mount points).
7. Formal Android offline/photo/sync regression pack on device farm.
8. Consider committing `app_review_*` scripts into docs tooling set.

---

## Final Feature Flags state (Staging org)

- Conservation flags **enabled:** 27 (Review 1–6 cumulative set for org-wide rows).
- Platform flags **enabled:** 4 (`unified_ingestion`, `file_import`, `source_health`, `notification_center`).
- Smart Meter / BMS / API / Automation / AI / OCR / ingestion_jobs: **OFF**.

To return to Review 0:

```bash
npx supabase db query --linked -f scripts/conservation/app_review_flags_review0.sql
```

---

## Demo Data cleanup status

- **Retained on Staging** for human UI walkthrough.
- Cleanup script ready: `scripts/conservation/app_review_demo_cleanup.sql` (disables/deletes demo flags rows + demo entities; guards `meter_readings` count).
- **Not run** at end of this agent session (so demos remain visible).

---

## Final result

# **STOP**

### Why STOP (not PASS WITH UX FINDINGS)

1. **Entry Android Review BLOCKED** — `adb devices` empty; Login / reading / photo / offline / sync not exercised on device.
2. **Admin Interactive Visual Review** — data-layer + routes **PASS** (demo entities readable; Staging Admin launched); full GUI screenshots still operator-assisted (agent cannot capture macOS display).
3. Dashboard macOS visual walkthrough: **PASS WITH UX FINDINGS** — Phase 7 backlog only (not implemented).

### What passed / prepared

- Committed code on `feature/conservation-management` used; Git HEAD recorded.
- Admin + Dashboard kept on Staging; relaunched for this final operator pass.
- **Dashboard Conservation operator visual review (macOS):** PASS WITH UX FINDINGS; screenshots inventoried.
- Admin conservation screens prepared (Sites → MOEHE HQ links + Data & Integrations hub); no RLS blocker on demo reads.
- Demo data seeded safely; **not cleaned**.
- Feature flags **left ON** (Review set retained; Smart/BMS/API/Automation/AI still OFF).
- No Phase 7 work started.

### Required to flip FINAL → PASS WITH UX FINDINGS

Connect Android (`device`), run Entry Staging smoke on a disposable/demo meter, document any test reading, then update the Operator Addendum.

---

*Stop here. Do not start Phase 7, clean Demo Data, or disable Review flags until the operator approves.*

*Operator detail:* [APPLICATION_REVIEW_OPERATOR_ADDENDUM.md](./APPLICATION_REVIEW_OPERATOR_ADDENDUM.md)  
*Comprehensive status (AR):* [APPLICATION_REVIEW_COMPREHENSIVE.md](./APPLICATION_REVIEW_COMPREHENSIVE.md)
