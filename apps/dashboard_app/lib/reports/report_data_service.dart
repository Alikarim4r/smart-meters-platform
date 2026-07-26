import 'package:smart_meters_core/smart_meters_core.dart';

import 'report_export_log.dart';
import 'report_models.dart';

class ReportDataService {
  ReportDataService(
    this._repository,
    this._alertRepository,
    this._policySettings,
  );

  final DashboardRepository _repository;
  final AlertRepository _alertRepository;
  final PolicySettingsRepository _policySettings;

  Future<AllSitesReportBundle> loadAllSitesReport({
    required String userEmail,
    required ChartPeriod period,
    required DateTime businessDate,
  }) async {
    reportExportLog('A', 'load all sites overview start');
    final sites = await _repository.getSitesOverview(businessDate: businessDate);
    reportExportLog('A', 'load all sites overview ok (${sites.length} sites)');

    final alerts = await _loadAlertsOptional(
      step: 'alerts-all',
      loader: () => _alertRepository.getAllAccessibleSitesAlerts(
        businessDate: businessDate,
      ),
    );

    return AllSitesReportBundle(
      meta: ReportMeta(
        title: 'All Accessible Sites Summary',
        generatedAt: DateTime.now(),
        generatedByEmail: userEmail,
        period: period,
      ),
      sites: sites,
      alerts: alerts,
    );
  }

  Future<SiteReportBundle> loadSiteReport({
    required String siteId,
    required String userEmail,
    required ChartPeriod period,
    required DateTime businessDate,
    String? categoryId,
    ReportType type = ReportType.siteSummary,
  }) async {
    final range = chartPeriodRange(period: period, businessDate: businessDate);
    final readingsRequired = type == ReportType.readings;

    final summary = await _loadEssential(
      'A',
      () => _repository.getSiteDashboardSummary(
        siteId: siteId,
        businessDate: businessDate,
      ),
    );
    final site = summary.site;

    final categories = await _loadEssential(
      'B',
      () => _repository.getSiteCategoriesSummary(
        siteId: siteId,
        businessDate: businessDate,
      ),
    );
    final meters = await _loadEssential(
      'C',
      () => _repository.getSiteMetersWithLatestReadings(
        siteId: siteId,
        businessDate: businessDate,
      ),
    );

    final completion = await _loadOptional(
      'completion',
      () => _repository.getTodayCompletion(
        siteId: siteId,
        businessDate: businessDate,
      ),
      fallback: const TodayReadingProgress(submitted: 0, total: 0, pending: 0),
    );

    final consumptionTrend = await _loadOptional(
      'E',
      () => _repository.getSiteConsumptionTrend(
        siteId: siteId,
        period: period,
        businessDate: businessDate,
      ),
      fallback: const SiteConsumptionTrend(
        series: [],
        emptyMessage: 'Consumption data unavailable',
      ),
    );

    final readings = await _loadReadings(
      siteId: siteId,
      fromDate: range.from,
      toDate: range.to,
      categoryId: categoryId,
      essential: readingsRequired,
    );

    final policy = await _loadOptional(
      'policy',
      () => _policySettings.getEffectivePolicyForSite(siteId),
      fallback: PolicySettings.defaults(site.organizationId),
    );

    final alerts = policy.includeAlertSectionDefault
        ? await _loadAlertsOptional(
            step: 'alerts-site',
            loader: () => _alertRepository.getSiteAlerts(
              siteId: siteId,
              businessDate: businessDate,
            ),
          )
        : <DashboardAlert>[];

    final rankings = await _loadRankings(
      siteId: siteId,
      categories: categories,
      categoryId: categoryId,
      period: period,
      businessDate: businessDate,
    );

    final copResults = await _loadCopResults(
      siteId: siteId,
      type: type,
      period: period,
      businessDate: businessDate,
    );

    String? categoryFilterName;
    if (categoryId != null) {
      categoryFilterName = categories
          .where((c) => c.category.id == categoryId)
          .map((c) => c.category.displayName)
          .firstOrNull;
    }

    return SiteReportBundle(
      meta: ReportMeta(
        title: _titleForType(type, categoryFilterName),
        generatedAt: DateTime.now(),
        generatedByEmail: userEmail,
        period: period,
        siteName: site.nameEn,
        zoneName: site.displayZoneName,
        siteType: site.siteType.label,
        location: site.location,
        organizationDisplayName: policy.organizationDisplayName,
        reportFooterText: policy.reportFooterText,
        includeAlertsSection: policy.includeAlertSectionDefault,
        includePhotoIndicator: policy.includePhotoIndicatorDefault,
      ),
      summary: summary,
      categories: categories,
      meters: meters,
      readings: readings,
      completion: completion,
      consumptionTrend: consumptionTrend,
      categoryRankings: rankings,
      copResults: copResults,
      categoryFilterName: categoryFilterName,
      alerts: alerts,
    );
  }

