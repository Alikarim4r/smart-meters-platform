# تقرير فني — طبقة ترشيد الطاقة والمياه (Conservation Layer)

**الحالة:** الدراسة معتمدة من حيث المبدأ — **لا تنفيذ حتى اعتماد** [`PHASE_1_IMPLEMENTATION_PLAN.md`](./PHASE_1_IMPLEMENTATION_PLAN.md)  
**التاريخ:** 2026-07-29 (محدّث بإضافة شروط التنفيذ)  
**البيئة المرجعية:** Staging `iqcxgtpcfhoapnklxdyl`  
**فرع الكود الحالي:** `main` @ `c8936de`  
**قيود المنتج لهذه المرحلة:** عدادات ميكانيكية + قراءات دورية يدوية + صورة إثبات  

### شروط تنفيذ معتمدة (ملزمة)

1. Backup مع **خطة Restore متحقَّق منها** (ليس dump فقط).  
2. **Regression Baseline Report** قبل أي تعديل وإعادة الفحص بعد كل خطوة.  
3. Rollback: Disable flags → Revert code → **Preserve conservation data** → DB rollback فقط عند الضرورة وبعد اعتماد.  
4. **تجميد** معادلة الاستهلاك وسلوك التقارير الحالية في Phase 1.  
5. حسابات Conservation = **Read-only derived** — لا تعديل `meter_readings`.  
6. كل Metric مهم مع **Calculation Metadata** كاملة.  
7. Phase 1 = **P1A→P1E** منفصلة مع Regression بعد كل واحدة.  
8. اختبارات حماية Virtual Meter الإلزامية.  
9. Feature Flags كلها **OFF** افتراضياً بعد Migration.  
10. لا Night/Peak/Hourly/Real-time/BMS/FDD — Future Ready فقط.

**خطة التنفيذ التفصيلية:** [`PHASE_1_IMPLEMENTATION_PLAN.md`](./PHASE_1_IMPLEMENTATION_PLAN.md)

---

## 0. ملخص تنفيذي

المنصة الحالية قوية في **التشغيل والمراقبة**: إدخال قراءات، صور، offline، صلاحيات، تصحيحات، رسوم بيانية، تنبيهات محسوبة محلياً، COP/EER، وتقارير.  
ما ينقصها هو طبقة **ترشيد Conservation** منفصلة: أهداف، baselines مُصدَّقة، توازن مياه/طاقة بمصطلحات صحيحة، فرص توفير، توفير مقدَّر/موثَّق، وتكلفة/ROI.

**المبدأ الحاكم:** تصميم **additive** فقط — جداول/وحدات/شاشات جديدة خلف Feature Flags، بدون حذف أو إعادة تسمية أو كسر مسارات الإدخال والتقارير الحالية.

**التوصية:** بعد اعتماد `PHASE_1_IMPLEMENTATION_PLAN.md` فقط، العمل على Staging من branch  
`feature/conservation-management` وفق ترتيب P1A→P1E.

---

## 1. Current System Assessment

### 1.1 التطبيقات الثلاثة

| التطبيق | الدور الحالي | ما سيُمس لاحقاً (إضافة فقط) |
|---------|--------------|------------------------------|
| **entry_app** | إدخال قراءات يدوية + صورة + offline/sync | لا يُغيَّر مسار الإدخال في P1؛ لاحقاً قد يُعرض تحذير جودة بيانات فقط (flag) |
| **dashboard_app** | Overview / Water / Electricity / BTU / Fuel / Alerts / Reports | قسم Conservation جديد أو بطاقات اختيارية خلف flag |
| **admin_app** | Structure / Meters / Network / Users / Policy / Corrections / COP | شاشات Targets، Baselines، Virtual meters، Opportunities، تكلفة اختيارية |

### 1.2 `smart_meters_core` — الموجود

| الطبقة | الموجود |
|--------|---------|
| Models | `Meter`, `MeterReading`, alerts, COP, policy, charts, corrections, utility network |
| Repos | readings, dashboard (استهلاك client-side), alerts, COP, policy, corrections, images, meters |
| Domain | `alert_detection`, `chart_period` / aggregation, efficiency bands, correction validation |
| Offline | داخل `entry_app/lib/offline/` وليس في core |
| Feature flags | **غير موجودة** — فقط `APP_ENV` |

**حساب الاستهلاك الحالي:** قراءة تراكمية → فرق يومي/فترة  
`max(0, current_normalized − previous_normalized)`  
أول قراءة = مرجع فقط (استهلاك 0).  
Dashboard **لا يعتمد** على view `meter_daily_consumption` (timeouts تاريخياً) — يحسب من `meter_readings` بنطاق تاريخ.

