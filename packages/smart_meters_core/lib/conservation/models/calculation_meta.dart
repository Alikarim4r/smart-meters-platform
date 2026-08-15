/// Metadata attached to every Conservation derived metric.
class CalculationMeta {
  const CalculationMeta({
    required this.calculationMethod,
    required this.periodStart,
    required this.periodEnd,
    required this.dataCompleteness,
    required this.confidenceScore,
    required this.calculatedAt,
    this.baselineVersion,
    this.targetVersion,
    this.notes = const [],
  });

  final String calculationMethod;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// 0.0–1.0. Null when frequency unknown and completeness was skipped.
  final double? dataCompleteness;
  final int confidenceScore;
  final DateTime calculatedAt;
  final String? baselineVersion;
  final String? targetVersion;
  final List<String> notes;

  Map<String, dynamic> toJson() => {
        'calculation_method': calculationMethod,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
        'data_completeness': dataCompleteness,
        'confidence_score': confidenceScore,
        'baseline_version': baselineVersion,
        'target_version': targetVersion,
        'calculated_at': calculatedAt.toIso8601String(),
        'notes': notes,
      };
}
