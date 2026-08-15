# تقرير فحص شامل — منصة العدادات الذكية

**تاريخ الفحص:** 2026-08-05  
**الفرع:** `hardening/pre-production-20260804`  
**HEAD:** `aa75d02` — `feat: synchronize app icons with brand colors`  
**مقابل `origin/main`:** ~55 commit ahead / 0 behind  
**بيئة التشغيل الحالية:** Staging Supabase `iqcxgtpcfhoapnklxdyl`  
**Production:** لم يُرفَع إليه شيء بعد

---

## 1. الخلاصة التنفيذية

| الحكم | التفاصيل |
|-------|----------|
| **جاهزية Staging / عرض وزارة** | عالية — تطبيقات Dashboard / Entry / Admin مستقرة على بيانات MOEHE |
| **جاهزية Production** | غير مكتملة — يحتاج قرار صريح + مشروع Supabase إنتاج + أسرار CI + توقيع متاجر |
| **Conservation (Phases 1–6)** | مغلقة (PASS) — Phase 7 منفَّذة (2026-08-06) |
| **Pre-production hardening (2026-08-04)** | منفَّذ على Staging (migrations 115–117، عزل Offline، تدوير كلمات المرور، 489 اختبار) |
| **Working tree** | **متسخ** (~70 ملف معدّل + ملفات غير متتبعة) — لم يُلتَزم بالكامل بعد |

**الحدّ الرسمي الحالي:** طبّق `docs/PRE_PRODUCTION_HARDENING_2026-08-04.md` كمرجع بوابات ما قبل الإنتاج. ملفات يوليو `PROJECT_STATUS.md` / `NEXT_STEPS.md` متقادمة جزئياً.

---

## 2. هيكل المستودع

| المكوّن | المسار | الحجم التقريبي |
|---------|--------|----------------|
| Dashboard App | `apps/dashboard_app` | عرض، رسوم، تنبيهات، تقارير، Conservation UI |
| Entry App | `apps/entry_app` | إدخال ميداني، صور، Offline، مزامنة |
| Admin App | `apps/admin_app` | ~43 شاشة: مواقع/عدادات/مستخدمين/استيراد/Conservation |
| الحزمة المشتركة | `packages/smart_meters_core` (~203 ملف Dart) | Auth، Conservation، Ingestion، Notifications، أمان |
| قاعدة البيانات | `supabase/migrations` | **103** ملف SQL (ترقيم 001–117 مع فجوات) |
| البوابة | `web_portal` + `gh-pages` | تحميلات APK/macOS/Windows + روابط ويب |
| السكربتات | `scripts/` | Staging run، flags مراجعة، استيراد، أدوات |
| التوثيق | `docs/` (~61 md) + `docs/conservation/` + `docs/regression/` | خطط، تقارير مراحل، انحدار |
| CI | `.github/workflows/` | `ci.yml`, `deploy-web.yml`, `build-windows.yml` |

المنصات المعلَنة لكل تطبيق Flutter: Android · iOS · macOS · Web · Windows · Linux.

---

## 3. التطبيقات — الحالة الوظيفية

### 3.1 Dashboard
- أدوار: viewer / technician / site_admin / super_admin (قراءة وتحليل)
- لوحات مواقع، رسوم، تنبيهات محسوبة، تصدير تقارير
- Conservation UI (أعلام)
- جسر إشعارات الستارة + ودجتات Android (تنبيهات / ملخص موقع)
- اختبارات: ~19 ملف

### 3.2 Entry
- أدوار: technician / site_admin (كتابة ميدانية)
- تدفق موقع → فئة → عداد → قراءة + صورة
- Offline (مسودات معزولة بـ user + `APP_ENV` بعد hardening)
- جسر إشعارات + ودجتات (طابور / مزامنة)
- اختبارات: ~5 + integration auth

### 3.3 Admin
- أدوار: site_admin / super_admin / platform owner
- كتالوج، شبكة مرافق، صلاحيات، تصحيحات، سياسة قراءة
- Import Center / Data & Integrations (flags)
- أدوات Conservation الإدارية
- إعدادات صوت إشعار الستارة (زر الاختبار أُزيل من الكود الحالي)
- اختبارات: ~5

---

## 4. `smart_meters_core`

| الوحدة | محتوى رئيسي |
|--------|-------------|
| Auth / Session | Supabase auth، بوابات أدوار، biometrics، stay-signed-in |
| Conservation | ~89 ملف: أهداف، baselines، عدادات افتراضية، توازن، فرص، M&V، تقارير… |
| Ingestion (Phase 6) | مصادر، استيراد ملفات، صحة مصادر، أتمتة (stubs)، OCR readiness |
| Notifications | Local shade + writer + session + home_widget sync — **بدون FCM** |
| Domain / Repos | عدادات، قراءات، سياسات، تصحيحات، شبكة | 

---

## 5. قاعدة البيانات و Flags

### Migrations
- **103** ملف على القرص
- فجوات ترقيم معروفة (مثل 058–059، 102–113)
- Hardening مطبّق على Staging: **115, 116, 117**
- **114** (self-insert إشعارات): وُجد في المستودع؛ على Staging طُبّق يدوياً بعد إصلاح `profiles.organization_id` — يُراجع ترتيب الرفع التالي لـ CLI

