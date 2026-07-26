import 'package:smart_meters_core/smart_meters_core.dart';

enum DashboardSiteTypeFilter {
  all,
  school,
  headquarters,
  office,
  warehouse,
  other,
}

enum DashboardReadingDateFilter {
  today,
  last7Days,
  last30Days,
  march2026,
  april2026,
  may2026,
}

enum DashboardChartMonth {
  current,
  march2026,
  april2026,
  may2026,
}

/// MOEHE HQ demo site id (staging showcase only).
const kMoeheHqSiteId = '22222222-2222-4222-8222-222222222222';

const kImportedReadingsHint =
    'Imported MOEHE HQ readings cover February 2020 through May 2026 '
    '(gaps on some days). Demo presets include March–May 2026.';

const kImportedReadingsHintAr =
    'قراءات مقر الوزارة المستوردة تغطي من فبراير 2020 حتى مايو 2026 '
    '(مع فراغات في بعض الأيام). الاختصارات التجريبية تشمل مارس–مايو 2026.';

/// Staging-only: MOEHE demo months / import banner / lazy analytics gate.
bool siteHasImportedHistoricalMonths(String siteId) =>
    AppEnv.showDemoSiteUx && siteId == kMoeheHqSiteId;

DashboardChartMonth defaultChartMonthForSite(String siteId) {
  if (siteHasImportedHistoricalMonths(siteId)) {
    return DashboardChartMonth.may2026;
  }
  return DashboardChartMonth.current;
}

extension DashboardReadingDateFilterLabel on DashboardReadingDateFilter {
  String get label => switch (this) {
        DashboardReadingDateFilter.today => 'Today',
        DashboardReadingDateFilter.last7Days => 'Last 7 days',
        DashboardReadingDateFilter.last30Days => 'Last 31 days',
        DashboardReadingDateFilter.march2026 => 'March 2026',
        DashboardReadingDateFilter.april2026 => 'April 2026',
        DashboardReadingDateFilter.may2026 => 'May 2026',
      };
}

extension DashboardChartMonthLabel on DashboardChartMonth {
  String get label => switch (this) {
        DashboardChartMonth.current => 'Current period',
        DashboardChartMonth.march2026 => 'March 2026',
        DashboardChartMonth.april2026 => 'April 2026',
        DashboardChartMonth.may2026 => 'May 2026',
      };
}

enum DashboardPhotoFilter {
  all,
  withPhoto,
  withoutPhoto,
}

List<DashboardSiteOverview> searchDashboardSites(
  List<DashboardSiteOverview> sites,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return sites;
  }
  return sites
      .where(
        (item) =>
            item.site.nameEn.toLowerCase().contains(q) ||
            item.site.nameAr.toLowerCase().contains(q) ||
            (item.site.location?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}

List<DashboardSiteOverview> filterDashboardSitesByZone(
  List<DashboardSiteOverview> sites,
  String? zoneFilterId,
) {
  return filterSitesByZoneId(
    sites.map((item) => item.site).toList(),
    zoneFilterId,
  )
      .map(
        (site) => sites.firstWhere((item) => item.site.id == site.id),
      )
      .toList();
}

List<DashboardSiteOverview> filterDashboardSitesByType(
  List<DashboardSiteOverview> sites,
  DashboardSiteTypeFilter filter,
) {
  if (filter == DashboardSiteTypeFilter.all) {
    return sites;
  }
  final type = switch (filter) {
    DashboardSiteTypeFilter.school => SiteType.school,
    DashboardSiteTypeFilter.headquarters => SiteType.headquarters,
    DashboardSiteTypeFilter.office => SiteType.office,
    DashboardSiteTypeFilter.warehouse => SiteType.warehouse,
    DashboardSiteTypeFilter.other => SiteType.other,
    DashboardSiteTypeFilter.all => SiteType.other,
  };
  return sites.where((item) => item.site.siteType == type).toList();
}

List<ZoneSiteGroup> groupDashboardSites(List<DashboardSiteOverview> sites) {
  return groupSitesByZone(sites.map((item) => item.site).toList());
}

List<DashboardMeterRow> searchDashboardMeters(
  List<DashboardMeterRow> meters,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return meters;
  }
  return meters
      .where(
        (meter) =>
            meter.nameEn.toLowerCase().contains(q) ||
            meter.meterCode.toLowerCase().contains(q),
      )
      .toList();
}

List<DashboardMeterRow> filterDashboardMeters({
  required List<DashboardMeterRow> meters,
  String? categoryId,
  MeterLevel? level,
  bool? activeOnly,
}) {
  return meters.where((meter) {
    if (categoryId != null && meter.categoryId != categoryId) {
      return false;
    }
    if (level != null && meter.level != level) {
      return false;
    }
    if (activeOnly == true && !meter.isActive) {
      return false;
    }
    if (activeOnly == false && meter.isActive) {
      return false;
    }
    return true;
  }).toList();
}

({DateTime from, DateTime to}) readingDateRangeForFilter({
  required DashboardReadingDateFilter filter,
  required DateTime businessDate,
}) {
  switch (filter) {
    case DashboardReadingDateFilter.today:
      return (from: businessDate, to: businessDate);
    case DashboardReadingDateFilter.last7Days:
      return (from: businessDate.subtract(const Duration(days: 6)), to: businessDate);
    case DashboardReadingDateFilter.last30Days:
      return (from: businessDate.subtract(const Duration(days: 30)), to: businessDate);
    case DashboardReadingDateFilter.march2026:
      return (from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));
    case DashboardReadingDateFilter.april2026:
      return (from: DateTime(2026, 4, 1), to: DateTime(2026, 4, 30));
    case DashboardReadingDateFilter.may2026:
      return (from: DateTime(2026, 5, 1), to: DateTime(2026, 5, 31));
  }
}

int readingListLimitForFilter(DashboardReadingDateFilter filter) {
  return switch (filter) {
    DashboardReadingDateFilter.today => 100,
    DashboardReadingDateFilter.last7Days => 100,
    DashboardReadingDateFilter.last30Days => 150,
    DashboardReadingDateFilter.march2026 => 150,
    DashboardReadingDateFilter.april2026 => 150,
    DashboardReadingDateFilter.may2026 => 150,
  };
}

bool readingFilterSupportsLoadMore(DashboardReadingDateFilter filter) {
  return switch (filter) {
    DashboardReadingDateFilter.march2026 => true,
    DashboardReadingDateFilter.april2026 => true,
    DashboardReadingDateFilter.may2026 => true,
    _ => false,
  };
}

DateTime chartBusinessDateForMonth({
  required DashboardChartMonth month,
  required DateTime currentBusinessDate,
}) {
  return switch (month) {
    DashboardChartMonth.current => currentBusinessDate,
    DashboardChartMonth.march2026 => DateTime(2026, 3, 31),
    DashboardChartMonth.april2026 => DateTime(2026, 4, 30),
    DashboardChartMonth.may2026 => DateTime(2026, 5, 31),
  };
}

/// Resolves a non-null chart/report anchor date from an optional override.
DateTime resolveBusinessDate({
  DateTime? override,
  required DateTime fallback,
}) =>
    override ?? fallback;

String formatDashboardDate(DateTime? date) {
  if (date == null) {
    return '—';
  }
  return formatBusinessDate(date);
}

String formatDashboardDateTime(DateTime? value) {
  if (value == null) {
    return '—';
  }
  final local = value.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '${formatBusinessDate(local)} $h:$m';
}
