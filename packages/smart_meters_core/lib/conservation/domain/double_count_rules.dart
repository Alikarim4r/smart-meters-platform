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

/// Site topology used by [DoubleCountRules]: meter parent chain plus the
/// meters each balance group covers.
class DoubleCountTopology {
  const DoubleCountTopology({
    this.parentByMeterId = const {},
    this.balanceGroupMembers = const {},
  });

  /// Build from raw site data.
  ///
  /// [parentMeterIdByMeterId]: meter id → `parent_meter_id` (null/empty = root).
  /// [mainMeterIdByGroupId]: balance group id → `main_meter_id`.
  /// [memberMeterIdsByGroupId]: balance group id → member meter ids.
  ///
  /// A group covers its main meter **and** its members — Main − Σ children
  /// is computed from all of them.
  factory DoubleCountTopology.fromSite({
    required Map<String, String?> parentMeterIdByMeterId,
    required Map<String, String> mainMeterIdByGroupId,
    required Map<String, List<String>> memberMeterIdsByGroupId,
  }) {
    final parents = <String, String>{};
    parentMeterIdByMeterId.forEach((meterId, parentId) {
      if (parentId != null && parentId.isNotEmpty && parentId != meterId) {
        parents[meterId] = parentId;
      }
    });

    final covered = <String, Set<String>>{};
    mainMeterIdByGroupId.forEach((groupId, mainId) {
      if (mainId.isNotEmpty) covered.putIfAbsent(groupId, () => {}).add(mainId);
    });
    memberMeterIdsByGroupId.forEach((groupId, ids) {
      final set = covered.putIfAbsent(groupId, () => {});
      for (final id in ids) {
        if (id.isNotEmpty) set.add(id);
      }
    });
    final members = <String, List<String>>{
      for (final e in covered.entries) e.key: e.value.toList(),
    };
    return DoubleCountTopology(
      parentByMeterId: parents,
      balanceGroupMembers: members,
    );
  }

  final Map<String, String> parentByMeterId;
  final Map<String, List<String>> balanceGroupMembers;
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
    final aMeter = _nonEmpty(a.meterId);
    final bMeter = _nonEmpty(b.meterId);
    final aGroup = _nonEmpty(a.balanceGroupId);
    final bGroup = _nonEmpty(b.balanceGroupId);

    if (aMeter != null && aMeter == bMeter) return 'meter:$aMeter';
    if (aGroup != null && aGroup == bGroup) return 'balance_group:$aGroup';

    // Each candidate covers its own meter plus every meter of its balance
    // group (main + members). Two candidates double-count when any covered
    // meters coincide or sit on the same parent/child chain.
    final aCovered = _covered(aMeter, aGroup, balanceGroupMembers);
    final bCovered = _covered(bMeter, bGroup, balanceGroupMembers);

    for (final x in aCovered.entries) {
      for (final y in bCovered.entries) {
        if (x.key == y.key) {
          if (x.value != null && y.value != null) {
            return 'bg_shared_member:${x.value}&${y.value}:${x.key}';
          }
          final group = x.value ?? y.value;
          if (group != null) return 'bg_membership:$group->${x.key}';
          return 'meter:${x.key}';
        }
        if (_isAncestor(x.key, y.key, parentByMeterId)) {
          return 'hierarchy:${x.key}->${y.key}';
        }
        if (_isAncestor(y.key, x.key, parentByMeterId)) {
          return 'hierarchy:${y.key}->${x.key}';
        }
      }
    }
    return null;
  }

  /// Covered meter id → balance group it came from (`null` = direct meter).
  static Map<String, String?> _covered(
    String? meterId,
    String? groupId,
    Map<String, List<String>> balanceGroupMembers,
  ) {
    final out = <String, String?>{};
    if (meterId != null) out[meterId] = null;
    if (groupId != null) {
      for (final m in balanceGroupMembers[groupId] ?? const <String>[]) {
        if (m.isNotEmpty) out.putIfAbsent(m, () => groupId);
      }
    }
    return out;
  }

  static String? _nonEmpty(String? v) => v == null || v.isEmpty ? null : v;

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
