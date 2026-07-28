import 'package:flutter/widgets.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/chart_period_selection.dart';
import '../utils/dashboard_date_range.dart';
import '../utils/dashboard_filters.dart';
import '../utils/meter_reading_filters.dart';
import '../utils/site_system_navigation.dart';
import '../utils/utility_chart_type.dart';

/// Bilingual UI strings for the dashboard shell, settings, and meter views.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  bool get isAr => locale.languageCode == 'ar';

  static AppStrings of(BuildContext context) {
    return AppStrings(Localizations.localeOf(context));
  }

  // ── Shell / settings ──────────────────────────────────────────────

  String userRole(UserRole role) {
    if (!isAr) return shellUserRoleLabelEn(role);
    return switch (role) {
      UserRole.superAdmin => 'مشرف النظام',
      UserRole.siteAdmin => 'مشرف الموقع',
      UserRole.technician => 'فني',
      UserRole.technicianRequest => 'طلب صلاحية فني',
      UserRole.viewer => 'مستعرض',
    };
  }

  String get appTitle => isAr ? 'العدادات الذكية' : 'Smart Meters';
  String get smartMetersBrand => isAr ? 'العدادات الذكية' : 'SMART METERS';
  String get dashboard => isAr ? 'الرئيسية' : 'Dashboard';
  String get utilities => isAr ? 'أنظمة المرافق' : 'Utilities';
  String get reports => isAr ? 'التقارير' : 'Reports';
  String get account => isAr ? 'الحساب' : 'Account';
  String get settings => isAr ? 'الإعدادات' : 'Settings';
  String get logout => isAr ? 'تسجيل الخروج' : 'Logout';
  String get overview => isAr ? 'نظرة عامة' : 'Overview';
  String get water => isAr ? 'المياه' : 'Water';
  String get electricity => isAr ? 'الكهرباء' : 'Electricity';
  String get btuCooling => isAr ? 'التبريد (BTU)' : 'BTU / Cooling';
  String get fuelDiesel => isAr ? 'الوقود والديزل' : 'Fuel / Diesel';
  String get alerts => isAr ? 'التنبيهات' : 'Alerts';
  String get network => isAr ? 'الشبكة' : 'Network';

  String get collapseSidebar =>
      isAr ? 'طيّ الشريط الجانبي' : 'Collapse sidebar';
  String get expandSidebar => isAr ? 'توسيع الشريط الجانبي' : 'Expand sidebar';

  String get accountDetails => isAr ? 'بيانات الحساب' : 'Account details';
  String get email => isAr ? 'البريد الإلكتروني' : 'Email';
  String get password => isAr ? 'كلمة المرور' : 'Password';
  String get changePassword => isAr ? 'تغيير كلمة المرور' : 'Change password';
  String get newPassword => isAr ? 'كلمة المرور الجديدة' : 'New password';
  String get confirmPassword => isAr ? 'تأكيد كلمة المرور' : 'Confirm password';
  String get savePassword => isAr ? 'حفظ كلمة المرور' : 'Save password';
  String get passwordUpdated =>
      isAr ? 'تم تحديث كلمة المرور بنجاح.' : 'Password updated successfully.';
  String get passwordRequired =>
      isAr ? 'يرجى إدخال كلمة المرور.' : 'Password is required.';
  String get passwordTooShort => isAr
      ? 'يجب ألا تقل كلمة المرور عن 6 أحرف.'
      : 'Password must be at least 6 characters.';
  String get passwordsDoNotMatch =>
      isAr ? 'كلمة المرور وتأكيدها غير متطابقتين.' : 'Passwords do not match.';

  String get language => isAr ? 'اللغة' : 'Language';
  String get arabic => isAr ? 'العربية' : 'Arabic';
  String get english => isAr ? 'الإنجليزية' : 'English';

  String get appearance => isAr ? 'المظهر' : 'Appearance';
  String get themeMode => isAr ? 'وضع العرض' : 'Display mode';
  String get lightTheme => isAr ? 'فاتح' : 'Light';
  String get darkTheme => isAr ? 'داكن' : 'Dark';
  String get systemTheme => isAr ? 'تلقائي' : 'System';
  String get lightThemeHint =>
      isAr ? 'واجهة بخلفية فاتحة' : 'Light background interface';
  String get darkThemeHint =>
      isAr ? 'واجهة بخلفية داكنة' : 'Dark background interface';
  String get systemThemeHint =>
      isAr ? 'يتبع إعدادات الجهاز تلقائياً' : 'Follows your device setting';

  String get designerContact => isAr ? 'بيانات المصمم' : 'Designer contact';

  /// Single localized credit line — Arabic or English based on app language.
  String get designerCredit => isAr
      ? 'تصميم & تطوير المهندس : علي عبد الكريم الحسن'
      : 'Design & development by Eng. Ali Abdulkarim Elhassan';
  String get designerEmail => 'support@alimind.com';
  String get designerPhone => '+974 3005 88 99';
  String get call => isAr ? 'اتصال' : 'Call';
  String get sendEmail => isAr ? 'إرسال بريد' : 'Send email';

  String get role => isAr ? 'الصلاحية' : 'Role';
  String get refresh => isAr ? 'تحديث' : 'Refresh';
  String get backToSites => isAr ? 'العودة إلى المواقع' : 'Back to sites';

  String get signedInAs => accountDetails;
  String get theme => themeMode;

  // ── Utility systems ───────────────────────────────────────────────

  String utilityTitle(UtilitySystemKey system) {
    if (!isAr) return system.title;
    return switch (system) {
      UtilitySystemKey.water => 'نظام المياه',
      UtilitySystemKey.electricity => 'نظام الكهرباء',
      UtilitySystemKey.btu => 'نظام التبريد (BTU)',
      UtilitySystemKey.fuel => 'نظام الوقود والديزل',
    };
  }

  String utilityLabel(UtilitySystemKey system) {
    if (!isAr) return system.label;
    return switch (system) {
      UtilitySystemKey.water => 'المياه',
      UtilitySystemKey.electricity => 'الكهرباء',
      UtilitySystemKey.btu => 'التبريد',
      UtilitySystemKey.fuel => 'الوقود',
    };
  }

  String sectionLabel(SiteDashboardSection section) {
    if (!isAr) return section.label;
    return switch (section) {
      SiteDashboardSection.overview => overview,
      SiteDashboardSection.water => water,
      SiteDashboardSection.electricity => electricity,
      SiteDashboardSection.btuCooling => btuCooling,
      SiteDashboardSection.fuel => fuelDiesel,
      SiteDashboardSection.network => network,
      SiteDashboardSection.alerts => alerts,
      SiteDashboardSection.reports => reports,
    };
  }

  String utilityReadingsSubtitle({
    required UtilitySystemKey system,
    required String unitCode,
    required DashboardDateSelection selection,
  }) {
    final date = dateSelectionLabel(selection);
    if (!isAr) {
      return '${utilityLabel(system)} readings for $date · $unitCode';
    }
    return 'قراءات ${utilityLabel(system)} لتاريخ $date · $unitCode';
  }

  String noMetersAtSite(UtilitySystemKey system) => isAr
      ? 'لا توجد عدادات ${utilityLabel(system)} في هذا الموقع'
      : 'No ${system.label.toLowerCase()} meters at this site';

  String addMetersHint(UtilitySystemKey system) => isAr
      ? 'أضف عدادات ${utilityLabel(system)} من تطبيق الإدارة لتفعيل هذه الشاشة.'
      : 'Add ${system.label.toLowerCase()} meters in Admin to enable this view.';

  String noMetersMatchFilters(UtilitySystemKey system) => isAr
      ? 'لا توجد عدادات ${utilityLabel(system)} مطابقة للفلاتر'
      : 'No ${system.label.toLowerCase()} meters match filters';

  String get tryDifferentFilters => isAr
      ? 'جرّب مصدراً أو حالة أو بحثاً أو تاريخاً مختلفاً.'
      : 'Try a different source, status filter, search term, or date.';

  String get couldNotLoadUtility =>
      isAr ? 'تعذّر تحميل ملخص المرفق' : 'Could not load utility summary';
  String get pleaseRefreshOrChangeDate => isAr
      ? 'يرجى التحديث أو تجربة نطاق تاريخ آخر.'
      : 'Please refresh or try another date range.';
  String get couldNotLoadMeterCards =>
      isAr ? 'تعذّر تحميل بطاقات العدادات' : 'Could not load meter cards';
  String get pleaseRefreshMeterCards => isAr
      ? 'يرجى التحديث أو تغيير التاريخ المحدد. إن استمرت المشكلة، امسح البحث والفلاتر.'
      : 'Please refresh or change the selected date. If the problem continues, try clearing search and filters.';

  // ── KPI labels ────────────────────────────────────────────────────

  String get totalMeters => isAr ? 'إجمالي العدادات' : 'Total meters';

  String summarySubmitted(DashboardDateSelection selection) {
    if (!isAr) return selection.summarySubmittedLabel;
    return 'مُسجَّل في التاريخ';
  }

  String summaryPending(DashboardDateSelection selection) {
    if (!isAr) return selection.summaryPendingLabel;
    return 'معلّق في التاريخ';
  }

  String summaryCompletion(DashboardDateSelection selection) {
    if (!isAr) return selection.summaryCompletionLabel;
    return 'نسبة الإنجاز في التاريخ';
  }

  // ── Meter card ────────────────────────────────────────────────────

  String get previous => isAr ? 'السابق' : 'Previous';
  String get current => isAr ? 'الحالي' : 'Current';
  String get consumption => isAr ? 'الاستهلاك' : 'Consumption';
  String get history => isAr ? 'السجل' : 'History';
  String get export => isAr ? 'تصدير' : 'Export';
  String get compare => isAr ? 'مقارنة' : 'Compare';
  String get viewPhoto => isAr ? 'عرض الصورة' : 'View photo';
  String get noPhoto => isAr ? 'لا توجد صورة' : 'No photo';
  String get statusSubmitted => isAr ? 'مُسجَّل' : 'Submitted';
  String get statusPending => isAr ? 'معلّق' : 'Pending';
  String get statusNoReading => isAr ? 'بدون قراءة' : 'No reading';
  String exportedTo(String path) =>
      isAr ? 'تم التصدير إلى $path' : 'Exported to $path';
  String get exportFailed =>
      isAr ? 'تعذّر تصدير قراءات العداد.' : 'Could not export meter readings.';
  String get exportShared => isAr ? 'جاهز للمشاركة' : 'Ready to share';
  String get exportNoReadings => isAr
      ? 'لا توجد قراءات في الفترة المحددة للتصدير.'
      : 'No readings in the selected period to export.';
  String compareAdded(String code) =>
      isAr ? 'أُضيف $code للمقارنة' : '$code added to comparison';
  String compareRemoved(String code) =>
      isAr ? 'أُزيل $code من المقارنة' : '$code removed from comparison';
  String get compareLimitReached => isAr
      ? 'يمكن مقارنة ٥ عدادات كحد أقصى.'
      : 'You can compare up to 5 meters.';
  String get compareSelectAnother => isAr
      ? 'اختر عداداً آخر لبدء المقارنة.'
      : 'Select another meter to start comparison.';

  String cardStatus(MeterReadingCardStatus status) => switch (status) {
    MeterReadingCardStatus.submittedOnDate => statusSubmitted,
    MeterReadingCardStatus.pendingOnDate => statusPending,
    MeterReadingCardStatus.noReadingOnDate => statusNoReading,
  };

  // ── Filters / toolbar ─────────────────────────────────────────────

  String get searchMeters => isAr ? 'بحث في العدادات (/)' : 'Search meters (/)';
  String get filterStatus => isAr ? 'الحالة' : 'Status';
  String get filterSource => isAr ? 'المصدر' : 'Source';
  String get filterSort => isAr ? 'الترتيب' : 'Sort';
  String get ascending => isAr ? 'تصاعدي' : 'Ascending';
  String get descending => isAr ? 'تنازلي' : 'Descending';
  String get viewCards => isAr ? 'بطاقات' : 'Cards';
  String get viewRelationships => isAr ? 'العلاقات' : 'Relationships';
  String get viewNetworkMap => isAr ? 'الشبكة' : 'Network';
  String get viewNetwork => isAr ? 'الشبكة' : 'Network';
  String get couldNotLoadNetworkMap =>
      isAr ? 'تعذر تحميل خريطة الشبكة' : 'Could not load network map';
  String get pleaseRefreshNetworkMap =>
      isAr ? 'حدّث الصفحة أو جرّب لاحقًا' : 'Refresh or try again later';
  String get networkMapEmpty => isAr
      ? 'لا توجد شبكة مياه بعد'
      : 'No water network yet';
  String get networkMapEmptyHint => isAr
      ? 'أضف عناصر في تطبيق الإدارة — تظهر هنا مباشرة وتُحدَّث باستمرار.'
      : 'Add elements in Meter Admin — they appear here and stay in sync.';
  String get networkMapHint => isAr
      ? 'عرض متزامن مع الإدارة — اضغط على عداد لفتح سجل القراءات.'
      : 'Synced with Admin — tap a meter to open reading history.';
  String get networkSources => isAr ? 'مصادر المياه' : 'Water sources';
  String get networkMetersKpi => isAr ? 'العدادات' : 'Meters';
  String get networkTanksKpi => isAr ? 'الخزانات' : 'Tanks';
  String get networkSelectElementHint =>
      isAr ? 'حدد عنصرًا لعرض التفاصيل' : 'Select an element for details';
  String get networkSelectedDetails =>
      isAr ? 'تفاصيل العنصر المحدد' : 'Selected element details';
  String get networkCurrentReading =>
      isAr ? 'القراءة الحالية' : 'Current reading';
  String get networkLastReading => isAr ? 'آخر قراءة' : 'Last reading';
  String get networkUpstreamPath => isAr ? 'المسار الأعلى' : 'Upstream path';
  String get networkDownstreamPath =>
      isAr ? 'المسار الأسفل' : 'Downstream path';
  String get networkSearchHint =>
      isAr ? 'ابحث عن عداد أو خزان' : 'Search meter or tank';
  String get networkWaterTypeFilter => isAr ? 'نوع المياه' : 'Water type';
  String get networkBuildingFilter => isAr ? 'المبنى' : 'Building';
  String get networkShowUpstream =>
      isAr ? 'إظهار المسار الأعلى' : 'Show upstream path';
  String get networkShowDownstream =>
      isAr ? 'إظهار المسار الأسفل' : 'Show downstream path';
  String get networkPathHighlightHint => isAr
      ? 'المسارات المرتبطة بالعنصر المحدد'
      : 'Paths related to the selected element';
  String get viewReadingHistory =>
      isAr ? 'عرض سجل القراءات' : 'View reading history';
  String get all => isAr ? 'الكل' : 'All';

  String statusFilter(MeterCardStatusFilter filter) {
    if (!isAr) return filter.label;
    return switch (filter) {
      MeterCardStatusFilter.all => 'الكل',
      MeterCardStatusFilter.submitted => 'مُسجَّل',
      MeterCardStatusFilter.pending => 'معلّق',
      MeterCardStatusFilter.hasAlert => 'به تنبيه',
      MeterCardStatusFilter.hasPhoto => 'به صورة',
      MeterCardStatusFilter.missingPhoto => 'بدون صورة',
      MeterCardStatusFilter.negativeConsumption => 'استهلاك سالب',
    };
  }

  String sortOption(MeterCardSort sort) {
    if (!isAr) return sort.label;
    return switch (sort) {
      MeterCardSort.meterName => 'الاسم',
      MeterCardSort.meterCode => 'الرمز',
      MeterCardSort.highestConsumption => 'أعلى استهلاك',
      MeterCardSort.pendingFirst => 'المعلّق أولاً',
      MeterCardSort.alertsFirst => 'التنبيهات أولاً',
      MeterCardSort.latestReadingDate => 'أحدث تاريخ قراءة',
      MeterCardSort.missingPhotoFirst => 'بدون صورة أولاً',
      MeterCardSort.sourceThenCode => 'المصدر ثم الرمز',
    };
  }

  String waterSourceChip(WaterSourceChip chip) {
    if (!isAr) return chip.label;
    return switch (chip) {
      WaterSourceChip.all => 'الكل',
      WaterSourceChip.kahramaa => 'كهرماء',
      WaterSourceChip.tse => 'TSE',
      WaterSourceChip.ro => 'RO',
      WaterSourceChip.irrigation => 'الري',
      WaterSourceChip.chilledWater => 'المياه المبرّدة',
      WaterSourceChip.other => 'أخرى',
    };
  }

  String waterSourceGroup(String groupKey) {
    if (!isAr) return waterSourceGroupLabel(groupKey);
    return switch (groupKey) {
      'kahramaa' => 'مياه كهرماء',
      'tse' => 'مياه TSE',
      'ro' => 'RO',
      'irrigation' => 'الري',
      'chilled_water' => 'المياه المبرّدة / التدفق',
      'storm' => 'مياه الأمطار',
      'other' => 'أخرى',
      _ => groupKey.isEmpty ? 'أخرى' : catalogLabel(groupKey),
    };
  }

  /// Translate known catalog / source / category display names from the API.
  String catalogLabel(String name) {
    final trimmed = name.trim();
    if (!isAr || trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    const map = <String, String>{
      'water': 'المياه',
      'electricity': 'الكهرباء',
      'btu': 'التبريد',
      'cooling': 'التبريد',
      'fuel': 'الوقود',
      'diesel': 'الديزل',
      'chilled water': 'المياه المبرّدة',
      'chilled water / flow': 'المياه المبرّدة / التدفق',
      'irrigation': 'الري',
      'kahramaa': 'كهرماء',
      'kahramaa water': 'مياه كهرماء',
      'tse': 'TSE',
      'tse water': 'مياه TSE',
      'ro': 'RO',
      'storm water': 'مياه الأمطار',
      'flow': 'التدفق',
      'other': 'أخرى',
      'submitted': 'مُسجَّل',
      'pending': 'معلّق',
    };
    return map[lower] ?? trimmed;
  }

  // ── Dates ─────────────────────────────────────────────────────────

  String get today => isAr ? 'اليوم' : 'Today';
  String get yesterday => isAr ? 'أمس' : 'Yesterday';
  String get pickDate => isAr ? 'اختيار تاريخ' : 'Pick date';
  String get customRange => isAr ? 'نطاق مخصص' : 'Custom range';
  String get currentMonth => isAr ? 'الشهر الحالي' : 'Current month';
  String get previousMonth => isAr ? 'الشهر السابق' : 'Previous month';
  String get last7Days => isAr ? 'آخر ٧ أيام' : 'Last 7 days';
  String get last30Days => isAr ? 'آخر ٣١ يوماً' : 'Last 31 days';
  String get month => isAr ? 'شهر' : 'Month';
  String get cancel => isAr ? 'إلغاء' : 'Cancel';
  String get apply => isAr ? 'تطبيق' : 'Apply';
  String get close => isAr ? 'إغلاق' : 'Close';
  String get date => isAr ? 'التاريخ' : 'Date';

  String monthName(int month) {
    if (!isAr) {
      return switch (month) {
        1 => 'January',
        2 => 'February',
        3 => 'March',
        4 => 'April',
        5 => 'May',
        6 => 'June',
        7 => 'July',
        8 => 'August',
        9 => 'September',
        10 => 'October',
        11 => 'November',
        12 => 'December',
        _ => '$month',
      };
    }
    return switch (month) {
      1 => 'يناير',
      2 => 'فبراير',
      3 => 'مارس',
      4 => 'أبريل',
      5 => 'مايو',
      6 => 'يونيو',
      7 => 'يوليو',
      8 => 'أغسطس',
      9 => 'سبتمبر',
      10 => 'أكتوبر',
      11 => 'نوفمبر',
      12 => 'ديسمبر',
      _ => '$month',
    };
  }

  String dateDisplay(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    if (!isAr) return formatBusinessDateDisplay(d);
    return '${d.day} ${monthName(d.month)} ${d.year}';
  }

  String dateSelectionLabel(DashboardDateSelection selection) {
    if (!isAr) return formatDashboardDateSelectionLabel(selection);
    if (selection.isSingleDay) {
      return dateDisplay(selection.selectedDay);
    }
    if (selection.isMonthMode) {
      final d = selection.startDate;
      return '${monthName(d.month)} ${d.year}';
    }
    return '${dateDisplay(selection.startDate)} – ${dateDisplay(selection.endDate)}';
  }

  String datePreset(DashboardDatePreset preset) {
    if (!isAr) return preset.label;
    return switch (preset) {
      DashboardDatePreset.today => today,
      DashboardDatePreset.yesterday => yesterday,
      DashboardDatePreset.pickDay => pickDate,
      DashboardDatePreset.last7Days => last7Days,
      DashboardDatePreset.last30Days => last30Days,
      DashboardDatePreset.currentMonth => currentMonth,
      DashboardDatePreset.previousMonth => previousMonth,
      DashboardDatePreset.monthPicker => month,
      DashboardDatePreset.customRange => customRange,
    };
  }

  // ── Analytics / history (common) ──────────────────────────────────

  String utilityAnalytics(UtilitySystemKey system) =>
      isAr ? 'تحليلات ${utilityLabel(system)}' : '${system.label} analytics';

  String get independentWorkspace => isAr
      ? 'مساحة مستقلة · تُحمَّل الرسوم بعد العدادات'
      : 'Independent workspace · charts load after meters';

  String get compareMeters => isAr ? 'مقارنة العدادات' : 'Compare meters';
  String get clear => isAr ? 'مسح' : 'Clear';
  String get recent => isAr ? 'الأخيرة' : 'Recent';
  String get period => isAr ? 'الفترة' : 'Period';
  String get chartType => isAr ? 'نوع الرسم' : 'Chart type';
  String get twelveMonths => isAr ? '١٢ شهراً' : '12 months';
  String get fiveYears => isAr ? '٥ سنوات' : '5 years';
  String get metersRange => isAr ? 'العدادات' : 'Meters';
  String get chartRange => isAr ? 'المخطط' : 'Chart';
  String get noReadingsForPeriod =>
      isAr ? 'لا توجد قراءات لهذه الفترة.' : 'No readings for this period.';
  String get noReadingsForDateRange => isAr
      ? 'لا توجد قراءات لنطاق التاريخ المحدد.'
      : 'No readings for the selected date range.';
  String get notEnoughReadingsForCop => isAr
      ? 'لا توجد قراءات كافية لحساب COP'
      : 'Not enough readings to calculate COP';
  String get critical => isAr ? 'حرج' : 'Critical';
  String get warning => isAr ? 'تحذير' : 'Warning';
  String get info => isAr ? 'معلومة' : 'Info';
  String get viewAll => isAr ? 'عرض الكل' : 'View all';

  String alertTitle(DashboardAlert alert) {
    if (!isAr) return alert.title;
    return switch (alert.type) {
      AlertType.missingReading => 'قراءة مفقودة اليوم',
      AlertType.lowerThanPrevious => 'قراءة أقل من السابقة',
      AlertType.highConsumption => 'استهلاك مرتفع',
      AlertType.zeroUnexpected => 'استهلاك صفري غير متوقع',
      AlertType.missingPhoto => 'صورة مفقودة',
      AlertType.inactiveMeterReading => 'عداد غير نشط لديه قراءة',
      AlertType.lowCop => 'COP منخفض',
      AlertType.copMissingData => 'بيانات COP ناقصة',
      AlertType.lowCompletion => 'إنجاز قراءة منخفض',
      AlertType.possibleLeak => 'احتمال تسرّب مياه',
    };
  }

  String alertMessage(DashboardAlert alert) {
    if (!isAr) return alert.message;
    return switch (alert.type) {
      AlertType.missingReading => 'لم تُسجَّل قراءة لهذا العداد اليوم.',
      AlertType.lowerThanPrevious => 'أحدث قراءة أقل من القراءة السابقة.',
      AlertType.highConsumption => alert.message,
      AlertType.zeroUnexpected => 'الاستهلاك صفر رغم وجود قراءات سابقة.',
      AlertType.missingPhoto => 'قراءة اليوم بدون صورة مرفقة.',
      AlertType.inactiveMeterReading => 'هذا العداد غير نشط لكن لديه قراءة حديثة.',
      AlertType.lowCop => alert.message,
      AlertType.copMissingData => 'مجموعة COP تحتاج ربط عدادات BTU والكهرباء.',
      AlertType.lowCompletion => alert.message,
      AlertType.possibleLeak => alert.message,
    };
  }

  String get couldNotLoadChart =>
      isAr ? 'تعذّر تحميل المخطط' : 'Could not load chart';
  String get couldNotLoadComparison =>
      isAr ? 'تعذّر تحميل مخطط المقارنة' : 'Could not load comparison chart';
  String get retry => isAr ? 'إعادة المحاولة' : 'Retry';
  String get selectAtLeastTwoMeters => isAr
      ? 'اختر عدادين على الأقل للمقارنة.'
      : 'Select at least two meters to compare.';
  String get searchSelectMeters => isAr
      ? 'ابحث واختر العدادات (حد أقصى 5)'
      : 'Search and select meters (max 5)';

  String chartTypeLabel(UtilityChartType type) {
    if (!isAr) return type.label;
    return switch (type) {
      UtilityChartType.line => 'خطي',
      UtilityChartType.bar => 'أعمدة',
      UtilityChartType.area => 'مساحي',
      UtilityChartType.step => 'درجي',
      UtilityChartType.cumulative => 'تراكمي',
      UtilityChartType.weekday => 'أيام الأسبوع',
      UtilityChartType.ranking => 'ترتيب',
      UtilityChartType.pie => 'دائري',
      UtilityChartType.stackedBar => 'مكدس',
      UtilityChartType.sourceSplit => 'توزيع المصدر',
    };
  }

  String chartPeriodKindLabel(UtilityChartPeriodKind kind) {
    return switch (kind) {
      UtilityChartPeriodKind.last7Days => last7Days,
      UtilityChartPeriodKind.last30Days => last30Days,
      UtilityChartPeriodKind.twelveMonths => twelveMonths,
      UtilityChartPeriodKind.fiveYears => fiveYears,
    };
  }

  String chartAxisLabel({
    required DateTime date,
    required ChartBucket bucket,
    bool compact = false,
  }) {
    switch (bucket) {
      case ChartBucket.daily:
        if (compact) return '${date.day}';
        return '${date.day} ${monthAbbrev(date.month)}';
      case ChartBucket.monthly:
        final yy = (date.year % 100).toString().padLeft(2, '0');
        if (compact) return monthAbbrev(date.month);
        return "${monthAbbrev(date.month)} '$yy";
      case ChartBucket.yearly:
        return '${date.year}';
    }
  }

  String utilityChartTitle(UtilityChartType type, UtilitySystemKey system) {
    final utility = utilityLabel(system);
    if (!isAr) {
      return switch (type) {
        UtilityChartType.line => '$utility consumption trend',
        UtilityChartType.bar => '$utility consumption bars',
        UtilityChartType.area => '$utility consumption area',
        UtilityChartType.step => '$utility step trend',
        UtilityChartType.cumulative => '$utility cumulative consumption',
        UtilityChartType.weekday => '$utility weekday profile',
        UtilityChartType.ranking => system.topConsumersTitle,
        UtilityChartType.pie => '$utility meter share',
        UtilityChartType.stackedBar => '$utility stacked consumption',
        UtilityChartType.sourceSplit => '$utility source split',
      };
    }
    return switch (type) {
      UtilityChartType.line => 'اتجاه استهلاك $utility',
      UtilityChartType.bar => 'أعمدة استهلاك $utility',
      UtilityChartType.area => 'مساحة استهلاك $utility',
      UtilityChartType.step => 'اتجاه درجي — $utility',
      UtilityChartType.cumulative => 'استهلاك تراكمي — $utility',
      UtilityChartType.weekday => 'ملف أيام الأسبوع — $utility',
      UtilityChartType.ranking => 'أعلى المستهلكين — $utility',
      UtilityChartType.pie => 'حصة العدادات — $utility',
      UtilityChartType.stackedBar => 'استهلاك مكدس — $utility',
      UtilityChartType.sourceSplit => 'توزيع المصدر — $utility',
    };
  }

  String comparisonChartTitle(UtilityChartType type, UtilitySystemKey system) {
    final utility = utilityLabel(system);
    if (!isAr) {
      return switch (type) {
        UtilityChartType.line => '$utility meter comparison',
        UtilityChartType.bar => '$utility comparison bars',
        UtilityChartType.area => '$utility comparison area',
        UtilityChartType.step => '$utility comparison step',
        UtilityChartType.cumulative => '$utility cumulative comparison',
        UtilityChartType.weekday => '$utility weekday comparison',
        UtilityChartType.pie => '$utility meter share',
        UtilityChartType.stackedBar => '$utility stacked comparison',
        _ => '$utility meter comparison',
      };
    }
    return switch (type) {
      UtilityChartType.line => 'مقارنة عدادات $utility',
      UtilityChartType.bar => 'أعمدة مقارنة — $utility',
      UtilityChartType.area => 'مساحة مقارنة — $utility',
      UtilityChartType.step => 'مقارنة درجية — $utility',
      UtilityChartType.cumulative => 'مقارنة تراكمية — $utility',
      UtilityChartType.weekday => 'مقارنة أيام الأسبوع — $utility',
      UtilityChartType.pie => 'حصة العدادات — $utility',
      UtilityChartType.stackedBar => 'مقارنة مكدسة — $utility',
      _ => 'مقارنة عدادات $utility',
    };
  }

  String monthAbbrev(int month) {
    if (!isAr) {
      return switch (month) {
        1 => 'Jan',
        2 => 'Feb',
        3 => 'Mar',
        4 => 'Apr',
        5 => 'May',
        6 => 'Jun',
        7 => 'Jul',
        8 => 'Aug',
        9 => 'Sep',
        10 => 'Oct',
        11 => 'Nov',
        12 => 'Dec',
        _ => '$month',
      };
    }
    return switch (month) {
      1 => 'ينا',
      2 => 'فبر',
      3 => 'مار',
      4 => 'أبر',
      5 => 'ماي',
      6 => 'يون',
      7 => 'يول',
      8 => 'أغس',
      9 => 'سبت',
      10 => 'أكت',
      11 => 'نوف',
      12 => 'ديس',
      _ => '$month',
    };
  }

  String weekdayAbbrev(int weekday) {
    // DateTime.weekday: Mon=1 … Sun=7
    if (!isAr) {
      return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday -
          1];
    }
    return const ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'][weekday - 1];
  }

  /// Prefer Arabic name when locale is Arabic and [ar] is non-empty.
  String localizedName({required String en, String? ar}) {
    final arabic = ar?.trim() ?? '';
    if (isAr && arabic.isNotEmpty) return arabic;
    return en;
  }

  String get meterReadingHistory =>
      isAr ? 'سجل قراءات العداد' : 'Meter reading history';
  String get reading => isAr ? 'القراءة' : 'Reading';
  String get note => isAr ? 'ملاحظة' : 'Note';
  String get photo => isAr ? 'الصورة' : 'Photo';
  String get yes => isAr ? 'نعم' : 'Yes';
  String get no => isAr ? 'لا' : 'No';

  // ── Home / sites browser ─────────────────────────────────────────

  String get homeDashboardTitle => isAr ? 'لوحة المعلومات' : 'Dashboard';
  String get homeDashboardSubtitle => isAr
      ? 'تصفّح المناطق وافتح موقعاً لعرض العدادات والتقارير'
      : 'Browse zones and open a site to view meters and reports';
  String get alertsOverview =>
      isAr ? 'نظرة عامة على التنبيهات' : 'Alerts overview';
  String get alertsOverviewSubtitle => isAr
      ? 'التنبيهات النشطة عبر المواقع المتاحة'
      : 'Active alerts across accessible sites';
  String welcomeUser(String name) => isAr ? 'مرحباً، $name' : 'Welcome, $name';

  String get sites => isAr ? 'المواقع' : 'Sites';
  String get meters => isAr ? 'العدادات' : 'Meters';
  String get accessible => isAr ? 'المتاح لك' : 'Accessible';
  String get acrossSites => isAr ? 'عبر المواقع' : 'Across sites';
  String get submittedToday => isAr ? 'مُسجَّل اليوم' : 'Submitted today';
  String get pendingToday => isAr ? 'معلّق اليوم' : 'Pending today';

  String get searchSitesHint => isAr
      ? 'ابحث باسم الموقع أو الموقع الجغرافي…'
      : 'Search site name or location…';
  String get siteType => isAr ? 'نوع الموقع' : 'Site type';
  String get allTypes => isAr ? 'كل الأنواع' : 'All types';

  String siteTypeFilter(DashboardSiteTypeFilter filter) {
    if (!isAr) {
      return switch (filter) {
        DashboardSiteTypeFilter.all => 'All types',
        DashboardSiteTypeFilter.school => 'School',
        DashboardSiteTypeFilter.headquarters => 'Headquarters',
        DashboardSiteTypeFilter.office => 'Office',
        DashboardSiteTypeFilter.warehouse => 'Warehouse',
        DashboardSiteTypeFilter.other => 'Other',
      };
    }
    return switch (filter) {
      DashboardSiteTypeFilter.all => 'كل الأنواع',
      DashboardSiteTypeFilter.school => 'مدرسة',
      DashboardSiteTypeFilter.headquarters => 'مقر رئيسي',
      DashboardSiteTypeFilter.office => 'مكتب',
      DashboardSiteTypeFilter.warehouse => 'مستودع',
      DashboardSiteTypeFilter.other => 'أخرى',
    };
  }

  String siteTypeLabel(SiteType type) => isAr ? type.labelAr : type.label;

  String get noZone => isAr ? 'بدون منطقة' : 'No Zone';
  String get directSites => isAr ? 'مواقع مباشرة' : 'Direct sites';
  String get organizations => isAr ? 'الجهات' : 'Organizations';
  String get organization => isAr ? 'الجهة' : 'Organization';
  String zonesCount(int count) {
    if (!isAr) return count == 1 ? '1 zone' : '$count zones';
    if (count == 0) return 'لا مناطق';
    if (count == 1)
      return '\u0645\u0646\u0637\u0642\u0629 \u0648\u0627\u062d\u062f\u0629';
    if (count == 2) return 'منطقتان';
    if (count >= 3 && count <= 10) return '$count مناطق';
    return '$count منطقة';
  }

  String zoneDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return noZone;
    if (!isAr) return trimmed;
    if (trimmed == kNoZoneLabel || trimmed.toLowerCase() == 'no zone') {
      return noZone;
    }
    final lower = trimmed.toLowerCase();
    return switch (lower) {
      'north zone' => 'المنطقة الشمالية',
      'south zone' => 'المنطقة الجنوبية',
      'east zone' => 'المنطقة الشرقية',
      'west zone' => 'المنطقة الغربية',
      'central zone' => 'المنطقة الوسطى',
      _ =>
        trimmed.endsWith(' Zone') || trimmed.endsWith(' zone')
            ? 'منطقة ${trimmed.substring(0, trimmed.length - 5).trim()}'
            : trimmed,
    };
  }

  String sitesCount(int count) {
    if (!isAr) return count == 1 ? '1 site' : '$count sites';
    if (count == 0) return 'لا مواقع';
    if (count == 1) return 'موقع واحد';
    if (count == 2) return 'موقعان';
    if (count >= 3 && count <= 10) return '$count مواقع';
    return '$count موقعاً';
  }

  String get noSitesMatchFilters =>
      isAr ? 'لا توجد مواقع مطابقة للفلاتر' : 'No sites match your filters';
  String get tryAdjustSearchOrFilters => isAr
      ? 'جرّب تعديل البحث أو معايير التصفية.'
      : 'Try adjusting search or filter criteria.';
  String get noAccessibleSitesInZone => isAr
      ? 'لا توجد مواقع متاحة في هذه المنطقة.'
      : 'No accessible sites in this zone.';

  String get active => isAr ? 'نشط' : 'Active';
  String get inactive => isAr ? 'غير نشط' : 'Inactive';
  String metersCount(int count) => isAr ? '$count عداد' : '$count meters';
  String categoriesCount(int count) =>
      isAr ? '$count فئة' : '$count categories';
  String todayProgress(int submitted, int eligible) {
    if (eligible == 0) {
      return isAr ? 'لا عدادات إدخال' : 'No entry meters';
    }
    return isAr
        ? '$submitted/$eligible مُسجَّل اليوم'
        : '$submitted/$eligible submitted today';
  }

  String get topCriticalAlerts =>
      isAr ? 'أهم التنبيهات الحرجة' : 'Top critical alerts';
  String get alertSeverityFilter =>
      isAr ? 'فلتر شدة التنبيه' : 'Alert severity filter';
  String get allSeverities => isAr ? 'كل المستويات' : 'All severities';
  String get criticalOnly => isAr ? 'حرج فقط' : 'Critical only';
  String get warningOnly => isAr ? 'تحذير فقط' : 'Warning only';
  String get infoOnly => isAr ? 'معلومات فقط' : 'Info only';
  String get previousPeriod => isAr ? 'الفترة السابقة' : 'Previous period';
  String get nextPeriod => isAr ? 'الفترة التالية' : 'Next period';

  String compactDateSelectorLabel(DashboardDateSelection selection) {
    if (selection.isSingleDay) {
      return dateDisplay(selection.subsequentReadingDate);
    }
    return dateSelectionLabel(selection);
  }

  String get signOut => logout;
}

String shellUserRoleLabelEn(UserRole role) {
  return switch (role) {
    UserRole.superAdmin => 'Super Admin',
    UserRole.siteAdmin => 'Site Admin',
    UserRole.technician => 'Technician',
    UserRole.technicianRequest => 'Technician Request',
    UserRole.viewer => 'Viewer',
  };
}
