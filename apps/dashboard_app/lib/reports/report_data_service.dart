import 'package:smart_meters_core/smart_meters_core.dart';

import 'report_export_log.dart';
import 'report_models.dart';

class ReportDataService {
  ReportDataService(
    this._repository,
    this._alertRepository,
    this._policySettings, [
    this._client,
  ]);

  final DashboardRepository _repository;
  final AlertRepository _alertRepository;
  final PolicySettingsRepository _policySettings;

  /// Supabase client from [supabaseClientProvider] (typed loosely to avoid
  /// a direct supabase_flutter dependency in this file).
  final dynamic _client;

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
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    final range = _resolveReportRange(
      period: period,
      businessDate: businessDate,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
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
        rangeOverride: range,
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
      rangeOverride: range,
    );

    final copResults = await _loadCopResults(
      siteId: siteId,
      type: type,
      period: period,
      businessDate: businessDate,
      rangeOverride: range,
    );

    final conservation = await _loadConservationSummary(
      siteId: siteId,
      organizationId: site.organizationId,
      type: type,
    );

    String? categoryFilterName;
    if (categoryId != null) {
      categoryFilterName = categories
          .where((c) => c.category.id == categoryId)
          .map((c) => c.category.displayName)
          .firstOrNull;
    }

    final secondaryLogoPath = site.reportLogoPath?.trim().isNotEmpty == true
        ? site.reportLogoPath
        : (site.zone?.reportLogoPath?.trim().isNotEmpty == true
            ? site.zone!.reportLogoPath
            : policy.reportLogoSecondaryPath);

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
        reportLogoPrimaryPath: policy.reportLogoPrimaryPath,
        reportLogoSecondaryPath: secondaryLogoPath,
        periodLabelOverride:
            '${formatBusinessDate(range.from)} → ${formatBusinessDate(range.to)}',
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
      conservation: conservation,
    );
  }

  ChartPeriodRange _resolveReportRange({
    required ChartPeriod period,
    required DateTime businessDate,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) {
    if (rangeStart != null && rangeEnd != null) {
      final from = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      final to = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
      final spanDays = to.difference(from).inDays;
      final bucket = spanDays > 90
          ? ChartBucket.monthly
          : (spanDays > 400 ? ChartBucket.yearly : ChartBucket.daily);
      return ChartPeriodRange(
        period: period,
        from: from,
        to: to,
        bucket: bucket,
      );
    }
    return chartPeriodRange(period: period, businessDate: businessDate);
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
    ChartPeriodRange? rangeOverride,
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
          rangeOverride: rangeOverride,
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
    ChartPeriodRange? rangeOverride,
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
              rangeOverride: rangeOverride,
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

  /// Loads M&V summary when conservation report type or reports flag is ON.
  /// Verified totals only from status=verified. Missing tariff → Cost Avoided N/A.
  Future<ConservationReportSummary?> _loadConservationSummary({
    required String siteId,
    required String organizationId,
    required ReportType type,
  }) async {
    final client = _client;
    if (client == null) return null;

    reportExportLog('cons', 'load conservation start');
    try {
      final flags = ConservationFeatureFlagRepository(client);
      final module = await flags.isEnabled(
        organizationId: organizationId,
        flagKey: ConservationFeatureFlags.conservationModule,
        siteId: siteId,
      );
      final reportsOn = module &&
          await flags.isEnabled(
            organizationId: organizationId,
            flagKey: ConservationFeatureFlags.conservationReports,
            siteId: siteId,
          );

      // Always allow loading for conservation type (may be empty when flag off).
      if (!reportsOn && type != ReportType.conservation) {
        reportExportLog('cons', 'skipped (flag off)');
        return null;
      }

      final estimationOn = module &&
          await flags.isEnabled(
            organizationId: organizationId,
            flagKey: ConservationFeatureFlags.savingsEstimation,
            siteId: siteId,
          );
      final verificationOn = module &&
          await flags.isEnabled(
            organizationId: organizationId,
            flagKey: ConservationFeatureFlags.savingsVerification,
            siteId: siteId,
          );

      if (!estimationOn && !verificationOn) {
        reportExportLog('cons', 'ok (no estimation/verification flags)');
        return ConservationReportSummary(
          records: const [],
          estimatedSavingTotal: 0,
          verifiedSavingTotal: 0,
          costAvoidedTotal: null,
          verificationPendingCount: 0,
          flagEnabled: reportsOn,
        );
      }

      final records = await MeasurementVerificationRepository(client)
          .listForSite(siteId, limit: 100);

      var estimatedTotal = 0.0;
      var verifiedTotal = 0.0;
      double? costTotal;
      var pending = 0;

      for (final row in records) {
        if (row.status == MvStatus.superseded ||
            row.status == MvStatus.archived) {
          continue;
        }
        if (row.estimatedSavingQuantity != null) {
          estimatedTotal += row.estimatedSavingQuantity!;
        }
        if (row.status == MvStatus.verificationPending) pending++;
        if (row.status == MvStatus.verified) {
          verifiedTotal += row.verifiedSavingQuantity ?? 0;
          if (row.costAvoided != null) {
            costTotal = (costTotal ?? 0) + row.costAvoided!;
          }
        }
      }

      reportExportLog('cons', 'ok (${records.length} rows)');
      return ConservationReportSummary(
        records: records,
        estimatedSavingTotal: estimatedTotal,
        verifiedSavingTotal: verifiedTotal,
        costAvoidedTotal: costTotal,
        verificationPendingCount: pending,
        flagEnabled: reportsOn,
      );
    } catch (error, stack) {
      reportExportLog('cons', 'failed', error: error, stack: stack);
      if (type == ReportType.conservation) {
        return const ConservationReportSummary(
          records: [],
          estimatedSavingTotal: 0,
          verifiedSavingTotal: 0,
          costAvoidedTotal: null,
          verificationPendingCount: 0,
          flagEnabled: false,
        );
      }
      return null;
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
      ReportType.conservation => 'Conservation Report',
    };
  }
}
