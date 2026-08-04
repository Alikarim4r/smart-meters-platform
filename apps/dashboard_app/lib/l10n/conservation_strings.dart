import 'package:flutter/widgets.dart';

/// نصوص إنجليزية/عربية احترافية لواجهة الترشيد وتكاملات البيانات (Dashboard).
class ConservationStrings {
  const ConservationStrings(this.locale);

  final Locale locale;

  bool get isAr => locale.languageCode == 'ar';

  String _t(String en, String ar) => isAr ? ar : en;

  factory ConservationStrings.of(BuildContext context) =>
      ConservationStrings(Localizations.localeOf(context));

  // —— Section / navigation ——
  String get conservation => _t('Conservation', 'الترشيد');
  String get tapToExpandSection => _t(
        'Tap to expand and load this section.',
        'اضغط لفتح القسم وتحميل بياناته.',
      );
  String get advancedOnDemand => _t('Advanced (on demand)', 'متقدم (عند الطلب)');
  String get advancedHint => _t(
        'Raw operational values stay primary. Normalized / models behind tabs.',
        'تبقى القيم التشغيلية الأصلية أساسية. القيم المعيّرة والنماذج خلف التبويبات.',
      );

  // —— Period / target / baseline ——
  String get periodComparison => _t('Period comparison', 'مقارنة الفترات');
  String get absoluteDifference => _t('Absolute difference', 'الفرق المطلق');
  String get percentageChange => _t('Percentage change', 'نسبة التغيّر');
  String get insufficientData => _t('Insufficient Data', 'بيانات غير كافية');
  String actualVsTarget(int version) =>
      _t('Actual vs Target · v$version', 'الفعلي مقابل الهدف · الإصدار $version');
  String actualVsBaseline(int version) => _t(
        'Actual vs Baseline · v$version',
        'الفعلي مقابل خط الأساس · الإصدار $version',
      );
  String get fullPeriodTarget => _t('Full-period target', 'هدف الفترة الكاملة');
  String get differenceActualMinusTarget =>
      _t('Difference (Actual − Target)', 'الفرق (الفعلي − الهدف)');
  String get absoluteVarianceActualMinusBaseline => _t(
        'Absolute variance (Actual − Baseline)',
        'الانحراف المطلق (الفعلي − خط الأساس)',
      );
  String get percentageVariance => _t('Percentage variance', 'نسبة الانحراف');
  String completenessPct(String pct) =>
      _t('Completeness: $pct%', 'اكتمال البيانات: $pct٪');
  String get targetsNotBaselinesNote => _t(
        'Targets ≠ Baselines. Gap is Above/Below Target — not Saving.',
        'الأهداف ≠ خطوط الأساس. الفجوة هي أعلى/أدنى من الهدف — وليست توفيراً.',
      );
  String get baselineNotTargetNote => _t(
        'Baseline ≠ Target. Gap is Above/Below Baseline — not Saving.',
        'خط الأساس ≠ الهدف. الفجوة هي أعلى/أدنى من خط الأساس — وليست توفيراً.',
      );
  String get aboveTarget => _t('Above Target', 'أعلى من الهدف');
  String get belowTarget => _t('Below Target', 'أدنى من الهدف');
  String get onTarget => _t('On Target', 'على الهدف');
  String get aboveBaseline => _t('Above Baseline', 'أعلى من خط الأساس');
  String get belowBaseline => _t('Below Baseline', 'أدنى من خط الأساس');
  String get onBaseline => _t('On Baseline', 'على خط الأساس');

  // —— Balance ——
  String get balanceDifference => _t('Balance Difference', 'فرق التوازن');
  String get balanceHierarchy => _t('Balance hierarchy', 'هيكل التوازن');
  String get unaccounted => _t('Unaccounted', 'غير محسوب');
  String get residual => _t('Residual', 'متبقٍ');
  String get neverLeak => _t('Never Leak.', 'لا يُصنَّف تلقائياً كتسرب.');
  String balanceStatus(String status) =>
      _t('Status: $status. Never Leak.', 'الحالة: $status. لا يُصنَّف كتسرب.');
  String get partiallyAligned => _t('Partially aligned', 'محاذاة جزئية');
  String get aligned => _t('Aligned', 'محاذاة كاملة');
  String get missingMeters => _t('Missing', 'ناقص');
  String get waterBalance => _t('Water Balance', 'توازن المياه');
  String get energyBalance => _t('Energy Balance', 'توازن الطاقة');

