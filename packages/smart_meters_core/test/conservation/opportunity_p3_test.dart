import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

void main() {
  final start = DateTime(2026, 7, 1);
  final end = DateTime(2026, 7, 31);
  const engine = OpportunityEngine();
  const siteId = 'site-1';

  group('fingerprint', () {
    test('stability — same inputs yield same fingerprint', () {
      final a = buildOpportunityFingerprint(
        siteId: siteId,
        sourceType: 'periodic_anomaly',
        sourceEntityKey: 'unusualIncrease:m1',
        periodStart: start,
        periodEnd: end,
        ruleVersion: 'conservation_opportunity_v1',
      );
      final b = buildOpportunityFingerprint(
        siteId: siteId,
        sourceType: 'periodic_anomaly',
        sourceEntityKey: 'unusualIncrease:m1',
        periodStart: DateTime(2026, 7, 1, 15),
        periodEnd: DateTime(2026, 7, 31, 23),
        ruleVersion: 'conservation_opportunity_v1',
      );
      expect(a, b);
      expect(
        a,
        'site-1|periodic_anomaly|unusualIncrease:m1|2026-07-01|2026-07-31|conservation_opportunity_v1',
      );
    });

    test('different entity or period → different fingerprint', () {
      final a = buildOpportunityFingerprint(
        siteId: siteId,
        sourceType: 'balance_difference',
        sourceEntityKey: 'bg-1',
        periodStart: start,
        periodEnd: end,
        ruleVersion: 'v1',
      );
      final b = buildOpportunityFingerprint(
        siteId: siteId,
        sourceType: 'balance_difference',
        sourceEntityKey: 'bg-2',
        periodStart: start,
        periodEnd: end,
        ruleVersion: 'v1',
      );
      expect(a, isNot(b));
    });
  });

  group('OpportunityEngine', () {
    test('anomaly → candidate with potential excess (not Saving)', () {
      final anomaly = ConsumptionAnomalyResult(
        detected: true,
        kind: AnomalyKind.unusualIncrease,
        severity: AnomalySeverity.high,
        statusLabel: ConsumptionAnomalyResult.unusualConsumption,
        reason: 'Increase > 25% vs previous period',
        confidenceScore: 85,
        completeness: 1,
        periodStart: start,
        periodEnd: end,
        referenceMethod: 'previous_period',
        contributingMeterIds: const ['m1'],
        warnings: const [],
        currentValue: 130,
        referenceValue: 100,
        percentageChange: 30,
        investigationNotes: const ['Review operational changes'],
      );

      final candidates = engine.buildCandidatesFromSignals(
        siteId: siteId,
        utilityType: 'water',
        anomalies: [anomaly],
      );

      expect(candidates, hasLength(1));
      final c = candidates.single;
      expect(c.sourceType, OpportunitySourceType.periodicAnomaly);
      expect(c.estimatedWasteQuantity, closeTo(30, 1e-9));
      expect(c.sourceFingerprint, contains('periodic_anomaly'));
      expect(c.title.toLowerCase(), isNot(contains('saving')));
      expect(c.description.toLowerCase(), isNot(contains('verified saving')));
      expect(
        c.sourceSnapshot['quantity_label'],
        ConservationOpportunityLabels.potentialExcess,
      );
      expect(c.possibleCauses, isNotEmpty);
      expect(c.suggestedInvestigations, isNotEmpty);
    });

    test('balance → candidate when Requires Review or |pct| >= 5', () {
      final balance = BalanceResult(
        calculationMethod: BalanceResult.method,
        periodStart: start,
        periodEnd: end,
        mainMeterId: 'main',
        childMeterIds: const ['c1'],
        mainConsumption: 100,
        childrenConsumption: 70,
        balanceDifference: 30,
        balancePercentage: 30,
        dataCompleteness: 1,
        confidenceScore: 80,
        alignmentStatus: ReadingAlignmentStatus.aligned,
        missingMeterIds: const [],
        calculatedAt: DateTime.utc(2026, 7, 31),
        warnings: const [],
        utilityCode: 'water',
        unitCode: 'm3',
        status: BalanceResultStatus.ok,
        reviewStatus: 'Requires Review',
        directionLabel: 'Unaccounted Consumption',
        isNegative: false,
        balanceGroupId: 'bg-1',
      );

      final candidates = engine.buildCandidatesFromSignals(
        siteId: siteId,
        utilityType: 'water',
        balances: [balance],
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.sourceType, OpportunitySourceType.balanceDifference);
      expect(candidates.single.estimatedWasteQuantity, closeTo(30, 1e-9));
      expect(candidates.single.balanceGroupId, 'bg-1');
    });

    test('balance insufficient / low pct without review → no candidate', () {
      final okLow = BalanceResult(
        calculationMethod: BalanceResult.method,
        periodStart: start,
        periodEnd: end,
        mainMeterId: 'main',
        childMeterIds: const ['c1'],
        mainConsumption: 100,
        childrenConsumption: 98,
        balanceDifference: 2,
        balancePercentage: 2,
        dataCompleteness: 1,
        confidenceScore: 90,
        alignmentStatus: ReadingAlignmentStatus.aligned,
        missingMeterIds: const [],
        calculatedAt: DateTime.utc(2026, 7, 31),
        warnings: const [],
        utilityCode: 'water',
        unitCode: 'm3',
        status: BalanceResultStatus.ok,
        reviewStatus: 'OK',
        directionLabel: 'Balance Difference',
        isNegative: false,
      );
      expect(
        engine.buildCandidatesFromSignals(
          siteId: siteId,
          utilityType: 'water',
          balances: [okLow],
        ),
        isEmpty,
      );
    });

    test('DQ missing photo / reading requires review excluded', () {
      final findings = [
        const DataQualityFinding(
          code: DataQualityFindingCode.missingRequiredPhoto,
          severity: DataQualitySeverity.warning,
          title: 'Missing Required Photo',
          detail: 'no photo',
        ),
        const DataQualityFinding(
          code: DataQualityFindingCode.readingRequiresReview,
          severity: DataQualitySeverity.warning,
          title: 'Reading Requires Review',
          detail: 'lower than previous',
        ),
      ];
      for (final f in findings) {
        expect(OpportunitySignalRules.isDataQualityOnly(f), isTrue);
        expect(
          OpportunitySignalRules.dataQualityFindingQualifiesAsOpportunity(f),
          isFalse,
        );
      }
      final candidates = engine.buildCandidatesFromSignals(
        siteId: siteId,
        utilityType: 'water',
        dataQualityFindings: findings,
      );
      expect(candidates, isEmpty);
    });

    test('unusualDecrease / repeatedLow do not qualify', () {
      for (final kind in [AnomalyKind.unusualDecrease, AnomalyKind.repeatedLow]) {
        final a = ConsumptionAnomalyResult(
          detected: true,
          kind: kind,
          severity: AnomalySeverity.high,
          statusLabel: ConsumptionAnomalyResult.unusualConsumption,
          reason: 'x',
          confidenceScore: 90,
          completeness: 1,
          periodStart: start,
          periodEnd: end,
          referenceMethod: 'prev',
          contributingMeterIds: const ['m1'],
          warnings: const [],
        );
        expect(OpportunitySignalRules.anomalyQualifies(a), isFalse);
      }
    });

    test('suddenChange only high/critical', () {
      expect(
        OpportunitySignalRules.anomalyKindQualifies(
          AnomalyKind.suddenChange,
          severity: AnomalySeverity.medium,
        ),
        isFalse,
      );
      expect(
        OpportunitySignalRules.anomalyKindQualifies(
          AnomalyKind.suddenChange,
          severity: AnomalySeverity.high,
        ),
        isTrue,
      );
    });

    test('actual vs target / baseline above with significant pct', () {
      final meta = CalculationMeta(
        calculationMethod: 'test',
        periodStart: start,
        periodEnd: end,
        dataCompleteness: 1,
        confidenceScore: 80,
        calculatedAt: DateTime.utc(2026, 7, 31),
      );
      final avt = ActualVsTargetResult(
        status: ActualVsTargetStatus.ok,
        standing: ActualVsTargetStanding.aboveTarget,
        comparisonMode: ActualVsTargetComparisonMode.fullPeriod,
        actualValue: 120,
        targetValue: 100,
        effectiveTargetValue: 100,
        absoluteDifference: 20,
        percentageOfTarget: 120,
        directionLabel: 'Above Target',
        unitCode: 'm3',
        completeness: 1,
        confidenceScore: 80,
        periodStart: start,
        periodEnd: end,
        analysisAsOf: end,
        targetVersion: 1,
        targetId: 't1',
        periodType: ConservationTargetPeriodType.monthly,
        calculationMethod: 'test',
        calculatedAt: DateTime.utc(2026, 7, 31),
        meta: meta,
      );
      final avb = ActualVsBaselineResult(
        status: ActualVsBaselineStatus.ok,
        standing: ActualVsBaselineStanding.aboveBaseline,
        actualValue: 120,
        baselineValue: 100,
        absoluteVariance: 20,
        percentageVariance: 20,
        directionLabel: 'Above Baseline',
        unitCode: 'm3',
        completeness: 1,
        confidenceScore: 80,
        actualCompleteness: 1,
        actualConfidence: 80,
        baselineCompleteness: 1,
        baselineConfidence: 80,
        periodStart: start,
        periodEnd: end,
        analysisAsOf: end,
        baselineVersion: 1,
        baselineId: 'b1',
        calculationMethod: BaselineCalculationMethod.totalPeriod,
        calculatedAt: DateTime.utc(2026, 7, 31),
        meta: meta,
      );

      final candidates = engine.buildCandidatesFromSignals(
        siteId: siteId,
        utilityType: 'water',
        actualVsTargets: [avt],
        actualVsBaselines: [avb],
      );
      expect(candidates, hasLength(2));
      expect(
        candidates.every(
          (c) =>
              c.title.contains('Potential Excess') ||
              c.description.contains('Potential Excess') ||
              c.description.contains('Quantity at risk') ||
              c.sourceSnapshot['quantity_label'] ==
                  ConservationOpportunityLabels.potentialExcess,
        ),
        isTrue,
      );
      for (final c in candidates) {
        expect(c.title.toLowerCase(), isNot(contains('saving')));
      }
    });
  });

  group('OpportunityGenerationService dedupe', () {
    test('duplicate fingerprint same open → refresh not duplicate', () async {
      final store = _FakeOpportunityStore();
      final service = OpportunityGenerationService(repository: store);

      final anomaly = ConsumptionAnomalyResult(
        detected: true,
        kind: AnomalyKind.repeatedHigh,
        severity: AnomalySeverity.medium,
        statusLabel: ConsumptionAnomalyResult.unusualConsumption,
        reason: 'repeated high',
        confidenceScore: 70,
        completeness: 1,
        periodStart: start,
        periodEnd: end,
        referenceMethod: 'multi',
        contributingMeterIds: const ['m1'],
        warnings: const [],
        currentValue: 150,
        referenceValue: 100,
        percentageChange: 50,
      );
      final candidates = engine.buildCandidatesFromSignals(
        siteId: siteId,
        utilityType: 'electricity',
        anomalies: [anomaly],
      );
      expect(candidates, hasLength(1));

      final first = await service.refreshForSite(
        siteId: siteId,
        periodStart: start,
        periodEnd: end,
        candidates: candidates,
      );
      expect(first.created, 1);
      expect(first.refreshed, 0);
      expect(store.rows, hasLength(1));

      final bumped = OpportunityCandidate(
        siteId: candidates.single.siteId,
        sourceType: candidates.single.sourceType,
        sourceFingerprint: candidates.single.sourceFingerprint,
        title: candidates.single.title,
        description: 'refreshed description',
        utilityType: candidates.single.utilityType,
        detectedPeriodStart: candidates.single.detectedPeriodStart,
        detectedPeriodEnd: candidates.single.detectedPeriodEnd,
        confidenceScore: 75,
        priority: candidates.single.priority,
        possibleCauses: candidates.single.possibleCauses,
        suggestedInvestigations: candidates.single.suggestedInvestigations,
        sourceSnapshot: {
          ...candidates.single.sourceSnapshot,
          'refreshed': true,
        },
        ruleVersion: candidates.single.ruleVersion,
        estimatedWasteQuantity: 55,
      );

      final second = await service.refreshForSite(
        siteId: siteId,
        periodStart: start,
        periodEnd: end,
        candidates: [bumped],
      );
      expect(second.created, 0);
      expect(second.refreshed, 1);
      expect(store.rows, hasLength(1));
      expect(store.rows.single.confidenceScore, 75);
      expect(store.rows.single.estimatedWasteQuantity, 55);
      expect(store.rows.single.sourceSnapshot['refreshed'], isTrue);
    });
  });

  group('OpportunityPriority', () {
    test('low confidence not critical (cap <60 medium, <70 no critical)', () {
      final lowConf = OpportunityPriority.compute(
        confidenceScore: 50,
        severity: AnomalySeverity.critical,
        magnitudePct: 50,
        repetitionCount: 3,
      );
      expect(lowConf.rank, lessThanOrEqualTo(OpportunityPriorityLevel.medium.rank));
      expect(lowConf, isNot(OpportunityPriorityLevel.critical));

      final midConf = OpportunityPriority.compute(
        confidenceScore: 65,
        severity: AnomalySeverity.critical,
        magnitudePct: 50,
      );
      expect(midConf, isNot(OpportunityPriorityLevel.critical));
      expect(OpportunityPriority.allowCriticalBelowConfidence70, isFalse);

      final highConf = OpportunityPriority.compute(
        confidenceScore: 90,
        severity: AnomalySeverity.critical,
        magnitudePct: 50,
      );
      expect(highConf, OpportunityPriorityLevel.critical);
    });
  });

  group('OpportunityLifecycle', () {
    test('valid / invalid transitions', () {
      expect(
        OpportunityLifecycle.canTransition(
          OpportunityStatus.detected,
          OpportunityStatus.triaged,
        ),
        isTrue,
      );
      expect(
        OpportunityLifecycle.canTransition(
          OpportunityStatus.detected,
          OpportunityStatus.resolved,
        ),
        isFalse,
      );
      expect(
        () => OpportunityLifecycle.assertCanTransition(
          OpportunityStatus.monitoring,
          OpportunityStatus.detected,
        ),
        throwsStateError,
      );
    });

    test('dismiss reasons enum covers DB values', () {
      final db = {
        'false_positive',
        'data_issue',
        'expected_operational_change',
        'duplicate',
        'no_action_required',
        'other',
      };
      expect(
        OpportunityDismissReason.values.map((e) => e.dbValue).toSet(),
        db,
      );
    });

    test('reopen from resolved/dismissed', () {
      expect(
        OpportunityLifecycle.canTransition(
          OpportunityStatus.resolved,
          OpportunityStatus.detected,
        ),
        isTrue,
      );
      expect(
        OpportunityLifecycle.canTransition(
          OpportunityStatus.dismissed,
          OpportunityStatus.triaged,
        ),
        isTrue,
      );
    });
  });

  group('ActionLifecycle', () {
    test('open → completed rejected', () {
      expect(
        ActionLifecycle.canTransition(ActionStatus.open, ActionStatus.completed),
        isFalse,
      );
      expect(
        () => ActionLifecycle.assertCanTransition(
          ActionStatus.open,
          ActionStatus.completed,
        ),
        throwsStateError,
      );
      expect(
        ActionLifecycle.canTransition(
          ActionStatus.inProgress,
          ActionStatus.completed,
        ),
        isTrue,
      );
    });
  });

  group('confirmed cause human-only', () {
    test('requires human ids', () {
      expect(
        ConservationInvestigation.validateConfirmedCause(
          cause: ConfirmedCause.confirmedLeak,
          confirmedBy: null,
          confirmedAt: DateTime.utc(2026, 7, 30),
        ),
        contains('confirmedBy'),
      );
      expect(
        ConservationInvestigation.validateConfirmedCause(
          cause: ConfirmedCause.suspectedLeak,
          confirmedBy: 'user-1',
          confirmedAt: null,
        ),
        contains('confirmedAt'),
      );
      expect(
        ConservationInvestigation.validateConfirmedCause(
          cause: ConfirmedCause.meterError,
          confirmedBy: 'user-1',
          confirmedAt: DateTime.utc(2026, 7, 30),
        ),
        isNull,
      );
      expect(
        ConservationInvestigation.validateConfirmedCause(
          cause: null,
          confirmedBy: null,
          confirmedAt: null,
        ),
        isNull,
      );
    });
  });

  group('labels / wording', () {
    test('no Saving terminology in labels', () {
      for (final forbidden in ConservationOpportunityLabels.forbidden) {
        expect(ConservationOpportunityLabels.potentialExcess, isNot(forbidden));
        expect(ConservationOpportunityLabels.quantityAtRisk, isNot(forbidden));
        expect(ConservationOpportunity.potentialExcessLabel, isNot(forbidden));
      }
      expect(
        ConservationOpportunity.forbiddenSavingLabels,
        containsAll(['Saving', 'Verified Saving', 'Estimated Saving']),
      );
    });

    test('potential excess wording on candidate quantity label', () {
      expect(
        OpportunityCandidate.quantityLabel,
        ConservationOpportunityLabels.potentialExcess,
      );
      expect(
        OpportunityCandidate.quantityLabel.toLowerCase(),
        isNot(contains('saving')),
      );
    });
  });

  group('feature flags', () {
    test('phase 3 keys in all', () {
      expect(ConservationFeatureFlags.opportunities, 'opportunities');
      expect(ConservationFeatureFlags.investigations, 'investigations');
      expect(ConservationFeatureFlags.actions, 'actions');
      expect(ConservationFeatureFlags.evidence, 'evidence');
      expect(
        ConservationFeatureFlags.all,
        containsAll([
          ConservationFeatureFlags.opportunities,
          ConservationFeatureFlags.investigations,
          ConservationFeatureFlags.actions,
          ConservationFeatureFlags.evidence,
        ]),
      );
    });
  });

  group('evidence path helper', () {
    test('conservationEvidencePath shape', () {
      expect(
        conservationEvidencePath(
          orgId: 'org',
          siteId: 'site',
          opportunityId: 'opp',
          fileName: 'photo.jpg',
        ),
        'org/site/opportunities/opp/photo.jpg',
      );
      expect(kConservationEvidenceBucket, 'conservation-evidence');
    });
  });
}

