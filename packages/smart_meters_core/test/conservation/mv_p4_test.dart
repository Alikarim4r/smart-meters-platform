import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

MeasurementVerification draftMv({
  String id = 'mv-1',
  String meterId = 'm1',
  String? balanceGroupId,
  double baselineValue = 100,
  double? actualPost,
  double? estimated,
  MvStatus status = MvStatus.draft,
  double completeness = 0.95,
  int confidence = 85,
  DateTime? postStart,
  DateTime? postEnd,
  String baselineId = 'bl-bound-v1',
  int version = 1,
}) {
  return MeasurementVerification(
    id: id,
    siteId: 'site-1',
    opportunityId: 'opp-1',
    actionId: 'act-1',
    baselineId: baselineId,
    meterId: meterId,
    balanceGroupId: balanceGroupId,
    utilityType: 'water',
    verificationMethod: MvVerificationMethod.baselineComparison,
    calculationVersion: version,
    prePeriodStart: DateTime(2026, 1, 1),
    prePeriodEnd: DateTime(2026, 1, 31),
    postPeriodStart: postStart ?? DateTime(2026, 2, 1),
    postPeriodEnd: postEnd ?? DateTime(2026, 2, 14),
    baselineValue: baselineValue,
    actualPostValue: actualPost,
    estimatedSavingQuantity: estimated,
    unitCode: 'm3',
    dataCompleteness: completeness,
    confidenceScore: confidence,
    status: status,
  );
}

UtilityTariff qarTariff({double rate = 5.0}) {
  return UtilityTariff(
    id: 'tar-1',
    organizationId: 'org-1',
    siteId: 'site-1',
    utilityType: 'water',
    rate: rate,
    currency: 'QAR',
    unitCode: 'm3',
    effectiveFrom: DateTime(2025, 1, 1),
    status: UtilityTariffStatus.active,
  );
}