  // —— Benchmark ——
  String get benchmarking => _t('Benchmarking', 'المقارنة المعيارية');
  String get consumption => _t('Consumption', 'الاستهلاك');
  String get intensityPerM2 => _t('Intensity / m²', 'الكثافة / م²');
  String get intensityPerOccupant =>
      _t('Intensity / occupant', 'الكثافة / شاغل');
  String get peerMedian => _t('Peer median', 'وسيط الأقران');
  String get notNormalized => _t('Not normalized', 'غير معيّر');
  String get normalizationDataMissing =>
      _t('Normalization Data Missing', 'بيانات المعايرة غير متوفرة');

  // —— Anomaly / opportunities ——
  String get anomalies => _t('Anomalies', 'الشذوذات');
  String get noAutomaticFault =>
      _t('No automatic fault classification.', 'لا يوجد تصنيف عطل تلقائي.');
  String get possibleInvestigationNotes =>
      _t('Possible investigation notes:', 'ملاحظات تحقيق مقترحة:');
  String get opportunities => _t('Opportunities', 'الفرص');
  String get open => _t('Open', 'مفتوحة');
  String get underInvestigation => _t('Under Investigation', 'قيد التحقيق');
  String get actionsDue => _t('Actions Due', 'إجراءات مستحقة');
  String get monitoring => _t('Monitoring', 'متابعة');
  String get resolved => _t('Resolved', 'مغلقة');
  String get noOpportunitiesFilter =>
      _t('No opportunities for this filter.', 'لا توجد فرص لهذه التصفية.');
  String get actualVsTargetTitle =>
      _t('Actual vs Target', 'الفعلي مقابل الهدف');
  String get actualVsBaselineTitle =>
      _t('Actual vs Baseline', 'الفعلي مقابل خط الأساس');
  String get forecast => _t('Forecast', 'التنبؤ');
  String get normalized => _t('Normalized', 'معيّر');
  String get actual => _t('Actual', 'الفعلي');
  String get method => _t('Method', 'الطريقة');
  String get normal => _t('Normal', 'طبيعي');
  String membersCount(int n) => _t('$n members', '$n أعضاء');
  String peerProfilesNa(int n) =>
      _t('N/A ($n peer profiles)', 'غير متاح ($n ملفات أقران)');
  String utilityBenchmark(String utility) =>
      _t('$utility · Benchmark', '$utility · مقارنة معيارية');

  String get target => _t('Target', 'الهدف');
  String get percentOfEffectiveTarget =>
      _t('% of effective target', '٪ من الهدف الفعّال');
  String get mainMeter => _t('Main', 'الرئيسي');
  String metersCount(int n) => _t('$n meters', '$n عدادات');
  String get increasedNotInVerifiedTotal => _t(
        '(increased — not in Verified Total)',
        '(ارتفاع — غير مدرج في إجمالي المُحقَّق)',
      );
  String boundBaseline(String shortId) =>
      _t('bound $shortId…', 'مرتبط $shortId…');
  String periodConfidenceDetail({
    required int confidence,
    required int current,
    required int comparison,
  }) =>
      _t(
        'Confidence: $confidence (current $current · comparison $comparison)',
        'الثقة: $confidence (الحالي $current · المقارنة $comparison)',
      );
  String completenessPair(String a, String b) =>
      _t('Completeness: $a% / $b%', 'اكتمال البيانات: $a٪ / $b٪');
  String actualConsumptionLine(String value, String unit) =>
      _t('Actual $value $unit', 'الفعلي $value $unit');
  String normalizedValueLine(String value, String unit, String reliability) =>
      _t(
        'Normalized: $value $unit ($reliability)',
        'معيّر: $value $unit ($reliability)',
      );
  String get startInvestigation => _t('Start Investigation', 'بدء التحقيق');
  String get requiresInvestigation => _t(
        'Requires investigation — not a Confirmed Cause or Saving.',
        'يتطلب تحقيقاً — وليس سبباً مؤكداً أو توفيراً.',
      );
  String highUtilityConsumption(String utility) =>
      _t('High $utility Consumption', 'استهلاك مرتفع ($utility)');
  String get potentialExcess => _t('Potential Excess', 'فائض محتمل');
  String get notSaving => _t('Not Saving', 'ليس توفيراً');
  String get confirmedCause => _t('Confirmed Cause', 'سبب مؤكد');
  String get investigations => _t('Investigations', 'التحقيقات');
  String get actions => _t('Actions', 'الإجراءات');
  String get evidence => _t('Evidence', 'الأدلة');

