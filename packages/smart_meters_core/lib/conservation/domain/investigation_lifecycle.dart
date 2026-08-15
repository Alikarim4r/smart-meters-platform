/// Investigation workflow status (matches
/// `conservation_investigations.investigation_status`).
enum InvestigationStatus {
  open('open'),
  assigned('assigned'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const InvestigationStatus(this.dbValue);
  final String dbValue;

  static InvestigationStatus fromDb(String value) =>
      InvestigationStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => InvestigationStatus.open,
      );
}

/// Allowed investigation status transitions.
abstract final class InvestigationLifecycle {
  static const Map<InvestigationStatus, Set<InvestigationStatus>>
      allowedTransitions = {
    InvestigationStatus.open: {
      InvestigationStatus.assigned,
      InvestigationStatus.inProgress,
      InvestigationStatus.cancelled,
    },
    InvestigationStatus.assigned: {
      InvestigationStatus.inProgress,
      InvestigationStatus.cancelled,
      InvestigationStatus.open,
    },
    InvestigationStatus.inProgress: {
      InvestigationStatus.completed,
      InvestigationStatus.cancelled,
      InvestigationStatus.assigned,
    },
    InvestigationStatus.completed: {},
    InvestigationStatus.cancelled: {
      InvestigationStatus.open,
    },
  };

  static bool canTransition(
    InvestigationStatus from,
    InvestigationStatus to,
  ) {
    if (from == to) return false;
    return allowedTransitions[from]?.contains(to) ?? false;
  }

  static void assertCanTransition(
    InvestigationStatus from,
    InvestigationStatus to,
  ) {
    if (!canTransition(from, to)) {
      throw StateError(
        'Invalid investigation transition: ${from.dbValue} → ${to.dbValue}',
      );
    }
  }
}

/// Human-confirmed cause codes (matches DB check). Never auto-assigned.
enum ConfirmedCause {
  confirmedLeak('confirmed_leak'),
  suspectedLeak('suspected_leak'),
  meterError('meter_error'),
  readingError('reading_error'),
  unmeteredConsumption('unmetered_consumption'),
  operationalUsage('operational_usage'),
  timingAlignmentDifference('timing_alignment_difference'),
  dataIssue('data_issue'),
  falsePositive('false_positive'),
  other('other'),
  unknown('unknown');

  const ConfirmedCause(this.dbValue);
  final String dbValue;

  static ConfirmedCause fromDb(String value) => ConfirmedCause.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ConfirmedCause.unknown,
      );
}
