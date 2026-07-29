import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

VirtualMeterContributorInput contributor({
  required String id,
  required double? consumption,
  String unit = 'm3',
  int confidence = 90,
  double completeness = 1,
  bool missing = false,
  DateTime? spanStart,
  DateTime? spanEnd,
}) {
  return VirtualMeterContributorInput(
    meterId: id,
    consumption: consumption,
    hasValidEndpoints: !missing && consumption != null,
    completeness: missing ? 0 : completeness,
    confidence: confidence,
    unitCode: unit,
    readingSpanStart: spanStart,
    readingSpanEnd: spanEnd,
    isMissing: missing,
  );
}

void main() {
  const service = BalanceService();
  final start = DateTime(2026, 7, 1);
  final end = DateTime(2026, 7, 31);
  final spanS = DateTime(2026, 7, 1);
  final spanE = DateTime(2026, 7, 31);

  group('BalanceService', () {
    test('positive Unaccounted Consumption / Balance Difference', () {
      final r = service.evaluate(
        utilityCode: 'water',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 100,
          spanStart: spanS,
          spanEnd: spanE,
        ),
        children: [
          contributor(id: 'c1', consumption: 40, spanStart: spanS, spanEnd: spanE),
          contributor(id: 'c2', consumption: 30, spanStart: spanS, spanEnd: spanE),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(r.status, BalanceResultStatus.ok);
      expect(r.balanceDifference, closeTo(30, 1e-9));
      expect(r.mainConsumption, 100);
      expect(r.childrenConsumption, 70);
      expect(r.balancePercentage, closeTo(30, 1e-9));
      expect(r.directionLabel.contains('Unaccounted Consumption') ||
          r.directionLabel.contains('Balance Difference'), isTrue);
      expect(r.directionLabel.toLowerCase().contains('leak'), isFalse);
      expect(r.isNegative, isFalse);
    });

    test('zero difference — Balance Difference / Residual', () {
      final r = service.evaluate(
        utilityCode: 'water',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 80,
          spanStart: spanS,
          spanEnd: spanE,
        ),
        children: [
          contributor(id: 'c1', consumption: 50, spanStart: spanS, spanEnd: spanE),
          contributor(id: 'c2', consumption: 30, spanStart: spanS, spanEnd: spanE),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(r.balanceDifference, closeTo(0, 1e-9));
      expect(r.directionLabel.contains('Balance Difference') ||
          r.directionLabel.contains('Residual'), isTrue);
    });

    test('negative Balance Difference kept with investigation warning (no Leak)', () {
      final r = service.evaluate(
        utilityCode: 'water',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 50,
          spanStart: spanS,
          spanEnd: spanE,
        ),
        children: [
          contributor(id: 'c1', consumption: 40, spanStart: spanS, spanEnd: spanE),
          contributor(id: 'c2', consumption: 30, spanStart: spanS, spanEnd: spanE),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(r.status, BalanceResultStatus.ok);
      expect(r.balanceDifference, closeTo(-20, 1e-9));
      expect(r.isNegative, isTrue);
      expect(r.warnings.any((w) => w.contains('Negative Balance Difference')), isTrue);
      expect(r.warnings.any((w) => w.toLowerCase().contains('not labeled leak')), isTrue);
      expect(r.directionLabel.toLowerCase().contains('leak'), isFalse);
      expect(r.reviewStatus, 'Requires Review');
    });

    test('main consumption 0 → balancePercentage null (N/A)', () {
      final r = service.evaluate(
        utilityCode: 'water',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 0,
          spanStart: spanS,
          spanEnd: spanE,
        ),
        children: [
          contributor(id: 'c1', consumption: 0, spanStart: spanS, spanEnd: spanE),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(r.balancePercentage, isNull);
    });

    test('missing main → insufficient', () {
      final r = service.evaluate(
        utilityCode: 'water',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(id: 'main', consumption: null, missing: true),
        children: [
          contributor(id: 'c1', consumption: 10, spanStart: spanS, spanEnd: spanE),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(r.status, BalanceResultStatus.insufficientData);
      expect(r.balanceDifference, isNull);
      expect(r.directionLabel, 'Insufficient Data');
    });

    test('missing child → not treated as 0; may be insufficient', () {
      final r = service.evaluate(
        utilityCode: 'water',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 100,
          spanStart: spanS,
          spanEnd: spanE,
        ),
        children: [
          contributor(id: 'c1', consumption: 40, spanStart: spanS, spanEnd: spanE),
          contributor(id: 'c2', consumption: null, missing: true),
        ],
        periodStart: start,
        periodEnd: end,
      );
      // With 50% completeness (1 of 2 children), VM may still compute.
      // Missing child must appear in missingMeterIds / warnings.
      expect(
        r.missingMeterIds.contains('c2') ||
            r.warnings.any((w) => w.contains('c2')),
        isTrue,
      );
      expect(r.warnings.any((w) => w.contains('not treated as 0')), isTrue);
    });

    test('misaligned spans → warnings + confidence penalty', () {
      final r = service.evaluate(
        utilityCode: 'water',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 100,
          spanStart: DateTime(2026, 7, 1),
          spanEnd: DateTime(2026, 7, 5),
        ),
        children: [
          contributor(
            id: 'c1',
            consumption: 40,
            spanStart: DateTime(2026, 7, 25),
            spanEnd: DateTime(2026, 7, 31),
          ),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(
        r.alignmentStatus == ReadingAlignmentStatus.misaligned ||
            r.alignmentStatus == ReadingAlignmentStatus.partiallyAligned,
        isTrue,
      );
      expect(r.warnings, isNotEmpty);
      expect(r.reviewStatus, 'Requires Review');
    });

    test('low confidence from contributors is preserved with alignment penalty', () {
      final r = service.evaluate(
        utilityCode: 'water',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 100,
          confidence: 55,
          spanStart: spanS,
          spanEnd: spanE,
        ),
        children: [
          contributor(
            id: 'c1',
            consumption: 70,
            confidence: 50,
            spanStart: spanS,
            spanEnd: spanE,
          ),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(r.confidenceScore, lessThanOrEqualTo(55));
      expect(r.reviewStatus, 'Requires Review');
    });

    test('reuses VirtualMeterCalculator — multipliers already in contributor values', () {
      // Caller applies multiplier into consumption (as VM docs say).
      final r = service.evaluate(
        utilityCode: 'water',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 200, // e.g. reading delta * multiplier 2
          spanStart: spanS,
          spanEnd: spanE,
        ),
        children: [
          contributor(
            id: 'c1',
            consumption: 50 * 2,
            spanStart: spanS,
            spanEnd: spanE,
          ),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(r.balanceDifference, closeTo(100, 1e-9));
      expect(r.calculationMethod, BalanceResult.method);
    });

    test('electricity with water unit → insufficient', () {
      final r = service.evaluate(
        utilityCode: 'electricity',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 100,
          unit: 'm3',
          spanStart: spanS,
          spanEnd: spanE,
        ),
        children: [
          contributor(
            id: 'c1',
            consumption: 40,
            unit: 'm3',
            spanStart: spanS,
            spanEnd: spanE,
          ),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(r.status, BalanceResultStatus.insufficientData);
      expect(r.message!.toLowerCase().contains('incompatible'), isTrue);
    });

    test('contributor unit mismatch → insufficient', () {
      final r = service.evaluate(
        utilityCode: 'electricity',
        unitCode: 'kWh',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 100,
          unit: 'kWh',
          spanStart: spanS,
          spanEnd: spanE,
        ),
        children: [
          contributor(
            id: 'c1',
            consumption: 40,
            unit: 'm3',
            spanStart: spanS,
            spanEnd: spanE,
          ),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(r.status, BalanceResultStatus.insufficientData);
    });

    test('human classification optional; Confirmed Leak never auto-assigned', () {
      final r = service.evaluate(
        utilityCode: 'water',
        unitCode: 'm3',
        mainMeterId: 'main',
        main: contributor(
          id: 'main',
          consumption: 100,
          spanStart: spanS,
          spanEnd: spanE,
        ),
        children: [
          contributor(id: 'c1', consumption: 60, spanStart: spanS, spanEnd: spanE),
        ],
        periodStart: start,
        periodEnd: end,
      );
      expect(r.humanClassification, isNull);
      expect(
        BalanceClassificationRules.validateHumanClassification(
          classification: BalanceClassificationType.confirmedLeak,
          humanReviewed: false,
        ),
        isNotNull,
      );
    });
  });
}
