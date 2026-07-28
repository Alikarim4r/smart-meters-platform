import 'alert_models.dart';

/// Severity for missing-photo alerts.
enum MissingPhotoSeverity { info, warning, critical }

extension MissingPhotoSeverityLabel on MissingPhotoSeverity {
  String get label => switch (this) {
    MissingPhotoSeverity.info => 'Info',
    MissingPhotoSeverity.warning => 'Warning',
    MissingPhotoSeverity.critical => 'Critical',
  };

  String get dbValue => name;

  AlertSeverity get alertSeverity => switch (this) {
    MissingPhotoSeverity.info => AlertSeverity.info,
    MissingPhotoSeverity.warning => AlertSeverity.warning,
    MissingPhotoSeverity.critical => AlertSeverity.critical,
  };

  static MissingPhotoSeverity parseDb(String value) {
    return MissingPhotoSeverity.values.firstWhere(
      (item) => item.dbValue == value,
      orElse: () => MissingPhotoSeverity.info,
    );
  }
}

/// Organization operational policy settings.
class PolicySettings {
  const PolicySettings({
    this.id,
    required this.organizationId,
    this.scope = 'organization',
    this.siteId,
    this.photoRequired = false,
    this.missingPhotoSeverity = MissingPhotoSeverity.info,
    this.highConsumptionMultiplier = 3.0,
    this.highConsumptionCriticalMultiplier = 5.0,
    this.zeroConsumptionAlertEnabled = true,
    this.lowCompletionWarningPercent = 80,
    this.lowCompletionCriticalPercent = 50,
    this.lowCopWarningThreshold = 2.5,
    this.lowCopCriticalThreshold = 2.0,
    this.copMissingDataAlertEnabled = true,
    this.possibleLeakDaysWarning = 2,
    this.possibleLeakDaysCritical = 3,
    this.dailyReadingCutoffTime,
    this.allowLateReadings = false,
    this.reportFooterText,
    this.organizationDisplayName,
    this.logoUrl,
    this.reportLogoPrimaryPath,
    this.reportLogoSecondaryPath,
    this.includeAlertSectionDefault = true,
    this.includePhotoIndicatorDefault = true,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String organizationId;
  final String scope;
  final String? siteId;
  final bool photoRequired;
  final MissingPhotoSeverity missingPhotoSeverity;
  final double highConsumptionMultiplier;
  final double highConsumptionCriticalMultiplier;
  final bool zeroConsumptionAlertEnabled;
  final double lowCompletionWarningPercent;
  final double lowCompletionCriticalPercent;
  final double lowCopWarningThreshold;
  final double lowCopCriticalThreshold;
  final bool copMissingDataAlertEnabled;
  final int possibleLeakDaysWarning;
  final int possibleLeakDaysCritical;
  final String? dailyReadingCutoffTime;
  final bool allowLateReadings;
  final String? reportFooterText;
  final String? organizationDisplayName;
  final String? logoUrl;
  final String? reportLogoPrimaryPath;
  final String? reportLogoSecondaryPath;
  final bool includeAlertSectionDefault;
  final bool includePhotoIndicatorDefault;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get lowCompletionWarningRatio => lowCompletionWarningPercent / 100;
  double get lowCompletionCriticalRatio => lowCompletionCriticalPercent / 100;

  factory PolicySettings.defaults(String organizationId) {
    return PolicySettings(organizationId: organizationId);
  }

  factory PolicySettings.fromJson(Map<String, dynamic> json) {
    return PolicySettings(
      id: json['id'] as String?,
      organizationId: json['organization_id'] as String,
      scope: json['scope'] as String? ?? 'organization',
      siteId: json['site_id'] as String?,
      photoRequired: json['photo_required'] as bool? ?? false,
      missingPhotoSeverity: MissingPhotoSeverityLabel.parseDb(
        json['missing_photo_severity'] as String? ?? 'info',
      ),
      highConsumptionMultiplier: _toDouble(
        json['high_consumption_multiplier'],
        3.0,
      ),
      highConsumptionCriticalMultiplier: _toDouble(
        json['high_consumption_critical_multiplier'],
        5.0,
      ),
      zeroConsumptionAlertEnabled:
          json['zero_consumption_alert_enabled'] as bool? ?? true,
      lowCompletionWarningPercent: _toDouble(
        json['low_completion_warning_percent'],
        80,
      ),
      lowCompletionCriticalPercent: _toDouble(
        json['low_completion_critical_percent'],
        50,
      ),
      lowCopWarningThreshold: _toDouble(json['low_cop_warning_threshold'], 2.5),
      lowCopCriticalThreshold: _toDouble(
        json['low_cop_critical_threshold'],
        2.0,
      ),
      copMissingDataAlertEnabled:
          json['cop_missing_data_alert_enabled'] as bool? ?? true,
      possibleLeakDaysWarning: json['possible_leak_days_warning'] as int? ?? 2,
      possibleLeakDaysCritical:
          json['possible_leak_days_critical'] as int? ?? 3,
      dailyReadingCutoffTime: json['daily_reading_cutoff_time'] as String?,
      allowLateReadings: json['allow_late_readings'] as bool? ?? false,
      reportFooterText: json['report_footer_text'] as String?,
      organizationDisplayName: json['organization_display_name'] as String?,
      logoUrl: json['logo_url'] as String?,
      reportLogoPrimaryPath: json['report_logo_primary_path'] as String?,
      reportLogoSecondaryPath: json['report_logo_secondary_path'] as String?,
      includeAlertSectionDefault:
          json['include_alert_section_default'] as bool? ?? true,
      includePhotoIndicatorDefault:
          json['include_photo_indicator_default'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'photo_required': photoRequired,
      'missing_photo_severity': missingPhotoSeverity.dbValue,
      'high_consumption_multiplier': highConsumptionMultiplier,
      'high_consumption_critical_multiplier': highConsumptionCriticalMultiplier,
      'zero_consumption_alert_enabled': zeroConsumptionAlertEnabled,
      'low_completion_warning_percent': lowCompletionWarningPercent,
      'low_completion_critical_percent': lowCompletionCriticalPercent,
      'low_cop_warning_threshold': lowCopWarningThreshold,
      'low_cop_critical_threshold': lowCopCriticalThreshold,
      'cop_missing_data_alert_enabled': copMissingDataAlertEnabled,
      'possible_leak_days_warning': possibleLeakDaysWarning,
      'possible_leak_days_critical': possibleLeakDaysCritical,
      'daily_reading_cutoff_time': dailyReadingCutoffTime,
      'allow_late_readings': allowLateReadings,
      'report_footer_text': reportFooterText,
      'organization_display_name': organizationDisplayName,
      'logo_url': logoUrl,
      'report_logo_primary_path': reportLogoPrimaryPath,
      'report_logo_secondary_path': reportLogoSecondaryPath,
      'include_alert_section_default': includeAlertSectionDefault,
      'include_photo_indicator_default': includePhotoIndicatorDefault,
      'is_active': isActive,
    };
  }

  PolicySettings copyWith({
    String? id,
    bool? photoRequired,
    MissingPhotoSeverity? missingPhotoSeverity,
    double? highConsumptionMultiplier,
    double? highConsumptionCriticalMultiplier,
    bool? zeroConsumptionAlertEnabled,
    double? lowCompletionWarningPercent,
    double? lowCompletionCriticalPercent,
    double? lowCopWarningThreshold,
    double? lowCopCriticalThreshold,
    bool? copMissingDataAlertEnabled,
    int? possibleLeakDaysWarning,
    int? possibleLeakDaysCritical,
    String? dailyReadingCutoffTime,
    bool? allowLateReadings,
    String? reportFooterText,
    String? organizationDisplayName,
    String? logoUrl,
    String? reportLogoPrimaryPath,
    String? reportLogoSecondaryPath,
    bool clearReportLogoPrimaryPath = false,
    bool clearReportLogoSecondaryPath = false,
    bool? includeAlertSectionDefault,
    bool? includePhotoIndicatorDefault,
    bool clearDailyReadingCutoffTime = false,
    bool clearReportFooterText = false,
    bool clearOrganizationDisplayName = false,
    bool clearLogoUrl = false,
  }) {
    return PolicySettings(
      id: id ?? this.id,
      organizationId: organizationId,
      scope: scope,
      siteId: siteId,
      photoRequired: photoRequired ?? this.photoRequired,
      missingPhotoSeverity: missingPhotoSeverity ?? this.missingPhotoSeverity,
      highConsumptionMultiplier:
          highConsumptionMultiplier ?? this.highConsumptionMultiplier,
      highConsumptionCriticalMultiplier:
          highConsumptionCriticalMultiplier ??
          this.highConsumptionCriticalMultiplier,
      zeroConsumptionAlertEnabled:
          zeroConsumptionAlertEnabled ?? this.zeroConsumptionAlertEnabled,
      lowCompletionWarningPercent:
          lowCompletionWarningPercent ?? this.lowCompletionWarningPercent,
      lowCompletionCriticalPercent:
          lowCompletionCriticalPercent ?? this.lowCompletionCriticalPercent,
      lowCopWarningThreshold:
          lowCopWarningThreshold ?? this.lowCopWarningThreshold,
      lowCopCriticalThreshold:
          lowCopCriticalThreshold ?? this.lowCopCriticalThreshold,
      copMissingDataAlertEnabled:
          copMissingDataAlertEnabled ?? this.copMissingDataAlertEnabled,
      possibleLeakDaysWarning:
          possibleLeakDaysWarning ?? this.possibleLeakDaysWarning,
      possibleLeakDaysCritical:
          possibleLeakDaysCritical ?? this.possibleLeakDaysCritical,
      dailyReadingCutoffTime: clearDailyReadingCutoffTime
          ? null
          : (dailyReadingCutoffTime ?? this.dailyReadingCutoffTime),
      allowLateReadings: allowLateReadings ?? this.allowLateReadings,
      reportFooterText: clearReportFooterText
          ? null
          : (reportFooterText ?? this.reportFooterText),
      organizationDisplayName: clearOrganizationDisplayName
          ? null
          : (organizationDisplayName ?? this.organizationDisplayName),
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      reportLogoPrimaryPath: clearReportLogoPrimaryPath
          ? null
          : (reportLogoPrimaryPath ?? this.reportLogoPrimaryPath),
      reportLogoSecondaryPath: clearReportLogoSecondaryPath
          ? null
          : (reportLogoSecondaryPath ?? this.reportLogoSecondaryPath),
      includeAlertSectionDefault:
          includeAlertSectionDefault ?? this.includeAlertSectionDefault,
      includePhotoIndicatorDefault:
          includePhotoIndicatorDefault ?? this.includePhotoIndicatorDefault,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value == null) return fallback;
    return double.parse(value as String);
  }
}

/// Returns true when a reading draft/row lacks the required photo.
bool readingViolatesPhotoPolicy({
  required PolicySettings policy,
  required bool hasPhoto,
}) {
  return policy.photoRequired && !hasPhoto;
}

const photoRequiredPolicyMessage = 'A meter photo is required by policy.';