### Feature flags
| النظام | العدد التقريبي | الافتراضي |
|--------|----------------|-----------|
| Conservation | 27 | OFF إن غاب الصف |
| Platform (Phase 6) | 11 | OFF إن غاب الصف |

أعلام مرحلة المراجعة (Script review0–7) موجودة تحت `scripts/conservation/`.

---

## 6. الإشعارات والودجتات

| القدرة | الحالة |
|--------|--------|
| إشعار نظام (ستارة) + صوت | منفّذ (`flutter_local_notifications`) على Android |
| FCM / Push والتطبيق مقتول طويلًا | **غير منفّذ** |
| ودجتات Android (2 لكل تطبيق) | منفّذة ومسجّلة على الجهاز سابقاً |
| ودجتات iOS | **غير منفّذة** |
| حفظ في `in_app_notifications` | مدعوم بعد سياسة 114 |

---

## 7. الاختبارات والجودة

| المصدر | مؤشر |
|--------|------|
| ملفات اختبار apps/packages | ~68 |
| حالات اختبار موثّقة في hardening | **489 passed** (Core 373 + Dashboard 77 + Entry 18 + Admin 21) |
| Analyzer | نُظّف في جولة 2026-08-04 |
| Smoke DB (15 فحصاً) | نجح داخل معاملة ثم `ROLLBACK` |

---

## 8. التصلّب قبل الإنتاج (ما تم)

من `docs/PRE_PRODUCTION_HARDENING_2026-08-04.md`:

1. إزالة كلمات مرور مدمجة؛ بيانات التحقق runtime فقط  
2. تدوير كلمة مرور قاعدة البيانات + حسابات التحقق → Keychain  
3. عزل Offline حسب المستخدم و`APP_ENV`  
4. سياسات قراءة/تصحيح على الخادم (115)  
5. أرشفة ناعمة بدل الحذف القسري (116) + تصحيح حافة تسلسل العدادات (117)  
6. نسخة احتياطية يدوية قبل الترحيل (Free Plan بلا نسخ مجدولة)  
7. علامة rollback: `pre-production-hardening-20260804`

---

## 9. المخاطر والفجوات المفتوحة

### تمنع «إنتاج فعلي»
- لا مشروع Supabase Production ولا قرار ترقية  
- لا GitHub Secrets إنتاج ولا نشر ويب إنتاج مؤكد من هذا الفرع  
- لا keystore AAB موقّع للمتجر / حسابات Play أو Apple  
- قرارات مفتوحة: SSO مقابل email، تأكيد البريد، منطقة الاستضافة  

### تقنية / عمليات
- شجرة عمل كانت متسخة — تُعالَج بالتزامات 2026-08-06  
- فجوات تاريخ Migrations + backlog `056–062`  
- بدون FCM (إشعارات الستارة تتطلب تشغيل/خلفية محدودة)  
- Phase 7 UX: منفَّذة 2026-08-06 — انظر [conservation/PHASE_7_COMPLETION_REPORT.md](./conservation/PHASE_7_COMPLETION_REPORT.md)  
- وثائق (`PROJECT_STATUS`, `NEXT_STEPS`) حُدِّثت 2026-08-06  
- خطة الإطلاق التدريجي إلى Production: لم تكتمل  

### أمني قائم (مفروض قبوله مع RLS)
- مفتاح anon في العملاء → الأمان يعتمد على صحة RLS  
- تعقيد RLS على المقياس الكبير  

---

## 10. خارطة الطريق المقترحة

| الأولوية | الخطوة |
|----------|--------|
| 1 | ~~تنظيف working tree~~ (جاري/مكتمل مع التزامات الإطلاق الاحترافي) |
| 2 | قرار: هل نرقّي إلى Production الآن؟ |
| 3 | إنشاء مشروع Production + سلسلة migrations كاملة (بما فيها ترتيب 114) |
| 4 | تحديث Secrets ونشر ويب إنتاج |
| 5 | Keystore + مسار Play داخلي |
| 6 | سياسة Auth (تأكيد بريد / SSO) |
| 7 | ~~Phase 7 UX~~ — منفَّذة 2026-08-06 |
| 8 | FCM اختياري إن لزم إشعار مع إغلاق التطبيق |

---

## 11. النتيجة الرسمية لهذا الفحص

# **STAGING PROFESSIONAL — PRODUCTION NOT PROMOTED**

المنصة جاهزة للعرض والتشغيل الاحترافي على **Staging** بعد hardening وConservation 1–7.  
ليست «مُصدَّرة للإنتاج» بعد.

---

*تحديث لاحق 2026-08-06: نُفِّذت Phase 7 UX + مزامنة الوثائق. Production ما زال يحتاج قراراً صريحاً.*

---

## مراجع سريعة

- [PRE_PRODUCTION_HARDENING_2026-08-04.md](./PRE_PRODUCTION_HARDENING_2026-08-04.md)  
- [GRADUAL_LAUNCH.md](./GRADUAL_LAUNCH.md)  
- [conservation/PHASE_6_COMPLETION_REPORT.md](./conservation/PHASE_6_COMPLETION_REPORT.md)  
- [conservation/APPLICATION_REVIEW_COMPREHENSIVE.md](./conservation/APPLICATION_REVIEW_COMPREHENSIVE.md)  
- [RISKS_AND_DECISIONS.md](./RISKS_AND_DECISIONS.md)  

*نهاية تقرير الفحص الشامل — 2026-08-05.*
