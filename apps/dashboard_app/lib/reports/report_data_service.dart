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
    ReportFormat format = ReportFormat.pdf,
    bool includeCharts = false,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    final range = _resolveReportRange(
      period: period,
      businessDate: businessDate,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    // Heavy consumption scan:
    // - always for consumption / category / readings-with-consumption exports
    // - for site summary only when charts (or Excel rankings) requested
    final isConsumptionReport = type == ReportType.consumption ||
        type == ReportType.categoryConsumption;
    final needsTrend = isConsumptionReport ||
        (includeCharts && type == ReportType.siteSummary);
    final loadRankings = isConsumptionReport ||
        (includeCharts && type == ReportType.siteSummary);
    final needsReadings = type == ReportType.readings ||
        isConsumptionReport ||
        // Overview PDF without charts: skip readings sample for speed.
        (type == ReportType.siteSummary &&
            (includeCharts || format == ReportFormat.excel));
    final needsSharedConsumption = needsTrend || loadRankings;
    final readingsRequired = type == ReportType.readings;
    final readingsLimit = _readingsLimit(type: type, format: format);
    // Overview PDF without charts: avoid consumption rebuild + 180-day meter scan.
    final useLiteMetadata = type == ReportType.siteSummary &&
        !includeCharts &&
        !needsSharedConsumption;

    late SiteDashboardSummary summary;
    late List<SiteCategorySummary> categories;
    late List<DashboardMeterRow> meters;
    late TodayReadingProgress completion;
    late List<DashboardExportReadingRow> readings;
    late List<Map<String, dynamic>> sharedConsumption;
    late PolicySettings policy;

    if (useLiteMetadata) {
      // One metadata round-trip + slim readings sample in parallel.
      reportExportLog('A', 'start (lite one-shot)');
      try {
        final liteLimit = format == ReportFormat.pdf ? 40 : 80;
        final results = await Future.wait<Object>([
          _repository.getSiteReportLiteMetadata(
            siteId: siteId,
            businessDate: businessDate,
          ),
          needsReadings
              ? _loadReadings(
                  siteId: siteId,
                  fromDate: range.from,
                  toDate: range.to,
                  categoryId: categoryId,
                  essential: readingsRequired,
                  limit: liteLimit,
                  slim: true,
                )
              : Future<List<DashboardExportReadingRow>>.value(const []),
          _policySettings.getEffectivePolicyForSite(siteId).then(
                (value) => value,
                onError: (_) => PolicySettings.defaults(''),
              ),
        ]);
        final lite = results[0] as SiteReportLiteMetadata;
        summary = lite.summary;
        categories = lite.categories;
        meters = lite.meters;
        completion = lite.completion;
        readings = results[1] as List<DashboardExportReadingRow>;
        final loadedPolicy = results[2] as PolicySettings;
        policy = loadedPolicy.organizationId.isEmpty
            ? PolicySettings.defaults(summary.site.organizationId)
            : loadedPolicy;
        sharedConsumption = const [];
        reportExportLog(
          'A',
          'lite ok (meters=${meters.length}, readings=${readings.length})',
        );
      } catch (error, stack) {
        reportExportLog('A', 'lite failed', error: error, stack: stack);
        rethrow;
      }
      reportExportLog('E', 'skipped (charts/rankings not requested)');
    } else {
      reportExportLog('A', 'start');
      try {
        final parallel = await Future.wait<Object>([
          _repository.getSiteDashboardSummary(
            siteId: siteId,
            businessDate: businessDate,
          ),
          _repository.getSiteCategoriesSummary(
            siteId: siteId,
            businessDate: businessDate,
          ),
          _repository.getSiteMetersWithLatestReadings(
            siteId: siteId,
            businessDate: businessDate,
          ),
          _repository.getTodayCompletion(
            siteId: siteId,
            businessDate: businessDate,
          ),
        ]);
        summary = parallel[0] as SiteDashboardSummary;
        categories = parallel[1] as List<SiteCategorySummary>;
        meters = parallel[2] as List<DashboardMeterRow>;
        completion = parallel[3] as TodayReadingProgress;
        reportExportLog('A', 'ok');
        reportExportLog('B', 'ok');
        reportExportLog('C', 'ok');
        reportExportLog('completion', 'ok');
      } catch (error, stack) {
        reportExportLog('A', 'failed', error: error, stack: stack);
        rethrow;
      }

      policy = await _loadOptional(
        'policy',
        () => _policySettings.getEffectivePolicyForSite(siteId),
        fallback: PolicySettings.defaults(summary.site.organizationId),
      );

      sharedConsumption = const [];
      if (needsSharedConsumption) {
        reportExportLog('E', 'shared consumption start');
        try {
          sharedConsumption = await _repository.fetchConsumptionRowsForReport(
            siteId: siteId,
            from: range.from,
            to: range.to,
            categoryId: categoryId,
            bucket: range.bucket,
          );
          reportExportLog(
            'E',
            'shared consumption ok (${sharedConsumption.length} rows)',
          );
        } catch (error, stack) {
          reportExportLog(
            'E',
            'shared consumption failed (empty)',
            error: error,
            stack: stack,
          );
          sharedConsumption = const [];
        }
      } else {
        reportExportLog('E', 'skipped (charts/rankings not requested)');
      }

      readings = needsReadings
          ? await _loadReadings(
              siteId: siteId,
              fromDate: range.from,
              toDate: range.to,
              categoryId: categoryId,
              essential: readingsRequired,
              limit: readingsLimit,
              prefetchedConsumptionRows: sharedConsumption,
              slim: false,
            )
          : const <DashboardExportReadingRow>[];
    }

    final site = summary.site;

    final consumptionTrend = needsTrend
        ? _trendFromRows(rows: sharedConsumption, range: range)
        : const SiteConsumptionTrend(
            series: [],
            emptyMessage: 'Charts not included in this export',
          );

    final rankings = loadRankings
        ? _rankingsFromRows(
            rows: sharedConsumption,
            categories: categories,
            categoryId: categoryId,
          )
        : <String, List<CategoryRankingItem>>{};

    // Alerts are expensive (another readings window) — skip on export.
    reportExportLog('alerts-site', 'skipped (export fast path)');
    const alerts = <DashboardAlert>[];

    // COP only for dedicated COP reports (each group re-scans consumption).
    final copResults = type == ReportType.cop
        ? await _loadCopResults(
            siteId: siteId,
            type: type,
            period: period,
            businessDate: businessDate,
            rangeOverride: range,
          )
        : const <CopTrendResult>[];
    if (type != ReportType.cop) {
      reportExportLog('F', 'skipped (not COP report)');
    }

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

  int _readingsLimit({
    required ReportType type,
    required ReportFormat format,
  }) {
    if (type == ReportType.readings) return 5000;
    if (format == ReportFormat.pdf) return 200;
    return 2000;
  }

  SiteConsumptionTrend _trendFromRows({
    required List<Map<String, dynamic>> rows,
    required ChartPeriodRange range,
  }) {
    reportExportLog('E', 'derive trend start');
    final series = aggregateCategoryConsumption(rows: rows, range: range);
    if (series.isEmpty) {
      reportExportLog('E', 'derive trend ok (empty)');
      return const SiteConsumptionTrend(
        series: [],
        emptyMessage: 'No readings for this period',
      );
    }
    reportExportLog('E', 'derive trend ok (${series.length} series)');
    return SiteConsumptionTrend(series: series);
  }

  Map<String, List<CategoryRankingItem>> _rankingsFromRows({
    required List<Map<String, dynamic>> rows,
    required List<SiteCategorySummary> categories,
    String? categoryId,
  }) {
    final rankings = <String, List<CategoryRankingItem>>{};
    final targetCategories = categoryId == null
        ? categories
        : categories.where((c) => c.category.id == categoryId);

    for (final category in targetCategories) {
      final step = 'ranking-${category.category.code}';
      reportExportLog(step, 'start');
      try {
        rankings[category.category.id] = aggregateMeterRanking(
          rows: rows,
          categoryId: category.category.id,
        );
        reportExportLog(step, 'ok');
      } catch (error, stack) {
        reportExportLog(step, 'failed (skipping)', error: error, stack: stack);
        rankings[category.category.id] = const [];
      }
    }
    return rankings;
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
    required int limit,
    List<Map<String, dynamic>>? prefetchedConsumptionRows,
    bool slim = false,
  }) async {
    reportExportLog('D', 'start (limit=$limit${slim ? ", slim" : ""})');
    try {
      final result = slim
          ? await _repository.getExportReadingsSlim(
              siteId: siteId,
              fromDate: fromDate,
              toDate: toDate,
              categoryId: categoryId,
              limit: limit > 100 ? 100 : limit,
            )
          : await _repository.getExportReadings(
              siteId: siteId,
              fromDate: fromDate,
              toDate: toDate,
              categoryId: categoryId,
              limit: limit,
              prefetchedConsumptionRows: prefetchedConsumptionRows,
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

  /// Loads M&V only for Conservation reports (or empty shell when type is conservation).
  Future<ConservationReportSummary?> _loadConservationSummary({
    required String siteId,
    required String organizationId,
    required ReportType type,
  }) async {
    final client = _client;
    if (client == null) return null;

    // Avoid extra flag/network work on every site summary when demo flags are ON.
    if (type != ReportType.conservation) {
      reportExportLog('cons', 'skipped (not conservation report)');
      return null;
    }

    reportExportLog('cons', 'load conservation start');
    try {
      final flags = ConservationFeatureFlagRepository(client);
      final map = await flags.resolvedEnabledByKey(
        organizationId: organizationId,
        siteId: siteId,
      );
      final module =
          map[ConservationFeatureFlags.conservationModule] ?? false;
      final reportsOn = module &&
          (map[ConservationFeatureFlags.conservationReports] ?? false);
      final estimationOn = module &&
          (map[ConservationFeatureFlags.savingsEstimation] ?? false);
      final verificationOn = module &&
          (map[ConservationFeatureFlags.savingsVerification] ?? false);

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
      return const ConservationReportSummary(
        records: [],
        estimatedSavingTotal: 0,
        verifiedSavingTotal: 0,
        costAvoidedTotal: null,
        verificationPendingCount: 0,
        flagEnabled: false,
      );
    }
  }

  String _titleForType(ReportType type, String? categoryName) {
    return switch (type) {
      ReportType.siteSummary => 'Site Summary Report',
      ReportType.readings => 'Site Readings Report',
      ReportType.consumption => 'Site Consumption Report',
      ReportType.categoryConsumption =>
        categoryName == null
            ? 'Category Consumption Report'
            : '$categoryName Consumption Report',
      ReportType.cop => 'COP Report',
      ReportType.allSitesSummary => 'All Sites Summary',
      ReportType.conservation => 'Conservation Report',
    };
  }
}
