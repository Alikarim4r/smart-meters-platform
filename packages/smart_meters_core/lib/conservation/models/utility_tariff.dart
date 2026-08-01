import '../domain/period_windows.dart';

/// Utility tariff status (matches `utility_tariffs.status`).
enum UtilityTariffStatus {
  active('active'),
  superseded('superseded'),
  archived('archived');

  const UtilityTariffStatus(this.dbValue);
  final String dbValue;

  static UtilityTariffStatus fromDb(String value) =>
      UtilityTariffStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => UtilityTariffStatus.active,
      );
}

/// Effective-dated utility tariff (`utility_tariffs`).
///
/// Never invent rates in Dart — missing tariff → Cost Avoided N/A (not 0).
/// Currency is typically QAR; no FX conversion is performed.
class UtilityTariff {
  const UtilityTariff({
    required this.id,
    required this.organizationId,
    required this.utilityType,
    required this.rate,
    required this.currency,
    required this.unitCode,
    required this.effectiveFrom,
    required this.status,
    this.siteId,
    this.effectiveTo,
    this.sourceNotes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;

  /// Null = organization-wide tariff.
  final String? siteId;
  final String utilityType;

  /// Positive rate per [unitCode]. Never fabricate.
  final double rate;
  final String currency;
  final String unitCode;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final UtilityTariffStatus status;
  final String? sourceNotes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool isEffectiveOn(DateTime date) {
    final d = dateOnly(date);
    final from = dateOnly(effectiveFrom);
    if (d.isBefore(from)) return false;
    if (effectiveTo == null) return true;
    return !d.isAfter(dateOnly(effectiveTo!));
  }

  factory UtilityTariff.fromJson(Map<String, dynamic> json) {
    return UtilityTariff(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      siteId: json['site_id'] as String?,
      utilityType: json['utility_type'] as String,
      rate: (json['rate'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'QAR',
      unitCode: json['unit_code'] as String,
      effectiveFrom: dateOnly(DateTime.parse(json['effective_from'] as String)),
      effectiveTo: json['effective_to'] == null
          ? null
          : dateOnly(DateTime.parse(json['effective_to'] as String)),
      status: UtilityTariffStatus.fromDb(json['status'] as String? ?? 'active'),
      sourceNotes: json['source_notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: _parseDt(json['created_at']),
      updatedAt: _parseDt(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'site_id': siteId,
        'utility_type': utilityType,
        'rate': rate,
        'currency': currency,
        'unit_code': unitCode,
        'effective_from': _isoDate(effectiveFrom),
        'effective_to':
            effectiveTo == null ? null : _isoDate(effectiveTo!),
        'status': status.dbValue,
        'source_notes': sourceNotes,
        'created_by': createdBy,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toInsertJson() => {
        'organization_id': organizationId,
        if (siteId != null) 'site_id': siteId,
        'utility_type': utilityType,
        'rate': rate,
        'currency': currency,
        'unit_code': unitCode,
        'effective_from': _isoDate(effectiveFrom),
        if (effectiveTo != null) 'effective_to': _isoDate(effectiveTo!),
        'status': status.dbValue,
        if (sourceNotes != null) 'source_notes': sourceNotes,
        if (createdBy != null) 'created_by': createdBy,
      };

  static DateTime? _parseDt(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);

  static String _isoDate(DateTime d) {
    final x = dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}
