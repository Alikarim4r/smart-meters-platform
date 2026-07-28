import '../models/alert_models.dart';
import '../models/policy_settings.dart';
import 'business_date.dart';
import 'efficiency_bands.dart';

/// Default COP threshold — values below suggest inefficient cooling.
const double kLowCopThreshold = 2.5;

/// High-consumption multiplier vs recent average.
const double kHighConsumptionRatio = 3.0;

/// Site completion thresholds.
const double kCompletionWarningRatio = 0.8;
const double kCompletionCriticalRatio = 0.5;

/// Minimum historical days before consumption-based alerts fire.
const int kMinConsumptionHistoryDays = 3;

/// Consecutive high-water days for leak suspicion.
const int kLeakWarningConsecutiveDays = 2;
const int kLeakCriticalConsecutiveDays = 3;

/// Input for per-meter alert evaluation.
class MeterAlertContext {
  const MeterAlertContext({
    required this.meterId,
    required this.meterCode,
    required this.meterName,
    required this.categoryName,
    required this.categoryCode,
    required this.isActive,
    required this.includeInDashboard,
    required this.hasReadingToday,
    this.latestValue,
    this.previousValue,
    this.latestReadingDate,
    this.todayReadingHasPhoto = false,
    this.todayConsumption,
    this.recentDailyConsumptions = const [],
    this.consecutiveHighWaterDays = 0,
    this.hasRecentReadingWhileInactive = false,
  });

  final String meterId;
  final String meterCode;
  final String meterName;
  final String categoryName;
  final String categoryCode;
  final bool isActive;
  final bool includeInDashboard;
  final bool hasReadingToday;
  final double? latestValue;
  final double? previousValue;
  final DateTime? latestReadingDate;
  final bool todayReadingHasPhoto;
  final double? todayConsumption;
  final List<double> recentDailyConsumptions;
  final int consecutiveHighWaterDays;
  final bool hasRecentReadingWhileInactive;

  bool get isWaterCategory {
    final code = categoryCode.toLowerCase();
    return code.contains('water') ||
        categoryName.toLowerCase().contains('water');
  }

  bool get isEntryEligible => isActive && includeInDashboard;
}

/// Input for COP group alert evaluation.
class CopAlertContext {
  const CopAlertContext({
    required this.copGroupId,
    required this.copGroupName,
    required this.btuMeterCount,
    required this.electricityMeterCount,
    this.averageCop,
    this.hasPartialData = false,
  });

  final String copGroupId;
  final String copGroupName;
  final int btuMeterCount;
  final int electricityMeterCount;
  final double? averageCop;
  final bool hasPartialData;
}

/// All site data needed to compute alerts.
class SiteAlertContext {
  SiteAlertContext({
    required this.siteId,
    required this.siteName,
    required this.zoneName,
    required this.submittedToday,
    required this.totalEntryMeters,
    required this.meters,
    required this.copGroups,
    required this.businessDate,
    PolicySettings? policy,
  }) : policy = policy ?? PolicySettings.defaults('');

  final String siteId;
  final String siteName;
  final String zoneName;
  final int submittedToday;
  final int totalEntryMeters;
  final List<MeterAlertContext> meters;
  final List<CopAlertContext> copGroups;
  final DateTime businessDate;
  final PolicySettings policy;
}

List<DashboardAlert> detectSiteAlerts(SiteAlertContext context) {
  final alerts = <DashboardAlert>[];
  final createdAt = DateTime.now();

  alerts.addAll(_detectCompletionAlerts(context, createdAt));

  for (final meter in context.meters) {
    alerts.addAll(_detectMeterAlerts(context, meter, createdAt));
  }

  for (final cop in context.copGroups) {
    alerts.addAll(_detectCopAlerts(context, cop, createdAt));
  }

  alerts.sort((a, b) {
    final severity = _severityRank(
      b.severity,
    ).compareTo(_severityRank(a.severity));
    if (severity != 0) return severity;
    return b.createdAt.compareTo(a.createdAt);
  });

  return alerts;
}

int _severityRank(AlertSeverity severity) => switch (severity) {
  AlertSeverity.critical => 3,
  AlertSeverity.warning => 2,
  AlertSeverity.info => 1,
};

List<DashboardAlert> _detectCompletionAlerts(
  SiteAlertContext context,
  DateTime createdAt,
) {
  if (context.totalEntryMeters <= 0) {
    return const [];
  }
  final ratio = context.submittedToday / context.totalEntryMeters;
  if (ratio >= context.policy.lowCompletionWarningRatio) {
    return const [];
  }

  final severity = ratio < context.policy.lowCompletionCriticalRatio
      ? AlertSeverity.critical
      : AlertSeverity.warning;

  return [
    DashboardAlert(
      id: 'lowCompletion_${context.siteId}_${formatBusinessDate(context.businessDate)}',
      type: AlertType.lowCompletion,
      severity: severity,
      title: 'Low reading completion',
      message:
          'Only ${context.submittedToday}/${context.totalEntryMeters} readings submitted today '
          '(${(ratio * 100).toStringAsFixed(0)}%).',
      siteId: context.siteId,
      siteName: context.siteName,
      zoneName: context.zoneName,
      createdAt: createdAt,
      thresholdValue: context.policy.lowCompletionWarningPercent,
      currentValue: ratio * 100,
      suggestedAction: 'Assign technician to complete readings',
    ),
  ];
}

