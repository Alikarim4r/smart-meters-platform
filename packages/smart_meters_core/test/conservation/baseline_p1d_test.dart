import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

PeriodReadingPoint p(DateTime d, double v) =>
    PeriodReadingPoint(date: d, value: v);

ConservationBaseline draftBaseline({
  double value = 100,
  double completeness = 1.0,
  int confidence = 90,
  BaselineBoundaryQuality boundary = BaselineBoundaryQuality.exactPrePeriod,
  BaselineCalculationMethod method = BaselineCalculationMethod.totalPeriod,
  ConservationBaselineStatus status = ConservationBaselineStatus.draft,
  DateTime? start,
  DateTime? end,
  String unit = 'kWh',
  int version = 1,
  String? scopeId,
  ConservationBaselineScopeType scopeType = ConservationBaselineScopeType.site,
}) {
  return ConservationBaseline(
    id: 'b1',
    siteId: 'site-1',
    scopeType: scopeType,
    scopeId: scopeId,
    versionNumber: version,
    label: 'Test',
    referencePeriodStart: start ?? DateTime(2026, 1, 1),
    referencePeriodEnd: end ?? DateTime(2026, 1, 31),
    calculationMethod: method,
    baselineValue: value,
    unitCode: unit,
    status: status,
    dataCompleteness: completeness,
    confidenceScore: confidence,
    boundaryQuality: boundary,
  );
}