class _FakeOpportunityStore implements OpportunityGenerationStore {
  final List<ConservationOpportunity> rows = [];
  var _seq = 0;

  @override
  Future<ConservationOpportunity?> findOpenByFingerprint({
    required String siteId,
    required String sourceFingerprint,
  }) async {
    for (final r in rows) {
      if (r.siteId == siteId &&
          r.sourceFingerprint == sourceFingerprint &&
          r.status.isOpen) {
        return r;
      }
    }
    return null;
  }

  @override
  Future<ConservationOpportunity> insert(ConservationOpportunity opp) async {
    final created = ConservationOpportunity(
      id: 'opp-${_seq++}',
      siteId: opp.siteId,
      meterId: opp.meterId,
      balanceGroupId: opp.balanceGroupId,
      utilityType: opp.utilityType,
      origin: opp.origin,
      sourceType: opp.sourceType,
      sourceFingerprint: opp.sourceFingerprint,
      title: opp.title,
      description: opp.description,
      detectedPeriodStart: opp.detectedPeriodStart,
      detectedPeriodEnd: opp.detectedPeriodEnd,
      unitCode: opp.unitCode,
      estimatedWasteQuantity: opp.estimatedWasteQuantity,
      confidenceScore: opp.confidenceScore,
      priority: opp.priority,
      status: opp.status,
      possibleCauses: opp.possibleCauses,
      suggestedInvestigations: opp.suggestedInvestigations,
      sourceSnapshot: opp.sourceSnapshot,
      ruleVersion: opp.ruleVersion,
      createdBy: opp.createdBy,
      detectedAt: opp.detectedAt,
    );
    rows.add(created);
    return created;
  }