List<DashboardAlert> _detectMeterAlerts(
  SiteAlertContext context,
  MeterAlertContext meter,
  DateTime createdAt,
) {
  final alerts = <DashboardAlert>[];
  final base = _meterBase(context, meter, createdAt);

  if (meter.isEntryEligible && !meter.hasReadingToday) {
    alerts.add(
      base(
        id: 'missingReading_${meter.meterId}_${formatBusinessDate(context.businessDate)}',
        type: AlertType.missingReading,
        severity: AlertSeverity.warning,
        title: 'Missing reading today',
        message: 'No reading submitted today for this meter.',
        suggestedAction: 'Verify meter reading',
        readingDate: context.businessDate,
      ),
    );
  }

  if (meter.latestValue != null &&
      meter.previousValue != null &&
      meter.latestValue! < meter.previousValue!) {
    alerts.add(
      base(
        id: 'lowerThanPrevious_${meter.meterId}_${meter.latestReadingDate != null ? formatBusinessDate(meter.latestReadingDate!) : 'latest'}',
        type: AlertType.lowerThanPrevious,
        severity: AlertSeverity.critical,
        title: 'Reading lower than previous',
        message: 'Latest reading is lower than previous reading.',
        suggestedAction: 'Verify meter reading',
        readingDate: meter.latestReadingDate,
        currentValue: meter.latestValue,
        previousValue: meter.previousValue,
      ),
    );
  }

  if (meter.hasReadingToday && !meter.todayReadingHasPhoto) {
    alerts.add(
      base(
        id: 'missingPhoto_${meter.meterId}_${formatBusinessDate(context.businessDate)}',
        type: AlertType.missingPhoto,
        severity: context.policy.missingPhotoSeverity.alertSeverity,
        title: 'Missing photo',
        message: 'Reading submitted today without an attached photo.',
        suggestedAction: 'Check meter photo',
        readingDate: context.businessDate,
      ),
    );
  }

  if (!meter.isActive && meter.hasRecentReadingWhileInactive) {
    alerts.add(
      base(
        id: 'inactiveMeterReading_${meter.meterId}',
        type: AlertType.inactiveMeterReading,
        severity: AlertSeverity.warning,
        title: 'Inactive meter has reading',
        message: 'This meter is inactive but has a recent reading.',
        suggestedAction: 'Verify meter reading',
        readingDate: meter.latestReadingDate,
      ),
    );
  }

  final history = meter.recentDailyConsumptions;
  if (history.length >= kMinConsumptionHistoryDays) {
    final average = history.reduce((a, b) => a + b) / history.length;
    final today = meter.todayConsumption ?? 0;

    if (average > 0 &&
        today > average * context.policy.highConsumptionMultiplier) {
      final ratio = today / average;
      alerts.add(
        base(
          id: 'highConsumption_${meter.meterId}_${formatBusinessDate(context.businessDate)}',
          type: AlertType.highConsumption,
          severity: ratio >= context.policy.highConsumptionCriticalMultiplier
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          title: 'High consumption',
          message:
              'Today consumption (${today.toStringAsFixed(2)}) is '
              '${ratio.toStringAsFixed(1)}× the recent average.',
          suggestedAction: 'Verify meter reading',
          readingDate: context.businessDate,
          currentValue: today,
          thresholdValue: average * context.policy.highConsumptionMultiplier,
        ),
      );
    }

    if (context.policy.zeroConsumptionAlertEnabled &&
        average > 0 &&
        today == 0 &&
        meter.hasReadingToday) {
      alerts.add(
        base(
          id: 'zeroUnexpected_${meter.meterId}_${formatBusinessDate(context.businessDate)}',
          type: AlertType.zeroUnexpected,
          severity: AlertSeverity.warning,
          title: 'Unexpected zero consumption',
          message:
              'Consumption is zero today although this meter usually records usage.',
          suggestedAction: 'Verify meter reading',
          readingDate: context.businessDate,
          currentValue: 0,
          thresholdValue: average,
        ),
      );
    }
  }

  if (meter.isWaterCategory) {
    if (meter.consecutiveHighWaterDays >=
        context.policy.possibleLeakDaysCritical) {
      alerts.add(
        base(
          id: 'possibleLeak_${meter.meterId}_${formatBusinessDate(context.businessDate)}',
          type: AlertType.possibleLeak,
          severity: AlertSeverity.critical,
          title: 'Possible water leak',
          message:
              'Water consumption has been abnormally high for '
              '${meter.consecutiveHighWaterDays} consecutive days.',
          suggestedAction: 'Inspect possible leak',
          readingDate: context.businessDate,
        ),
      );
    } else if (meter.consecutiveHighWaterDays >=
        context.policy.possibleLeakDaysWarning) {
      alerts.add(
        base(
          id: 'possibleLeak_${meter.meterId}_${formatBusinessDate(context.businessDate)}',
          type: AlertType.possibleLeak,
          severity: AlertSeverity.warning,
          title: 'Possible water leak',
          message:
              'Water consumption has been elevated for '
              '${meter.consecutiveHighWaterDays} consecutive days.',
          suggestedAction: 'Inspect possible leak',
          readingDate: context.businessDate,
        ),
      );
    }
  }

  return alerts;
}