void main() {
  const estimation = SavingsEstimationService();
  const verification = SavingsVerificationService();
  const costRoi = CostRoiService();
  const tariffLookup = TariffLookupService();

  group('Estimated Saving', () {
    test('positive delta → Estimated Saving (not Potential Excess)', () {
      final r = estimation.estimate(
        baselineValue: 100,
        actualPostValue: 70,
        prePeriodStart: DateTime(2026, 1, 1),
        prePeriodEnd: DateTime(2026, 1, 31),
        postPeriodStart: DateTime(2026, 2, 1),
        postPeriodEnd: DateTime(2026, 2, 14),
        unitCode: 'm3',
        dataCompleteness: 1,
        confidenceScore: 90,
      );
      expect(r.canEstimate, isTrue);
      expect(r.estimatedSavingQuantity, 30);
      expect(r.displayLabel, ConservationSavingLabels.estimatedSaving);
      expect(r.displayLabel, isNot(ConservationSavingLabels.potentialExcess));
      expect(r.notes, contains('not_potential_excess'));
      expect(r.notes, contains('not_verified_saving'));
    });

    test('uses adjusted baseline when provided', () {
      final r = estimation.estimate(
        baselineValue: 100,
        adjustedBaselineValue: 110,
        actualPostValue: 90,
        prePeriodStart: DateTime(2026, 1, 1),
        prePeriodEnd: DateTime(2026, 1, 31),
        postPeriodStart: DateTime(2026, 2, 1),
        postPeriodEnd: DateTime(2026, 2, 14),
        unitCode: 'm3',
      );
      expect(r.referenceValue, 110);
      expect(r.estimatedSavingQuantity, 20);
    });

    test('insufficient post data → cannot estimate', () {
      final r = estimation.estimate(
        baselineValue: 100,
        actualPostValue: null,
        prePeriodStart: DateTime(2026, 1, 1),
        prePeriodEnd: DateTime(2026, 1, 31),
        postPeriodStart: DateTime(2026, 2, 1),
        postPeriodEnd: DateTime(2026, 2, 14),
        unitCode: 'm3',
      );
      expect(r.canEstimate, isFalse);
      expect(r.estimatedSavingQuantity, isNull);
      expect(r.notes, contains('insufficient_post_value'));
    });

    test('negative outcome stores signed delta (increased consumption)', () {
      final r = estimation.estimate(
        baselineValue: 100,
        actualPostValue: 130,
        prePeriodStart: DateTime(2026, 1, 1),
        prePeriodEnd: DateTime(2026, 1, 31),
        postPeriodStart: DateTime(2026, 2, 1),
        postPeriodEnd: DateTime(2026, 2, 14),
        unitCode: 'm3',
      );
      expect(r.estimatedSavingQuantity, -30);
      expect(r.isIncreasedConsumption, isTrue);
      expect(
        r.displayLabel,
        ConservationSavingLabels.noSavingIncreasedConsumption,
      );
      expect(r.performanceChange, closeTo(30, 1e-9));
    });

    test('zero estimated saving allowed', () {
      final r = estimation.estimate(
        baselineValue: 50,
        actualPostValue: 50,
        prePeriodStart: DateTime(2026, 1, 1),
        prePeriodEnd: DateTime(2026, 1, 31),
        postPeriodStart: DateTime(2026, 2, 1),
        postPeriodEnd: DateTime(2026, 2, 14),
        unitCode: 'm3',
      );
      expect(r.estimatedSavingQuantity, 0);
      expect(r.isZeroSaving, isTrue);
    });
  });

  group('MvLifecycle', () {
    test('draft → verified blocked', () {
      expect(
        MvLifecycle.canTransition(MvStatus.draft, MvStatus.verified),
        isFalse,
      );
      expect(
        () => MvLifecycle.assertCanTransition(
          MvStatus.draft,
          MvStatus.verified,
        ),
        throwsStateError,
      );
    });

    test('verified only from verification_pending', () {
      expect(
        MvLifecycle.canTransition(
          MvStatus.verificationPending,
          MvStatus.verified,
        ),
        isTrue,
      );
      expect(
        MvLifecycle.canTransition(MvStatus.estimated, MvStatus.verified),
        isFalse,
      );
    });

    test('happy path transitions', () {
      expect(
        MvLifecycle.canTransition(MvStatus.draft, MvStatus.estimated),
        isTrue,
      );
      expect(
        MvLifecycle.canTransition(
          MvStatus.estimated,
          MvStatus.verificationPending,
        ),
        isTrue,
      );
    });
  });

  group('SavingsVerificationGates', () {
    test('happy path passes', () {
      final g = verification.evaluateGates(
        currentStatus: MvStatus.verificationPending,
        dataCompleteness: 0.9,
        confidenceScore: 80,
        followUpDays: 14,
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.monitoring,
        hasPendingCriticalDq: false,
        verifiedBy: 'admin-1',
        actorRole: 'site_admin',
      );
      expect(g.passed, isTrue);
      expect(g.reasons, isEmpty);
    });

    test('insufficient completeness fails', () {
      final g = verification.evaluateGates(
        currentStatus: MvStatus.verificationPending,
        dataCompleteness: 0.5,
        confidenceScore: 80,
        followUpDays: 14,
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.resolved,
        hasPendingCriticalDq: false,
        verifiedBy: 'admin-1',
        actorRole: 'site_admin',
      );
      expect(g.passed, isFalse);
      expect(g.reasons.any((r) => r.contains('Completeness')), isTrue);
    });

    test('low confidence fails', () {
      final g = verification.evaluateGates(
        currentStatus: MvStatus.verificationPending,
        dataCompleteness: 0.9,
        confidenceScore: 40,
        followUpDays: 14,
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.monitoring,
        hasPendingCriticalDq: false,
        verifiedBy: 'admin-1',
        actorRole: 'super_admin',
      );
      expect(g.passed, isFalse);
      expect(g.reasons.any((r) => r.contains('Confidence')), isTrue);
    });

    test('unapproved baseline fails', () {
      final g = verification.evaluateGates(
        currentStatus: MvStatus.verificationPending,
        dataCompleteness: 0.9,
        confidenceScore: 80,
        followUpDays: 14,
        baselineStatus: ConservationBaselineStatus.draft,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.monitoring,
        hasPendingCriticalDq: false,
        verifiedBy: 'admin-1',
        actorRole: 'site_admin',
      );
      expect(g.passed, isFalse);
      expect(g.reasons.any((r) => r.toLowerCase().contains('baseline')), isTrue);
    });

    test('action not completed fails', () {
      final g = verification.evaluateGates(
        currentStatus: MvStatus.verificationPending,
        dataCompleteness: 0.9,
        confidenceScore: 80,
        followUpDays: 14,
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.inProgress,
        opportunityStatus: OpportunityStatus.monitoring,
        hasPendingCriticalDq: false,
        verifiedBy: 'admin-1',
        actorRole: 'site_admin',
      );
      expect(g.passed, isFalse);
      expect(g.reasons.any((r) => r.contains('Action')), isTrue);
    });
  });

  group('verify happy path / outcomes', () {
    test('verified happy path with positive saving', () {
      var record = draftMv(actualPost: 70, status: MvStatus.draft);
      record = verification.applyEstimation(record: record, actualPostValue: 70);
      record = verification.prepareVerificationPending(record);
      final outcome = verification.verify(
        record: record,
        verifiedBy: 'admin-1',
        actorRole: 'site_admin',
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.monitoring,
        hasPendingCriticalDq: false,
        tariff: qarTariff(),
      );
      expect(outcome.success, isTrue);
      expect(outcome.record!.status, MvStatus.verified);
      expect(outcome.record!.verifiedSavingQuantity, 30);
      expect(outcome.record!.estimatedSavingQuantity, 30);
      expect(outcome.record!.baselineId, 'bl-bound-v1');
      expect(outcome.costRoi!.costAvoided, 150); // 30 * 5
      expect(outcome.costRoi!.costCurrency, 'QAR');
    });

    test('negative outcome → verified saving 0 (no positive claim)', () {
      var record = draftMv(actualPost: 130, status: MvStatus.draft);
      record =
          verification.applyEstimation(record: record, actualPostValue: 130);
      expect(record.estimatedSavingQuantity, -30);
      record = verification.prepareVerificationPending(record);
      final outcome = verification.verify(
        record: record,
        verifiedBy: 'admin-1',
        actorRole: 'platform_owner',
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.resolved,
        hasPendingCriticalDq: false,
        tariff: qarTariff(),
      );
      expect(outcome.success, isTrue);
      expect(outcome.record!.verifiedSavingQuantity, 0);
      expect(outcome.costRoi!.costAvoidedIsNa, isTrue);
    });

    test('zero estimated → zero verified allowed', () {
      var record = draftMv(actualPost: 100, status: MvStatus.draft);
      record =
          verification.applyEstimation(record: record, actualPostValue: 100);
      record = verification.prepareVerificationPending(record);
      final outcome = verification.verify(
        record: record,
        verifiedBy: 'admin-1',
        actorRole: 'site_admin',
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.monitoring,
        hasPendingCriticalDq: false,
      );
      expect(outcome.success, isTrue);
      expect(outcome.record!.verifiedSavingQuantity, 0);
    });

    test('draft → verified blocked via apply path', () {
      final draft = draftMv(actualPost: 70, estimated: 30);
      expect(
        () => verification.verify(
          record: draft,
          verifiedBy: 'admin-1',
          actorRole: 'site_admin',
          baselineStatus: ConservationBaselineStatus.approved,
          actionStatus: ActionStatus.completed,
          opportunityStatus: OpportunityStatus.monitoring,
          hasPendingCriticalDq: false,
        ),
        // gates fail first (not verification_pending) → blocked outcome
        returnsNormally,
      );
      final blocked = verification.verify(
        record: draft,
        verifiedBy: 'admin-1',
        actorRole: 'site_admin',
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.monitoring,
        hasPendingCriticalDq: false,
      );
      expect(blocked.success, isFalse);
      expect(
        blocked.blockReasons.any((r) => r.contains('draft')),
        isTrue,
      );
    });
  });

  group('authority policy', () {
    test('technician cannot verify', () {
      expect(ConservationAuthorityPolicy.canVerifySaving('technician'), isFalse);
      expect(ConservationAuthorityPolicy.canVerifySaving('site_admin'), isTrue);
      expect(
        () => ConservationAuthorityPolicy.assertCanVerify('technician'),
        throwsStateError,
      );

      var record = draftMv(actualPost: 70);
      record =
          verification.applyEstimation(record: record, actualPostValue: 70);
      record = verification.prepareVerificationPending(record);
      expect(
        () => verification.verify(
          record: record,
          verifiedBy: 'tech-1',
          actorRole: 'technician',
          baselineStatus: ConservationBaselineStatus.approved,
          actionStatus: ActionStatus.completed,
          opportunityStatus: OpportunityStatus.monitoring,
          hasPendingCriticalDq: false,
        ),
        throwsStateError,
      );
    });

    test('technician cannot confirm cause (policy helper)', () {
      expect(
        ConservationAuthorityPolicy.canConfirmCause('technician'),
        isFalse,
      );
      expect(
        () => ConservationAuthorityPolicy.assertCanConfirmCause('viewer'),
        throwsStateError,
      );
    });
  });

  group('Cost / ROI', () {
    test('missing tariff → Cost Avoided N/A (not 0)', () {
      final r = costRoi.compute(
        verifiedSavingQuantity: 30,
        tariff: null,
        postPeriodStart: DateTime(2026, 2, 1),
        postPeriodEnd: DateTime(2026, 2, 14),
      );
      expect(r.costAvoided, isNull);
      expect(r.displayCostAvoided, ConservationSavingLabels.costAvoidedNa);
      expect(r.costAvoided, isNot(0));
    });

    test('QAR cost avoided = verified × rate', () {
      final r = costRoi.compute(
        verifiedSavingQuantity: 20,
        tariff: qarTariff(rate: 4.5),
        postPeriodStart: DateTime(2026, 2, 1),
        postPeriodEnd: DateTime(2026, 2, 14), // 14 days
      );
      expect(r.costAvoided, closeTo(90, 1e-9));
      expect(r.costCurrency, 'QAR');
      expect(r.notes, contains('qar_no_fx'));
      // annualized = 90 * (365/14)
      expect(r.annualizedValue, closeTo(90 * (365 / 14), 1e-6));
    });

    test('ROI and payback when cost present', () {
      final r = costRoi.compute(
        verifiedSavingQuantity: 30,
        tariff: qarTariff(rate: 5),
        postPeriodStart: DateTime(2026, 1, 1),
        postPeriodEnd: DateTime(2026, 12, 31), // ~365 days
        implementationCost: 100,
        implementationCostCurrency: 'QAR',
      );
      expect(r.costAvoided, 150);
      expect(r.annualizedValue, isNotNull);
      expect(r.simpleRoi, isNotNull);
      expect(r.simplePaybackMonths, isNotNull);
      // annualized ≈ 150 for ~365-day window
      expect(r.simpleRoi!, closeTo((150 - 100) / 100, 0.05));
      expect(r.simplePaybackMonths!, greaterThan(0));
    });

    test('missing implementation cost → ROI/payback N/A', () {
      final r = costRoi.compute(
        verifiedSavingQuantity: 30,
        tariff: qarTariff(),
        postPeriodStart: DateTime(2026, 2, 1),
        postPeriodEnd: DateTime(2026, 2, 14),
      );
      expect(r.roiIsNa, isTrue);
      expect(r.paybackIsNa, isTrue);
    });
  });

  group('TariffLookupService', () {
    test('prefers site-specific over org-wide', () {
      final orgWide = UtilityTariff(
        id: 't-org',
        organizationId: 'org-1',
        utilityType: 'water',
        rate: 3,
        currency: 'QAR',
        unitCode: 'm3',
        effectiveFrom: DateTime(2025, 1, 1),
        status: UtilityTariffStatus.active,
      );
      final site = UtilityTariff(
        id: 't-site',
        organizationId: 'org-1',
        siteId: 'site-1',
        utilityType: 'water',
        rate: 5,
        currency: 'QAR',
        unitCode: 'm3',
        effectiveFrom: DateTime(2025, 6, 1),
        status: UtilityTariffStatus.active,
      );
      final found = tariffLookup.resolve(
        candidates: [orgWide, site],
        organizationId: 'org-1',
        utilityType: 'water',
        onDate: DateTime(2026, 2, 1),
        siteId: 'site-1',
      );
      expect(found!.id, 't-site');
    });

    test('no match → null (N/A path)', () {
      final found = tariffLookup.resolve(
        candidates: const [],
        organizationId: 'org-1',
        utilityType: 'electricity',
        onDate: DateTime(2026, 2, 1),
      );
      expect(found, isNull);
    });
  });

  group('DoubleCountRules', () {
    test('detects overlapping verified same meter', () {
      final overlaps = DoubleCountRules.detectOverlap([
        DoubleCountCandidate(
          id: 'a',
          status: MvStatus.verified,
          postPeriodStart: DateTime(2026, 2, 1),
          postPeriodEnd: DateTime(2026, 2, 14),
          meterId: 'm1',
        ),
        DoubleCountCandidate(
          id: 'b',
          status: MvStatus.verified,
          postPeriodStart: DateTime(2026, 2, 10),
          postPeriodEnd: DateTime(2026, 2, 28),
          meterId: 'm1',
        ),
      ]);
      expect(overlaps, hasLength(1));
      expect(overlaps.single.scopeKey, 'meter:m1');
    });

    test('superseded does not double-count', () {
      final overlaps = DoubleCountRules.detectOverlap([
        DoubleCountCandidate(
          id: 'a',
          status: MvStatus.superseded,
          postPeriodStart: DateTime(2026, 2, 1),
          postPeriodEnd: DateTime(2026, 2, 14),
          meterId: 'm1',
        ),
        DoubleCountCandidate(
          id: 'b',
          status: MvStatus.verified,
          postPeriodStart: DateTime(2026, 2, 1),
          postPeriodEnd: DateTime(2026, 2, 14),
          meterId: 'm1',
        ),
      ]);
      expect(overlaps, isEmpty);
    });

    test('verify blocks on overlap', () {
      var record = draftMv(id: 'new', actualPost: 70);
      record =
          verification.applyEstimation(record: record, actualPostValue: 70);
      record = verification.prepareVerificationPending(record);
      final outcome = verification.verify(
        record: record,
        verifiedBy: 'admin-1',
        actorRole: 'site_admin',
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.monitoring,
        hasPendingCriticalDq: false,
        existingVerified: [
          DoubleCountCandidate(
            id: 'old',
            status: MvStatus.verified,
            postPeriodStart: DateTime(2026, 2, 1),
            postPeriodEnd: DateTime(2026, 2, 20),
            meterId: 'm1',
          ),
        ],
      );
      expect(outcome.success, isFalse);
      expect(
        outcome.blockReasons.any((r) => r.contains('Double-count')),
        isTrue,
      );
    });
  });

  group('recalculation versioning', () {
    test('supersedes old and creates V+1 draft with same baseline bind', () {
      var record = draftMv(actualPost: 70, version: 1);
      record =
          verification.applyEstimation(record: record, actualPostValue: 70);
      record = verification.prepareVerificationPending(record);
      final verified = verification.verify(
        record: record,
        verifiedBy: 'admin-1',
        actorRole: 'site_admin',
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.monitoring,
        hasPendingCriticalDq: false,
      );
      expect(verified.success, isTrue);

      final versioning = verification.recalculateAsNewVersion(
        old: verified.record!,
        newActualPostValue: 65,
      );
      expect(versioning.superseded.status, MvStatus.superseded);
      expect(versioning.superseded.verifiedSavingQuantity, 30);
      expect(versioning.nextDraft.status, MvStatus.draft);
      expect(versioning.nextDraft.calculationVersion, 2);
      expect(versioning.nextDraft.supersedesId, verified.record!.id);
      expect(versioning.nextDraft.baselineId, 'bl-bound-v1');
      expect(versioning.nextDraft.verifiedSavingQuantity, isNull);
    });
  });

  group('terminology', () {
    test('Potential Excess is never called Saving', () {
      expect(
        ConservationSavingLabels.potentialExcess
            .toLowerCase()
            .contains('saving'),
        isFalse,
      );
      expect(
        ConservationSavingLabels.estimatedSaving,
        isNot(ConservationSavingLabels.potentialExcess),
      );
      expect(
        ConservationSavingLabels.verifiedSaving,
        isNot(ConservationSavingLabels.potentialExcess),
      );
      for (final forbidden in ConservationSavingLabels.forbiddenAsSaving) {
        expect(
          ConservationSavingLabels.estimatedSaving,
          isNot(forbidden),
        );
        expect(
          ConservationSavingLabels.verifiedSaving,
          isNot(forbidden),
        );
      }
    });

    test('opportunity Potential Excess label distinct from Estimated Saving', () {
      expect(
        ConservationOpportunityLabels.potentialExcess,
        ConservationSavingLabels.potentialExcess,
      );
      expect(
        ConservationOpportunityLabels.potentialExcess,
        isNot(ConservationSavingLabels.estimatedSaving),
      );
    });
  });

  group('feature flags Phase 4', () {
    test('P4 keys present in all', () {
      expect(
        ConservationFeatureFlags.savingsEstimation,
        'savings_estimation',
      );
      expect(
        ConservationFeatureFlags.savingsVerification,
        'savings_verification',
      );
      expect(ConservationFeatureFlags.costRoi, 'cost_roi');
      expect(
        ConservationFeatureFlags.conservationReports,
        'conservation_reports',
      );
      expect(
        ConservationFeatureFlags.all,
        containsAll([
          ConservationFeatureFlags.savingsEstimation,
          ConservationFeatureFlags.savingsVerification,
          ConservationFeatureFlags.costRoi,
          ConservationFeatureFlags.conservationReports,
        ]),
      );
    });
  });

  group('proposed_cause model', () {
    test('fromJson includes proposed_cause without confirmed', () {
      final inv = ConservationInvestigation.fromJson({
        'id': 'inv-1',
        'opportunity_id': 'opp-1',
        'site_id': 'site-1',
        'investigation_status': 'in_progress',
        'proposed_cause': 'possible pipe leak near zone A',
        'confirmed_cause': null,
      });
      expect(inv.proposedCause, 'possible pipe leak near zone A');
      expect(inv.confirmedCause, isNull);
    });

    test('action cost fields round-trip', () {
      final action = ConservationAction.fromJson({
        'id': 'a1',
        'opportunity_id': 'o1',
        'site_id': 's1',
        'title': 'Fix leak',
        'description': '',
        'action_type': 'repair_leak',
        'priority': 'high',
        'status': 'completed',
        'implementation_cost': 2500.5,
        'cost_currency': 'QAR',
        'cost_source': 'invoice',
        'cost_approved': true,
      });
      expect(action.implementationCost, 2500.5);
      expect(action.costCurrency, 'QAR');
      expect(action.costApproved, isTrue);
      expect(action.toJson()['implementation_cost'], 2500.5);
    });
  });

  group('reject', () {
    test('reject from verification_pending', () {
      var record = draftMv(actualPost: 70);
      record =
          verification.applyEstimation(record: record, actualPostValue: 70);
      record = verification.prepareVerificationPending(record);
      final rejected = verification.reject(
        record: record,
        rejectedBy: 'admin-1',
        actorRole: 'site_admin',
        rejectionReason: 'insufficient evidence',
      );
      expect(rejected.status, MvStatus.rejected);
      expect(rejected.rejectionReason, 'insufficient evidence');
    });
  });
}
