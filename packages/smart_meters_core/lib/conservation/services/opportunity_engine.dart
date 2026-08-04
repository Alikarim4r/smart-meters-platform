import '../domain/opportunity_fingerprint.dart';
import '../domain/opportunity_lifecycle.dart';
import '../domain/opportunity_signal_rules.dart';
import '../domain/period_windows.dart';
import '../models/actual_vs_baseline_result.dart';
import '../models/actual_vs_target_result.dart';
import '../models/anomaly_result.dart';
import '../models/balance_result.dart';
import '../models/data_quality_result.dart';
import 'opportunity_priority.dart';

/// In-memory suggestion before persist — never auto-inserts.
class OpportunityCandidate {
  const OpportunityCandidate({
    required this.siteId,
    required this.sourceType,
    required this.sourceFingerprint,
    required this.title,
    required this.description,
    required this.utilityType,
    required this.detectedPeriodStart,
    required this.detectedPeriodEnd,
    required this.confidenceScore,
    required this.priority,
    required this.possibleCauses,
    required this.suggestedInvestigations,
    required this.sourceSnapshot,
    required this.ruleVersion,
    this.meterId,
    this.balanceGroupId,
    this.unitCode,

    /// Potential excess / quantity at risk — never Saving.
    this.estimatedWasteQuantity,
    this.origin = OpportunityOrigin.automatic,
    this.status = OpportunityStatus.detected,
  });

  final String siteId;
  final OpportunitySourceType sourceType;
  final String sourceFingerprint;
  final String title;
  final String description;
  final String utilityType;
  final DateTime detectedPeriodStart;
  final DateTime detectedPeriodEnd;
  final int confidenceScore;
  final OpportunityPriorityLevel priority;
  final List<String> possibleCauses;
  final List<String> suggestedInvestigations;
  final Map<String, dynamic> sourceSnapshot;
  final String ruleVersion;
  final String? meterId;
  final String? balanceGroupId;
  final String? unitCode;

  /// Potential excess / quantity at risk (not Verified Saving).
  final double? estimatedWasteQuantity;
  final OpportunityOrigin origin;
  final OpportunityStatus status;

  /// Safe display label for quantity field.
  static const quantityLabel = ConservationOpportunityLabels.potentialExcess;
}

/// Display labels — Potential Excess only; never Saving.
abstract final class ConservationOpportunityLabels {
  static const potentialExcess = 'Potential Excess';
  static const quantityAtRisk = 'Quantity at Risk';
  static const opportunity = 'Opportunity';

  static const forbidden = <String>[
    'Saving',
    'Verified Saving',
    'Estimated Saving',
  ];
}

/// Builds opportunity candidates from Phase 1/2 analysis signals.
///
/// Does **not** persist. Does **not** treat Opportunity as Confirmed Cause.
/// Does **not** use Saving terminology.
class OpportunityEngine {
  const OpportunityEngine({
    this.ruleVersion = OpportunitySignalRules.defaultRuleVersion,
  });

  final String ruleVersion;

  /// Build candidates from provided analysis-period signals only.
  List<OpportunityCandidate> buildCandidatesFromSignals({
    required String siteId,
    required String utilityType,
    List<ConsumptionAnomalyResult> anomalies = const [],
    List<BalanceResult> balances = const [],
    List<ActualVsTargetResult> actualVsTargets = const [],
    List<ActualVsBaselineResult> actualVsBaselines = const [],
    List<DataQualityFinding> dataQualityFindings = const [],
    String? meterId,
    String? defaultUnitCode,
  }) {
    final out = <OpportunityCandidate>[];

    for (final a in anomalies) {
      final c = _fromAnomaly(
        siteId: siteId,
        utilityType: utilityType,
        anomaly: a,
        meterId: meterId,
        unitCode: defaultUnitCode,
      );
      if (c != null) out.add(c);
    }

    for (final b in balances) {
      final c = _fromBalance(
        siteId: siteId,
        utilityType: utilityType,
        balance: b,
        meterId: meterId,
      );
      if (c != null) out.add(c);
    }

    for (final t in actualVsTargets) {
      final c = _fromActualVsTarget(
        siteId: siteId,
        utilityType: utilityType,
        result: t,
        meterId: meterId,
      );
      if (c != null) out.add(c);
    }

    for (final bl in actualVsBaselines) {
      final c = _fromActualVsBaseline(
        siteId: siteId,
        utilityType: utilityType,
        result: bl,
        meterId: meterId,
      );
      if (c != null) out.add(c);
    }

    // Explicitly skip DQ-only findings (missing photo / reading requires review).
    for (final f in dataQualityFindings) {
      if (!OpportunitySignalRules.dataQualityFindingQualifiesAsOpportunity(f)) {
        continue;
      }
      // Reserved: no default DQ → opportunity path in Phase 3.
    }

    return out;
  }