  // —— M&V ——
  String get measurementVerification =>
      _t('Measurement & Verification', 'القياس والتحقق');
  String get estimatedSaving => _t('Estimated Saving', 'التوفير التقديري');
  String get verifiedSaving => _t('Verified Saving', 'التوفير المُحقَّق');
  String get verifiedSavingsTotal =>
      _t('Verified Savings Total', 'إجمالي التوفير المُحقَّق');
  String get performanceChange => _t('Performance change', 'تغيّر الأداء');
  String get costAvoided => _t('Cost Avoided', 'التكلفة المتجنَّبة');
  String get costAvoidedNa => _t(
        'Cost Avoided = N/A (no tariff)',
        'التكلفة المتجنَّبة = غير متاحة (لا تعرفة)',
      );
  String get roi => _t('ROI', 'العائد على الاستثمار');
  String get payback => _t('Payback', 'فترة الاسترداد');
  String get verificationPending =>
      _t('Verification Pending', 'بانتظار التحقق');
  String get readyForVerification =>
      _t('Ready for Verification', 'جاهز للتحقق');
  String get verifiedBy => _t('Verified by', 'تم التحقق بواسطة');
  String get postPeriod => _t('Post period', 'فترة ما بعد الإجراء');
  String get terminologyChain => _t(
        'Potential Excess ≠ Estimated Saving ≠ Verified Saving',
        'الفائض المحتمل ≠ التوفير التقديري ≠ التوفير المُحقَّق',
      );
  String get noSavingIncreased =>
      _t('No Saving — Consumption Increased', 'لا توفير — الاستهلاك ارتفع');
  String get estimatedVsVerified => _t(
        'Estimated vs Verified Saving · Cost Avoided (N/A if no tariff)',
        'التوفير التقديري مقابل المُحقَّق · التكلفة المتجنَّبة (غير متاحة بدون تعرفة)',
      );

  // —— Advanced tabs ——
  String get persistence => _t('Persistence', 'استمرارية التوفير');
  String get carbon => _t('Carbon', 'الكربون');
  String get carbonAvoided => _t('Carbon Avoided', 'الكربون المتجنَّب');
  String get forecasting => _t('Forecasting', 'التنبؤ');
  String get recommendations => _t('Recommendations', 'التوصيات');
  String get portfolio => _t('Portfolio', 'المحفظة');
  String get weatherNormalization =>
      _t('Weather normalization', 'معايرة الطقس');
  String get occupancyNormalization =>
      _t('Occupancy normalization', 'معايرة الإشغال');
  String get noPersistenceYet =>
      _t('No persistence follow-up results yet.', 'لا نتائج متابعة استمرارية بعد.');
  String get persistenceNeverDeletesVerified => _t(
        'No follow-up persistence rows. Original Verified Saving is never deleted.',
        'لا صفوف متابعة استمرارية. التوفير المُحقَّق الأصلي لا يُحذف أبداً.',
      );
  String get carbonNotAvailable => _t(
        'Carbon Avoided = Not Available until an approved factor exists.',
        'الكربون المتجنَّب = غير متاح حتى يوجد معامل انبعاث معتمد.',
      );
  String get noCarbonResults => _t(
        'No carbon results. Missing factor ⇒ Not Available (never invent).',
        'لا نتائج كربون. غياب المعامل ⇒ غير متاح (لا تُخترع أرقام).',
      );
  String get noForecasts => _t(
        'No forecasts. Insufficient History yields no invented number.',
        'لا تنبؤات. التاريخ غير الكافي لا يُنتج أرقاماً مخترعة.',
      );
  String get noOpenRecommendations =>
      _t('No open recommendations.', 'لا توصيات مفتوحة.');
  String get normalizationFlagsOff =>
      _t('Normalization flags OFF.', 'أعلام المعايرة متوقفة.');
  String get aiAssistedSuggestion => _t(
        'AI-assisted suggestion — Requires human review.',
        'اقتراح بمساعدة الذكاء الاصطناعي — يتطلب مراجعة بشرية.',
      );

