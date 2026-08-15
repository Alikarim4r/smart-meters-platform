/// Opportunity workflow status (matches `conservation_opportunities.status`).
enum OpportunityStatus {
  detected('detected'),
  triaged('triaged'),
  underInvestigation('under_investigation'),
  actionRequired('action_required'),
  monitoring('monitoring'),
  resolved('resolved'),
  dismissed('dismissed');

  const OpportunityStatus(this.dbValue);
  final String dbValue;

  static OpportunityStatus fromDb(String value) =>
      OpportunityStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => OpportunityStatus.detected,
      );

  bool get isClosed =>
      this == OpportunityStatus.resolved || this == OpportunityStatus.dismissed;

  bool get isOpen => !isClosed;
}

/// Human dismiss reasons (matches DB check constraint).
enum OpportunityDismissReason {
  falsePositive('false_positive'),
  dataIssue('data_issue'),
  expectedOperationalChange('expected_operational_change'),
  duplicate('duplicate'),
  noActionRequired('no_action_required'),
  other('other');

  const OpportunityDismissReason(this.dbValue);
  final String dbValue;

  static OpportunityDismissReason fromDb(String value) =>
      OpportunityDismissReason.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => OpportunityDismissReason.other,
      );
}

/// Allowed opportunity status transitions (workflow only).
abstract final class OpportunityLifecycle {
  /// Map of from → allowed to statuses.
  static const Map<OpportunityStatus, Set<OpportunityStatus>>
      allowedTransitions = {
    OpportunityStatus.detected: {
      OpportunityStatus.triaged,
      OpportunityStatus.underInvestigation,
      OpportunityStatus.actionRequired,
      OpportunityStatus.monitoring,
      OpportunityStatus.dismissed,
    },
    OpportunityStatus.triaged: {
      OpportunityStatus.underInvestigation,
      OpportunityStatus.actionRequired,
      OpportunityStatus.monitoring,
      OpportunityStatus.resolved,
      OpportunityStatus.dismissed,
    },
    OpportunityStatus.underInvestigation: {
      OpportunityStatus.actionRequired,
      OpportunityStatus.monitoring,
      OpportunityStatus.resolved,
      OpportunityStatus.dismissed,
      OpportunityStatus.triaged,
    },
    OpportunityStatus.actionRequired: {
      OpportunityStatus.underInvestigation,
      OpportunityStatus.monitoring,
      OpportunityStatus.resolved,
      OpportunityStatus.dismissed,
    },
    OpportunityStatus.monitoring: {
      OpportunityStatus.actionRequired,
      OpportunityStatus.underInvestigation,
      OpportunityStatus.resolved,
      OpportunityStatus.dismissed,
    },
    // reopen paths
    OpportunityStatus.resolved: {
      OpportunityStatus.detected,
      OpportunityStatus.triaged,
    },
    OpportunityStatus.dismissed: {
      OpportunityStatus.detected,
      OpportunityStatus.triaged,
    },
  };

  static bool canTransition(OpportunityStatus from, OpportunityStatus to) {
    if (from == to) return false;
    return allowedTransitions[from]?.contains(to) ?? false;
  }

  static void assertCanTransition(OpportunityStatus from, OpportunityStatus to) {
    if (!canTransition(from, to)) {
      throw StateError(
        'Invalid opportunity transition: ${from.dbValue} → ${to.dbValue}',
      );
    }
  }
}
