# P1E Completion Report — Virtual Meters

**Status: P1E PASS**  
**Date (UTC):** 2026-07-29  
**Branch:** `feature/conservation-management`  
**Environment:** Staging (`iqcxgtpcfhoapnklxdyl`)  
**Git tip at report time (pre-commit):** `c23b024` + uncommitted P1E implementation

**Next:** Stop for approval before **Phase 2**. Do **not** start Phase 2 until approved.

---

## 1. Migration 066 — was it needed?

**Yes — additive only.**

Existing `meters.meter_kind` / `calculation_type` / `parent_meter_id` suffice for virtual **identity**, but **cannot** safely use `parent_meter_id` to attach physical children without mutating the physical main→sub→sub_sub hierarchy (forbidden by P1E constraints).

**File:** `supabase/migrations/066_conservation_virtual_meter_members.sql`  
**Applied via:** `db query --linked -f` (not `db push`). Tracked as version `066`.

### Schema added

| Object | Purpose |
|--------|---------|
| `conservation_virtual_meter_members` | Links virtual → contributors **without** changing physical `parent_meter_id` |
| Validate trigger | Virtual must be `virtual` + `sum_children`/`parent_minus_children`; same site/org |
| `conservation_meters_reject_parent_cycle` | Additive cycle guard on `meters.parent_meter_id` |
| RLS | SELECT has_site_access / super / owner; WRITE site_admin+manage / super / owner |

**Not changed:** physical meter semantics, reading helpers, reports, entry filters, 056–062 backlog.

Existing reading-rejection (001/002/019) remains authoritative for virtual meters.

---

## 2. Architecture

```
Virtual meter (meters row: kind=virtual, calc=sum_children|parent_minus_children)
  └─ members via conservation_virtual_meter_members  (children)
  └─ parent_meter_id on virtual row only for parent_minus_children (reference to main)

Physical meters: unchanged parent_meter_id, still entry-eligible, still receive readings.
```

Calculator expands nested virtuals to **physical leaves** (visited-set), then aggregates with existing `periodConsumptionFromEndpoints`.

---

## 3. Calculation types

| Type | Formula | UI label |
|------|---------|----------|
| `sum_children` | Σ child consumption | Sum of children |
| `parent_minus_children` | Parent − Σ children | Residual (Balance Difference) |

**Forbidden labels:** Leak, Leakage, Water Loss, Waste.  
Negative residual shown as-is + warning (never `max(0, …)`).

`direct_reading` remains physical-only (existing CHECK).

---

## 4. Hierarchy validation (defense in depth)

| Layer | Checks |
|-------|--------|
| UI | Create dialog + preview validation |
| `VirtualMeterValidation` | Self-parent, cycles, duplicate child/leaf, cross-site, utility/unit mismatch, invalid calc type, max depth 8 |
| DB | Members same-site/org; cycle trigger on `parent_meter_id`; reading rejection for virtual |

Double-counting prevented by leaf expansion with visited-set (`duplicate_leaf`).

---

## 5. Boundary / alignment / missing children

- No invented `periodStart−1`.
- Missing child ≠ 0; lowers completeness/confidence; may → Insufficient Data.
- Misaligned spans → warning **Misaligned Reading Periods** + confidence penalty.
- Confidence = min(contributors) with penalties (conservative).

---

## 6. Multipliers / units

- Prefer DB `normalized_value` with `meterMultiplier: 1` in dashboard preview (no double apply).
- Calculator applies series multiplier once when raw series provided (tested).
- Incompatible units rejected (no silent kWh+m³).

---

## 7. Feature flags / UI

| Gate | Requirement |
|------|-------------|
| Admin Virtual meters screen | `conservation_module` AND `virtual_meters` |
| Dashboard Conservation preview | same |
| Default | **OFF** (unchanged nav when OFF) |

Admin: list, create (sum/parent_minus), members, validation preview, delete with dependency check.  
Dashboard: Conservation-only preview cards (no full Balance UX — Phase 2).  
Reports / Overview / utility tabs / entry_app: **unchanged**.

---

## 8. RLS results

`scripts/conservation/p1e_rls_validate.sql` → **`P1E_RLS_RESULT=PASS`**

Viewer SELECT / no write · Tech no write · Site admin in-scope · Cross-site rejected · Virtual reading rejected · Self-parent rejected · targets/baselines/readings unchanged · flags OFF · test virtual cleaned up.

---

## 9. Tests

| Suite | Result |
|-------|--------|
| Conservation (all) | **96 PASS** |
| `smart_meters_core` | **215 PASS** |
| `dashboard_app` | **77 PASS** |
| `entry_app` | **13 PASS** |
| `admin_app` | **21 PASS** |
| P1E RLS | **PASS** |

Examples covered: A sum · B positive residual · C negative · D missing · E nested leaves · F cycle rejected · multipliers · misalignment · confidence min.

---

## 10. Regression POST_P1E

**RESULT: PASS — protected metrics unchanged**

| Metric | Value |
|--------|------:|
| meter_readings | **43845** |
| meters physical | **35** |
| meters virtual | **0** (test cleanup) |
| targets / baselines / members | **0** |
| migration_max | **066** |
| any flag ON | **false** |

Artifacts: `docs/regression/snapshot_POST_P1E_*`, `COMPARE_POST_P1E.md`

---

## 11. Performance

- Dashboard provider short-circuits when flag OFF.
- When ON: loads site virtuals + members map once; leaf expansion bounded (`kVirtualMeterMaxDepth=8`); readings fetched only for leaf IDs.
- No unbounded recursive SQL on every Overview render.

---

## 12. Numeric examples

**A — sum_children:** children 10 + 15 → **25** · Sum of children.

**B — parent_minus positive:** parent 100 − (40+30) → **30** Residual.

**C — negative residual:** parent 50 − 80 → **−30** + Negative Residual warning (not Leak).

**D — missing child:** 1 of 3 present → Insufficient Data; missing IDs listed.

**E — nested:** leaves D+E+C expanded once → 15; depth recorded.

**F — cycle:** vA↔vB → validation `cycle` error; not persisted.

---

## 13. Known limitations

- Full Water/Energy Balance Difference product deferred to Phase 2.
- Category/meter scopes for conservation targets/baselines unchanged here.
- No new audit log system for virtual config edits (limitation documented).
- `manual_adjustment` calc type exists in enum but not enabled in P1E UI.
- Approve/create of virtual uses same site_admin write roles as meters manage.

---

## 14. Rollback

1. Flags OFF.  
2. Revert P1E app code.  
3. Preserve any valid virtual definitions if present.  
4. Never delete physical meter/reading data.  
5. DROP 066 objects only with explicit approval.

---

## 15. Stop condition

**P1E complete. Phase 1 complete pending Phase 1 summary approval. Do not start Phase 2.**
