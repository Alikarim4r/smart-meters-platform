/// M&V record status (matches `conservation_measurement_verifications.status`).
enum MvStatus {
  draft('draft'),
  estimated('estimated'),
  verificationPending('verification_pending'),
  verified('verified'),
  rejected('rejected'),
  superseded('superseded'),
  archived('archived');

  const MvStatus(this.dbValue);
  final String dbValue;

  static MvStatus fromDb(String value) => MvStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => MvStatus.draft,
      );

  /// Active verified rows that can double-count with a new verification.
  bool get isActiveVerified => this == MvStatus.verified;
}

/// Verification method codes (matches DB check).
enum MvVerificationMethod {
  baselineComparison('baseline_comparison'),
  beforeAfterPeriod('before_after_period'),
  normalizedPeriodComparison('normalized_period_comparison');

  const MvVerificationMethod(this.dbValue);
  final String dbValue;

  static MvVerificationMethod fromDb(String value) =>
      MvVerificationMethod.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => MvVerificationMethod.baselineComparison,
      );
}

/// Allowed M&V status transitions.
///
/// **Blocked:** `draft → verified` (must estimate + verification_pending first).
/// Same guard as DB trigger `conservation_mv_transition_guard`.
///
/// Verified only from `verification_pending`.
abstract final class MvLifecycle {
  /// Documented allowed transitions.
  ///
  /// - draft → estimated | rejected | archived
  /// - estimated → verification_pending | draft | rejected | archived
  /// - verification_pending → verified | rejected | estimated | archived
  /// - verified → superseded | archived
  /// - rejected → draft | archived
  /// - superseded → archived
  /// - archived → (none)
  ///
  /// Explicitly **not** allowed: draft → verified.
  static const Map<MvStatus, Set<MvStatus>> allowedTransitions = {
    MvStatus.draft: {
      MvStatus.estimated,
      MvStatus.rejected,
      MvStatus.archived,
    },
    MvStatus.estimated: {
      MvStatus.verificationPending,
      MvStatus.draft,
      MvStatus.rejected,
      MvStatus.archived,
    },
    MvStatus.verificationPending: {
      MvStatus.verified,
      MvStatus.rejected,
      MvStatus.estimated,
      MvStatus.archived,
    },
    MvStatus.verified: {
      MvStatus.superseded,
      MvStatus.archived,
    },
    MvStatus.rejected: {
      MvStatus.draft,
      MvStatus.archived,
    },
    MvStatus.superseded: {
      MvStatus.archived,
    },
    MvStatus.archived: {},
  };

  static bool canTransition(MvStatus from, MvStatus to) {
    if (from == to) return false;
    // Defense in depth: never allow draft → verified even if map drifts.
    if (from == MvStatus.draft && to == MvStatus.verified) {
      return false;
    }
    // Verified only from verification_pending.
    if (to == MvStatus.verified && from != MvStatus.verificationPending) {
      return false;
    }
    return allowedTransitions[from]?.contains(to) ?? false;
  }

  static void assertCanTransition(MvStatus from, MvStatus to) {
    if (from == MvStatus.draft && to == MvStatus.verified) {
      throw StateError(
        'conservation_mv: draft → verified not allowed; '
        'estimate + verification_pending + gates first',
      );
    }
    if (to == MvStatus.verified && from != MvStatus.verificationPending) {
      throw StateError(
        'conservation_mv: verified requires prior verification_pending status',
      );
    }
    if (!canTransition(from, to)) {
      throw StateError(
        'Invalid M&V transition: ${from.dbValue} → ${to.dbValue}',
      );
    }
  }
}

/// Unit-level policy: who may set Verified Saving / confirmed_cause.
///
/// DB triggers enforce the same roles; this helper is for Dart-side checks.
abstract final class ConservationAuthorityPolicy {
  static const verifierRoles = [
    'site_admin',
    'super_admin',
    'platform_owner',
  ];

  /// Technicians cannot verify savings.
  static bool canVerifySaving(String? role) {
    if (role == null || role.trim().isEmpty) return false;
    return verifierRoles.contains(role.trim());
  }

  /// Technicians cannot set confirmed_cause (proposed_cause only).
  static bool canConfirmCause(String? role) => canVerifySaving(role);

  static void assertCanVerify(String? role) {
    if (!canVerifySaving(role)) {
      throw StateError(
        'Verified Saving requires site_admin / super_admin / platform_owner '
        '(technician cannot verify)',
      );
    }
  }

  static void assertCanConfirmCause(String? role) {
    if (!canConfirmCause(role)) {
      throw StateError(
        'confirmed_cause requires site_admin / super_admin / platform_owner '
        '(not technician)',
      );
    }
  }
}
