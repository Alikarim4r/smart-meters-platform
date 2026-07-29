import 'package:smart_meters_core/models/enums.dart';

import '../domain/period_windows.dart';
import '../domain/reading_alignment.dart';
import '../models/balance_result.dart';
import '../models/virtual_meter_result.dart';
import 'virtual_meter_calculator.dart';

/// Water / Energy Balance Difference via VirtualMeterCalculator.
///
/// Labels: Balance Difference / Unaccounted Consumption / Residual only.
/// Never auto Leak / Leakage / Water Loss / Waste / Saving.
class BalanceService {
  const BalanceService({
    this.calculator = const VirtualMeterCalculator(),
    this.alignmentAnalyzer = const ReadingAlignmentAnalyzer(),
  });

  final VirtualMeterCalculator calculator;
  final ReadingAlignmentAnalyzer alignmentAnalyzer;

  static const method = BalanceResult.method;

  /// Confidence penalty when alignment is only partial.
  static const partialAlignmentPenalty = 10;

  /// Confidence penalty when alignment is misaligned.
  static const misalignedPenalty = 25;

  /// Confidence penalty when alignment data is insufficient.
  static const insufficientAlignmentPenalty = 20;

  BalanceResult evaluate({
    required String utilityCode,
    required String unitCode,
    required String mainMeterId,
    required List<VirtualMeterContributorInput> children,
    required VirtualMeterContributorInput main,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? balanceGroupId,
    DateTime? calculatedAt,
  }) {
    final start = dateOnly(periodStart);
    final end = dateOnly(periodEnd);
    final at = calculatedAt ?? DateTime.now().toUtc();
    final warnings = <String>[];
    final childIds = children.map((c) => c.meterId).toList();

    final utility = utilityCode.trim().toLowerCase();
    if (utility != 'water' && utility != 'electricity') {
      return _insufficient(
        utilityCode: utilityCode,
        unitCode: unitCode,
        mainMeterId: mainMeterId,
        childMeterIds: childIds,
        start: start,
        end: end,
        at: at,
        balanceGroupId: balanceGroupId,
        alignmentStatus: ReadingAlignmentStatus.insufficientData,
        reason: 'Unsupported utility_code "$utilityCode" '
            '(expected water|electricity).',
        warnings: warnings,
      );
    }

    if (!_unitsCompatibleWithUtility(utility: utility, unitCode: unitCode) ||
        !_contributorsMatchUnit(main: main, children: children, unitCode: unitCode)) {
      return _insufficient(
        utilityCode: utilityCode,
        unitCode: unitCode,
        mainMeterId: mainMeterId,
        childMeterIds: childIds,
        start: start,
        end: end,
        at: at,
        balanceGroupId: balanceGroupId,
        alignmentStatus: ReadingAlignmentStatus.insufficientData,
        reason: 'Insufficient Data: incompatible units for $utility '
            '(expected consistent $unitCode contributors).',
        warnings: warnings,
        missing: [
          for (final c in children)
            if (c.unitCode != unitCode) c.meterId,
          if (main.unitCode != unitCode) main.meterId,
        ],
      );
    }

    final alignment = alignmentAnalyzer.analyze(
      periodStart: start,
      periodEnd: end,
      mainSpanStart: main.readingSpanStart,
      mainSpanEnd: main.readingSpanEnd,
      children: [
        for (final c in children)
          (
            meterId: c.meterId,
            spanStart: c.readingSpanStart,
            spanEnd: c.readingSpanEnd,
            isMissing: c.isMissing || !c.hasValidEndpoints,
          ),
      ],
    );
    warnings.addAll(alignment.warnings);

    final vm = calculator.calculate(
      calculationType: CalculationType.parentMinusChildren,
      unitCode: unitCode,
      periodStart: start,
      periodEnd: end,
      children: children,
      parent: main,
    );
    warnings.addAll(
      vm.warnings.where((w) => !warnings.contains(w)),
    );

    var confidence = vm.confidenceScore;
    confidence = _applyAlignmentPenalty(
      confidence: confidence,
      alignment: alignment.status,
    );

    if (vm.isInsufficient || vm.value == null) {
      // Misaligned / insufficient alignment with no usable VM value.
      final forceInsufficient =
          alignment.status == ReadingAlignmentStatus.misaligned ||
              alignment.status == ReadingAlignmentStatus.insufficientData;
      return BalanceResult(
        calculationMethod: method,
        periodStart: start,
        periodEnd: end,
        mainMeterId: mainMeterId,
        childMeterIds: childIds,
        mainConsumption: vm.parentContribution ?? main.consumption,
        childrenConsumption: vm.childrenContribution,
        balanceDifference: null,
        balancePercentage: null,
        dataCompleteness: vm.completeness,
        confidenceScore: confidence.clamp(0, 100),
        alignmentStatus: alignment.status,
        missingMeterIds: vm.missingMeterIds,
        calculatedAt: at,
        warnings: warnings,
        utilityCode: utility,
        unitCode: unitCode,
        status: BalanceResultStatus.insufficientData,
        reviewStatus: 'Requires Review',
        directionLabel: 'Insufficient Data',
        isNegative: false,
        balanceGroupId: balanceGroupId,
        message: forceInsufficient
            ? (vm.message ??
                'Insufficient Data due to reading alignment / missing endpoints.')
            : (vm.message ?? 'Insufficient Data'),
      );
    }

    final mainCons = vm.parentContribution ?? main.consumption;
    final childrenCons = vm.childrenContribution;
    final diff = vm.value!;
    final isNeg = diff < -1e-9;

    if (isNeg) {
      warnings.add(
        'Negative Balance Difference — investigate meter hierarchy, '
        'reading timing / period alignment, missing submeters, unit or '
        'multiplier errors, or data quality. Not labeled Leak / Leakage / '
        'Water Loss / Waste.',
      );
    }

    // Strong alignment issues: keep numeric value but require review + penalty.
    if (alignment.status == ReadingAlignmentStatus.misaligned ||
        alignment.status == ReadingAlignmentStatus.insufficientData) {
      warnings.add(
        'Alignment ${alignment.status.name}: Balance Difference retained with '
        'reduced confidence — treat as Requires Review, not precise Unaccounted '
        'Consumption.',
      );
    }

    final pct = (mainCons != null && mainCons > 0)
        ? (diff / mainCons) * 100.0
        : null;

    final direction = _directionLabel(diff);
    final needsReview = isNeg ||
        confidence < 60 ||
        alignment.status != ReadingAlignmentStatus.aligned ||
        warnings.isNotEmpty;

    return BalanceResult(
      calculationMethod: method,
      periodStart: start,
      periodEnd: end,
      mainMeterId: mainMeterId,
      childMeterIds: childIds,
      mainConsumption: mainCons,
      childrenConsumption: childrenCons,
      balanceDifference: diff,
      balancePercentage: pct,
      dataCompleteness: vm.completeness,
      confidenceScore: confidence.clamp(0, 100),
      alignmentStatus: alignment.status,
      missingMeterIds: vm.missingMeterIds,
      calculatedAt: at,
      warnings: warnings,
      utilityCode: utility,
      unitCode: unitCode,
      status: BalanceResultStatus.ok,
      reviewStatus: needsReview ? 'Requires Review' : 'OK',
      directionLabel: direction,
      isNegative: isNeg,
      balanceGroupId: balanceGroupId,
      message: direction,
    );
  }