### 1.3 Schema / Migrations

- Migrations المطبقة/الموجودة حتى **`062_super_admin_visibility_and_list_readings.sql`**
- جداول محورية: `organizations`, `zones`, `sites`, `meters`, `meter_readings`, `reading_audit_logs`, `cop_groups` (+ join tables), `policy_settings`, `profiles`, `user_site_access`, utility network v2, `site_facility_areas`
- على `meters` مسبقاً: `parent_meter_id`, `meter_kind` (`physical`|`virtual`), `calculation_type` (`direct_reading`|`sum_children`|`parent_minus_children`|`manual_adjustment`), multipliers
- **لا توجد** جداول: targets, baselines, savings, opportunities, actions, tariffs, intensity metadata

### 1.4 RLS / Auth / Storage

- Auth: Supabase email/password + profiles + موافقات
- Helpers: `is_approved_active_user`, `is_super_admin`, `is_platform_owner`, `has_site_access`, `can_write_site`, `can_manage_site` (+ scope assignments)
- Storage: `meter-images` (صور القراءات)، `report-logos`
- التنبيهات **ليست جدولاً** — تُحسب في العميل من القراءات + السياسة

### 1.5 ما سيتأثر بإضافة Conservation (وما لن يتأثر)

| يتأثر (إضافة/قراءة) | لا يجب أن يتأثر |
|---------------------|-----------------|
| قراءة `meter_readings` لحسابات جديدة | INSERT/UPDATE مسار الإدخال |
| قراءة تسلسل العدادات / COP | RLS الحالي للمستخدمين |
| تقارير جديدة منفصلة | تقارير الاستهلاك الحالية |
| شاشات dashboard/admin اختيارية | Offline sync، approvals، corrections الأساسية |
| Migrations جديدة فقط (≥063) | تعديل/حذف migrations 001–062 |

### 1.6 فجوات حرجة للتوافق مع العداد الميكانيكي

| الفجوة | الأثر |
|--------|--------|
| Virtual meters schema موجود لكن **لا حاسبة في Dart** وAdmin ينشئ physical/direct فقط | Balance يحتاج تفعيل UI + calculator |
| `site_facility_areas` بدون `area_m2` | Intensity تحتاج عموداً جديداً أو جدول metadata للموقع |
| لا تعرفة/تكلفة | Cost Avoided / ROI مرحلة لاحقة اختيارية |
| لا baseline مُصدَّق | المقارنات اليوم = فترات متحركة فقط |
| تنبيهات غير مُخزَّنة | Opportunity workflow يحتاج جدولاً جديداً (لا تعديل alert_detection كهدم) |

---

## 2. Architecture Proposal (Additive)

### 2.1 مبدأ التصميم

```
[Existing Platform] ── unchanged read/write paths ──►
        │
        └──► [Conservation Module] (new package OR core/domain/conservation/)
                 │
                 ├── Tables (new only)
                 ├── Services (compute from meter_readings)
                 ├── Feature flags
                 └── UI sections (gated)
```

**مفضّل:** حزمة أو مجلد مستقل داخل core:

`packages/smart_meters_core/lib/conservation/`  
أو لاحقاً `packages/smart_meters_conservation/` إن كبر الحجم.

لا يُعاد كتابة `dashboard_repository` الحالي؛ يُستدعى كمصدر بيانات أو تُعاد استخدام دوال الفترة عبر service جديد.

### 2.2 الجداول الجديدة المقترحة (أسماء أولية)

| جدول | الغرض |
|------|--------|
| `conservation_feature_flags` | تفعيل خصائص لكل org/site |
| `conservation_targets` | أهداف شهرية/سنوية (موقع/فئة/عداد) |
| `conservation_baselines` | إصدارات baseline (لا overwrite) |
| `site_conservation_profiles` | مساحة m²، إشغال اختياري، ملاحظات |
| `utility_tariffs` | تعرفة اختيارية (Cost/ROI) |
| `virtual_meter_definitions` *(اختياري)* | إن احتجنا metadata فوق `meters` الافتراضي؛ وإلا الاكتفاء بـ `meters` الموجود |
| `balance_groups` | مجموعة رئيسي + قائمة فرعيات لحساب Balance Difference |
| `balance_classifications` | تصنيف الفرق بعد التحقيق |
| `data_quality_findings` | نتائج فحوص الجودة (اختياري persist) |
| `conservation_opportunities` | فرص الترشيد |
| `conservation_actions` | تحقيق → إجراء → إغلاق |
| `conservation_savings` | estimated / verified + cost avoided |
| `conservation_report_runs` | سجل تقارير شهرية (اختياري) |

