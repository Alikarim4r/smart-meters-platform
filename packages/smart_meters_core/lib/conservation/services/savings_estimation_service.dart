import '../domain/period_windows.dart';
import '../models/measurement_verification.dart';

/// Pure estimation of **Estimated Saving** (not Verified, not Potential Excess).
///
/// ## Formula
///
/// ```
/// reference = adjustedBaselineValue ?? baselineValue
/// estimatedSavingQuantity = reference − actualPostValue   (signed)
/// ```
///
/// - Positive → reduced consumption (Estimated Saving)
/// - Zero → no change
/// - Negative → increased consumption; UI should show
///   [ConservationSavingLabels.noSavingIncreasedConsumption]
///
/// Never invent missing post values as zero savings.
class SavingsEstimationService {
  const SavingsEstimationService();

  static const calculationMethod = 'estimated_saving_v1';
  static const quantityLabel = ConservationSavingLabels.estimatedSaving;

  SavingsEstimationResult estimate({
    required double baselineValue,
    required double? actualPostValue,
    double? adjustedBaselineValue,
    required DateTime prePeriodStart,
    required DateTime prePeriodEnd,
    required DateTime postPeriodStart,
    required DateTime postPeriodEnd,
    required String unitCode,
    double? dataCompleteness,
    int confidenceScore = 0,
    DateTime? calculatedAt,
  }) {
    final notes = <String>[
      'label=$quantityLabel',
      'not_potential_excess',
      'not_verified_saving',
    ];

    if (actualPostValue == null) {
      notes.add('insufficient_post_value');
      return SavingsEstimationResult(
        canEstimate: false,
        referenceValue: adjustedBaselineValue ?? baselineValue,
        actualPostValue: null,
        estimatedSavingQuantity: null,
        performanceChange: null,
        unitCode: unitCode,
        dataCompleteness: dataCompleteness,
        confidenceScore: confidenceScore,
        displayLabel: quantityLabel,
        notes: notes,
        calculatedAt: calculatedAt ?? DateTime.now().toUtc(),
        prePeriodStart: dateOnly(prePeriodStart),
        prePeriodEnd: dateOnly(prePeriodEnd),
        postPeriodStart: dateOnly(postPeriodStart),
        postPeriodEnd: dateOnly(postPeriodEnd),
      );
    }

    final reference = adjustedBaselineValue ?? baselineValue;
    final delta = reference - actualPostValue;
    final performanceChange = reference == 0
        ? null
        : ((actualPostValue - reference) / reference) * 100;

    if (delta < 0) {
      notes.add('increased_consumption');
      notes.add('display=${ConservationSavingLabels.noSavingIncreasedConsumption}');
    } else if (delta == 0) {
      notes.add('zero_saving');
    } else {
      notes.add('positive_estimated_saving');
    }

    return SavingsEstimationResult(
      canEstimate: true,
      referenceValue: reference,
      actualPostValue: actualPostValue,
      estimatedSavingQuantity: delta,
      performanceChange: performanceChange,
      unitCode: unitCode,
      dataCompleteness: dataCompleteness,
      confidenceScore: confidenceScore,
      displayLabel: delta < 0
          ? ConservationSavingLabels.noSavingIncreasedConsumption
          : quantityLabel,
      notes: notes,
      calculatedAt: calculatedAt ?? DateTime.now().toUtc(),
      prePeriodStart: dateOnly(prePeriodStart),
      prePeriodEnd: dateOnly(prePeriodEnd),
      postPeriodStart: dateOnly(postPeriodStart),
      postPeriodEnd: dateOnly(postPeriodEnd),
    );
  }
}

/// Result of Estimated Saving calculation.
class SavingsEstimationResult {
  const SavingsEstimationResult({
    required this.canEstimate,
    required this.referenceValue,
    required this.actualPostValue,
    required this.estimatedSavingQuantity,
    required this.performanceChange,
    required this.unitCode,
    required this.dataCompleteness,
    required this.confidenceScore,
    required this.displayLabel,
    required this.notes,
    required this.calculatedAt,
    required this.prePeriodStart,
    required this.prePeriodEnd,
    required this.postPeriodStart,
    required this.postPeriodEnd,
  });

  final bool canEstimate;
  final double referenceValue;
  final double? actualPostValue;

  /// Signed delta (reference − post). Negative = increased consumption.
  final double? estimatedSavingQuantity;

  /// Percent change of post vs reference: ((post − ref) / ref) × 100.
  /// Negative percentage means consumption decreased (saving direction).
  final double? performanceChange;
  final String unitCode;
  final double? dataCompleteness;
  final int confidenceScore;
  final String displayLabel;
  final List<String> notes;
  final DateTime calculatedAt;
  final DateTime prePeriodStart;
  final DateTime prePeriodEnd;
  final DateTime postPeriodStart;
  final DateTime postPeriodEnd;

  bool get isIncreasedConsumption =>
      estimatedSavingQuantity != null && estimatedSavingQuantity! < 0;

  bool get isZeroSaving =>
      estimatedSavingQuantity != null && estimatedSavingQuantity == 0;

  bool get hasPositiveEstimatedSaving =>
      estimatedSavingQuantity != null && estimatedSavingQuantity! > 0;

  Map<String, dynamic> toMetaJson() => {
        'calculation_method': SavingsEstimationService.calculationMethod,
        'quantity_label': displayLabel,
        'reference_value': referenceValue,
        'actual_post_value': actualPostValue,
        'estimated_saving_quantity': estimatedSavingQuantity,
        'performance_change_pct': performanceChange,
        'unit_code': unitCode,
        'data_completeness': dataCompleteness,
        'confidence_score': confidenceScore,
        'notes': notes,
        'calculated_at': calculatedAt.toUtc().toIso8601String(),
      };
}