  // —— Data sources summary (Phase 6) ——
  String get dataSources => _t('Data sources', 'مصادر البيانات');
  String get dataAndIntegrations =>
      _t('Data & Integrations', 'البيانات والتكاملات');
  String get healthy => _t('Healthy', 'سليم');
  String get delayed => _t('Delayed', 'متأخر');
  String get importsPending => _t('Imports pending', 'استيرادات معلّقة');
  String get availabilityAlerts =>
      _t('Availability alerts', 'تنبيهات توفّر البيانات');
  String get dataAvailabilityAlert =>
      _t('Data Availability Alert', 'تنبيه توفّر البيانات');
  String get notEquipmentFault =>
      _t('Not an Equipment Fault', 'ليس عطل معدات');
  String latestSync(String when) =>
      _t('Latest sync: $when', 'آخر مزامنة: $when');
  String get dataAvailabilityNotFault => _t(
        'Details in drill-down. Data Availability ≠ Equipment Fault.',
        'التفاصيل في العرض التفصيلي. توفّر البيانات ≠ عطل معدات.',
      );
  String get importCenter => _t('Import Center', 'مركز الاستيراد');
  String get sourceHealth => _t('Source Health', 'صحة المصادر');
  String get neverSynced => _t('Never Synced', 'لم تتم المزامنة بعد');
  String get authenticationRequired =>
      _t('Authentication Required', 'مطلوب مصادقة');
  String get disabled => _t('Disabled', 'معطّل');
  String get failed => _t('Failed', 'فشل');

  // —— Empty / gated ——
  String get featureDisabled =>
      _t('This feature is disabled.', 'هذه الميزة غير مفعّلة.');
  String get enableFlagsHint => _t(
        'Enable the related feature flags for this organization/site.',
        'فعّل أعلام الميزات ذات الصلة لهذه الجهة/الموقع.',
      );
  String get noDataYet => _t('No data yet.', 'لا توجد بيانات بعد.');
  String get manualRefreshOnly => _t(
        'Potential Excess only — not Saving. Refresh is manual; never auto-runs on load.',
        'فائض محتمل فقط — وليس توفيراً. التحديث يدوي؛ لا يعمل تلقائياً عند التحميل.',
      );
  String get mvDisclaimer => _t(
        'Estimated Saving ≠ Verified Saving. Potential Excess is never counted as Saving.',
        'التوفير التقديري ≠ التوفير المُحقَّق. الفائض المحتمل لا يُحتسب توفيراً أبداً.',
      );