**أعمدة على جداول موجودة (additive فقط إن لزم):**

| جدول | عمود مقترح | ملاحظة |
|------|------------|--------|
| `sites` أو `site_conservation_profiles` | `floor_area_m2`, `occupancy_count` | **لا** تعديل أعمدة قائمة؛ جدول profile أفضل |
| `policy_settings` | **لا تغيير إلزامي في P1** | يمكن لاحقاً مفاتيح JSON جديدة فقط إن وُجد عمود مرن؛ وإلا جدول flags |

### 2.3 علاقات رئيسية

- `conservation_baselines.site_id` → `sites`
- `conservation_targets.site_id` → `sites` (+ optional `category_id`, `meter_id`)
- `balance_groups.main_meter_id` → `meters`; أعضاء → `meters`
- `conservation_opportunities.site_id` → `sites`; optional `meter_id`, `balance_group_id`
- `conservation_actions.opportunity_id` → opportunities
- `conservation_savings.opportunity_id` / `baseline_id` / `target_id`

### 2.4 Models / Repositories / Services الجديدة

| Component | مسؤولية |
|-----------|---------|
| `BaselineModel` + `BaselineRepository` | إصدارات + اعتماد |
| `TargetModel` + `TargetRepository` | CRUD أهداف |
| `ConsumptionComparisonService` | Actual vs Target / prev period / YoY |
| `VirtualMeterCalculator` | `sum_children`, `parent_minus_children` |
| `BalanceService` | Water/Energy Balance Difference + classification hooks |
| `DataQualityService` | فحوص + Confidence Score |
| `OpportunityEngine` | تحويل anomalies → opportunities (غير تشخيص مؤكد) |
| `ActionWorkflowService` | Investigation → Action → Close |
| `SavingsService` | Estimated vs Verified + recalculation بعد corrections |
| `ConservationReportService` | تقرير شهري |
| `FeatureFlagService` | قراءة flags |

### 2.5 الشاشات المقترحة

| التطبيق | شاشة/قسم | مرحلة |
|---------|----------|--------|
| Admin | Targets & Baselines | P1 |
| Admin | Virtual meters / Balance groups | P1–P2 |
| Admin | Site conservation profile (m²) | P1 (لـ intensity لاحقاً) |
| Dashboard | Conservation overview (Actual vs Target, vs prev, YoY) | P1 |
| Dashboard | Data quality & confidence | P1 |
| Dashboard | Balance Difference panel | P2 |
| Dashboard | Benchmarking | P2 |
| Dashboard/Admin | Opportunities & Actions | P3 |
| Dashboard | Savings (Estimated/Verified) + Cost | P4 |
| All | Report: Monthly Conservation | P4 |

### 2.6 ما يبقى Module مستقل

يُفضّل أن يكون **Opportunity Engine + Savings + Workflow** معزولاً تماماً بحيث:

- إيقاف الـ flag يخفي UI ولا يمس مسار القراءات
- لا يُعدَّل `alert_detection.dart` بشكل كاسر؛ يمكن *الاستماع* لنتائجه أو إعادة استخدام قواعد مشابهة داخل conservation فقط

---

## 3. Database Safety

### 3.1 قواعد إلزامية

| ممنوع | البديل |
|-------|--------|
| DROP TABLE للجداول الحالية | جداول جديدة فقط |
| DROP COLUMN | أعمدة جديدة nullable أو جدول جانبي |
| Rename أعمدة مستخدمة | أسماء جديدة |
| تغيير نوع بيانات يكسر العملاء | نوع جديد / cast في views جديدة |
| تعديل سياسات RLS الحالية لتقليل الصلاحيات | سياسات **جديدة** على الجداول الجديدة فقط |
| تعديل migrations 001–062 | ملف migration جديد مستقل (يبدأ من 063+) |

### 3.2 نمط Migration المقترح

- ملف واحد لكل مرحلة منطقية، مثال:
  - `063_conservation_flags_and_profiles.sql`
  - `064_conservation_baselines_targets.sql`
  - …
- كل ملف: `IF NOT EXISTS` / idempotent قدر الإمكان
- RLS جديد: `USING (has_site_access(site_id))` بنفس النمط الحالي
- لا تُلمس سياسات `meter_readings` / `meters` إلا لإضافة SELECT من security definer جديد إن لزم — **بتوسيع فقط وبمراجعة**

### 3.3 قبل أي `db push` على Staging

1. مراجعة SQL يدوياً  
2. Dry-run / تطبيق على نسخة احتياطية إن أمكن  
3. اختبار RLS بحسابات أدوار مختلفة  
4. عدم لمس Production