List<DashboardAlert> _detectCopAlerts(
  SiteAlertContext context,
  CopAlertContext cop,
  DateTime createdAt,
) {
  final alerts = <DashboardAlert>[];

  if (context.policy.copMissingDataAlertEnabled &&
      (cop.btuMeterCount == 0 || cop.electricityMeterCount == 0)) {
    alerts.add(
      DashboardAlert(
        id: 'copMissingData_${cop.copGroupId}',
        type: AlertType.copMissingData,
        severity: AlertSeverity.warning,
        title: 'COP missing meter links',
        message: 'COP group requires both BTU and electricity meters.',
        siteId: context.siteId,
        siteName: context.siteName,
        zoneName: context.zoneName,
        createdAt: createdAt,
        suggestedAction: 'Review COP group data',
      ),
    );
    return alerts;
  }

  if (context.policy.copMissingDataAlertEnabled && cop.hasPartialData) {
    alerts.add(
      DashboardAlert(
        id: 'copPartialData_${cop.copGroupId}_${formatBusinessDate(context.businessDate)}',
        type: AlertType.copMissingData,
        severity: AlertSeverity.warning,
        title: 'COP incomplete data',
        message:
            'COP requires both BTU and electricity readings for this period.',
        siteId: context.siteId,
        siteName: context.siteName,
        zoneName: context.zoneName,
        createdAt: createdAt,
        suggestedAction: 'Review COP group data',
      ),
    );
  }

  final avg = cop.averageCop;
  if (avg != null && avg > 0 && avg < context.policy.lowCopWarningThreshold) {
    alerts.add(
      DashboardAlert(
        id: 'lowCop_${cop.copGroupId}_${formatBusinessDate(context.businessDate)}',
        type: AlertType.lowCop,
        severity: avg < context.policy.lowCopCriticalThreshold
            ? AlertSeverity.critical
            : AlertSeverity.warning,
        title: 'Low COP',
        message: () {
          final band = classifyCop(
            avg,
            warningThreshold: context.policy.lowCopWarningThreshold,
            criticalThreshold: context.policy.lowCopCriticalThreshold,
          );
          return 'Average COP (${avg.toStringAsFixed(2)}) — ${band.labelEn(EfficiencyMetricKind.cop)}. '
              '${band.meaningEn(EfficiencyMetricKind.cop)} '
              'Warning threshold: ${context.policy.lowCopWarningThreshold}.';
        }(),
        siteId: context.siteId,
        siteName: context.siteName,
        zoneName: context.zoneName,
        createdAt: createdAt,
        currentValue: avg,
        thresholdValue: context.policy.lowCopWarningThreshold,
        suggestedAction: 'Review COP group data',
      ),
    );
  }

  return alerts;
}

DashboardAlert Function({
  required String id,
  required AlertType type,
  required AlertSeverity severity,
  required String title,
  required String message,
  String? suggestedAction,
  DateTime? readingDate,
  double? currentValue,
  double? previousValue,
  double? thresholdValue,
})
_meterBase(
  SiteAlertContext context,
  MeterAlertContext meter,
  DateTime createdAt,
) {
  return ({
    required String id,
    required AlertType type,
    required AlertSeverity severity,
    required String title,
    required String message,
    String? suggestedAction,
    DateTime? readingDate,
    double? currentValue,
    double? previousValue,
    double? thresholdValue,
  }) {
    return DashboardAlert(
      id: id,
      type: type,
      severity: severity,
      title: title,
      message: message,
      siteId: context.siteId,
      siteName: context.siteName,
      zoneName: context.zoneName,
      meterId: meter.meterId,
      meterName: meter.meterName,
      meterCode: meter.meterCode,
      categoryName: meter.categoryName,
      readingDate: readingDate,
      currentValue: currentValue,
      previousValue: previousValue,
      thresholdValue: thresholdValue,
      createdAt: createdAt,
      suggestedAction: suggestedAction,
    );
  };
}

int countConsecutiveHighWaterDays({
  required List<double> dailyConsumptionsNewestFirst,
  required double average,
  double multiplier = 2.0,
}) {
  if (average <= 0) return 0;
  var count = 0;
  for (final value in dailyConsumptionsNewestFirst) {
    if (value > average * multiplier) {
      count++;
    } else {
      break;
    }
  }
  return count;
}