  // —— Panel section titles / empty states ——
  String get derivedMetricsOnly => _t(
        'Derived metrics only. Gaps are Above/Below Target or Baseline — not Saving.',
        'مؤشرات مشتقّة فقط. الفجوات أعلى/أدنى من الهدف أو خط الأساس — وليست توفيراً.',
      );
  String get trendsAndCharts => _t('Trends & charts', 'مخططات واتجاهات');
  String get trendsAndChartsHint => _t(
        'Conservation metrics only — not daily utility consumption charts.',
        'مؤشرات الترشيد فقط — وليست مخططات الاستهلاك اليومية لأنظمة المرافق.',
      );
  String get chartPeriodComparison =>
      _t('Period comparison', 'مقارنة الفترات');
  String get chartCopTrend => _t('COP trend', 'اتجاه معامل الأداء');
  String get chartAnomalyHistory =>
      _t('Anomaly period history', 'تاريخ فترات الشذوذ');
  String get chartBenchmarkPeers =>
      _t('Site vs peer median', 'الموقع مقابل وسيط الأقران');
  String get chartBalanceShare =>
      _t('Main vs children balance', 'الرئيسي مقابل مجموع الأبناء');
  String get chartNoData => _t('No chart data for this period.', 'لا بيانات مخطط لهذه الفترة.');
  String get chartMainMeter => _t('Main meter', 'العداد الرئيسي');
  String get chartChildrenSum => _t('Sum of children', 'مجموع الأبناء');
  String get chartThisSite => _t('This site', 'هذا الموقع');
  String get chartPeriodN => _t('P', 'ف');
  String get periodComparisons => _t('Period comparisons', 'مقارنات الفترات');
  String get virtualMetersPreview =>
      _t('Virtual meters (preview)', 'العدادات الافتراضية (معاينة)');
  String get waterAndEnergyBalance =>
      _t('Water & Energy Balance', 'توازن المياه والطاقة');
  String get anomaliesAndCop =>
      _t('Anomalies & COP trend', 'الشذوذات واتجاه معامل الأداء');
  String get copTrend => _t('COP trend', 'اتجاه معامل الأداء');
  String get copTrendNote => _t(
        'COP trend uses existing dashboard COP values — formulas unchanged.',
        'اتجاه معامل الأداء يستخدم قيم لوحة التحكم الحالية — دون تغيير المعادلات.',
      );
  String get refreshOpportunities =>
      _t('Refresh opportunities', 'تحديث الفرص');
  String opportunitiesRefreshResult({
    required int created,
    required int refreshed,
    required int candidates,
  }) =>
      _t(
        'Opportunities: $created created, $refreshed refreshed ($candidates candidates).',
        'الفرص: أُنشئ $created، حُدّث $refreshed ($candidates مرشّحاً).',
      );
  String get noUtilityMetersPeriod => _t(
        'No utility meters available for period comparison.',
        'لا توجد عدادات مرافق متاحة لمقارنة الفترات.',
      );
  String get previousPeriod => _t('Previous period', 'الفترة السابقة');
  String get comparedWithSamePeriodLastYear => _t(
        'Compared with same period last year',
        'مقارنة بنفس الفترة من العام الماضي',
      );
  String get noActiveTargets =>
      _t('No active targets for this site.', 'لا توجد أهداف نشطة لهذا الموقع.');
  String get noApprovedBaselines => _t(
        'No approved baselines for this site.',
        'لا توجد خطوط أساس معتمدة لهذا الموقع.',
      );
  String get noVirtualMeters => _t(
        'No virtual meters configured for this site.',
        'لا توجد عدادات افتراضية مُعدّة لهذا الموقع.',
      );
  String get residualNotLeak => _t(
        'Residual/Balance Difference only — not Leak.',
        'فرق متبقٍ/توازن فقط — وليس تسرباً.',
      );
  String get noActiveBalanceGroups => _t(
        'No active balance groups for this site.',
        'لا توجد مجموعات توازن نشطة لهذا الموقع.',
      );
  String get noBenchmarkTotals => _t(
        'No water/electricity totals for benchmark.',
        'لا مجاميع مياه/كهرباء للمقارنة المعيارية.',
      );
  String get noAnomalySignals => _t(
        'No anomaly signals for this period.',
        'لا إشارات شذوذ لهذه الفترة.',
      );
  String get noOpportunitiesYet => _t(
        'No opportunities yet. Tap Refresh opportunities to scan current signals.',
        'لا فرص بعد. اضغط «تحديث الفرص» لمسح الإشارات الحالية.',
      );
  String get investigationStarted =>
      _t('Investigation started', 'بدأ التحقيق');
  String get noMvRecordsYet => _t(
        'No measurement & verification records yet.',
        'لا سجلات قياس وتحقق بعد.',
      );
  String confidenceCompleteness({
    required int confidence,
    required String completenessPct,
  }) =>
      _t(
        'Confidence $confidence · Completeness $completenessPct%',
        'الثقة $confidence · اكتمال البيانات $completenessPct٪',
      );
  String get na => _t('N/A', 'غير متاح');

