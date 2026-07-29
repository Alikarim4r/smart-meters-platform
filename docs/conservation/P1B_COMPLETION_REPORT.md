# P1B Completion Report — Period Comparisons

**Status: P1B PASS**  
**Date (UTC):** 2026-07-29  
**Branch:** `feature/conservation-management`  
**Environment:** Staging (`iqcxgtpcfhoapnklxdyl`)  
**Git commit SHA:** *(see footer after commit)*  

**Next:** Stop for approval before **P1C**.

---

## 1. Migration

**No new migration required.**  
P1A already introduced flag keys including `period_compare` (default OFF via missing rows).

056–062 backlog untouched.

---

## 2. Files created

| Path |
|------|
| `packages/smart_meters_core/lib/conservation/domain/period_windows.dart` |
| `packages/smart_meters_core/lib/conservation/models/period_comparison_result.dart` |
| `packages/smart_meters_core/lib/conservation/services/period_comparison_service.dart` |
| `packages/smart_meters_core/test/conservation/period_comparison_service_test.dart` |
| `apps/dashboard_app/lib/providers/conservation_providers.dart` |
| `apps/dashboard_app/lib/widgets/conservation/period_comparison_cards.dart` |
| `apps/dashboard_app/lib/widgets/system/site_conservation_panel.dart` |
| `docs/conservation/P1B_COMPLETION_REPORT.md` |
| `docs/regression/snapshot_POST_P1B_*.json` / `REGRESSION_POST_P1B_*.md` / `COMPARE_POST_P1B.md` |

## 3. Existing files modified

| Path | Change |
|------|--------|
| `packages/smart_meters_core/lib/conservation/conservation.dart` | Export P1B symbols |
| `apps/dashboard_app/lib/utils/site_system_navigation.dart` | Optional `conservation` section + flag-gated section list (defaults unchanged) |
| `apps/dashboard_app/lib/screens/site_dashboard_screen.dart` | Wire gated Conservation panel |
| `apps/dashboard_app/lib/widgets/shell/dashboard_sidebar.dart` | Show Conservation nav **only** when flags ON |
| `apps/dashboard_app/lib/l10n/app_strings.dart` | Conservation label |
| `apps/dashboard_app/test/site_navigation_test.dart` | Gate visibility tests |

**Not modified:** report exporters, consumption helpers’ semantics, entry_app, admin_app business logic, `meter_readings`.

---

## 4. PeriodComparisonService design

- Pure / read-only service in `smart_meters_core`.
- UI cards **display only**; no business math in widgets.
- Consumption via existing `periodConsumptionFromEndpoints` (normalized endpoints).
- Per-utility aggregation (Water/Electricity/BTU/Fuel) — incompatible units rejected.
- Combined confidence = **min(current, comparison)**.

### Previous Period (equal length)

```
length = inclusiveDayCount(currentStart, currentEnd)
prevEnd = currentStart - 1 day
prevStart = prevEnd - (length - 1) days
```

Example: 1–29 Jul (29 days) → **2–30 Jun** (29 days). Never compares 29 days to a full 30/31-day month.

### Same Period Last Year (calendar-aware)

```
start' = shiftCalendarYears(currentStart, -1)
end'   = shiftCalendarYears(currentEnd, -1)
```

`shiftCalendarYears` clamps day-of-month (Feb 29 → Feb 28 in non-leap years).  
**Not** `DateTime.subtract(Duration(days: 365))`.

Example: 01–29 Jul 2026 → 01–29 Jul 2025 (not full July 2025).

---

## 5. Partial periods / insufficient data / zeros

| Case | Behavior |
|------|----------|
| Missing endpoints either side | `Insufficient Data` — no fake 0% / No Change / Saving |
| Completeness < 50% either side | `Insufficient Data` |
| Previous = 0, current ≠ 0 | Absolute kept; **Percentage = N/A** |
| Current = 0, previous > 0, weak completeness/confidence | `Insufficient Data / Low Confidence` (not −100%) |
| Current = 0, previous > 0, strong complete data | −100% · Decrease (not Saving) |
| Both 0, complete | 0% · No significant change |

Allowed labels: Higher/Lower than previous period, Increase/Decrease, No significant change, Compared with same period last year.  
**Forbidden:** Energy/Water/Verified Saving.

---

## 6. Confidence across both periods

```
combined = min(current_period_confidence, comparison_period_confidence)
```

Recorded in `CalculationMeta.notes` and `PeriodComparisonResult.confidenceScore`.

### CalculationMeta example (Example A)

```
calculation_method: conservation_period_compare_v1
period_start / period_end: current window
data_completeness: current completeness
confidence_score: min(current, comparison)
notes include comparison window, both confidences, equal_length_days
```

---

## 7. Numeric examples

### Example A — Current > Previous

- Current 1–10 Jul: endpoints 150 → 300 ⇒ **150**
- Previous 21–30 Jun: 100 → 150 ⇒ **50**
- Absolute **+100**, Percentage **+200%**, label **Higher than previous period · Increase**

### Example B — Current < Previous

- Current ⇒ **20**, Previous ⇒ **100**
- Absolute **−80**, Percentage **−80%**, label **Lower … · Decrease** (no Saving)

### Example C — Insufficient historical data

- Only readings inside current window (no comparison endpoints)
- Status **insufficientData**, Percentage **N/A**, message cites missing comparison endpoints

---

## 8. Feature flags status

| Flag | Status |
|------|--------|
| `conservation_module` | **OFF** (no rows) |
| `period_compare` | **OFF** |
| Other P1 flags | **OFF** |

UI: Conservation nav/panel only when **both** ON. With defaults OFF, **no visual change** to default dashboard navigation.

---

## 9. Screens / widgets

- `SiteConservationPanel` + `PeriodComparisonCard`
- Sidebar / mobile chips append Conservation only when gate passes
- Default `mainSiteDashboardSections` unchanged

---

## 10. Tests

| Suite | Result |
|-------|--------|
| P1B period comparison unit tests | PASS (23) |
| All conservation tests | PASS (38) |
| smart_meters_core | PASS (157) |
| dashboard_app | PASS (77) |
| entry_app | PASS (13) |
| admin_app | PASS (21) |

### Regression POST_P1B

**RESULT: PASS — protected metrics unchanged**  
`meter_readings` = **43845** (Conservation did not mutate).  
Migration max remains **063** (no new migration).

Dashboard / reports / COP: suites green; COP counts unchanged; reports code untouched.

---

## 11. Performance

When flags OFF: provider short-circuits — **no readings query**.  
When ON: single bounded `meter_readings` select from  
`min(prevStart, yoyStart) − 1 day` through `currentEnd` only (endpoint baseline + both windows).

---

## 12. Known limitations

1. Completeness without `expectedIntervalDays` uses share of meters with valid endpoints (not invented daily).  
2. Correction impact uses optional correction dates on series (UI loader does not yet join audit logs — confidence still conservative via completeness/endpoints).  
3. Flags remain OFF — Conservation UI not visible on Staging until explicit enable.  
4. Not added to PDF/Excel reports (deferred).

---

## 13. Rollback readiness

1. Keep flags OFF (current).  
2. Revert P1B commits.  
3. No new tables to preserve/drop.

---

## 14. Confirmation

- Read-only; **no** writes to `meter_readings` / meters / audit / policy.  
- No Saving terminology.  
- **P1C not started.**

---

## Git commit SHA

*(filled on commit)*
