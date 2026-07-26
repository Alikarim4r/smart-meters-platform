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
}

enum DashboardChartMonth {
  current,
}

extension DashboardReadingDateFilterLabel on DashboardReadingDateFilter {
  String get label => switch (this) {
        DashboardReadingDateFilter.today => 'Today',
        DashboardReadingDateFilter.last7Days => 'Last 7 days',
        DashboardReadingDateFilter.last30Days => 'Last 31 days',
      };
}

extension DashboardChartMonthLabel on DashboardChartMonth {
  String get label => switch (this) {
        DashboardChartMonth.current => 'Current period',
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
  }
}

int readingListLimitForFilter(DashboardReadingDateFilter filter) {
  return switch (filter) {
    DashboardReadingDateFilter.today => 100,
    DashboardReadingDateFilter.last7Days => 100,
    DashboardReadingDateFilter.last30Days => 150,
  };
}

bool readingFilterSupportsLoadMore(DashboardReadingDateFilter filter) {
  return false;
}

DateTime chartBusinessDateForMonth({
  required DashboardChartMonth month,
  required DateTime currentBusinessDate,
}) {
  return switch (month) {
    DashboardChartMonth.current => currentBusinessDate,
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