  OpportunityCandidate? _fromAnomaly({
    required String siteId,
    required String utilityType,
    required ConsumptionAnomalyResult anomaly,
    String? meterId,
    String? unitCode,
  }) {
    if (!OpportunitySignalRules.anomalyQualifies(anomaly)) return null;

    final kind = anomaly.kind!;
    final sourceType = kind == AnomalyKind.copDeclining
        ? OpportunitySourceType.copDeterioration
        : OpportunitySourceType.periodicAnomaly;

    final entityKey = [
      kind.name,
      ...(anomaly.contributingMeterIds.isEmpty
          ? [meterId ?? 'site']
          : anomaly.contributingMeterIds),
    ].join(':');

    final fingerprint = buildOpportunityFingerprint(
      siteId: siteId,
      sourceType: sourceType.dbValue,
      sourceEntityKey: entityKey,
      periodStart: anomaly.periodStart,
      periodEnd: anomaly.periodEnd,
      ruleVersion: ruleVersion,
    );

    // Potential excess ≈ current − reference when above.
    double? potentialExcess;
    if (anomaly.currentValue != null &&
        anomaly.referenceValue != null &&
        anomaly.currentValue! > anomaly.referenceValue!) {
      potentialExcess = anomaly.currentValue! - anomaly.referenceValue!;
    }

    final priority = OpportunityPriority.compute(
      confidenceScore: anomaly.confidenceScore,
      severity: anomaly.severity,
      magnitudePct: anomaly.percentageChange,
      repetitionCount: kind == AnomalyKind.repeatedHigh ? 3 : 1,
    );

    return OpportunityCandidate(
      siteId: siteId,
      sourceType: sourceType,
      sourceFingerprint: fingerprint,
      title: _anomalyTitle(kind),
      description: anomaly.reason,
      utilityType: utilityType,
      detectedPeriodStart: dateOnly(anomaly.periodStart),
      detectedPeriodEnd: dateOnly(anomaly.periodEnd),
      confidenceScore: anomaly.confidenceScore,
      priority: priority,
      possibleCauses: _anomalyPossibleCauses(kind),
      suggestedInvestigations: anomaly.investigationNotes.isNotEmpty
          ? anomaly.investigationNotes
          : _defaultInvestigations(sourceType),
      sourceSnapshot: {
        'kind': kind.name,
        'severity': anomaly.severity.name,
        'status_label': anomaly.statusLabel,
        'current_value': anomaly.currentValue,
        'reference_value': anomaly.referenceValue,
        'percentage_change': anomaly.percentageChange,
        'reference_method': anomaly.referenceMethod,
        'completeness': anomaly.completeness,
        'quantity_label': ConservationOpportunityLabels.potentialExcess,
      },
      ruleVersion: ruleVersion,
      meterId:
          meterId ??
          (anomaly.contributingMeterIds.isNotEmpty
              ? anomaly.contributingMeterIds.first
              : null),
      unitCode: unitCode,
      estimatedWasteQuantity: potentialExcess,
    );
  }