  @override
  Future<ConservationOpportunity> refreshOpenSignal({
    required String id,
    required int confidenceScore,
    required OpportunityPriorityLevel priority,
    required Map<String, dynamic> sourceSnapshot,
    double? estimatedWasteQuantity,
    List<String>? possibleCauses,
    List<String>? suggestedInvestigations,
    String? title,
    String? description,
  }) async {
    final i = rows.indexWhere((r) => r.id == id);
    if (i < 0) throw StateError('missing $id');
    final old = rows[i];
    final next = ConservationOpportunity(
      id: old.id,
      siteId: old.siteId,
      meterId: old.meterId,
      balanceGroupId: old.balanceGroupId,
      utilityType: old.utilityType,
      origin: old.origin,
      sourceType: old.sourceType,
      sourceFingerprint: old.sourceFingerprint,
      title: title ?? old.title,
      description: description ?? old.description,
      detectedPeriodStart: old.detectedPeriodStart,
      detectedPeriodEnd: old.detectedPeriodEnd,
      unitCode: old.unitCode,
      estimatedWasteQuantity: estimatedWasteQuantity ?? old.estimatedWasteQuantity,
      confidenceScore: confidenceScore,
      priority: priority,
      status: old.status,
      possibleCauses: possibleCauses ?? old.possibleCauses,
      suggestedInvestigations:
          suggestedInvestigations ?? old.suggestedInvestigations,
      sourceSnapshot: sourceSnapshot,
      ruleVersion: old.ruleVersion,
      createdBy: old.createdBy,
      detectedAt: old.detectedAt,
      updatedAt: DateTime.now().toUtc(),
    );
    rows[i] = next;
    return next;
  }
}
