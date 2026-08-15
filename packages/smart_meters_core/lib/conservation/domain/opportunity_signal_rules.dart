import '../models/actual_vs_baseline_result.dart';
import '../models/actual_vs_target_result.dart';
import '../models/anomaly_result.dart';
import '../models/balance_result.dart';
import '../models/data_quality_result.dart';

/// Which Phase 1/2 signals become conservation opportunities vs data-quality-only.
///
/// **Opportunity ≠ Confirmed Cause.** Signals suggest investigation only.
///
/// **DataQualityIssue (NOT automatic opportunities):**
/// - [DataQualityFindingCode.missingRequiredPhoto]
/// - [DataQualityFindingCode.readingRequiresReview]
/// (and similar DQ findings) unless explicitly conservation-relevant via a
/// separate [OpportunitySourceType.dataQualityConservation] path that callers
/// must opt into — never via default DQ scan.
abstract final class OpportunitySignalRules {
  static const defaultRuleVersion = 'conservation_opportunity_v1';

  /// Absolute balance % at/above which an OK balance becomes an opportunity.
  static const balancePercentageThreshold = 5.0;

  /// Absolute % gap considered significant for Actual vs Target / Baseline.
  static const significantPercentageThreshold = 5.0;

  /// Anomaly kinds that qualify as conservation opportunity signals.
  static const Set<AnomalyKind> qualifyingAnomalyKinds = {
    AnomalyKind.unusualIncrease,
    AnomalyKind.repeatedHigh,
    AnomalyKind.farAboveBaseline,
    AnomalyKind.aboveTarget,
    AnomalyKind.copDeclining,
    AnomalyKind.suddenChange,
  };

  /// DQ finding codes that must never auto-create opportunities.
  static const Set<DataQualityFindingCode> dataQualityOnlyCodes = {
    DataQualityFindingCode.missingRequiredPhoto,
    DataQualityFindingCode.readingRequiresReview,
  };

  /// True when [kind] can become an opportunity (with severity gates for sudden).
  static bool anomalyKindQualifies(
    AnomalyKind? kind, {
    AnomalySeverity severity = AnomalySeverity.info,
  }) {
    if (kind == null) return false;
    if (!qualifyingAnomalyKinds.contains(kind)) return false;
    // suddenChange only at high/critical severity.
    if (kind == AnomalyKind.suddenChange) {
      return severity == AnomalySeverity.high ||
          severity == AnomalySeverity.critical;
    }
    return true;
  }

  static bool anomalyQualifies(ConsumptionAnomalyResult r) {
    if (!r.detected) return false;
    return anomalyKindQualifies(r.kind, severity: r.severity);
  }

  /// Balance: status ok AND (Requires Review OR |pct| >= threshold).
  static bool balanceQualifies(BalanceResult r) {
    if (r.status != BalanceResultStatus.ok) return false;
    if (r.reviewStatus == ConsumptionAnomalyResult.requiresReview) return true;
    final pct = r.balancePercentage;
    if (pct == null) return false;
    return pct.abs() >= balancePercentageThreshold;
  }

  /// Actual vs Target: aboveTarget with significant % of target.
  static bool actualVsTargetQualifies(ActualVsTargetResult r) {
    if (r.status != ActualVsTargetStatus.ok) return false;
    if (r.standing != ActualVsTargetStanding.aboveTarget) return false;
    final pct = r.percentageOfTarget;
    if (pct == null) return false;
    // percentageOfTarget is actual/target*100; gap above 100 is excess.
    final abovePct = pct - 100.0;
    return abovePct >= significantPercentageThreshold;
  }

  /// Actual vs Baseline: aboveBaseline with significant % variance.
  static bool actualVsBaselineQualifies(ActualVsBaselineResult r) {
    if (r.status != ActualVsBaselineStatus.ok) return false;
    if (r.standing != ActualVsBaselineStanding.aboveBaseline) return false;
    final pct = r.percentageVariance;
    if (pct == null) return false;
    return pct.abs() >= significantPercentageThreshold;
  }

  /// Returns true when finding is data-quality-only (not an opportunity source).
  static bool isDataQualityOnly(DataQualityFinding finding) =>
      dataQualityOnlyCodes.contains(finding.code);

  /// Explicit filter: missing photo / reading requires review never qualify.
  static bool dataQualityFindingQualifiesAsOpportunity(
    DataQualityFinding finding,
  ) {
    // Default: none of the DQ-only codes become opportunities.
    if (isDataQualityOnly(finding)) return false;
    // Other DQ codes also do not auto-create opportunities unless a future
    // caller uses source_type=data_quality_conservation with explicit opt-in.
    return false;
  }
}

/// DB `source_type` values for opportunities.
enum OpportunitySourceType {
  periodicAnomaly('periodic_anomaly'),
  balanceDifference('balance_difference'),
  actualVsTarget('actual_vs_target'),
  actualVsBaseline('actual_vs_baseline'),
  copDeterioration('cop_deterioration'),
  manual('manual'),
  dataQualityConservation('data_quality_conservation');

  const OpportunitySourceType(this.dbValue);
  final String dbValue;

  static OpportunitySourceType fromDb(String value) =>
      OpportunitySourceType.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => OpportunitySourceType.manual,
      );
}

/// Opportunity origin.
enum OpportunityOrigin {
  automatic('automatic'),
  manual('manual');

  const OpportunityOrigin(this.dbValue);
  final String dbValue;

  static OpportunityOrigin fromDb(String value) =>
      OpportunityOrigin.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => OpportunityOrigin.automatic,
      );
}

/// Priority levels (matches DB).
enum OpportunityPriorityLevel {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  const OpportunityPriorityLevel(this.dbValue);
  final String dbValue;

  static OpportunityPriorityLevel fromDb(String value) =>
      OpportunityPriorityLevel.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => OpportunityPriorityLevel.medium,
      );

  int get rank => switch (this) {
        OpportunityPriorityLevel.low => 0,
        OpportunityPriorityLevel.medium => 1,
        OpportunityPriorityLevel.high => 2,
        OpportunityPriorityLevel.critical => 3,
      };

  static OpportunityPriorityLevel fromRank(int rank) {
    if (rank <= 0) return OpportunityPriorityLevel.low;
    if (rank == 1) return OpportunityPriorityLevel.medium;
    if (rank == 2) return OpportunityPriorityLevel.high;
    return OpportunityPriorityLevel.critical;
  }

  OpportunityPriorityLevel cappedAt(OpportunityPriorityLevel max) =>
      rank <= max.rank ? this : max;
}