  OpportunityCandidate? _fromBalance({
    required String siteId,
    required String utilityType,
    required BalanceResult balance,
    String? meterId,
  }) {
    if (!OpportunitySignalRules.balanceQualifies(balance)) return null;

    final groupKey = balance.balanceGroupId ?? balance.mainMeterId;
    final fingerprint = buildOpportunityFingerprint(
      siteId: siteId,
      sourceType: OpportunitySourceType.balanceDifference.dbValue,
      sourceEntityKey: groupKey,
      periodStart: balance.periodStart,
      periodEnd: balance.periodEnd,
      ruleVersion: ruleVersion,
    );

    final diff = balance.balanceDifference;
    // Potential excess = positive unaccounted quantity (abs when meaningful).
    final potentialExcess = diff?.abs();

    final priority = OpportunityPriority.compute(
      confidenceScore: balance.confidenceScore,
      severity: _severityFromBalancePct(balance.balancePercentage),
      magnitudePct: balance.balancePercentage,
    );

    return OpportunityCandidate(
      siteId: siteId,
      sourceType: OpportunitySourceType.balanceDifference,
      sourceFingerprint: fingerprint,
      title: 'Balance Difference Requires Investigation',
      description:
          '${balance.directionLabel}: difference '
          '${diff?.toStringAsFixed(2) ?? 'n/a'} ${balance.unitCode} '
          '(${balance.balancePercentage?.toStringAsFixed(1) ?? 'n/a'}%). '
          'Review status: ${balance.reviewStatus}. '
          'Not a confirmed cause.',
      utilityType: utilityType,
      detectedPeriodStart: dateOnly(balance.periodStart),
      detectedPeriodEnd: dateOnly(balance.periodEnd),
      confidenceScore: balance.confidenceScore,
      priority: priority,
      possibleCauses: const [
        'unmetered_consumption',
        'timing_alignment_difference',
        'meter_error',
        'reading_error',
        'operational_usage',
      ],
      suggestedInvestigations: const [
        'Verify main vs submeter reading alignment',
        'Check for unmetered branches',
        'Review recent corrections in the period',
      ],
      sourceSnapshot: {
        'balance_difference': balance.balanceDifference,
        'balance_percentage': balance.balancePercentage,
        'direction_label': balance.directionLabel,
        'review_status': balance.reviewStatus,
        'alignment_status': balance.alignmentStatus.name,
        'main_meter_id': balance.mainMeterId,
        'child_meter_ids': balance.childMeterIds,
        'quantity_label': ConservationOpportunityLabels.potentialExcess,
      },
      ruleVersion: ruleVersion,
      meterId: meterId ?? balance.mainMeterId,
      balanceGroupId: balance.balanceGroupId,
      unitCode: balance.unitCode,
      estimatedWasteQuantity: potentialExcess,
    );
  }

  OpportunityCandidate? _fromActualVsTarget({
    required String siteId,
    required String utilityType,
    required ActualVsTargetResult result,
    String? meterId,
  }) {
    if (!OpportunitySignalRules.actualVsTargetQualifies(result)) return null;

    final fingerprint = buildOpportunityFingerprint(
      siteId: siteId,
      sourceType: OpportunitySourceType.actualVsTarget.dbValue,
      sourceEntityKey: result.targetId,
      periodStart: result.periodStart,
      periodEnd: result.periodEnd,
      ruleVersion: ruleVersion,
    );

    final potentialExcess =
        result.absoluteDifference != null && result.absoluteDifference! > 0
        ? result.absoluteDifference
        : null;

    final abovePct = (result.percentageOfTarget ?? 100) - 100;
    final priority = OpportunityPriority.compute(
      confidenceScore: result.confidenceScore,
      magnitudePct: abovePct,
    );

    return OpportunityCandidate(
      siteId: siteId,
      sourceType: OpportunitySourceType.actualVsTarget,
      sourceFingerprint: fingerprint,
      title: 'Above Target — Potential Excess',
      description:
          '${result.directionLabel}: actual exceeds target by '
          '${potentialExcess?.toStringAsFixed(2) ?? 'n/a'} ${result.unitCode} '
          '(${abovePct.toStringAsFixed(1)}% above). '
          'Opportunity for investigation — not a verified saving.',
      utilityType: utilityType,
      detectedPeriodStart: dateOnly(result.periodStart),
      detectedPeriodEnd: dateOnly(result.periodEnd),
      confidenceScore: result.confidenceScore,
      priority: priority,
      possibleCauses: const [
        'operational_usage',
        'meter_error',
        'reading_error',
        'unknown',
      ],
      suggestedInvestigations: const [
        'Compare actual vs prorated/full target assumptions',
        'Review operational schedule changes',
        'Check meter completeness in the period',
      ],
      sourceSnapshot: {
        'target_id': result.targetId,
        'target_version': result.targetVersion,
        'actual_value': result.actualValue,
        'effective_target_value': result.effectiveTargetValue,
        'absolute_difference': result.absoluteDifference,
        'percentage_of_target': result.percentageOfTarget,
        'standing': result.standing.name,
        'quantity_label': ConservationOpportunityLabels.potentialExcess,
      },
      ruleVersion: ruleVersion,
      meterId: meterId,
      unitCode: result.unitCode,
      estimatedWasteQuantity: potentialExcess,
    );
  }

