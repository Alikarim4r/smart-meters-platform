import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

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

    test('two balance groups sharing a member meter are blocked', () {
      final overlaps = DoubleCountRules.detectOverlap(
        [
          cand(id: 'c1', balanceGroupId: 'bgA'),
          cand(id: 'c2', balanceGroupId: 'bgB'),
        ],
        balanceGroupMembers: {
          'bgA': ['mainA', 'm5', 'm6'],
          'bgB': ['mainB', 'm5', 'm7'],
        },
      );
      expect(overlaps, hasLength(1));
      expect(overlaps.single.scopeKey, 'bg_shared_member:bgA&bgB:m5');
    });

    test('disjoint balance groups remain allowed', () {
      final overlaps = DoubleCountRules.detectOverlap(
        [
          cand(id: 'c1', balanceGroupId: 'bgA'),
          cand(id: 'c2', balanceGroupId: 'bgB'),
        ],
        balanceGroupMembers: {
          'bgA': ['mainA', 'm5'],
          'bgB': ['mainB', 'm7'],
        },
      );
      expect(overlaps, isEmpty);
    });

    test('balance group member under a separately verified parent meter', () {
      // m1 → m2 (child); bgA covers m2. Saving on m1 already includes m2.
      final overlaps = DoubleCountRules.detectOverlap(
        [
          cand(id: 'c1', meterId: 'm1'),
          cand(id: 'c2', balanceGroupId: 'bgA'),
        ],
        parentByMeterId: {'m2': 'm1'},
        balanceGroupMembers: {
          'bgA': ['m2', 'm9'],
        },
      );
      expect(overlaps, hasLength(1));
      expect(overlaps.single.scopeKey, 'hierarchy:m1->m2');
    });

    test('balance groups whose members are parent/child are blocked', () {
      final overlaps = DoubleCountRules.detectOverlap(
        [
          cand(id: 'c1', balanceGroupId: 'bgA'),
          cand(id: 'c2', balanceGroupId: 'bgB'),
        ],
        parentByMeterId: {'leaf': 'mid', 'mid': 'top'},
        balanceGroupMembers: {
          'bgA': ['top'],
          'bgB': ['leaf'],
        },
      );
      expect(overlaps, hasLength(1));
      expect(overlaps.single.scopeKey, 'hierarchy:top->leaf');
    });

    test('hierarchy cycles terminate', () {
      final overlaps = DoubleCountRules.detectOverlap(
        [
          cand(id: 'c1', meterId: 'a'),
          cand(id: 'c2', meterId: 'z'),
        ],
        parentByMeterId: {'a': 'b', 'b': 'a'},
      );
      expect(overlaps, isEmpty);
    });
  });

  group('DoubleCountTopology.fromSite', () {
    test('groups cover main meter + members; roots/self-parents dropped', () {
      final t = DoubleCountTopology.fromSite(
        parentMeterIdByMeterId: {
          'm1': null,
          'm2': 'm1',
          'm3': '',
          'm4': 'm4',
        },
        mainMeterIdByGroupId: {'bg1': 'main1'},
        memberMeterIdsByGroupId: {
          'bg1': ['x', 'y', 'x'],
          'bg2': ['z'],
        },
      );
      expect(t.parentByMeterId, {'m2': 'm1'});
      expect(
        t.balanceGroupMembers['bg1'],
        unorderedEquals(['main1', 'x', 'y']),
      );
      expect(t.balanceGroupMembers['bg2'], ['z']);
    });
  });

  group('SavingsVerificationService.verify uses real topology', () {
    const svc = SavingsVerificationService();

    MeasurementVerification pending({String? meterId, String? bg}) {
      final draft = MeasurementVerification(
        id: 'new',
        siteId: 'site-1',
        opportunityId: 'opp-1',
        actionId: 'act-1',
        baselineId: 'bl-1',
        meterId: meterId,
        balanceGroupId: bg,
        utilityType: 'water',
        verificationMethod: MvVerificationMethod.baselineComparison,
        calculationVersion: 1,
        prePeriodStart: DateTime(2026, 1, 1),
        prePeriodEnd: DateTime(2026, 1, 31),
        postPeriodStart: DateTime(2026, 2, 1),
        postPeriodEnd: DateTime(2026, 2, 14),
        baselineValue: 100,
        unitCode: 'm3',
        dataCompleteness: 0.95,
        confidenceScore: 85,
        status: MvStatus.draft,
      );
      final estimated = svc.applyEstimation(record: draft, actualPostValue: 70);
      return svc.prepareVerificationPending(estimated);
    }

    VerificationOutcome run(
      MeasurementVerification record,
      List<DoubleCountCandidate> existing,
      DoubleCountTopology topology,
    ) =>
        svc.verify(
          record: record,
          verifiedBy: 'admin-1',
          actorRole: 'site_admin',
          baselineStatus: ConservationBaselineStatus.approved,
          actionStatus: ActionStatus.completed,
          opportunityStatus: OpportunityStatus.monitoring,
          hasPendingCriticalDq: false,
          existingVerified: existing,
          topology: topology,
        );

    final existingOnParent = DoubleCountCandidate(
      id: 'old',
      status: MvStatus.verified,
      postPeriodStart: DateTime(2026, 2, 1),
      postPeriodEnd: DateTime(2026, 2, 28),
      meterId: 'parent',
    );

    test('child meter saving blocked by verified parent saving', () {
      final outcome = run(
        pending(meterId: 'child'),
        [existingOnParent],
        DoubleCountTopology.fromSite(
          parentMeterIdByMeterId: {'child': 'parent'},
          mainMeterIdByGroupId: const {},
          memberMeterIdsByGroupId: const {},
        ),
      );
      expect(outcome.success, isFalse);
      expect(outcome.blockReasons.single, contains('hierarchy:parent->child'));
    });

    test('same inputs without topology would pass (proves wiring matters)', () {
      final outcome = run(
        pending(meterId: 'child'),
        [existingOnParent],
        const DoubleCountTopology(),
      );
      expect(outcome.success, isTrue);
    });

    test('balance-group saving blocked when its main meter is verified', () {
      final outcome = run(
        pending(bg: 'bg1'),
        [existingOnParent],
        DoubleCountTopology.fromSite(
          parentMeterIdByMeterId: const {},
          mainMeterIdByGroupId: {'bg1': 'parent'},
          memberMeterIdsByGroupId: {
            'bg1': ['c1', 'c2'],
          },
        ),
      );
      expect(outcome.success, isFalse);
      expect(
        outcome.blockReasons.single,
        contains('bg_membership:bg1->parent'),
      );
    });
  });
}