  String _directionLabel(double diff) {
    if (diff.abs() < 1e-9) return 'Balance Difference · Residual';
    if (diff > 0) return 'Unaccounted Consumption · Balance Difference';
    return 'Residual · Balance Difference';
  }

  int _applyAlignmentPenalty({
    required int confidence,
    required ReadingAlignmentStatus alignment,
  }) {
    switch (alignment) {
      case ReadingAlignmentStatus.aligned:
        return confidence;
      case ReadingAlignmentStatus.partiallyAligned:
        return confidence - partialAlignmentPenalty;
      case ReadingAlignmentStatus.misaligned:
        return confidence - misalignedPenalty;
      case ReadingAlignmentStatus.insufficientData:
        return confidence - insufficientAlignmentPenalty;
    }
  }

  bool _unitsCompatibleWithUtility({
    required String utility,
    required String unitCode,
  }) {
    final u = unitCode.trim().toLowerCase();
    if (utility == 'electricity') {
      // Reject clear water volume units on electricity balances.
      if (u == 'm3' || u == 'm³' || u == 'l' || u == 'liter' || u == 'litre') {
        return false;
      }
      return true;
    }
    // water
    if (u == 'kwh' || u == 'mwh' || u == 'kw' || u == 'mw') {
      return false;
    }
    return true;
  }

  bool _contributorsMatchUnit({
    required VirtualMeterContributorInput main,
    required List<VirtualMeterContributorInput> children,
    required String unitCode,
  }) {
    if (main.unitCode != unitCode) return false;
    return children.every((c) => c.unitCode == unitCode);
  }

  BalanceResult _insufficient({
    required String utilityCode,
    required String unitCode,
    required String mainMeterId,
    required List<String> childMeterIds,
    required DateTime start,
    required DateTime end,
    required DateTime at,
    required ReadingAlignmentStatus alignmentStatus,
    required String reason,
    required List<String> warnings,
    String? balanceGroupId,
    List<String> missing = const [],
    double completeness = 0,
    int confidence = 0,
  }) {
    return BalanceResult(
      calculationMethod: method,
      periodStart: start,
      periodEnd: end,
      mainMeterId: mainMeterId,
      childMeterIds: childMeterIds,
      mainConsumption: null,
      childrenConsumption: null,
      balanceDifference: null,
      balancePercentage: null,
      dataCompleteness: completeness,
      confidenceScore: confidence,
      alignmentStatus: alignmentStatus,
      missingMeterIds: missing,
      calculatedAt: at,
      warnings: warnings,
      utilityCode: utilityCode,
      unitCode: unitCode,
      status: BalanceResultStatus.insufficientData,
      reviewStatus: 'Requires Review',
      directionLabel: 'Insufficient Data',
      isNegative: false,
      balanceGroupId: balanceGroupId,
      message: reason,
    );
  }
}