---

## 4. Backup and Recovery Plan

### 4.1 قبل أي مرحلة تنفيذ

| الأصل | طريقة الحفظ المقترحة |
|-------|----------------------|
| **Schema** | `supabase db dump --schema-only` → ملف مؤرخ في مكان آمن خارج repo أو `backups/` gitignored |
| **البيانات** | `supabase db dump --data-only` أو Dashboard backup / PITR إن مفعّل على الخطة |
| **Storage** | توثيق buckets + عينة مسارات؛ إن لزم مزامنة `meter-images` / `report-logos` عبر Storage API |
| **إعدادات Supabase** | تصدير Auth settings المعروفة (autoconfirm، URLs) وتوثيق project ref |
| **Git** | Tag ثابت: `pre-conservation-stable` على commit معتمد بعد تنظيف working tree |

### 4.2 نقطة الرجوع الكاملة

1. Git tag/commit المستقر  
2. Schema dump + data dump بنفس الطابع الزمني  
3. قائمة migrations المطبقة (`schema_migrations`)  
4. إن فشل التطوير:  
   - إعادة checkout للـ tag  
   - استعادة DB من dump على Staging  
   - عدم تطبيق migrations Conservation

### 4.3 ملاحظة على الحالة الحالية للـ Git (مهم قبل التنفيذ)

عند إعداد هذا التقرير كان:

- الفرع: `main` متزامن مع `origin/main` عند `c8936de`
- **working tree فيها تعديلات كثيرة غير committed** (أيقونات، docs، سكربتات، …)

**قبل إنشاء branch Conservation يجب:**

1. تحديد ما يُلتزم به وما يُستبعد  
2. commit أو stash واعٍ  
3. ثم إنشاء `feature/conservation-management` من commit مستقر نظيف  

*(لا يُنفَّذ الآن — توثيق فقط.)*

---

## 5. Git Safety Strategy (خطة فقط)

| الخطوة | التفاصيل |
|--------|----------|
| Stable commit مرجعي | `c8936de` (آخر commit معروف وقت الدراسة) — يُحدَّث عند الاعتماد |
| Branch | `feature/conservation-management` |
| القاعدة | لا تطوير Conservation مباشرة على `main` |
| الدمج | فقط بعد نجاح اختبارات المرحلة على Staging |
| Commits | صغيرة حسب المرحلة (P1a schema، P1b services، P1c UI…) |
| حماية | عدم force-push؛ عدم تعديل migrations القديمة |

---

## 6. Rollback Plan (لكل مرحلة)

### نمط عام لكل Phase

| السؤال | الجواب المعياري |
|--------|-----------------|
| ماذا يتغير؟ | Migrations additive + كود خلف flags |
| كيف نختبر؟ | انظر §17 |
| كيف نرجع؟ | إيقاف flags → إخفاء UI؛ إن لزم revert commits؛ جداول تبقى فارغة أو تُترك |
| هل Migration قابلة للـ Rollback؟ | يُفضَّل كتابة `DOWN` موثّق يدوياً (DROP الجديدة فقط) — لا يُشغَّل إلا بقرار |
| تعطيل بدون كسر المنصة؟ | **نعم** عبر Feature Flags |

### تفاصيل مختصرة حسب المرحلة

| Phase | Rollback |
|-------|----------|
| P1 | إيقاف flags؛ DROP جداول baselines/targets فقط إذا لزم وبعد backup |
| P2 | إيقاف Balance/Benchmark flags؛ لا يمس القراءات |
| P3 | إيقاف Opportunities؛ تبقى سجلات إن وُجدت بلا أثر تشغيلي |
| P4 | إيقاف Savings/Reports الجديدة؛ التقارير القديمة تعمل |
| P5 | أصلاً مؤجلة / Future |

---

## 7. Feature Flags

### 7.1 Flags المقترحة

| Flag key | يتحكم بـ |
|----------|----------|
| `conservation_module` | المفتاح الرئيسي للوحدة |
| `baseline` | Baselines + Actual vs Baseline |
| `targets` | Monthly/Annual targets + Actual vs Target |
| `period_compare` | vs previous period / YoY cards |
| `virtual_meters` | حاسبة العداد الافتراضي |
| `water_balance` / `energy_balance` | Balance Difference UI |
| `data_quality` | فحوص + Confidence |
| `benchmarking` | مقارنة مواقع |
| `intensity` | kWh/m²، m³/m² |
| `cop_conservation` | تحليل COP ضمن Conservation (غير تبويب BTU الحالي) |
| `opportunities` | Opportunity Engine |
| `savings_verification` | Estimated/Verified |
| `cost_roi` | Cost Avoided / ROI |
| `conservation_reports` | التقارير الشهرية |

