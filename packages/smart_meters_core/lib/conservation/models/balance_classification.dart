/// Human-reviewed Balance Difference classification (DB values).
///
/// [confirmedLeak] is a valid stored value but MUST only be assigned by a
/// human reviewer — never by BalanceService / auto detectors.
enum BalanceClassificationType {
  confirmedLeak('confirmed_leak'),
  suspectedLeak('suspected_leak'),
  meterError('meter_error'),
  readingError('reading_error'),
  unmeteredConsumption('unmetered_consumption'),
  operationalUsage('operational_usage'),
  timingAlignmentDifference('timing_alignment_difference'),
  unknown('unknown');

  const BalanceClassificationType(this.dbValue);
  final String dbValue;

  static BalanceClassificationType fromDb(String value) =>
      BalanceClassificationType.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => BalanceClassificationType.unknown,
      );

  /// True when this type must never be auto-assigned by services.
  bool get isHumanOnly => this == BalanceClassificationType.confirmedLeak;
}

/// Current classification row for a balance group + period.
class BalanceClassificationRecord {
  const BalanceClassificationRecord({
    required this.id,
    required this.siteId,
    required this.balanceGroupId,
    required this.periodStart,
    required this.periodEnd,
    required this.classification,
    required this.classifiedAt,
    this.notes,
    this.evidenceRefs = const [],
    this.balanceDifference,
    this.unitCode,
    this.classifiedBy,
    this.previousClassification,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String balanceGroupId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final BalanceClassificationType classification;
  final String? notes;
  final List<dynamic> evidenceRefs;
  final double? balanceDifference;
  final String? unitCode;
  final String? classifiedBy;
  final DateTime classifiedAt;
  final BalanceClassificationType? previousClassification;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BalanceClassificationRecord.fromJson(Map<String, dynamic> json) {
    return BalanceClassificationRecord(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      balanceGroupId: json['balance_group_id'] as String,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      classification:
          BalanceClassificationType.fromDb(json['classification'] as String),
      notes: json['notes'] as String?,
      evidenceRefs: (json['evidence_refs'] as List?)?.toList() ?? const [],
      balanceDifference: (json['balance_difference'] as num?)?.toDouble(),
      unitCode: json['unit_code'] as String?,
      classifiedBy: json['classified_by'] as String?,
      classifiedAt: DateTime.parse(json['classified_at'] as String),
      previousClassification: json['previous_classification'] == null
          ? null
          : BalanceClassificationType.fromDb(
              json['previous_classification'] as String,
            ),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Audit trail entry for classification changes.
class BalanceClassificationAuditEntry {
  const BalanceClassificationAuditEntry({
    required this.id,
    required this.classificationId,
    required this.changedAt,
    required this.newClassification,
    this.changedBy,
    this.previousClassification,
    this.notes,
    this.evidenceRefs = const [],
  });

  final String id;
  final String classificationId;
  final String? changedBy;
  final DateTime changedAt;
  final BalanceClassificationType? previousClassification;
  final BalanceClassificationType newClassification;
  final String? notes;
  final List<dynamic> evidenceRefs;

  factory BalanceClassificationAuditEntry.fromJson(Map<String, dynamic> json) {
    return BalanceClassificationAuditEntry(
      id: json['id'] as String,
      classificationId: json['classification_id'] as String,
      changedBy: json['changed_by'] as String?,
      changedAt: DateTime.parse(json['changed_at'] as String),
      previousClassification: json['previous_classification'] == null
          ? null
          : BalanceClassificationType.fromDb(
              json['previous_classification'] as String,
            ),
      newClassification: BalanceClassificationType.fromDb(
        json['new_classification'] as String,
      ),
      notes: json['notes'] as String?,
      evidenceRefs: (json['evidence_refs'] as List?)?.toList() ?? const [],
    );
  }
}

/// Helpers enforcing human-only Confirmed Leak assignment.
///
/// Services must never auto-assign [BalanceClassificationType.confirmedLeak].
/// Call [validateHumanClassification] (or repository
/// `assertHumanReviewed`) before persisting a confirmed_leak row.
abstract final class BalanceClassificationRules {
  /// Documentation + guard: Confirmed Leak is human-reviewed only.
  static const neverAutoAssignConfirmedLeak =
      'Confirmed Leak must never be auto-assigned by BalanceService, '
      'anomaly detectors, or default inserts. Only a human reviewer may '
      'set classification=confirmed_leak after investigation.';

  /// Returns null when valid; otherwise an error message.
  ///
  /// [confirmedLeak] requires [humanReviewed]=true and a non-empty
  /// [classifiedBy] identity.
  static String? validateHumanClassification({
    required BalanceClassificationType classification,
    required bool humanReviewed,
    String? classifiedBy,
  }) {
    if (classification != BalanceClassificationType.confirmedLeak) {
      return null;
    }
    if (!humanReviewed) {
      return 'Confirmed Leak requires explicit human review '
          '($neverAutoAssignConfirmedLeak)';
    }
    if (classifiedBy == null || classifiedBy.trim().isEmpty) {
      return 'Confirmed Leak requires classifiedBy (human reviewer id).';
    }
    return null;
  }
}