  // —— Shared field labels ——
  String get status => _t('Status', 'الحالة');
  String get confidence => _t('Confidence', 'الثقة');
  String get source => _t('Source', 'المصدر');
  String get utility => _t('Utility', 'المنفعة');
  String get current => _t('Current', 'الحالي');
  String get comparison => _t('Comparison', 'المقارنة');
  String get baseline => _t('Baseline', 'خط الأساس');
  String get severity => _t('Severity', 'الشدّة');
  String get variance => _t('Variance', 'الانحراف');
  String get alignment => _t('Alignment', 'المحاذاة');
  String get submeters => _t('Submeters', 'العدادات الفرعية');
  String get peerGroup => _t('Peer group', 'مجموعة الأقران');
  String get needsRecalculation =>
      _t('Needs recalculation', 'يتطلب إعادة حساب');
  String get proratedTarget => _t('Prorated target', 'هدف مُقسَّم نسبياً');
  String get unusualConsumption =>
      _t('Unusual Consumption', 'استهلاك غير معتاد');
  String get requiresReviewNotFault => _t(
        'Recommended: Requires Review (not a Confirmed Fault).',
        'موصى به: يتطلب مراجعة (وليس عطلاً مؤكداً).',
      );
  String get missingData => _t('Missing data', 'بيانات ناقصة');
  String get misaligned => _t('Misaligned', 'غير محاذٍ');
  String get lowConfidence => _t('Low confidence', 'ثقة منخفضة');
  String get partial => _t('Partial', 'جزئي');
  String missingCount(int n) => _t('Missing: $n', 'ناقص: $n');
  String get insufficientHistoryForecast => _t(
        'No stored forecasts. Run forecast on demand.',
        'لا تنبؤات مخزّنة. شغّل التنبؤ عند الطلب.',
      );
  String get noNormalizedYet => _t(
        'No normalized results yet. Actual consumption remains the operational source of truth.',
        'لا نتائج معايرة بعد. الاستهلاك الفعلي يبقى المصدر التشغيلي للحقيقة.',
      );
  String combinedConfidence(int score) =>
      _t('Combined confidence: $score', 'الثقة المجمّعة: $score');
  String confidenceLabel(int score) =>
      _t('Confidence: $score', 'الثقة: $score');
  String normalizedStatus(String status) =>
      _t('Normalized: $status', 'معيّر: $status');

  String combinedConfidenceDetail({
    required int combined,
    required int baseline,
    required int actual,
  }) =>
      _t(
        'Combined confidence: $combined (min baseline $baseline / actual $actual)',
        'الثقة المجمّعة: $combined (الحد الأدنى لخط الأساس $baseline / الفعلي $actual)',
      );

  /// User-facing load error (never raw PostgresException).
  String friendlyLoadError(Object error) {
    final raw = '$error'.toLowerCase();
    if (raw.contains('57014') ||
        raw.contains('statement timeout') ||
        raw.contains('canceling statement') ||
        raw.contains('timeout')) {
      return _t(
        'The request took too long. Try a shorter date range, then refresh.',
        'استغرق الطلب وقتاً طويلاً. جرّب نطاقاً أقصر للتواريخ ثم حدّث الصفحة.',
      );
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return _t(
        'Network error. Check your connection and try again.',
        'خطأ في الشبكة. تحقق من الاتصال ثم أعد المحاولة.',
      );
    }
    return _t(
      'Could not load this section. Please refresh.',
      'تعذّر تحميل هذا القسم. يُرجى التحديث.',
    );
  }

  String localizeUtilityCode(String code) {
    final c = code.trim().toLowerCase();
    if (!isAr) return code.toUpperCase();
    return switch (c) {
      'water' => 'المياه',
      'electricity' || 'electric' => 'الكهرباء',
      'btu' || 'cooling' => 'التبريد',
      'fuel' || 'diesel' => 'الوقود',
      _ => code.toUpperCase(),
    };
  }

  String localizeUnit(String? unit) {
    if (unit == null || unit.isEmpty) return '';
    if (!isAr) return unit;
    final u = unit.trim().toLowerCase();
    return switch (u) {
      'm3' || 'm³' || 'م3' => 'م³',
      'kwh' => 'ك.و.س',
      'btu' => 'وحدة حرارية',
      'l' || 'liter' || 'litre' => 'لتر',
      _ => unit,
    };
  }

