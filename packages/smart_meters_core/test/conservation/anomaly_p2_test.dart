import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

void main() {
  const anomaly = PeriodicAnomalyService();
  const cop = CopConservationTrendService();
  final start = DateTime(2026, 7, 1);
  final end = DateTime(2026, 7, 31);

  group('PeriodicAnomalyService', () {
    test('unusual increase > 25% vs previous', () {
      final r = anomaly.detect(
        currentConsumption: 130,
        previousConsumption: 100,
        periodStart: start,
        periodEnd: end,
        completeness: 1,
        confidence: 90,
        meterIds: ['m1'],
      );
      expect(r.detected, isTrue);
      expect(r.kind, AnomalyKind.unusualIncrease);
      expect(r.statusLabel, isNot(ConsumptionAnomalyResult.forbiddenConfirmedFault));
      expect(
        r.statusLabel == ConsumptionAnomalyResult.unusualConsumption ||
            r.statusLabel == ConsumptionAnomalyResult.requiresReview,
        isTrue,
      );
    });

    test('unusual decrease > 25% vs previous', () {
      final r = anomaly.detect(
        currentConsumption: 70,
        previousConsumption: 100,
        periodStart: start,
        periodEnd: end,
        completeness: 1,
        confidence: 90,
        meterIds: ['m1'],
      );
      expect(r.detected, isTrue);
      expect(r.kind, AnomalyKind.unusualDecrease);
    });

    test('repeated high across 3+ periods', () {
      final r = anomaly.detect(
        currentConsumption: 150,
        previousConsumption: 145,
        periodStart: start,
        periodEnd: end,
        completeness: 1,
        confidence: 85,
        meterIds: ['m1'],
        historicalPeriodConsumptions: [80, 85, 140, 145],
      );
      expect(r.detected, isTrue);
      expect(r.kind, AnomalyKind.repeatedHigh);
    });

    test('above target', () {
      final r = anomaly.detect(
        currentConsumption: 120,
        previousConsumption: 118,
        target: 100,
        periodStart: start,
        periodEnd: end,
        completeness: 1,
        confidence: 90,
        meterIds: ['m1'],
      );
      expect(r.detected, isTrue);
      expect(r.kind, AnomalyKind.aboveTarget);
    });

    test('far above baseline > 20%', () {
      final r = anomaly.detect(
        currentConsumption: 130,
        previousConsumption: 128,
        baseline: 100,
        periodStart: start,
        periodEnd: end,
        completeness: 1,
        confidence: 90,
        meterIds: ['m1'],
      );
      expect(r.detected, isTrue);
      expect(r.kind, AnomalyKind.farAboveBaseline);
    });

    test('insufficient current / low completeness', () {
      final r = anomaly.detect(
        currentConsumption: null,
        previousConsumption: 100,
        periodStart: start,
        periodEnd: end,
        completeness: 0.2,
        confidence: 40,
        meterIds: ['m1'],
      );
      expect(r.detected, isFalse);
      expect(r.statusLabel, ConsumptionAnomalyResult.insufficientData);
    });

    test('low confidence caps severity and adds warning — never Critical without warning', () {
      final r = anomaly.detect(
        currentConsumption: 200,
        previousConsumption: 100, // +100%
        periodStart: start,
        periodEnd: end,
        completeness: 1,
        confidence: 50,
        meterIds: ['m1'],
      );
      expect(r.detected, isTrue);
      expect(r.severity.index, lessThanOrEqualTo(AnomalySeverity.medium.index));
      expect(
        r.warnings.any((w) => w.contains(PeriodicAnomalyService.lowConfidenceWarning)),
        isTrue,
      );
      expect(r.severity, isNot(AnomalySeverity.critical));
      expect(r.statusLabel, isNot(ConsumptionAnomalyResult.forbiddenConfirmedFault));
    });

    test('confidence 65 can be high but Critical requires >= 70 or warning', () {
      final r = anomaly.detect(
        currentConsumption: 200,
        previousConsumption: 100,
        periodStart: start,
        periodEnd: end,
        completeness: 1,
        confidence: 65,
        meterIds: ['m1'],
      );
      expect(r.detected, isTrue);
      if (r.severity == AnomalySeverity.critical) {
        expect(
          r.warnings.any((w) => w.contains(PeriodicAnomalyService.lowConfidenceWarning)),
          isTrue,
        );
      } else {
        expect(r.severity.index, lessThan(AnomalySeverity.critical.index));
      }
    });

    test('no anomaly within thresholds', () {
      final r = anomaly.detect(
        currentConsumption: 105,
        previousConsumption: 100,
        periodStart: start,
        periodEnd: end,
        completeness: 1,
        confidence: 90,
        meterIds: ['m1'],
      );
      expect(r.detected, isFalse);
      expect(r.statusLabel, ConsumptionAnomalyResult.noAnomaly);
    });
  });

  group('CopConservationTrendService', () {
    test('detects declining COP for N consecutive valid periods', () {
      final r = cop.analyzeDeclining(
        copValuesChronological: [4.0, 3.5, 3.0, 2.5],
        consecutiveRequired: 3,
        periodStart: start,
        periodEnd: end,
      );
      expect(r.detected, isTrue);
      expect(r.kind, AnomalyKind.copDeclining);
      expect(r.statusLabel, ConsumptionAnomalyResult.requiresReview);
      expect(r.investigationNotes, isNotEmpty);
      expect(
        r.investigationNotes.any((n) => n.toLowerCase().contains('heat exchanger')),
        isTrue,
      );
      expect(r.statusLabel, isNot(ConsumptionAnomalyResult.forbiddenConfirmedFault));
    });

    test('insufficient valid COP values', () {
      final r = cop.analyzeDeclining(
        copValuesChronological: [4.0, null, 0.05],
        consecutiveRequired: 3,
        minValidCop: 0.1,
      );
      expect(r.detected, isFalse);
      expect(r.statusLabel, ConsumptionAnomalyResult.insufficientData);
    });

    test('no decline → no anomaly', () {
      final r = cop.analyzeDeclining(
        copValuesChronological: [3.0, 3.2, 3.1, 3.5],
        consecutiveRequired: 3,
      );
      expect(r.detected, isFalse);
      expect(r.statusLabel, ConsumptionAnomalyResult.noAnomaly);
    });

    test('skips null / below minValidCop without inventing', () {
      final r = cop.analyzeDeclining(
        copValuesChronological: [4.0, null, 3.5, 0.01, 3.0, 2.5],
        consecutiveRequired: 3,
        minValidCop: 0.1,
      );
      // Valid sequence: 4.0, 3.5, 3.0, 2.5 — last 3 declining.
      expect(r.detected, isTrue);
      expect(r.kind, AnomalyKind.copDeclining);
    });
  });
}
