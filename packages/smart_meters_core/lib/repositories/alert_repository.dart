import '../domain/alert_detection.dart';
import '../domain/business_date.dart';
import '../models/alert_models.dart';
import '../models/dashboard_models.dart';
import '../models/meter_reading.dart';
import '../models/report_export_models.dart';
import '../repositories/policy_settings_repository.dart';
import 'dashboard_repository.dart';

class AlertRepository {
  AlertRepository(this._dashboard, this._policySettings);

  final DashboardRepository _dashboard;
  final PolicySettingsRepository _policySettings;

  Future<List<DashboardAlert>> getSiteAlerts({
    required String siteId,
    required DateTime businessDate,
  }) async {
    final context = await _buildSiteAlertContext(
      siteId: siteId,
      businessDate: businessDate,
    );
    return detectSiteAlerts(context);
  }

  Future<List<DashboardAlert>> getAllAccessibleSitesAlerts({
    required DateTime businessDate,
  }) async {
    final sites = await _dashboard.getAccessibleSitesForDashboard();
    final results = await Future.wait(
      sites.map((site) async {
        try {
          return await getSiteAlerts(
            siteId: site.id,
            businessDate: businessDate,
          );
        } catch (_) {
          // One large/slow site must not fail the whole home alerts load.
          return <DashboardAlert>[];
        }
      }),
    );
    final alerts = results.expand((list) => list).toList();
    alerts.sort((a, b) {
      final severity = _severityRank(
        b.severity,
      ).compareTo(_severityRank(a.severity));
      return severity != 0 ? severity : b.createdAt.compareTo(a.createdAt);
    });
    return alerts;
  }

  Future<AlertSummary> getAlertSummaryForSite({
    required String siteId,
    required DateTime businessDate,
  }) async {
    return AlertSummary.fromAlerts(
      await getSiteAlerts(siteId: siteId, businessDate: businessDate),
    );
  }

  Future<AlertSummary> getAlertSummaryForDashboardHome({
    required DateTime businessDate,
  }) async {
    return AlertSummary.fromAlerts(
      await getAllAccessibleSitesAlerts(businessDate: businessDate),
    );
  }

