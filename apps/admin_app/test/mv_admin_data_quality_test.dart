import 'package:admin_app/screens/mv_admin_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  const verification = SavingsVerificationService();

  test('critical unresolved Data Quality finding blocks verification gate', () {
    final hasPendingCriticalDq = hasPendingCriticalMvDataQuality([
      _result(
        findings: const [
          DataQualityFinding(
            code: DataQualityFindingCode.readingRequiresReview,
            severity: DataQualitySeverity.critical,
            title: 'Critical reading issue',
            detail: 'The current period still has a critical finding.',
          ),
        ],
      ),
    ]);

    final gate = _evaluateGate(
      verification,
      hasPendingCriticalDq: hasPendingCriticalDq,
    );

    expect(hasPendingCriticalDq, isTrue);
    expect(gate.passed, isFalse);
    expect(gate.reasons, contains('Unresolved critical Data Quality findings'));
  });

  test('clean Data Quality snapshots retain verification behavior', () {
    final hasPendingCriticalDq = hasPendingCriticalMvDataQuality([
      _result(),
      _result(
        findings: const [
          DataQualityFinding(
            code: DataQualityFindingCode.correctionInAnalysisPeriod,
            severity: DataQualitySeverity.info,
            title: 'Correction in period',
            detail: 'Non-critical findings do not trip the critical gate.',
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
