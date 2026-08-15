enum ConservationTargetScopeType {
  site('site'),
  category('category'),
  meter('meter');

  const ConservationTargetScopeType(this.dbValue);
  final String dbValue;

  static ConservationTargetScopeType fromDb(String value) =>
      ConservationTargetScopeType.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ConservationTargetScopeType.site,
      );
}

enum ConservationTargetPeriodType {
  monthly('monthly'),
  annual('annual');

  const ConservationTargetPeriodType(this.dbValue);
  final String dbValue;

  static ConservationTargetPeriodType fromDb(String value) =>
      ConservationTargetPeriodType.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ConservationTargetPeriodType.monthly,
      );
}

enum ConservationTargetStatus {
  draft('draft'),
  active('active'),
  archived('archived');

  const ConservationTargetStatus(this.dbValue);
  final String dbValue;

  static ConservationTargetStatus fromDb(String value) =>
      ConservationTargetStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ConservationTargetStatus.draft,
      );
}

/// Versioned conservation target (separate from baselines).
class ConservationTarget {
  const ConservationTarget({
    required this.id,
    required this.siteId,
    required this.scopeType,
    required this.scopeId,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.targetValue,
    required this.unitCode,
    required this.version,
    required this.status,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final ConservationTargetScopeType scopeType;
  final String? scopeId;
  final ConservationTargetPeriodType periodType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double targetValue;
  final String unitCode;
  final int version;
  final ConservationTargetStatus status;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ConservationTarget.fromJson(Map<String, dynamic> json) {
    return ConservationTarget(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      scopeType: ConservationTargetScopeType.fromDb(
        json['scope_type'] as String? ?? 'site',
      ),
      scopeId: json['scope_id'] as String?,
      periodType: ConservationTargetPeriodType.fromDb(
        json['period_type'] as String? ?? 'monthly',
      ),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      targetValue: (json['target_value'] as num).toDouble(),
      unitCode: json['unit_code'] as String,
      version: json['version'] as int? ?? 1,
      status: ConservationTargetStatus.fromDb(
        json['status'] as String? ?? 'draft',
      ),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'site_id': siteId,
        'scope_type': scopeType.dbValue,
        'scope_id': scopeId,
        'period_type': periodType.dbValue,
        'period_start': _isoDate(periodStart),
        'period_end': _isoDate(periodEnd),
        'target_value': targetValue,
        'unit_code': unitCode,
        'version': version,
        'status': status.dbValue,
        if (createdBy != null) 'created_by': createdBy,
      };

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
