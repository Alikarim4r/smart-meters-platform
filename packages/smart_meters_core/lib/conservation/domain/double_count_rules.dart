import 'mv_lifecycle.dart';
import 'period_windows.dart';

/// Minimal shape for double-count overlap checks.
class DoubleCountCandidate {
  const DoubleCountCandidate({
    required this.id,
    required this.status,
    required this.postPeriodStart,
    required this.postPeriodEnd,
    this.meterId,
    this.balanceGroupId,
  });

  final String id;
  final MvStatus status;
  final DateTime postPeriodStart;
  final DateTime postPeriodEnd;
  final String? meterId;
  final String? balanceGroupId;
}

/// Overlap pair between two verified (or candidate) M&V rows.
class DoubleCountOverlap {
  const DoubleCountOverlap({
    required this.aId,
    required this.bId,
    required this.scopeKey,
    required this.reason,
  });

  final String aId;
  final String bId;
  final String scopeKey;
  final String reason;
}

/// Detect overlapping verified savings for the same meter / balance scope.
///
/// Active statuses: [MvStatus.verified] only (superseded/archived/rejected
/// do not double-count).
abstract final class DoubleCountRules {
  /// Returns overlapping pairs among [candidates] that share meter or
  /// balance_group scope and have overlapping inclusive post periods.
  static List<DoubleCountOverlap> detectOverlap(
    List<DoubleCountCandidate> candidates, {
    Set<MvStatus> activeStatuses = const {MvStatus.verified},
    Map<String, String> parentByMeterId = const {},
    Map<String, List<String>> balanceGroupMembers = const {},
  }) {
    final active = candidates
        .where((c) => activeStatuses.contains(c.status))
        .toList();
    final overlaps = <DoubleCountOverlap>[];

    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        final a = active[i];
        final b = active[j];
        final scope = _sharedScope(a, b, parentByMeterId, balanceGroupMembers);
        if (scope == null) continue;
        if (!_periodsOverlap(
          a.postPeriodStart,
          a.postPeriodEnd,
          b.postPeriodStart,
          b.postPeriodEnd,
        )) {
          continue;
        }
        overlaps.add(
          DoubleCountOverlap(
            aId: a.id,
            bId: b.id,
            scopeKey: scope,
            reason:
                'Overlapping verified post periods for $scope '
                '(${_iso(a.postPeriodStart)}–${_iso(a.postPeriodEnd)} vs '
                '${_iso(b.postPeriodStart)}–${_iso(b.postPeriodEnd)})',
          ),
        );
      }
    }
    return overlaps;
  }

  /// Whether [candidate] overlaps any [existing] active verified rows.
  static List<DoubleCountOverlap> detectAgainstExisting({
    required DoubleCountCandidate candidate,
    required List<DoubleCountCandidate> existing,
    Map<String, String> parentByMeterId = const {},
    Map<String, List<String>> balanceGroupMembers = const {},
  }) {
    return detectOverlap(
      [candidate, ...existing],
      parentByMeterId: parentByMeterId,
      balanceGroupMembers: balanceGroupMembers,
    );
  }

  static String? _sharedScope(
    DoubleCountCandidate a,
    DoubleCountCandidate b,
    Map<String, String> parentByMeterId,
    Map<String, List<String>> balanceGroupMembers,
  ) {
    if (a.meterId != null &&
        a.meterId!.isNotEmpty &&
        a.meterId == b.meterId) {
      return 'meter:${a.meterId}';
    }
    if (a.balanceGroupId != null &&
        a.balanceGroupId!.isNotEmpty &&
        a.balanceGroupId == b.balanceGroupId) {
      return 'balance_group:${a.balanceGroupId}';
    }

    if (a.meterId != null && a.meterId!.isNotEmpty && b.meterId != null && b.meterId!.isNotEmpty) {
      if (_isAncestor(a.meterId!, b.meterId!, parentByMeterId)) {
        return 'hierarchy:${a.meterId}->${b.meterId}';
      }
      if (_isAncestor(b.meterId!, a.meterId!, parentByMeterId)) {
        return 'hierarchy:${b.meterId}->${a.meterId}';
      }
    }

    if (a.balanceGroupId != null && a.balanceGroupId!.isNotEmpty && b.meterId != null && b.meterId!.isNotEmpty) {
      final members = balanceGroupMembers[a.balanceGroupId!] ?? const [];
      if (members.contains(b.meterId)) {
        return 'bg_membership:${a.balanceGroupId}->${b.meterId}';
      }
    }
    if (b.balanceGroupId != null && b.balanceGroupId!.isNotEmpty && a.meterId != null && a.meterId!.isNotEmpty) {
      final members = balanceGroupMembers[b.balanceGroupId!] ?? const [];
      if (members.contains(a.meterId)) {
        return 'bg_membership:${b.balanceGroupId}->${a.meterId}';
      }
    }

    return null;
  }

  static bool _isAncestor(
    String ancestorId,
    String descendantId,
    Map<String, String> parentByMeterId,
  ) {
    String? current = parentByMeterId[descendantId];
    final seen = <String>{};
    while (current != null) {
      if (current == ancestorId) return true;
      if (!seen.add(current)) break;
      current = parentByMeterId[current];
    }
    return false;
  }

  static bool _periodsOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final as = dateOnly(aStart);
    final ae = dateOnly(aEnd);
    final bs = dateOnly(bStart);
    final be = dateOnly(bEnd);
    // Inclusive ranges overlap when startA <= endB && startB <= endA.
    return !as.isAfter(be) && !bs.isAfter(ae);
  }

  static String _iso(DateTime d) {
    final x = dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}