### 7.2 التخزين

- جدول `conservation_feature_flags (organization_id, site_id nullable, flag_key, enabled)`
- افتراضي: الكل `false` حتى تفعيل واعٍ على Staging
- قراءة في bootstrap/provider؛ UI يختفي بالكامل عند الإيقاف

---

## 8. Compatibility Matrix

| وظيفة حالية | ضمان التوافق |
|-------------|---------------|
| إدخال القراءات | لا تغيير على insert API في P1–P2 |
| رفع الصور | bucket ومسار كما هما؛ Conservation يقرأ `image_url` فقط |
| Offline/Sync | لا تغيير عقود المسودة |
| Approvals | جداول profiles/access كما هي |
| Corrections | بعد التصحيح: إعادة احتساب Conservation من القراءات المحدّثة (service)؛ مسار التصحيح نفسه |
| Reports الحالية | ملفات/خدمات منفصلة؛ عدم تعديل قوالب قديمة إلا بإضافة اختيارية |
| Dashboard analytics | تبويبات موجودة تبقى؛ قسم جديد بجانب |
| Admin | تبويبات جديدة أو تحت Structure |
| Auth / Roles | RLS جديد يطابق `has_site_access` / `can_manage_site` |

---

## 9. Historical Data Compatibility

### يُحسب مباشرة من البيانات الحالية

| الميزة | المصدر |
|--------|--------|
| Previous period compare | `meter_readings` + منطق الاستهلاك الحالي |
| Same period last year (YoY) | نفس المصدر إن وُجدت قراءات كافية |
| Abnormal consumption (مقابل متوسط فترة سابقة) | مشابه لـ highConsumption الحالي |
| Data completeness | وجود قراءة لكل عداد/يوم عمل |
| Missing photo | `image_url` + `photo_required` |
| Lower than previous / jumps | تسلسل القراءات |
| Correction history | `reading_audit_logs` |
| COP/EER trend | `cop_groups` + قراءات BTU/كهرباء |
| Virtual balance *بعد* ضبط التسلسل | `parent_meter_id` + قراءات الرئيسي/الفرعي |

### يحتاج بيانات جديدة من تاريخ التفعيل

| الميزة | المطلوب الجديد |
|--------|----------------|
| Monthly/Annual Targets | إدخال أهداف |
| Versioned Baseline (معتمد) | إنشاء/اعتماد إصدار |
| Intensity | `floor_area_m2` (وإشغال اختياري) |
| Cost Avoided / ROI | تعرفات + تكاليف إجراءات |
| Opportunity workflow history | سجلات opportunities/actions |
| Verified Saving رسمي | قواعد تحقق + اعتماد بشري |
| Balance classification | تصنيفات بعد التحقيق |

**لا إعادة إدخال قراءات تاريخية** — الحسابات تبني على الموجود.

---

## 10. Baseline Design

### نموذج إصدارات (لا overwrite)

```
conservation_baselines
  id
  site_id
  scope_type          -- site | category | meter | balance_group
  scope_id            -- nullable FK logical
  version_number      -- 1, 2, 3…
  label
  reference_period_start
  reference_period_end
  calculation_method  -- avg_daily | total_period | custom_fixed
  baseline_value      -- كمية في الوحدة الأساسية
  unit_code
  status              -- draft | approved | superseded | archived
  valid_from
  valid_to            -- null = الحالي المعتمد
  approved_by
  approved_at
  notes
  created_at / updated_at
```

**قواعد:**

- اعتماد إصدار جديد → الإصدار السابق `superseded` مع `valid_to`
- التوفير الموثق يربط `baseline_id` المحدد (لا «أحدث متوسط» فقط)
- يُمنع حذف إصدار مرتبط بـ verified savings (restrict)

---

## 11. Saving Classification

| النوع | المعنى | شروط |
|-------|--------|------|
| **Estimated Saving** | تقدير أولي | يمكن حسابه من فرق فعلي vs هدف/baseline أو من فرصة مغلقة جزئياً؛ يُعرض مع Confidence |
| **Verified Saving** | توفير معتمد | اكتمال بيانات الفترة ≥ عتبة؛ لا findings حرجة مفتوحة؛ صورة حيث إلزامي؛ لا corrections معلّقة تؤثر؛ اعتماد صريح من role مخوّل |

لا يُعرض Verified في التقارير الرسمية إلا بعد التحقق.

---

## 12. Data Quality Layer

### فحوص مطلوبة (متوافقة مع القراءات الدورية)

