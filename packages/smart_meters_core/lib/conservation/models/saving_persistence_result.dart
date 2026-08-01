import '../domain/persistence_status.dart';

class SavingPersistenceResult {
  const SavingPersistenceResult({
    required this.id,
    required this.siteId,
    required this.measurementVerificationId,
    required this.followUpWindow,
    required this.followUpStart,
    required this.followUpEnd,
    required this.status,
    required this.confidenceScore,
    this.expectedReferenceConsumption,
    this.actualConsumption,
    this.sustainedQuantity,
    this.persistencePct,
    this.dataCompleteness,
    this.reopenOpportunitySuggested = false,
    this.reopenSuggestionKey,
    this.warnings = const [],
    this.lineage = const {},
    this.calculatedAt,
  });

  final String id;
  final String siteId;
  final String measurementVerificationId;
  final PersistenceWindow followUpWindow;
  final DateTime followUpStart;
  final DateTime followUpEnd;
  final double? expectedReferenceConsumption;
  final double? actualConsumption;
  final double? sustainedQuantity;
  final double? persistencePct;
  final double? dataCompleteness;
  final int confidenceScore;
  final PersistenceStatus status;
  final bool reopenOpportunitySuggested;
  final String? reopenSuggestionKey;
  final List<dynamic> warnings;
  final Map<String, dynamic> lineage;
  final DateTime? calculatedAt;

  factory SavingPersistenceResult.fromJson(Map<String, dynamic> json) {
    return SavingPersistenceResult(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      measurementVerificationId: json['measurement_verification_id'] as String,
      followUpWindow:
          PersistenceWindow.fromDb(json['follow_up_window'] as String? ?? '1m'),
      followUpStart: DateTime.parse(json['follow_up_start'] as String),
      followUpEnd: DateTime.parse(json['follow_up_end'] as String),
      expectedReferenceConsumption:
          (json['expected_reference_consumption'] as num?)?.toDouble(),
      actualConsumption: (json['actual_consumption'] as num?)?.toDouble(),
      sustainedQuantity: (json['sustained_quantity'] as num?)?.toDouble(),
      persistencePct: (json['persistence_pct'] as num?)?.toDouble(),
      dataCompleteness: (json['data_completeness'] as num?)?.toDouble(),
      confidenceScore: json['confidence_score'] as int? ?? 0,
      status: PersistenceStatus.fromDb(
        json['status'] as String? ?? 'insufficient_follow_up',
      ),
      reopenOpportunitySuggested:
          json['reopen_opportunity_suggested'] as bool? ?? false,
      reopenSuggestionKey: json['reopen_suggestion_key'] as String?,
      warnings: List<dynamic>.from((json['warnings'] as List?) ?? const []),
      lineage: Map<String, dynamic>.from((json['lineage'] as Map?) ?? const {}),
      calculatedAt: json['calculated_at'] != null
          ? DateTime.parse(json['calculated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'site_id': siteId,
        'measurement_verification_id': measurementVerificationId,
        'follow_up_window': followUpWindow.dbValue,
        'follow_up_start': followUpStart.toIso8601String().substring(0, 10),
        'follow_up_end': followUpEnd.toIso8601String().substring(0, 10),
        'expected_reference_consumption': expectedReferenceConsumption,
        'actual_consumption': actualConsumption,
        'sustained_quantity': sustainedQuantity,
        'persistence_pct': persistencePct,
        'data_completeness': dataCompleteness,
        'confidence_score': confidenceScore,
        'status': status.dbValue,
        'reopen_opportunity_suggested': reopenOpportunitySuggested,
        'reopen_suggestion_key': reopenSuggestionKey,
        'warnings': warnings,
        'lineage': lineage,
      };
}
