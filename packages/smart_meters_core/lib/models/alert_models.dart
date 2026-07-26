/// Severity of a dashboard alert.
enum AlertSeverity { info, warning, critical }

extension AlertSeverityLabel on AlertSeverity {
  String get label => switch (this) {
    AlertSeverity.info => 'Info',
    AlertSeverity.warning => 'Warning',
    AlertSeverity.critical => 'Critical',
  };
}

/// Lifecycle status for a computed alert.
enum AlertStatus { active, acknowledged, resolved }

/// Types of anomaly / operational alerts.
enum AlertType {
  missingReading,
  lowerThanPrevious,
  highConsumption,
  zeroUnexpected,
  missingPhoto,
  inactiveMeterReading,
  lowCop,
  copMissingData,
  lowCompletion,
  possibleLeak,
}

extension AlertTypeLabel on AlertType {
  String get label => switch (this) {
    AlertType.missingReading => 'Missing reading',
    AlertType.lowerThanPrevious => 'Lower than previous',
    AlertType.highConsumption => 'High consumption',
    AlertType.zeroUnexpected => 'Unexpected zero consumption',
    AlertType.missingPhoto => 'Missing photo',
    AlertType.inactiveMeterReading => 'Inactive meter reading',
    AlertType.lowCop => 'Low COP',
    AlertType.copMissingData => 'COP missing data',
    AlertType.lowCompletion => 'Low completion',
    AlertType.possibleLeak => 'Possible leak',
  };
}

/// Computed alert row for dashboard monitoring.
class DashboardAlert {
  const DashboardAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.siteId,
    required this.siteName,
    required this.zoneName,
    required this.createdAt,
    this.meterId,
    this.meterName,
    this.meterCode,
    this.categoryName,
    this.readingDate,
    this.currentValue,
    this.previousValue,
    this.thresholdValue,
    this.suggestedAction,
    this.status = AlertStatus.active,
  });

  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final String siteId;
  final String siteName;
  final String zoneName;
  final String? meterId;
  final String? meterName;
  final String? meterCode;
  final String? categoryName;
  final DateTime? readingDate;
  final double? currentValue;
  final double? previousValue;
  final double? thresholdValue;
  final DateTime createdAt;
  final AlertStatus status;
  final String? suggestedAction;

  bool get isActive => status == AlertStatus.active;
}

/// Aggregated alert counts.
class AlertSummary {
  const AlertSummary({
    required this.total,
    required this.critical,
    required this.warning,
    required this.info,
    this.alerts = const [],
  });

  final int total;
  final int critical;
  final int warning;
  final int info;
  final List<DashboardAlert> alerts;

  bool get hasAlerts => total > 0;

  factory AlertSummary.fromAlerts(List<DashboardAlert> alerts) {
    var critical = 0;
    var warning = 0;
    var info = 0;
    for (final alert in alerts) {
      switch (alert.severity) {
        case AlertSeverity.critical:
          critical++;
        case AlertSeverity.warning:
          warning++;
        case AlertSeverity.info:
          info++;
      }
    }
    return AlertSummary(
      total: alerts.length,
      critical: critical,
      warning: warning,
      info: info,
      alerts: alerts,
    );
  }
}