| فحص | الوصف |
|-----|--------|
| Missing Reading | غياب قراءة في يوم متوقع |
| Reading lower than previous | انخفاض تراكمي غير مبرر (قبل اعتبار rollover) |
| Unreasonable jump | قفزة فوق مضاعف السياسة/عتبة Conservation |
| Duplicate Reading | تعارض مع unique (meter_id, reading_date) |
| Incorrect date sequence | تواريخ خارج الترتيب المنطقي عند التصحيح |
| Missing photo | إن `photo_required` |
| Meter rollover | انخفاض حاد يطابق سعة العداد إن عُرّفت لاحقاً؛ وإلا «يحتاج مراجعة» |
| Correction history | وجود تعديلات في نافذة التحليل |
| Incomplete meter group | مجموعة Balance/COP ينقصها أعضاء أو قراءات |

### Data Confidence Score (اقتراح)

- مقياس 0–100 أو حالات: `high` / `medium` / `low` / `blocked`
- خصم نقاط لكل finding حسب الشدة
- `blocked` يمنع Verified Saving ويمنع اعتماد تقرير رسمي لتلك الفترة
- يُعرض بجانب كل بطاقة مقارنة مهمة

---

## 13. Water Balance Terminology

**لا** تسمية مباشرة: «تسريب».

### الحساب

```
Balance Difference = Main Meter Consumption − Σ Submeter Consumptions
(Unaccounted Consumption)
```

نفس المنطق لفئة الطاقة عند وجود رئيسي/فرعيات.

### بعد التحقيق — تصنيف اختياري

- Confirmed Leak  
- Suspected Leak  
- Meter Error  
- Reading Error  
- Unmetered Consumption  
- Operational Usage  
- Unknown  

الواجهة تعرض أولاً **Water Balance Difference** + Confidence، ثم التصنيف يدوياً.

---

## 14. Conservation Opportunity Engine

Module مستقل يحول التحليل إلى فرصة (ليس تشخيصاً قطعياً):

```
Signal (High consumption / Balance difference / COP deterioration / Quality)
  → Opportunity
       estimated_waste
       possible_causes[]          -- قائمة احتمالات
       suggested_investigations[]
       priority
       confidence
  → Action workflow
       Investigation
       Corrective Action
       Evidence (photo/note/links to readings)
       Close
       Follow-up reading window
       Saving Verification (Estimated → Verified)
```

---

## 15. No Automatic Diagnosis

صياغة واجهة وتقرير ملزمة:

| استخدم | لا تستخدم |
|--------|-----------|
| Possible cause | Root cause confirmed |
| Suggested investigation | Fault automatically detected |
| Suspected leak | Confirmed leak (إلا بعد تصنيف بشري) |
| Probable loss zone | Exact leak location |
| Balance difference | Water leak amount |

---

## 16. Implementation Phases

### Phase 1 — الأساس (Manual Meter Ready)
Data Quality + Targets + Baseline + Previous/YoY compare + Virtual Meters (calculator + admin UI محدود)

### Phase 2 — التوازن والمقارنة
Water/Energy Balance Difference + Classification hooks + Benchmarking + Intensity (بعد m²) + Anomalies الدورية

### Phase 3 — الفرص وسير العمل
Opportunity Engine + Alert→Investigation→Action→Close (+ evidence)

### Phase 4 — التوفير والتقارير
Estimated/Verified Saving + إعادة الاحتساب بعد Corrections + Cost Avoided/ROI (إن وُجدت تعرفة) + Monthly Conservation Reports

### Phase 5 — متقدم / Future
Weather/Occupancy normalization؛ وأي شيء يعتمد interval/BMS (مؤجّل)

### Future Smart Meter / BMS Ready (توثيق فقط — لا تنفيذ الآن)

- Night Flow Leak Detection  
- Night Electricity Consumption  
- Peak Demand Analysis  
- Hourly Load Profiles  
- Real-Time Leak Detection  
- Pressure/Flow Analytics  
- Automatic BMS Control  
- Automatic FDD المستمر  

---

## 17. Testing Plan

### قبل أي تطوير

1. تشغيل اختبارات موجودة:  
   `smart_meters_core/test`, `dashboard_app/test`, `entry_app/test`, `admin_app/test`
2. دخان يدوي Staging: دخول، إدخال قراءة+صورة، تصحيح، تقرير، تنبيهات، COP
3. توثيق نتيجة baseline للاختبارات (pass/fail)

### لكل مرحلة