void main() {
  const calc = BaselineCalculationService();
  const avb = ActualVsBaselineService();

  group('BaselineCalculationService', () {
    test('total_period with exact pre-period boundary', () {
      final r = calc.calculate(
        method: BaselineCalculationMethod.totalPeriod,
        referencePeriodStart: DateTime(2026, 1, 1),
        referencePeriodEnd: DateTime(2026, 1, 31),
        unitCode: 'kWh',
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2025, 12, 31), 100),
              p(DateTime(2026, 1, 31), 200),
            ],
          ),
        ],
      );
      expect(r.canCompute, isTrue);
      expect(r.baselineValue, 100);
      expect(r.boundaryQuality, BaselineBoundaryQuality.exactPrePeriod);
      expect(r.confidenceScore, greaterThanOrEqualTo(70));
      expect(r.meta.notes.any((n) => n.contains('exact_pre_period')), isTrue);
    });

    test('average_daily uses calendar-aware day count (Jan=31)', () {
      final r = calc.calculate(
        method: BaselineCalculationMethod.averageDaily,
        referencePeriodStart: DateTime(2026, 1, 1),
        referencePeriodEnd: DateTime(2026, 1, 31),
        unitCode: 'kWh',
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2025, 12, 31), 0),
              p(DateTime(2026, 1, 31), 310),
            ],
          ),
        ],
      );
      expect(r.baselineValue, closeTo(10, 0.001)); // 310/31
      expect(r.meta.notes.any((n) => n.contains('calendar_days=31')), isTrue);
    });

    test('custom_fixed uses admin value', () {
      final r = calc.calculate(
        method: BaselineCalculationMethod.customFixed,
        referencePeriodStart: DateTime(2026, 1, 1),
        referencePeriodEnd: DateTime(2026, 1, 31),
        unitCode: 'kWh',
        meters: const [],
        customFixedValue: 42,
      );
      expect(r.baselineValue, 42);
      expect(r.boundaryQuality, BaselineBoundaryQuality.notApplicable);
    });

    test('missing boundary readings → insufficient', () {
      final r = calc.calculate(
        method: BaselineCalculationMethod.totalPeriod,
        referencePeriodStart: DateTime(2026, 1, 1),
        referencePeriodEnd: DateTime(2026, 1, 31),
        unitCode: 'kWh',
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: const [],
          ),
        ],
      );
      expect(r.isInsufficient, isTrue);
      expect(r.boundaryQuality, BaselineBoundaryQuality.insufficient);
    });

    test('first-in-period fallback labeled and confidence reduced', () {
      final r = calc.calculate(
        method: BaselineCalculationMethod.totalPeriod,
        referencePeriodStart: DateTime(2026, 1, 1),
        referencePeriodEnd: DateTime(2026, 1, 31),
        unitCode: 'kWh',
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 1, 1), 10),
              p(DateTime(2026, 1, 31), 110),
            ],
          ),
        ],
      );
      expect(r.canCompute, isTrue);
      expect(r.baselineValue, 100);
      expect(
        r.boundaryQuality,
        BaselineBoundaryQuality.firstInPeriodFallback,
      );
      expect(r.usedFirstInPeriodFallback, isTrue);
      expect(r.warnings.any((w) => w.toLowerCase().contains('fallback')), isTrue);
      expect(r.meta.notes.any((n) => n.contains('first_in_period_fallback')), isTrue);
    });

    test('unit mismatch → insufficient', () {
      final r = calc.calculate(
        method: BaselineCalculationMethod.totalPeriod,
        referencePeriodStart: DateTime(2026, 1, 1),
        referencePeriodEnd: DateTime(2026, 1, 31),
        unitCode: 'kWh',
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'm³',
            readings: [
              p(DateTime(2025, 12, 31), 1),
              p(DateTime(2026, 1, 31), 2),
            ],
          ),
        ],
      );
      expect(r.isInsufficient, isTrue);
      expect(r.message!.toLowerCase(), contains('unit'));
    });

    test('invalid reference period', () {
      final r = calc.calculate(
        method: BaselineCalculationMethod.totalPeriod,
        referencePeriodStart: DateTime(2026, 2, 1),
        referencePeriodEnd: DateTime(2026, 1, 1),
        unitCode: 'kWh',
        meters: const [],
      );
      expect(r.isInsufficient, isTrue);
      expect(r.message!.toLowerCase(), contains('invalid'));
    });
  });

  group('BaselineApprovalGates', () {
    test('exact good boundaries allow approval', () {
      final gate = BaselineApprovalService.checkGates(
        draft: draftBaseline(),
      );
      expect(gate.allowed, isTrue);
    });

    test('low completeness blocks approval', () {
      final gate = BaselineApprovalService.checkGates(
        draft: draftBaseline(completeness: 0.5, confidence: 90),
      );
      expect(gate.allowed, isFalse);
      expect(gate.reasons.any((r) => r.contains('Completeness')), isTrue);
    });

    test('low confidence blocks approval', () {
      final gate = BaselineApprovalService.checkGates(
        draft: draftBaseline(completeness: 1.0, confidence: 40),
      );
      expect(gate.allowed, isFalse);
      expect(gate.reasons.any((r) => r.contains('Confidence')), isTrue);
    });

    test('first-in-period fallback blocks approval', () {
      final gate = BaselineApprovalService.checkGates(
        draft: draftBaseline(
          boundary: BaselineBoundaryQuality.firstInPeriodFallback,
        ),
      );
      expect(gate.allowed, isFalse);
      expect(gate.reasons.any((r) => r.toLowerCase().contains('fallback')), isTrue);
    });

    test('insufficient boundaries block approval', () {
      final gate = BaselineApprovalService.checkGates(
        draft: draftBaseline(
          boundary: BaselineBoundaryQuality.insufficient,
          completeness: 0,
          confidence: 0,
        ),
      );
      expect(gate.allowed, isFalse);
    });

    test('cross-site scope rejected', () {
      final gate = BaselineApprovalService.checkGates(
        draft: draftBaseline(),
        crossSiteScope: true,
      );
      expect(gate.allowed, isFalse);
      expect(gate.reasons.any((r) => r.contains('Cross-site')), isTrue);
    });

    test('unit mismatch rejected', () {
      final gate = BaselineApprovalService.checkGates(
        draft: draftBaseline(),
        unitMismatch: true,
      );
      expect(gate.allowed, isFalse);
    });

    test('meter scope without scope_id rejected', () {
      final gate = BaselineApprovalService.checkGates(
        draft: draftBaseline(
          scopeType: ConservationBaselineScopeType.meter,
          scopeId: null,
        ),
      );
      expect(gate.allowed, isFalse);
    });

    test('approved row cannot be re-approved via gate (not draft)', () {
      final gate = BaselineApprovalService.checkGates(
        draft: draftBaseline(status: ConservationBaselineStatus.approved),
      );
      expect(gate.allowed, isFalse);
    });

    test('custom_fixed can approve without exact boundary', () {
      final gate = BaselineApprovalService.checkGates(
        draft: draftBaseline(
          method: BaselineCalculationMethod.customFixed,
          value: 50,
          boundary: BaselineBoundaryQuality.notApplicable,
          completeness: 1,
          confidence: 80,
        ),
      );
      expect(gate.allowed, isTrue);
    });

    test('thresholds are explicit in BaselineApprovalGates.standard', () {
      expect(BaselineApprovalGates.standard.minCompleteness, 0.80);
      expect(BaselineApprovalGates.standard.minConfidence, 70);
      expect(BaselineApprovalGates.standard.requireExactPrePeriodBoundary, isTrue);
    });
  });

  group('ActualVsBaselineService', () {
    ConservationBaseline approved({
      double value = 100,
      double completeness = 1.0,
      int confidence = 90,
      String unit = 'kWh',
    }) =>
        draftBaseline(
          value: value,
          completeness: completeness,
          confidence: confidence,
          unit: unit,
          status: ConservationBaselineStatus.approved,
        );

    test('actual above baseline', () {
      final r = avb.evaluate(
        baseline: approved(value: 50),
        analysisPeriodStart: DateTime(2026, 2, 1),
        analysisPeriodEnd: DateTime(2026, 2, 28),
        analysisAsOf: DateTime(2026, 2, 28),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 1, 31), 0),
              p(DateTime(2026, 2, 28), 80),
            ],
          ),
        ],
      );
      expect(r.status, ActualVsBaselineStatus.ok);
      expect(r.standing, ActualVsBaselineStanding.aboveBaseline);
      expect(r.directionLabel, 'Above Baseline');
      expect(r.directionLabel.toLowerCase(), isNot(contains('saving')));
      expect(r.absoluteVariance, 30);
      expect(r.percentageVariance, closeTo(60, 0.01));
      expect(r.meta.baselineVersion, '1');
    });

    test('actual below baseline', () {
      final r = avb.evaluate(
        baseline: approved(value: 100),
        analysisPeriodStart: DateTime(2026, 2, 1),
        analysisPeriodEnd: DateTime(2026, 2, 28),
        analysisAsOf: DateTime(2026, 2, 28),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 1, 31), 0),
              p(DateTime(2026, 2, 28), 40),
            ],
          ),
        ],
      );
      expect(r.standing, ActualVsBaselineStanding.belowBaseline);
      expect(r.directionLabel, 'Below Baseline');
      expect(r.directionLabel.toLowerCase(), isNot(contains('saving')));
    });

    test('actual equal baseline → on baseline', () {
      final r = avb.evaluate(
        baseline: approved(value: 50),
        analysisPeriodStart: DateTime(2026, 2, 1),
        analysisPeriodEnd: DateTime(2026, 2, 28),
        analysisAsOf: DateTime(2026, 2, 28),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 1, 31), 0),
              p(DateTime(2026, 2, 28), 50),
            ],
          ),
        ],
      );
      expect(r.standing, ActualVsBaselineStanding.onBaseline);
      expect(r.directionLabel, 'On Baseline');
    });

    test('baseline_value = 0 → percentage N/A', () {
      final r = avb.evaluate(
        baseline: approved(value: 0),
        analysisPeriodStart: DateTime(2026, 2, 1),
        analysisPeriodEnd: DateTime(2026, 2, 28),
        analysisAsOf: DateTime(2026, 2, 28),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 1, 31), 0),
              p(DateTime(2026, 2, 28), 10),
            ],
          ),
        ],
      );
      expect(r.status, ActualVsBaselineStatus.ok);
      expect(r.percentageVariance, isNull);
      expect(r.absoluteVariance, 10);
    });

    test('missing actual data → insufficient', () {
      final r = avb.evaluate(
        baseline: approved(),
        analysisPeriodStart: DateTime(2026, 2, 1),
        analysisPeriodEnd: DateTime(2026, 2, 28),
        analysisAsOf: DateTime(2026, 2, 28),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: const [],
          ),
        ],
      );
      expect(r.isInsufficient, isTrue);
    });

    test('combined confidence = min(baseline, actual)', () {
      final r = avb.evaluate(
        baseline: approved(confidence: 90),
        analysisPeriodStart: DateTime(2026, 2, 1),
        analysisPeriodEnd: DateTime(2026, 2, 28),
        analysisAsOf: DateTime(2026, 2, 28),
        meters: [
          // 1 of 2 meters → actual completeness 0.5, confidence reduced
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 1, 31), 0),
              p(DateTime(2026, 2, 28), 50),
            ],
          ),
          PeriodMeterReadingSeries(
            meterId: 'm2',
            unitCode: 'kWh',
            readings: const [],
          ),
        ],
      );
      // completeness 0.5 is at threshold — may still be ok
      expect(r.confidenceScore, lessThanOrEqualTo(90));
      expect(
        r.confidenceScore,
        equals(
          r.actualConfidence < r.baselineConfidence
              ? r.actualConfidence
              : r.baselineConfidence,
        ),
      );
    });

    test('low actual completeness → insufficient even if baseline strong', () {
      final r = avb.evaluate(
        baseline: approved(completeness: 1.0, confidence: 95),
        analysisPeriodStart: DateTime(2026, 2, 1),
        analysisPeriodEnd: DateTime(2026, 2, 28),
        analysisAsOf: DateTime(2026, 2, 28),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 1, 31), 0),
              p(DateTime(2026, 2, 28), 50),
            ],
          ),
          PeriodMeterReadingSeries(
            meterId: 'm2',
            unitCode: 'kWh',
            readings: const [],
          ),
          PeriodMeterReadingSeries(
            meterId: 'm3',
            unitCode: 'kWh',
            readings: const [],
          ),
        ],
      );
      // 1/3 completeness ≈ 0.333 < 0.5
      expect(r.isInsufficient, isTrue);
      expect(r.message!.toLowerCase(), contains('actual'));
    });

    test('draft baseline not usable', () {
      final r = avb.evaluate(
        baseline: draftBaseline(),
        analysisPeriodStart: DateTime(2026, 2, 1),
        analysisPeriodEnd: DateTime(2026, 2, 28),
        analysisAsOf: DateTime(2026, 2, 28),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 1, 31), 0),
              p(DateTime(2026, 2, 28), 50),
            ],
          ),
        ],
      );
      expect(r.isInsufficient, isTrue);
    });

    test('labels never say Saving', () {
      for (final standing in ActualVsBaselineStanding.values) {
        expect(standing.name.toLowerCase(), isNot(contains('saving')));
      }
    });

    test('mixed units are converted correctly', () {
      final r = avb.evaluate(
        baseline: approved(value: 100, unit: 'mwh'),
        analysisPeriodStart: DateTime(2026, 2, 1),
        analysisPeriodEnd: DateTime(2026, 2, 28),
        analysisAsOf: DateTime(2026, 2, 28),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kwh', // 1 mwh = 1000 kwh
            readings: [
              p(DateTime(2026, 1, 31), 0),
              p(DateTime(2026, 2, 28), 100000), // 100,000 kwh = 100 mwh
            ],
          ),
        ],
      );
      expect(r.status, ActualVsBaselineStatus.ok);
      expect(r.standing, ActualVsBaselineStanding.onBaseline);
      expect(r.actualValue, 100.0);
    });

    test('incompatible units are explicitly rejected', () {
      final r = avb.evaluate(
        baseline: approved(value: 100, unit: 'm3'),
        analysisPeriodStart: DateTime(2026, 2, 1),
        analysisPeriodEnd: DateTime(2026, 2, 28),
        analysisAsOf: DateTime(2026, 2, 28),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kwh',
            readings: [
              p(DateTime(2026, 1, 31), 0),
              p(DateTime(2026, 2, 28), 100),
            ],
          ),
        ],
      );
      expect(r.isInsufficient, isTrue);
      expect(r.message, contains('Incompatible'));
    });
  });

  group('Lifecycle documentation helpers', () {
    test('immutable core statuses', () {
      expect(ConservationBaselineStatus.approved.isImmutableCore, isTrue);
      expect(ConservationBaselineStatus.superseded.isImmutableCore, isTrue);
      expect(ConservationBaselineStatus.archived.isImmutableCore, isTrue);
      expect(ConservationBaselineStatus.draft.isImmutableCore, isFalse);
    });

    test('permissions lists exclude technician/viewer', () {
      expect(BaselinePermissions.approveRoles, isNot(contains('technician')));
      expect(BaselinePermissions.approveRoles, isNot(contains('viewer')));
      expect(BaselinePermissions.createDraftRoles, contains('site_admin'));
    });
  });
}
