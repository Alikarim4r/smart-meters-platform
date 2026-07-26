import 'package:smart_meters_core/smart_meters_core.dart';

enum ReportType {
  allSitesSummary,
  siteSummary,
  readings,
  consumption,
  categoryConsumption,
  cop,
}

enum ReportFormat {
  pdf,
  excel,
}

extension ReportTypeLabel on ReportType {
  String get label => switch (this) {
        ReportType.allSitesSummary => 'All Sites Summary',
        ReportType.siteSummary => 'Site Summary',
        ReportType.readings => 'Site Readings',
        ReportType.consumption => 'Site Consumption',
        ReportType.categoryConsumption => 'Category Consumption',
        ReportType.cop => 'COP Report',
      };
}

extension ReportFormatLabel on ReportFormat {
  String get label => switch (this) {
        ReportFormat.pdf => 'PDF',
        ReportFormat.excel => 'Excel',
      };

  String get extension => switch (this) {
        ReportFormat.pdf => 'pdf',
        ReportFormat.excel => 'xlsx',
      };
}

class ReportExportOptions {
  const ReportExportOptions({
    required this.type,
    required this.format,
    required this.period,
    this.categoryId,
    this.includePhotos = false,
    this.includeCharts = false,
    this.dataAnchorDate,
    this.rangeStart,
    this.rangeEnd,
  });

  final ReportType type;
  final ReportFormat format;
  final ChartPeriod period;
  final String? categoryId;
  final bool includePhotos;
  final bool includeCharts;
  final DateTime? dataAnchorDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
}

class ReportMeta {
  const ReportMeta({
    required this.title,
    required this.generatedAt,
    required this.generatedByEmail,
    required this.period,
    this.siteName,
    this.zoneName,
    this.siteType,
    this.location,
    this.organizationDisplayName,
    this.reportFooterText,
    this.includeAlertsSection = true,
    this.includePhotoIndicator = true,
  });

  final String title;
  final DateTime generatedAt;
  final String generatedByEmail;
  final ChartPeriod period;
  final String? siteName;
  final String? zoneName;
  final String? siteType;
  final String? location;
  final String? organizationDisplayName;
  final String? reportFooterText;
  final bool includeAlertsSection;
  final bool includePhotoIndicator;
}

class SiteReportBundle {
  const SiteReportBundle({
    required this.meta,
    required this.summary,
    required this.categories,
    required this.meters,
    required this.readings,
    required this.completion,
    required this.consumptionTrend,
    this.categoryRankings = const {},
    this.copResults = const [],
    this.categoryFilterName,
    this.alerts = const [],
  });

  final ReportMeta meta;
  final SiteDashboardSummary summary;
  final List<SiteCategorySummary> categories;
  final List<DashboardMeterRow> meters;
  final List<DashboardExportReadingRow> readings;
  final TodayReadingProgress completion;
  final SiteConsumptionTrend consumptionTrend;
  final Map<String, List<CategoryRankingItem>> categoryRankings;
  final List<CopTrendResult> copResults;
  final String? categoryFilterName;
  final List<DashboardAlert> alerts;
}

class AllSitesReportBundle {
  const AllSitesReportBundle({
    required this.meta,
    required this.sites,
    this.alerts = const [],
  });

  final ReportMeta meta;
  final List<DashboardSiteOverview> sites;
  final List<DashboardAlert> alerts;
}

class GeneratedReportFile {
  const GeneratedReportFile({
    required this.path,
    required this.filename,
    required this.format,
  });

  final String path;
  final String filename;
  final ReportFormat format;
}

String periodSlug(ChartPeriod period) => switch (period) {
      ChartPeriod.weekly => 'weekly',
      ChartPeriod.monthly => 'monthly',
      ChartPeriod.last30Days => 'last30days',
      ChartPeriod.yearly => 'yearly',
    };

String reportTypeSlug(ReportType type) => switch (type) {
      ReportType.allSitesSummary => 'all_sites_summary',
      ReportType.siteSummary => 'site_summary',
      ReportType.readings => 'readings',
      ReportType.consumption => 'consumption',
      ReportType.categoryConsumption => 'category_consumption',
      ReportType.cop => 'cop',
    };