| نوع | أمثلة |
|-----|--------|
| Unit | Confidence score، period compare، virtual calc، saving rules |
| Repository | CRUD targets/baselines مع RLS |
| Migration | تطبيق على Staging؛ التحقق من بقاء جداول قديمة |
| RLS | viewer/technician/site_admin/super_admin |
| Regression | مسار إدخال كامل + offline sync + approvals |
| Photo | رفع وعرض `meter-images` |
| Correction | تصحيح ثم إعادة احتساب compare/savings |
| Report | تقرير قديم + تقرير conservation جديد |
| Dashboard | التبويبات الحالية بدون انحدار |
| Historical | YoY/prev على بيانات MOEHE الحالية |

**قاعدة:** لا الانتقال للمرحلة التالية إذا ظهرت regression.

---

## 18. Staging First

| البيئة | مسموح |
|--------|--------|
| Staging `iqcxgtpcfhoapnklxdyl` | migrations + flags + اختبار الأدوار |
| Production | **ممنوع** حتى اعتماد صريح بعد P-stage ناجحة |

ترتيب: schema على Staging → تفعيل flags لموقع تجريبي → اختبار → توسيع → قرار إنتاج لاحقاً.

---

## 19. Performance Assessment

| خطر | التخفيف |
|-----|---------|
| Aggregations على تاريخ طويل | نفس أسلوب Dashboard: نطاق تاريخ محدود؛ لا الاعتماد على `meter_daily_consumption` الكامل |
| Balance لكل المواقع دفعة واحدة | حساب per-site عند الفتح؛ cache بسيط في provider |
| Quality على كل القراءات | نافذة 30/90 يوماً؛ indexes على `(meter_id, reading_date)` (موجودة غالباً) |
| Benchmarking محفظة كبيرة | RPC security definer لاحقاً إن لزم؛ ليس في P1 |
| Materialized views | **غير ضرورية في P1–P2**؛ تُراجع في P4 إذا بطؤ التقارير |

Indexes مقترحة للجداول الجديدة:  
`(site_id, status)`, `(site_id, period_start)`, `(opportunity_id)`, `(flag_key, organization_id)`.

---

## 20. Final Risk Report — جدول الخصائص

**التصنيف:**  
🟢 Manual Meter Ready · 🟡 يحتاج قراءات متكررة منتظمة · 🔵 Smart Meter / BMS Future

