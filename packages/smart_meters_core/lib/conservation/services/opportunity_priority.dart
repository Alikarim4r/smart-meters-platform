import '../domain/opportunity_signal_rules.dart';
import '../models/anomaly_result.dart';

/// Computes opportunity priority from signal characteristics.
///
/// Caps:
/// - confidence < 60 → max Medium
/// - confidence < 70 → no Critical (documented exception = false)
abstract final class OpportunityPriority {
  /// When true, critical may be assigned below confidence 70. Always false
  /// for Phase 3 — no undocumented exceptions.
  static const allowCriticalBelowConfidence70 = false;

  static OpportunityPriorityLevel compute({
    required int confidenceScore,
    AnomalySeverity? severity,
    double? magnitudePct,
    int repetitionCount = 1,
  }) {
    var rank = _baseRank(
      severity: severity,
      magnitudePct: magnitudePct,
      repetitionCount: repetitionCount,
    );

    var level = OpportunityPriorityLevel.fromRank(rank);

    if (confidenceScore < 60) {
      level = level.cappedAt(OpportunityPriorityLevel.medium);
    } else if (confidenceScore < 70 && !allowCriticalBelowConfidence70) {
      level = level.cappedAt(OpportunityPriorityLevel.high);
    }

    return level;
  }

  static int _baseRank({
    AnomalySeverity? severity,
    double? magnitudePct,
    required int repetitionCount,
  }) {
    var rank = switch (severity) {
      AnomalySeverity.critical => 3,
      AnomalySeverity.high => 2,
      AnomalySeverity.medium => 1,
      AnomalySeverity.low => 0,
      AnomalySeverity.info || null => 1,
    };

    final mag = magnitudePct?.abs();
    if (mag != null) {
      if (mag >= 40) {
        rank = rank < 3 ? 3 : rank;
      } else if (mag >= 20) {
        rank = rank < 2 ? 2 : rank;
      } else if (mag >= 10) {
        rank = rank < 1 ? 1 : rank;
      }
    }

    if (repetitionCount >= 3) {
      rank = (rank + 1).clamp(0, 3);
    } else if (repetitionCount >= 2) {
      rank = rank < 2 ? rank + 1 : rank;
    }

    return rank.clamp(0, 3);
  }
}