  OpportunityCandidate? _fromActualVsBaseline({
    required String siteId,
    required String utilityType,
    required ActualVsBaselineResult result,
    String? meterId,
  }) {
    if (!OpportunitySignalRules.actualVsBaselineQualifies(result)) return null;

    final fingerprint = buildOpportunityFingerprint(
      siteId: siteId,
      sourceType: OpportunitySourceType.actualVsBaseline.dbValue,
      sourceEntityKey: result.baselineId,
      periodStart: result.periodStart,
      periodEnd: result.periodEnd,
      ruleVersion: ruleVersion,
    );

    final potentialExcess =
        result.absoluteVariance != null && result.absoluteVariance! > 0
        ? result.absoluteVariance
        : null;

    final priority = OpportunityPriority.compute(
      confidenceScore: result.confidenceScore,
      magnitudePct: result.percentageVariance,
    );

    return OpportunityCandidate(
      siteId: siteId,
      sourceType: OpportunitySourceType.actualVsBaseline,
      sourceFingerprint: fingerprint,
      title: 'Above Baseline — Potential Excess',
      description:
          '${result.directionLabel}: actual exceeds baseline by '
          '${potentialExcess?.toStringAsFixed(2) ?? 'n/a'} ${result.unitCode} '
          '(${result.percentageVariance?.toStringAsFixed(1) ?? 'n/a'}%). '
          'Quantity at risk for investigation — not a verified saving.',
      utilityType: utilityType,
      detectedPeriodStart: dateOnly(result.periodStart),
      detectedPeriodEnd: dateOnly(result.periodEnd),
      confidenceScore: result.confidenceScore,
      priority: priority,
      possibleCauses: const [
        'operational_usage',
        'suspected_leak',
        'meter_error',
        'unknown',
      ],
      suggestedInvestigations: const [
        'Validate baseline version applicability',
        'Review period completeness vs baseline window',
        'Investigate drivers of above-baseline consumption',
      ],
      sourceSnapshot: {
        'baseline_id': result.baselineId,
        'baseline_version': result.baselineVersion,
        'actual_value': result.actualValue,
        'baseline_value': result.baselineValue,
        'absolute_variance': result.absoluteVariance,
        'percentage_variance': result.percentageVariance,
        'standing': result.standing.name,
        'quantity_label': ConservationOpportunityLabels.potentialExcess,
      },
      ruleVersion: ruleVersion,
      meterId: meterId,
      unitCode: result.unitCode,
      estimatedWasteQuantity: potentialExcess,
    );
  }

  static String _anomalyTitle(AnomalyKind kind) => switch (kind) {
    AnomalyKind.unusualIncrease => 'Unusual Increase — Potential Excess',
    AnomalyKind.repeatedHigh => 'Repeated High Consumption',
    AnomalyKind.farAboveBaseline => 'Far Above Baseline — Potential Excess',
    AnomalyKind.aboveTarget => 'Above Target Signal',
    AnomalyKind.copDeclining => 'COP Declining Trend',
    AnomalyKind.suddenChange => 'Sudden Consumption Change',
    _ => 'Consumption Anomaly Signal',
  };

  static List<String> _anomalyPossibleCauses(AnomalyKind kind) =>
      switch (kind) {
        AnomalyKind.copDeclining => const [
          'hvac_performance',
          'operational_usage',
          'meter_error',
          'unknown',
        ],
        AnomalyKind.unusualIncrease ||
        AnomalyKind.repeatedHigh ||
        AnomalyKind.farAboveBaseline ||
        AnomalyKind.aboveTarget ||
        AnomalyKind.suddenChange => const [
          'suspected_leak',
          'operational_usage',
          'meter_error',
          'reading_error',
          'unknown',
        ],
        _ => const ['unknown'],
      };

  static List<String> _defaultInvestigations(OpportunitySourceType t) =>
      switch (t) {
        OpportunitySourceType.copDeterioration => const [
          'Review COP group completeness',
          'Inspect HVAC operating conditions',
        ],
        _ => const [
          'Review source readings and completeness',
          'Compare to prior periods',
          'Check for operational changes',
        ],
      };

  static AnomalySeverity _severityFromBalancePct(double? pct) {
    final a = pct?.abs() ?? 0;
    if (a >= 25) return AnomalySeverity.critical;
    if (a >= 15) return AnomalySeverity.high;
    if (a >= 5) return AnomalySeverity.medium;
    return AnomalySeverity.low;
  }
}
