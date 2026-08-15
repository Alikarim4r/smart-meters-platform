/// Action workflow status (matches `conservation_actions.status`).
enum ActionStatus {
  open('open'),
  assigned('assigned'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled'),
  verificationPending('verification_pending');

  const ActionStatus(this.dbValue);
  final String dbValue;

  static ActionStatus fromDb(String value) => ActionStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ActionStatus.open,
      );
}

/// Allowed action status transitions.
///
/// **Blocked:** `open → completed` (must assign/start first). Same guard as DB
/// trigger `conservation_action_transition_guard`.
abstract final class ActionLifecycle {
  /// Documented allowed transitions.
  ///
  /// - open → assigned | in_progress | cancelled
  /// - assigned → in_progress | cancelled | open
  /// - in_progress → completed | verification_pending | cancelled | assigned
  /// - verification_pending → completed | in_progress | cancelled
  /// - completed → (none; reopen via new action if needed)
  /// - cancelled → open
  ///
  /// Explicitly **not** allowed: open → completed.
  static const Map<ActionStatus, Set<ActionStatus>> allowedTransitions = {
    ActionStatus.open: {
      ActionStatus.assigned,
      ActionStatus.inProgress,
      ActionStatus.cancelled,
    },
    ActionStatus.assigned: {
      ActionStatus.inProgress,
      ActionStatus.cancelled,
      ActionStatus.open,
    },
    ActionStatus.inProgress: {
      ActionStatus.completed,
      ActionStatus.verificationPending,
      ActionStatus.cancelled,
      ActionStatus.assigned,
    },
    ActionStatus.verificationPending: {
      ActionStatus.completed,
      ActionStatus.inProgress,
      ActionStatus.cancelled,
    },
    ActionStatus.completed: {},
    ActionStatus.cancelled: {
      ActionStatus.open,
    },
  };

  static bool canTransition(ActionStatus from, ActionStatus to) {
    if (from == to) return false;
    // Defense in depth: never allow open → completed even if map drifts.
    if (from == ActionStatus.open && to == ActionStatus.completed) {
      return false;
    }
    return allowedTransitions[from]?.contains(to) ?? false;
  }

  static void assertCanTransition(ActionStatus from, ActionStatus to) {
    if (from == ActionStatus.open && to == ActionStatus.completed) {
      throw StateError(
        'conservation_actions: open → completed not allowed; '
        'assign/start first',
      );
    }
    if (!canTransition(from, to)) {
      throw StateError(
        'Invalid action transition: ${from.dbValue} → ${to.dbValue}',
      );
    }
  }
}