  String localizeReviewStatus(String status) {
    if (!isAr) return status;
    final key = status.trim().toLowerCase();
    if (key == 'requires review') return 'يتطلب مراجعة';
    if (key == 'ok') return 'سليم';
    return status;
  }

  String localizeMethod(String method) {
    if (!isAr) return method;
    return switch (method.trim().toLowerCase()) {
      'total_period' => 'إجمالي الفترة',
      'period_to_date' || 'period-to-date' => 'من بداية الفترة حتى اليوم',
      'prorated' => 'مُقسَّم نسبياً',
      'daily_average' => 'متوسط يومي',
      _ => method,
    };
  }

  /// Maps domain English labels (Above Baseline, Sum of children, …) to Arabic.
  String localizeDomainLabel(String label) {
    if (!isAr) return label;
    final t = label.trim();
    final lower = t.toLowerCase();
    if (lower == 'insufficient data') return insufficientData;
    if (lower == 'above baseline') return aboveBaseline;
    if (lower == 'below baseline') return belowBaseline;
    if (lower == 'on baseline') return onBaseline;
    if (lower == 'above target') return aboveTarget;
    if (lower == 'below target') return belowTarget;
    if (lower == 'on target') return onTarget;
    if (lower == 'sum of children') return sumOfChildren;
    if (lower == 'requires review') return requiresReview;
    if (lower == 'unusual consumption') return unusualConsumption;
    if (lower.contains('balance difference') && lower.contains('residual')) {
      if (lower.contains('on balance')) {
        return 'فرق التوازن (متبقٍ) · متوازن';
      }
      if (lower.contains('negative')) {
        return 'فرق التوازن (متبقٍ) · سالب';
      }
      return 'فرق التوازن (متبقٍ)';
    }
    if (lower == 'residual · balance difference' ||
        lower == 'balance difference · residual') {
      return 'فرق التوازن (متبقٍ)';
    }
    if (lower.startsWith('residual')) return residual;
    if (lower.contains('unaccounted')) return unaccounted;
    return t;
  }

  String get sumOfChildren => _t('Sum of children', 'مجموع العدادات الفرعية');
  String get requiresReview => _t('Requires Review', 'يتطلب مراجعة');

  /// Soften/translate common domain English messages for Arabic UI.
  String localizeDomainMessage(String? message) {
    if (message == null || message.trim().isEmpty) return insufficientData;
    if (!isAr) return message;
    final m = message.trim();
    final lower = m.toLowerCase();
    if (lower.contains('no valid boundary readings')) {
      return 'بيانات غير كافية: لا توجد قراءات حدّية صالحة لفترة التحليل '
          '(قد تفتقد العدادات اليدوية قراءة في اليوم السابق لبداية الفترة — '
          'ولا يُختلق يوم قبل البداية).';
    }
    if (lower.contains('misaligned reading periods') ||
        lower.contains('contributor spans are not comparable')) {
      return 'فترات القراءات غير متطابقة — نطاقات المساهمين غير قابلة للمقارنة '
          'بدقة دون حذر؛ لا تعامل المتبقي كفرق توازن دقيق.';
    }
    if (lower.contains('negative residual')) {
      return 'متبقٍ سالب — راجع هيكل العدادات / توقيت القراءات / جودة البيانات. '
          'لا يُصنَّف كتسرب.';
    }
    if (lower.contains('missing/incomplete child')) {
      return 'بيانات غير كافية: قراءات العدادات الفرعية ناقصة أو غير مكتملة.';
    }
    if (lower.contains('parent meter lacks')) {
      return 'بيانات غير كافية: العداد الرئيسي بلا قراءات حدّية صالحة.';
    }
    if (lower.contains('completeness')) {
      return 'بيانات غير كافية بسبب انخفاض اكتمال البيانات في الفترة.';
    }
    if (lower.startsWith('insufficient data')) {
      return insufficientData;
    }
    // Strip leading "." sometimes present in messages.
    return m.startsWith('.') ? m.substring(1).trim() : m;
  }

  String formatQuantity(double? value, String? unit) {
    if (value == null) return na;
    final u = localizeUnit(unit);
    final n = value.toStringAsFixed(value.abs() >= 100 ? 1 : 2);
    return u.isEmpty ? n : '$u $n';
  }
}
