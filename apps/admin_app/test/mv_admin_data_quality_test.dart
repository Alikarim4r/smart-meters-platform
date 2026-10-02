import 'package:admin_app/screens/mv_admin_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  const verification = SavingsVerificationService();

  test('production replacement/reset info finding blocks verification gate', () {
    final result = _evaluateDataQuality(currentValue: 5);
    final replacement = result.findings.singleWhere(
      (finding) =>
          finding.code == DataQualityFindingCode.possibleRolloverOrReset,
    );
    final hasPendingCriticalDq = hasBlockingMvDataQuality([result]);

    final gate = _evaluateGate(
      verification,
      hasPendingCriticalDq: hasPendingCriticalDq,
    );

    expect(replacement.severity, DataQualitySeverity.info);
    expect(
      replacement.metadata['possible_cause'],
      'rollover_or_reset',
    );
    expect(hasPendingCriticalDq, isTrue);
    expect(gate.passed, isFalse);
    expect(gate.reasons, contains('Unresolved blocking Data Quality findings'));
  });

  test('production implausible-drop warning blocks verification gate', () {
    final result = _evaluateDataQuality();
    final implausibleDrop = result.findings.singleWhere(
      (finding) =>
          finding.code == DataQualityFindingCode.readingRequiresReview,
    );
    final hasPendingCriticalDq = hasBlockingMvDataQuality([result]);

    final gate = _evaluateGate(
      verification,
      hasPendingCriticalDq: hasPendingCriticalDq,
    );

    expect(implausibleDrop.severity, DataQualitySeverity.warning);
    expect(implausibleDrop.metadata['possible_cause'], 'possible_entry_error');
    expect(hasPendingCriticalDq, isTrue);
    expect(gate.passed, isFalse);
  });

  test('production correction info finding blocks verification gate', () {
    final result = _evaluateDataQuality(correctionCountInPeriod: 1);

    expect(
      result.findings,
      contains(
        isA<DataQualityFinding>()
            .having(
              (finding) => finding.code,
              'code',
              DataQualityFindingCode.correctionInAnalysisPeriod,
            )
            .having(
              (finding) => finding.severity,
              'severity',
              DataQualitySeverity.info,
            ),
      ),
    );
    expect(hasBlockingMvDataQuality([result]), isTrue);
  });

  test('benign informational finding does not weaken other gates', () {
    final hasPendingCriticalDq = hasBlockingMvDataQuality([
      _result(
        findings: const [
          DataQualityFinding(
            code: DataQualityFindingCode.missingExpectedReading,
            severity: DataQualitySeverity.info,
            title: 'Informational context',
            detail: 'This code is not a cumulative drop/reset/correction.',
          ),
        ],
      ),
    ]);

    final gate = _evaluateGate(
      verification,
      hasPendingCriticalDq: hasPendingCriticalDq,
    );

    expect(hasPendingCriticalDq, isFalse);
    expect(gate.passed, isTrue);
    expect(gate.reasons, isEmpty);
  });

  test('critical findings remain blocking regardless of code', () {
    expect(
      hasBlockingMvDataQuality([
        _result(
          findings: const [
            DataQualityFinding(
              code: DataQualityFindingCode.missingRequiredPhoto,
              severity: DataQualitySeverity.critical,
              title: 'Critical policy failure',
              detail: 'Existing critical-severity behavior remains enforced.',
            ),
          ],
        ),
      ]),
      isTrue,
    );
  });
}

DataQualityResult _evaluateDataQuality({
  int correctionCountInPeriod = 0,
  double currentValue = 60,
}) {
  return const DataQualityService().evaluate(
    DataQualityRuleContext(
      siteId: 'site-1',
      periodStart: DateTime.utc(2026, 1, 1),
      periodEnd: DateTime.utc(2026, 1, 31),
      photoRequired: false,
      highConsumptionMultiplier: 3,
      meters: [
        QualityMeterInput(
          meterId: 'meter-1',
          meterCode: 'M-1',
          isActive: true,
          includeInDashboard: true,
          correctionCountInPeriod: correctionCountInPeriod,
          readings: [
            QualityReadingInput(
              readingId: 'reading-1',
              meterId: 'meter-1',
              readingDate: DateTime.utc(2025, 12, 31),
              rawValue: 100,
              normalizedValue: 100,
            ),
            QualityReadingInput(
              readingId: 'reading-2',
              meterId: 'meter-1',
              readingDate: DateTime.utc(2026, 1, 31),
              rawValue: currentValue,
              normalizedValue: currentValue,
            ),
          ],
        ),
      ],
    ),
  );
}

GateEvaluationResult _evaluateGate(
  SavingsVerificationService service, {
  required bool hasPendingCriticalDq,
}) {
  return service.evaluateGates(
    currentStatus: MvStatus.verificationPending,
    dataCompleteness: 0.9,
    confidenceScore: 80,
    followUpDays: 14,
    baselineStatus: ConservationBaselineStatus.approved,
    actionStatus: ActionStatus.completed,
    opportunityStatus: OpportunityStatus.monitoring,
    hasPendingCriticalDq: hasPendingCriticalDq,
    verifiedBy: 'admin-1',
    actorRole: 'site_admin',
  );
}

DataQualityResult _result({List<DataQualityFinding> findings = const []}) {
  final now = DateTime.utc(2026, 1, 31);
  return DataQualityResult(
    siteId: 'site-1',
    findings: findings,
    confidence: const ConfidenceBreakdown(
      base: 100,
      adjustments: [],
      finalScore: 100,
    ),
    meta: CalculationMeta(
      calculationMethod: 'test',
      periodStart: DateTime.utc(2026, 1, 1),
      periodEnd: now,
      dataCompleteness: 1,
      confidenceScore: 100,
      calculatedAt: now,
    ),
    sourceReadings: const [],
  );
}
