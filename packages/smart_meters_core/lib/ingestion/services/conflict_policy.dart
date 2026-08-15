import '../domain/reading_source.dart';

enum ConflictKind {
  duplicateIdentical,
  differingValues,
  sourcePriority,
  manualVsAutomated,
}

enum ConflictResolution {
  pendingReview,
  keepExisting,
  acceptIncoming,
  retainBoth,
  cancelled,
}

class ConflictAssessment {
  const ConflictAssessment({
    required this.kind,
    required this.requiresHumanReview,
    required this.silentOverwriteAllowed,
    this.message,
  });

  final ConflictKind kind;
  final bool requiresHumanReview;

  /// Always false by Phase 6 policy.
  final bool silentOverwriteAllowed;
  final String? message;
}

/// Conflict policy: never silently overwrite existing readings.
class ConflictPolicy {
  const ConflictPolicy();

  ConflictAssessment assess({
    required double existingRawValue,
    required ReadingSource existingSource,
    required double incomingRawValue,
    required ReadingSource incomingSource,
  }) {
    if (existingRawValue == incomingRawValue) {
      return const ConflictAssessment(
        kind: ConflictKind.duplicateIdentical,
        requiresHumanReview: false,
        silentOverwriteAllowed: false,
        message: 'Identical duplicate — retain existing; do not insert again',
      );
    }

    final manualVsAuto = existingSource.isManualFamily && incomingSource.isAutomated;
    return ConflictAssessment(
      kind: manualVsAuto
          ? ConflictKind.manualVsAutomated
          : ConflictKind.differingValues,
      requiresHumanReview: true,
      silentOverwriteAllowed: false,
      message: manualVsAuto
          ? 'Manual/API conflict — requires human review; no silent overwrite'
          : 'Differing values for same meter/date — requires human review',
    );
  }

  /// Canonical selection is never automatic.
  bool canAutoSelectCanonical(ConflictResolution resolution) => false;

  bool isValidHumanResolution(ConflictResolution resolution) =>
      resolution == ConflictResolution.keepExisting ||
      resolution == ConflictResolution.acceptIncoming ||
      resolution == ConflictResolution.retainBoth ||
      resolution == ConflictResolution.cancelled;
}