  Future<SiteAlertContext> _buildSiteAlertContext({
    required String siteId,
    required DateTime businessDate,
  }) async {
    final summary = await _dashboard.getSiteDashboardSummary(
      siteId: siteId,
      businessDate: businessDate,
    );
    final policy = await _policySettings.getEffectivePolicyForSite(siteId);
    final completion = await _dashboard.getTodayCompletion(
      siteId: siteId,
      businessDate: businessDate,
    );
    final meters = await _dashboard.getSiteMetersWithLatestReadings(
      siteId: siteId,
      businessDate: businessDate,
    );

    final todayIso = formatBusinessDate(businessDate);
    final historyFrom = businessDate.subtract(const Duration(days: 29));

    // Slim window reads — compute consumption in-memory (no second heavy scan).
    final historyRaw = await _dashboard.getAlertWindowReadings(
      siteId: siteId,
      fromDate: historyFrom,
      toDate: businessDate,
    );

    final meterById = {for (final m in meters) m.meterId: m};
    final historyReadings = [
      for (final reading in historyRaw)
        _toExportRow(reading, meterById[reading.meterId]),
    ];
    final todayReadings = [
      for (final row in historyReadings)
        if (formatBusinessDate(row.reading.readingDate) == todayIso) row,
    ];

    final consumptionByMeterDate = <String, double>{};
    final waterHistoryByMeter = <String, List<double>>{};
    final byMeterAsc = <String, List<MeterReading>>{};
    for (final reading in historyRaw) {
      byMeterAsc.putIfAbsent(reading.meterId, () => []).add(reading);
    }
    for (final entry in byMeterAsc.entries) {
      final sorted = List<MeterReading>.from(entry.value)
        ..sort((a, b) => a.readingDate.compareTo(b.readingDate));
      double? prev;
      final meter = meterById[entry.key];
      final isWater = (meter?.categoryName ?? '').toLowerCase().contains(
        'water',
      );
      for (final reading in sorted) {
        final value = reading.normalizedValue;
        final daily = prev == null
            ? 0.0
            : (value - prev < 0 ? 0.0 : value - prev);
        prev = value;
        final key =
            '${reading.meterId}|${formatBusinessDate(reading.readingDate)}';
        consumptionByMeterDate[key] = daily;
        if (isWater) {
          waterHistoryByMeter.putIfAbsent(entry.key, () => []).add(daily);
        }
      }
    }

    final todayByMeter = {
      for (final row in todayReadings) row.reading.meterId: row,
    };

    final readingsByMeter = <String, List<DashboardExportReadingRow>>{};
    for (final row in historyReadings) {
      readingsByMeter.putIfAbsent(row.reading.meterId, () => []).add(row);
    }

    final meterContexts = <MeterAlertContext>[];
    for (final meter in meters) {
      final meterReadings = List<DashboardExportReadingRow>.from(
        readingsByMeter[meter.meterId] ?? const [],
      );
      meterReadings.sort(
        (a, b) => b.reading.readingDate.compareTo(a.reading.readingDate),
      );

      final latest = meterReadings.isNotEmpty ? meterReadings.first : null;
      final previous = meterReadings.length > 1 ? meterReadings[1] : null;
      final todayRow = todayByMeter[meter.meterId];

      final recentConsumptions = <double>[];
      for (var i = 1; i <= 7; i++) {
        final date = businessDate.subtract(Duration(days: i));
        final key = '${meter.meterId}|${formatBusinessDate(date)}';
        final value = consumptionByMeterDate[key];
        if (value != null) {
          recentConsumptions.add(value);
        }
      }

      final todayConsumption =
          consumptionByMeterDate['${meter.meterId}|$todayIso'];

      final waterHistory = waterHistoryByMeter[meter.meterId] ?? const [];
      final waterAvg = waterHistory.isEmpty
          ? 0.0
          : waterHistory.reduce((a, b) => a + b) / waterHistory.length;
      final consecutiveHigh = countConsecutiveHighWaterDays(
        dailyConsumptionsNewestFirst: [
          ?todayConsumption,
          for (var i = 1; i <= 6; i++)
            consumptionByMeterDate['${meter.meterId}|${formatBusinessDate(businessDate.subtract(Duration(days: i)))}'] ??
                0,
        ],
        average: waterAvg,
        multiplier: policy.highConsumptionMultiplier,
      );

      final hasInactiveReading =
          !meter.isActive &&
          meterReadings.any(
            (row) => !row.reading.readingDate.isBefore(
              businessDate.subtract(const Duration(days: 7)),
            ),
          );

      meterContexts.add(
        MeterAlertContext(
          meterId: meter.meterId,
          meterCode: meter.meterCode,
          meterName: meter.nameEn,
          categoryName: meter.categoryName,
          categoryCode: meter.categoryName.toLowerCase(),
          isActive: meter.isActive,
          includeInDashboard: meter.includeInDashboard,
          hasReadingToday: meter.hasSubmittedToday,
          latestValue: latest?.reading.rawValue ?? meter.latestRawValue,
          previousValue: previous?.reading.rawValue,
          latestReadingDate:
              latest?.reading.readingDate ?? meter.latestReadingDate,
          todayReadingHasPhoto: todayRow?.hasPhoto ?? false,
          todayConsumption: todayConsumption,
          recentDailyConsumptions: recentConsumptions,
          consecutiveHighWaterDays: consecutiveHigh,
          hasRecentReadingWhileInactive: hasInactiveReading,
        ),
      );
    }

    // Skip per-group COP trend fetches on alert load (too heavy for large sites).
    final copGroups = await _dashboard.getCopGroupsForSite(siteId);
    final copContexts = [
      for (final group in copGroups)
        CopAlertContext(
          copGroupId: group.id,
          copGroupName: group.nameEn,
          btuMeterCount: group.btuMeterCount,
          electricityMeterCount: group.electricityMeterCount,
        ),
    ];

    return SiteAlertContext(
      siteId: siteId,
      siteName: summary.site.nameEn,
      zoneName: summary.site.displayZoneName,
      submittedToday: completion.submitted,
      totalEntryMeters: completion.total,
      meters: meterContexts,
      copGroups: copContexts,
      businessDate: businessDate,
      policy: policy,
    );
  }

  static DashboardExportReadingRow _toExportRow(
    MeterReading reading,
    DashboardMeterRow? meter,
  ) {
    return DashboardExportReadingRow(
      reading: reading,
      siteName: '',
      zoneName: '',
      meterName: meter?.nameEn ?? '',
      meterCode: meter?.meterCode ?? '',
      categoryName: meter?.categoryName ?? '',
      unitLabel: meter?.unitLabel ?? '',
      sourceName: meter?.sourceName ?? '',
    );
  }

  static int _severityRank(AlertSeverity severity) => switch (severity) {
    AlertSeverity.critical => 3,
    AlertSeverity.warning => 2,
    AlertSeverity.info => 1,
  };
}