| Feature | Current Data Support | Manual Compatible | DB Changes | Code Changes | Risk | Complexity | Dependencies | Phase | Rollback | Recommendation |
|---------|---------------------|-------------------|------------|--------------|------|------------|--------------|-------|----------|----------------|
| Baseline (versioned) | جزئي (تاريخ قراءات) | 🟢 | جداول جديدة | Admin+Service+Dash | منخفض | متوسط | Data Quality | P1 | سهل (flag) | **Recommended Now** |
| Actual vs Target | يحتاج أهداف | 🟢 | targets | Admin+Dash | منخفض | متوسط | Targets | P1 | سهل | **Recommended Now** |
| vs Previous Period | كامل | 🟢 | لا/طفيف | Service+UI | منخفض | صغير | — | P1 | سهل | **Recommended Now** |
| vs Same Period Last Year | إن وُجد تاريخ ≥12ش | 🟢 | لا | Service+UI | منخفض | صغير | اكتمال بيانات | P1 | سهل | **Recommended Now** |
| Monthly/Annual Targets | لا | 🟢 | targets | Admin | منخفض | متوسط | — | P1 | سهل | **Recommended Now** |
| Virtual Meters calculator | Schema فقط | 🟢 | طفيف/لا | Calculator+Admin UI | متوسط | متوسط | تسلسل عدادات صحيح | P1 | متوسط | **Recommended Now** (بحذر) |
| Main vs Sub Balance | تسلسل موجود | 🟢 | balance_groups | Service+UI | متوسط | متوسط | Virtual/hierarchy | P2 | سهل | **Recommended Now** (P2) |
| Water Balance Difference | مشتق | 🟢 | classifications | UI+workflow | متوسط | متوسط | Balance | P2 | سهل | **Recommended Now** (P2) |
| Abnormal Consumption | تنبيه جزئي موجود | 🟢🟡 | اختياري persist | Conservation rules | منخفض | صغير | Quality | P2 | سهل | **Recommended Now** |
| Data Quality Validation | جزئي في alerts | 🟢 | findings اختياري | Service | منخفض | متوسط | — | P1 | سهل | **Recommended Now** |
| Data Completeness | موجود كمفهوم | 🟢 | لا | Service+UI | منخفض | صغير | — | P1 | سهل | **Recommended Now** |
| Building/Site Benchmarking | قراءات متعددة مواقع | 🟢 | profile m² يفضّل | Dash | متوسط | متوسط | Intensity أفضل | P2 | سهل | Recommended بعد m² |
| Intensity kWh/m² m³/m² | **لا مساحة** | 🟢 | profile | Admin+Dash | منخفض | صغير | إدخال m² | P2 | سهل | Recommended بعد تعبئة m² |
| COP/BTU analysis | موجود | 🟢 | لا إلزامي | قسم Conservation اختياري | منخفض | صغير | مجموعات COP | P2 | سهل | Recommended (تعزيز) |
| COP deterioration trend | اتجاهات موجودة جزئياً | 🟢🟡 | لا | Trend+opportunity hook | منخفض | صغير | COP data | P2–P3 | سهل | Recommended |
| Saving Opportunities | لا | 🟢 | opportunities | Engine+UI | متوسط | كبير | Quality+Anomalies | P3 | سهل عبر flag | Recommended بعد P1–P2 |
| Alert→Action→Close | تنبيهات غير persisted | 🟢 | actions | Workflow | متوسط | كبير | Opportunities | P3 | سهل عبر flag | Recommended P3 |
| Estimated Saving | مشتق | 🟢 | savings | Service | متوسط | متوسط | Baseline/Target | P4 | سهل | Recommended P4 |
| Verified Saving | يحتاج قواعد | 🟢 | savings+approval | Service+Admin | متوسط | متوسط | Quality gates | P4 | سهل | Recommended P4 |
| Cost Avoided | لا تعرفة | 🟢 | tariffs | Service | متوسط | متوسط | Tariffs | P4 | سهل | Optional |
| ROI / Payback | لا تكلفة إجراءات | 🟢 | cost fields | Service | متوسط | متوسط | Cost+Actions | P4 | سهل | Optional |
| Monthly Conservation Reports | تقارير عامة فقط | 🟢 | اختياري | Report service | منخفض | متوسط | P1 metrics | P4 | سهل | Recommended P4 |
| Photo/Evidence verification | image_url موجود | 🟢 | لا | Quality rules | منخفض | صغير | Policy photos | P1 | سهل | **Recommended Now** |
| Recalc بعد Corrections | audit موجود | 🟢 | لا | Hook/service | متوسط | متوسط | Savings/Compare | P1/P4 | سهل | **Recommended Now** (compare فوراً) |
| Data Confidence Score | لا | 🟢 | اختياري | Service | منخفض | متوسط | Quality | P1 | سهل | **Recommended Now** |
| Night Flow / Peak / Hourly / Real-time / Pressure / BMS FDD | غير متوفر | 🔵 | — | — | عالي إن فُرض | كبير | عدادات ذكية | Future | — | **Not Now — Future Ready only** |

---

## 21. توصية نهائية — أعلى قيمة بأقل خطر

### يُنفَّذ أولاً بعد الاعتماد (Phase 1 فقط)

1. Feature Flags + عزل الوحدة  
2. Data Quality + Confidence Score + Photo checks  
3. Previous Period + YoY comparisons  
4. Monthly/Annual Targets + Actual vs Target  
5. Versioned Baselines  
6. Virtual Meter calculator (تفعيل schema الموجود) + تحضير Balance  

### يؤجَّل إلى P2–P4

Balance Difference + Classification، Benchmarking/Intensity، Opportunities/Workflow، Verified Savings، Cost/ROI، تقارير Conservation الشهرية.

### لا يُنفَّذ في المدى الحالي

كل خصائص 🔵 المعتمدة على بيانات لحظية/BMS — تبقى موثّقة كـ Future Ready فقط.

---

## 22. شروط الانتقال من الدراسة إلى التنفيذ

قبل أي كود أو migration:

- [ ] اعتماد هذا التقرير من صاحب المنتج  
- [ ] تنظيف/تثبيت Git working tree + tag `pre-conservation-stable`  
- [ ] إنشاء `feature/conservation-management`  
- [ ] Backup schema+data لـ Staging  
- [ ] نجاح اختبارات الانحدار الحالية على Staging  
- [ ] الاتفاق على نطاق **Phase 1 فقط**  

**ثم** التنفيذ خطوة بخطوة مع اختبار بعد كل خطوة — دون الانتقال للمرحلة التالية عند أي regression.

---

## 23. ملحق — ما لن يتغير في المنصة الأساسية

- معادلات الإدخال والتطبيع الحالية  
- سياسات RLS للمستخدمين الحاليين (توسيع فقط لجداول جديدة)  
- buckets التخزين ومسارات الصور  
- تبويبات Dashboard الحالية كمسار افتراضي  
- عدم مشاركة مشروع Supabase مع أي منتج آخر (قوائم الفحص وغيرها)

---

*نهاية تقرير الدراسة — لا يشمل أي تنفيذ.*