  Future<T> _loadEssential<T>(String step, Future<T> Function() loader) async {
    reportExportLog(step, 'start');
    try {
      final result = await loader();
      reportExportLog(step, 'ok');
      return result;
    } catch (error, stack) {
      reportExportLog(step, 'failed', error: error, stack: stack);
      rethrow;
    }
  }

  Future<T> _loadOptional<T>(
    String step,
    Future<T> Function() loader, {
    required T fallback,
  }) async {
    reportExportLog(step, 'start');
    try {
      final result = await loader();
      reportExportLog(step, 'ok');
      return result;
    } catch (error, stack) {
      reportExportLog(step, 'failed (using fallback)', error: error, stack: stack);
      return fallback;
    }
  }

  Future<List<DashboardExportReadingRow>> _loadReadings({
    required String siteId,
    required DateTime fromDate,
    required DateTime toDate,
    String? categoryId,
    required bool essential,
  }) async {
    reportExportLog('D', 'start');
    try {
      final result = await _repository.getExportReadings(
        siteId: siteId,
        fromDate: fromDate,
        toDate: toDate,
        categoryId: categoryId,
      );
      reportExportLog('D', 'ok (${result.length} rows)');
      return result;
    } catch (error, stack) {
      reportExportLog('D', 'failed', error: error, stack: stack);
      if (essential) {
        rethrow;
      }
      return const [];
    }
  }

  Future<List<DashboardAlert>> _loadAlertsOptional({
    required String step,
    required Future<List<DashboardAlert>> Function() loader,
  }) async {
    reportExportLog(step, 'start');
    try {
      final result = await loader();
      reportExportLog(step, 'ok (${result.length} alerts)');
      return result;
    } catch (error, stack) {
      reportExportLog(step, 'failed (skipping alerts)', error: error, stack: stack);
      return const [];
    }
  }

  Future<Map<String, List<CategoryRankingItem>>> _loadRankings({
    required String siteId,
    required List<SiteCategorySummary> categories,
    required ChartPeriod period,
    required DateTime businessDate,
    String? categoryId,
  }) async {
    final rankings = <String, List<CategoryRankingItem>>{};
    final targetCategories = categoryId == null
        ? categories
        : categories.where((c) => c.category.id == categoryId);

    for (final category in targetCategories) {
      final step = 'ranking-${category.category.code}';
      reportExportLog(step, 'start');
      try {
        rankings[category.category.id] = await _repository.getCategoryRanking(
          siteId: siteId,
          categoryId: category.category.id,
          period: period,
          businessDate: businessDate,
        );
        reportExportLog(step, 'ok');
      } catch (error, stack) {
        reportExportLog(step, 'failed (skipping)', error: error, stack: stack);
        rankings[category.category.id] = const [];
      }
    }
    return rankings;
  }

  Future<List<CopTrendResult>> _loadCopResults({
    required String siteId,
    required ReportType type,
    required ChartPeriod period,
    required DateTime businessDate,
  }) async {
    if (type != ReportType.cop && type != ReportType.siteSummary) {
      return const [];
    }

    reportExportLog('F', 'load COP groups start');
    try {
      final copGroups = await _repository.getCopGroupsForSite(siteId);
      reportExportLog('F', 'load COP groups ok (${copGroups.length})');

      final copResults = <CopTrendResult>[];
      for (final group in copGroups) {
        final step = 'F-${group.nameEn}';
        reportExportLog(step, 'start');
        try {
          copResults.add(
            await _repository.getCopTrend(
              copGroupId: group.id,
              period: period,
              businessDate: businessDate,
            ),
          );
          reportExportLog(step, 'ok');
        } catch (error, stack) {
          reportExportLog(step, 'failed (placeholder)', error: error, stack: stack);
          copResults.add(
            CopTrendResult(
              copGroupId: group.id,
              copGroupName: group.nameEn,
              points: const [],
              btuMeterCount: group.btuMeterCount,
              electricityMeterCount: group.electricityMeterCount,
              emptyMessage: 'COP data unavailable',
            ),
          );
        }
      }
      return copResults;
    } catch (error, stack) {
      reportExportLog('F', 'failed (no COP section)', error: error, stack: stack);
      return const [];
    }
  }

  String _titleForType(ReportType type, String? categoryName) {
    return switch (type) {
      ReportType.siteSummary => 'Site Summary Report',
      ReportType.readings => 'Site Readings Report',
      ReportType.consumption => 'Site Consumption Report',
      ReportType.categoryConsumption =>
        categoryName == null ? 'Category Consumption Report' : '$categoryName Consumption Report',
      ReportType.cop => 'COP Report',
      ReportType.allSitesSummary => 'All Sites Summary',
    };
  }
}
