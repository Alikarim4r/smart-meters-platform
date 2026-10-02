import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/domain/double_count_rules.dart';
import 'package:smart_meters_core/conservation/domain/mv_lifecycle.dart';

void main() {
  group('DoubleCountRules', () {
    final jan1 = DateTime.utc(2025, 1, 1);
    final jan31 = DateTime.utc(2025, 1, 31);
    final feb1 = DateTime.utc(2025, 2, 1);
    final feb28 = DateTime.utc(2025, 2, 28);

    DoubleCountCandidate cand({
      required String id,
      String? meterId,
      String? balanceGroupId,
      DateTime? start,
      DateTime? end,
      MvStatus status = MvStatus.verified,
    }) {
      return DoubleCountCandidate(
        id: id,
        status: status,
        postPeriodStart: start ?? jan1,
        postPeriodEnd: end ?? jan31,
        meterId: meterId,
        balanceGroupId: balanceGroupId,
      );
    }

    test('exact match blocks overlapping verified savings', () {
      final candidates = [
        cand(id: 'c1', meterId: 'm1'),
        cand(id: 'c2', meterId: 'm1'),
      ];

      final overlaps = DoubleCountRules.detectOverlap(candidates);
      expect(overlaps, hasLength(1));
      expect(overlaps.first.scopeKey, 'meter:m1');
    });

    test('disjoint meters remain allowed', () {
      final candidates = [
        cand(id: 'c1', meterId: 'm1'),
        cand(id: 'c2', meterId: 'm2'),
      ];

      final overlaps = DoubleCountRules.detectOverlap(candidates);
      expect(overlaps, isEmpty);
    });

    test('exact balance group overlap blocks overlapping verified savings', () {
      final candidates = [
        cand(id: 'c1', balanceGroupId: 'bg1'),
        cand(id: 'c2', balanceGroupId: 'bg1'),
      ];

      final overlaps = DoubleCountRules.detectOverlap(candidates);
      expect(overlaps, hasLength(1));
      expect(overlaps.first.scopeKey, 'balance_group:bg1');
    });

    test('parent-child hierarchy overlap is blocked', () {
      // m1 is parent of m2, m2 is parent of m3
      final parentByMeterId = {
        'm2': 'm1',
        'm3': 'm2',
      };

      final candidates = [
        cand(id: 'c1', meterId: 'm1'),
        cand(id: 'c2', meterId: 'm3'), // m3 is descendant of m1
      ];

      final overlaps = DoubleCountRules.detectOverlap(
        candidates,
        parentByMeterId: parentByMeterId,
      );

      expect(overlaps, hasLength(1));
      expect(overlaps.first.scopeKey, 'hierarchy:m1->m3');
    });

    test('disjoint meters in hierarchy remain allowed', () {
      // m1 is parent of m2 and m3. m2 and m3 are siblings, so they don't overlap with each other.
      final parentByMeterId = {
        'm2': 'm1',
        'm3': 'm1',
      };

      final candidates = [
        cand(id: 'c1', meterId: 'm2'),
        cand(id: 'c2', meterId: 'm3'),
      ];

      final overlaps = DoubleCountRules.detectOverlap(
        candidates,
        parentByMeterId: parentByMeterId,
      );

      expect(overlaps, isEmpty);
    });

    test('balance-group overlap is blocked where data is available', () {
      final balanceGroupMembers = {
        'bg1': ['m1', 'm2', 'm3'],
      };

      // A candidate on the balance group overlaps with a candidate on one of its members.
      final candidates = [
        cand(id: 'c1', balanceGroupId: 'bg1'),
        cand(id: 'c2', meterId: 'm2'),
      ];

      final overlaps = DoubleCountRules.detectOverlap(
        candidates,
        balanceGroupMembers: balanceGroupMembers,
      );

      expect(overlaps, hasLength(1));
      expect(overlaps.first.scopeKey, 'bg_membership:bg1->m2');
    });

    test('non-overlapping time periods do not block', () {
      final candidates = [
        cand(id: 'c1', meterId: 'm1', start: jan1, end: jan31),
        cand(id: 'c2', meterId: 'm1', start: feb1, end: feb28),
      ];

      final overlaps = DoubleCountRules.detectOverlap(candidates);
      expect(overlaps, isEmpty);
    });
  });
}
