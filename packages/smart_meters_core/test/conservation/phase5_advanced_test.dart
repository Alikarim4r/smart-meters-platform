import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

void main() {
  group('Weather sensitivity', () {
    test('cooling eligible; bare water not; electricity needs tag', () {
      expect(
        WeatherSensitiveUtilities.isEligible(utilityType: 'cooling'),
        isTrue,
      );
      expect(
        WeatherSensitiveUtilities.isEligible(utilityType: 'water'),
        isFalse,
      );
      expect(
        WeatherSensitiveUtilities.isEligible(utilityType: 'electricity'),
        isFalse,
      );
      expect(
        WeatherSensitiveUtilities.isEligible(
          utilityType: 'electricity',
          endUseTag: 'cooling_electricity',
        ),
        isTrue,
      );
    });
  });

  group('Degree-day normalization', () {
    const svc = DegreeDayNormalizationService();
    final approved = WeatherDataset(
      id: 'wd-1',
      organizationId: 'org-1',
      locationLabel: 'Doha',
      source: 'imported_monthly',
      periodStart: DateTime(2025, 1, 1),
      periodEnd: DateTime(2025, 12, 31),
      quality: 'high',
      status: WeatherDatasetStatus.approved,
    );

    test('A — weather-adjusted consumption', () {
      final r = svc.normalize(
        utilityType: 'cooling',
        actualConsumption: 1200,
        periodDegreeDays: 300,
        referenceDegreeDays: 250,
        dataset: approved,
        unitCode: 'kWh',
        sampleCount: 12,
        goodnessOfFit: 0.72,
        dataCompleteness: 0.95,
      );
      expect(r.canNormalize, isTrue);
      expect(r.actualConsumption, 1200);
      expect(r.normalizedConsumption, closeTo(1000, 0.01));
      expect(r.actualConsumption, isNot(r.normalizedConsumption));
    });

    test('B — model rejected insufficient samples', () {
      final r = svc.normalize(
        utilityType: 'cooling',
        actualConsumption: 1200,
        periodDegreeDays: 300,
        referenceDegreeDays: 250,
        dataset: approved,
        unitCode: 'kWh',
        sampleCount: 2,
        goodnessOfFit: 0.9,
        dataCompleteness: 1,
      );
      expect(r.canNormalize, isFalse);
      expect(r.displayLabel, NormalizationQualityGates.notReliableLabel);
      expect(r.normalizedConsumption, isNull);
      expect(r.actualConsumption, 1200);
    });

    test('unapproved weather blocked', () {
      final draft = WeatherDataset(
        id: 'wd-2',
        organizationId: 'org-1',
        locationLabel: 'Doha',
        source: 'manual_approved',
        periodStart: DateTime(2025, 1, 1),
        periodEnd: DateTime(2025, 6, 30),
        quality: 'medium',
        status: WeatherDatasetStatus.draft,
      );
      final r = svc.normalize(
        utilityType: 'cooling',
        actualConsumption: 100,
        periodDegreeDays: 10,
        referenceDegreeDays: 10,
        dataset: draft,
        unitCode: 'kWh',
        sampleCount: 12,
        goodnessOfFit: 0.8,
        dataCompleteness: 1,
      );
      expect(r.canNormalize, isFalse);
      expect(r.failures, contains('unapproved_weather_data'));
    });

    test('missing weather blocked', () {
      final r = svc.normalize(
        utilityType: 'cooling',
        actualConsumption: 100,
        periodDegreeDays: 0,
        referenceDegreeDays: 10,
        dataset: null,
        unitCode: 'kWh',
        sampleCount: 12,
        dataCompleteness: 1,
      );
      expect(r.canNormalize, isFalse);
      expect(r.failures, contains('missing_weather'));
    });

    test('poor model fit rejected', () {
      final gate = NormalizationQualityGates.evaluate(
        sampleCount: 12,
        method: 'simple_linear_regression',
        weatherApproved: true,
        weatherPresent: true,
        unitsCompatible: true,
        goodnessOfFit: 0.1,
        dataCompleteness: 1,
      );
      expect(gate.passed, isFalse);
      expect(gate.displayLabel, NormalizationQualityGates.notReliableLabel);
    });
  });

  group('Occupancy normalization', () {
    const svc = OccupancyNormalizationService();

    test('missing occupancy → Not Available', () {
      final r = svc.normalize(
        actualConsumption: 500,
        unitCode: 'm3',
      );
      expect(r.available, isFalse);
      expect(r.displayLabel, OccupancyNormalizationService.notAvailableLabel);
      expect(r.actualConsumption, 500);
    });

    test('calendar-aware operating days', () {
      final cal = [
        for (var i = 1; i <= 5; i++)
          SiteOperatingCalendarEntry(
            id: 'c$i',
            siteId: 's1',
            periodDate: DateTime(2026, 3, i),
            operatingStatus: i == 5 ? 'holiday' : 'operating',
            source: 'school_calendar',
            status: 'approved',
            occupancyCount: 200,
          ),
      ];
      final r = svc.normalize(
        actualConsumption: 400,
        unitCode: 'm3',
        calendar: cal,
        referenceOperatingDays: 4,
      );
      expect(r.available, isTrue);
      expect(r.operatingDays, 4);
      expect(r.occupancyAdjustedBaseline, 400);
      expect(r.intensities['per_occupied_day'], 100);
    });
  });

  group('Normalization model service', () {
    const svc = NormalizationModelService();
    test('model version binding in metadata', () {
      final approved = WeatherDataset(
        id: 'wd-1',
        organizationId: 'org',
        locationLabel: 'Doha',
        source: 'imported_monthly',
        periodStart: DateTime(2025, 1, 1),
        periodEnd: DateTime(2025, 12, 31),
        quality: 'high',
        status: WeatherDatasetStatus.approved,
      );
      final r = svc.evaluateDraft(
        utilityType: 'cooling',
        method: 'degree_day',
        sampleCount: 12,
        trainingPeriodStart: DateTime(2025, 1, 1),
        trainingPeriodEnd: DateTime(2025, 12, 31),
        dependentVariable: 'kWh',
        weatherVariables: const ['cdd'],
        weatherDataset: approved,
        goodnessOfFit: 0.75,
        dataCompleteness: 0.95,
        modelVersion: 3,
        createdBy: 'admin-1',
      );
      expect(r.qualityGatePassed, isTrue);
      expect(r.metadata['version'], 3);
      expect(r.metadata['weather_dataset_id'], 'wd-1');
    });
  });

  group('Saving persistence', () {
    const svc = SavingPersistenceService();
    final start = DateTime(2026, 3, 1);
    final end = DateTime(2026, 3, 31);

    test('C — saving sustained', () {
      final r = svc.evaluate(
        siteId: 's1',
        measurementVerificationId: 'mv-1',
        originalVerifiedSaving: 100,
        window: PersistenceWindow.oneMonth,
        followUpStart: start,
        followUpEnd: end,
        expectedReferenceConsumption: 900,
        actualConsumption: 810, // sustained 90 → 90%
        dataCompleteness: 0.95,
        confidenceScore: 85,
      );
      expect(r.status, PersistenceStatus.sustained);
      expect(r.sustainedQuantity, 90);
      expect(r.lineage['original_verified_saving'], 100);
    });

    test('D — saving not sustained', () {
      final r = svc.evaluate(
        siteId: 's1',
        measurementVerificationId: 'mv-1',
        originalVerifiedSaving: 100,
        window: PersistenceWindow.threeMonths,
        followUpStart: start,
        followUpEnd: end,
        expectedReferenceConsumption: 900,
        actualConsumption: 890, // sustained 10 → 10%
        confidenceScore: 80,
      );
      expect(r.status, PersistenceStatus.notSustained);
      expect(r.reopenOpportunitySuggested, isTrue);
      expect(r.reopenSuggestionKey, isNotNull);
    });

    test('missing follow-up', () {
      final r = svc.evaluate(
        siteId: 's1',
        measurementVerificationId: 'mv-1',
        originalVerifiedSaving: 50,
        window: PersistenceWindow.oneMonth,
        followUpStart: start,
        followUpEnd: end,
      );
      expect(r.status, PersistenceStatus.insufficientFollowUp);
    });

    test('reopen suggestion deduped', () {
      final key = 'reopen:mv-1:1m';
      final r = svc.evaluate(
        siteId: 's1',
        measurementVerificationId: 'mv-1',
        originalVerifiedSaving: 100,
        window: PersistenceWindow.oneMonth,
        followUpStart: start,
        followUpEnd: end,
        expectedReferenceConsumption: 900,
        actualConsumption: 895,
        existingReopenKeys: {key},
      );
      expect(r.reopenOpportunitySuggested, isFalse);
      expect(r.reopenSuggestionKey, isNull);
    });

    test('available windows respect data cadence', () {
      expect(SavingPersistenceService.availableWindows(20), isEmpty);
      expect(
        SavingPersistenceService.availableWindows(30),
        contains(PersistenceWindow.oneMonth),
      );
      expect(
        SavingPersistenceService.availableWindows(30),
        isNot(contains(PersistenceWindow.twelveMonths)),
      );
    });

    test('partially sustained', () {
      final r = svc.evaluate(
        siteId: 's1',
        measurementVerificationId: 'mv-1',
        originalVerifiedSaving: 100,
        window: PersistenceWindow.oneMonth,
        followUpStart: start,
        followUpEnd: end,
        expectedReferenceConsumption: 900,
        actualConsumption: 840, // 60%
        confidenceScore: 70,
      );
      expect(r.status, PersistenceStatus.partiallySustained);
    });
  });

  group('Carbon accounting', () {
    const svc = CarbonAccountingService();
    final factor = EmissionFactor(
      id: 'ef-1',
      organizationId: 'org',
      utilityOrFuelType: 'grid_electricity',
      geography: 'QA',
      factor: 0.5,
      unitCode: 'kWh',
      co2eUnit: 'kgCO2e',
      source: 'official_grid_2025',
      effectiveFrom: DateTime(2025, 1, 1),
      status: 'active',
    );

    test('E — verified carbon avoided', () {
      final r = svc.compute(
        siteId: 's1',
        basis: CarbonQuantityBasis.verifiedSaving,
        savingQuantity: 100,
        factor: factor,
        asOf: DateTime(2026, 1, 15),
        measurementVerificationId: 'mv-1',
      );
      expect(r.status, 'computed');
      expect(r.carbonAvoided, 50);
      expect(r.factorValueSnapshot, 0.5);
      expect(r.emissionFactorId, 'ef-1');
    });

    test('F — missing factor → N/A', () {
      final r = svc.compute(
        siteId: 's1',
        basis: CarbonQuantityBasis.verifiedSaving,
        savingQuantity: 100,
        factor: null,
        asOf: DateTime(2026, 1, 15),
      );
      expect(r.isNotAvailable, isTrue);
      expect(r.carbonAvoided, isNull);
      expect(r.displayLabel, CarbonAccountingService.notAvailableLabel);
    });

    test('expired factor', () {
      final expired = EmissionFactor(
        id: 'ef-x',
        organizationId: 'org',
        utilityOrFuelType: 'diesel',
        geography: 'QA',
        factor: 2.6,
        unitCode: 'L',
        co2eUnit: 'kgCO2e',
        source: 'lab',
        effectiveFrom: DateTime(2020, 1, 1),
        effectiveTo: DateTime(2024, 12, 31),
        status: 'active',
      );
      final r = svc.compute(
        siteId: 's1',
        basis: CarbonQuantityBasis.verifiedSaving,
        savingQuantity: 10,
        factor: expired,
        asOf: DateTime(2026, 1, 1),
      );
      expect(r.status, 'expired_factor');
      expect(r.carbonAvoided, isNull);
    });

    test('verified-only total ignores estimated', () {
      final verified = svc.compute(
        siteId: 's1',
        basis: CarbonQuantityBasis.verifiedSaving,
        savingQuantity: 100,
        factor: factor,
        asOf: DateTime(2026, 1, 1),
      );
      final estimated = svc.compute(
        siteId: 's1',
        basis: CarbonQuantityBasis.estimatedSaving,
        savingQuantity: 200,
        factor: factor,
        asOf: DateTime(2026, 1, 1),
      );
      expect(
        CarbonAccountingService.verifiedCarbonTotal([verified, estimated]),
        50,
      );
    });

    test('fuel type supported', () {
      final diesel = EmissionFactor(
        id: 'ef-d',
        organizationId: 'org',
        utilityOrFuelType: 'diesel',
        geography: 'QA',
        factor: 2.68,
        unitCode: 'L',
        co2eUnit: 'kgCO2e',
        source: 'approved_fuel_table',
        effectiveFrom: DateTime(2025, 1, 1),
        status: 'active',
      );
      final r = svc.compute(
        siteId: 's1',
        basis: CarbonQuantityBasis.verifiedSaving,
        savingQuantity: 10,
        factor: diesel,
        asOf: DateTime(2026, 1, 1),
      );
      expect(r.carbonAvoided, closeTo(26.8, 0.01));
    });
  });

  group('Portfolio optimization', () {
    const svc = PortfolioOptimizationService();
    final sites = [
      const PortfolioSiteInput(
        siteId: 'a',
        verifiedSaving: 100,
        costAvoided: 500,
        floorAreaM2: 1000,
        dataConfidence: 90,
        openOpportunities: 2,
      ),
      const PortfolioSiteInput(
        siteId: 'b',
        verifiedSaving: 80,
        costAvoided: 800,
        floorAreaM2: 200,
        dataConfidence: 70,
        openOpportunities: 1,
        repeatedAnomalies: true,
      ),
      const PortfolioSiteInput(
        siteId: 'c',
        verifiedSaving: -50, // must not enter verified total
        dataConfidence: 40,
      ),
    ];

    test('organization aggregation verified-only', () {
      final agg = svc.aggregate(
        organizationId: 'org',
        scopeLevel: 'organization',
        sites: sites,
      );
      expect(agg.verifiedSavingsTotal, 180);
      expect(agg.costAvoidedTotal, 1300);
    });

    test('G — intensity ranking', () {
      final ranked = svc.rankSites(
        sites: sites.where((s) => s.verifiedSaving > 0).toList(),
        method: PortfolioRankingMethod.verifiedSavingIntensity,
      );
      expect(ranked.first.siteId, 'b'); // 80/200 = 0.4 > 100/1000
      expect(ranked.first.rankingMethod, 'verified_saving_intensity');
      expect(ranked.first.explanations, isNotEmpty);
    });

    test('confidence filtering', () {
      final ranked = svc.rankSites(
        sites: sites,
        method: PortfolioRankingMethod.verifiedSavingAbsolute,
        minConfidence: 80,
      );
      expect(ranked.map((e) => e.siteId), ['a']);
    });

    test('explainable priority score', () {
      final ranked = svc.rankSites(
        sites: [sites[1]],
        method: PortfolioRankingMethod.confidenceAdjustedPriority,
      );
      expect(
        ranked.first.explanations.any((e) => e.contains('Repeated')),
        isTrue,
      );
    });

    test('bounded pagination', () {
      final agg = svc.aggregate(
        organizationId: 'org',
        scopeLevel: 'organization',
        sites: sites,
        limit: 1,
      );
      expect(agg.siteCount, 1);
      expect(agg.verifiedSavingsTotal, 100);
    });
  });

  group('Forecasting', () {
    const svc = ForecastingService();

    test('run-rate', () {
      final r = svc.forecast(
        siteId: 's1',
        utilityType: 'water',
        horizon: ForecastHorizon.monthEnd,
        preferredMethod: ForecastMethod.runRate,
        historyPeriods: const [100, 110, 90],
      );
      expect(r.isInsufficientHistory, isFalse);
      expect(r.expectedValue, closeTo(100, 0.01));
      expect(r.method, ForecastMethod.runRate);
    });

    test('seasonal average', () {
      final r = svc.forecast(
        siteId: 's1',
        utilityType: 'water',
        horizon: ForecastHorizon.monthEnd,
        preferredMethod: ForecastMethod.seasonalAverage,
        historyPeriods: const [10, 12, 11, 13, 12, 14],
      );
      expect(r.method, ForecastMethod.seasonalAverage);
      expect(r.expectedValue, isNotNull);
    });

    test('H — annual target exceedance forecast', () {
      final r = svc.forecast(
        siteId: 's1',
        utilityType: 'electricity',
        horizon: ForecastHorizon.annualTarget,
        preferredMethod: ForecastMethod.runRate,
        historyPeriods: const [100, 100, 100],
        annualTarget: 1000,
        tariffRate: 0.3,
        budgetCurrency: 'QAR',
      );
      expect(r.expectedValue, 1200);
      expect(r.expectedTargetExceedance, 200);
      expect(r.expectedBudgetImpact, closeTo(60, 0.01));
    });

    test('insufficient history', () {
      final r = svc.forecast(
        siteId: 's1',
        utilityType: 'water',
        horizon: ForecastHorizon.monthEnd,
        preferredMethod: ForecastMethod.runRate,
        historyPeriods: const [100],
      );
      expect(r.isInsufficientHistory, isTrue);
      expect(r.expectedValue, isNull);
      expect(r.warnings, contains(ForecastLabels.insufficientHistory));
    });

    test('missing tariff → budget N/A', () {
      final r = svc.forecast(
        siteId: 's1',
        utilityType: 'water',
        horizon: ForecastHorizon.annualTarget,
        preferredMethod: ForecastMethod.runRate,
        historyPeriods: const [100, 100, 100],
        annualTarget: 500,
      );
      expect(r.expectedBudgetImpact, isNull);
      expect(r.warnings, contains('budget_impact_na_missing_tariff'));
    });
  });

  group('Recommendation engine', () {
    const eng = RecommendationEngine();
    test('rule-based recommendations', () {
      final r = eng.evaluate(
        siteId: 's1',
        verificationPending: 2,
        repeatedAnomaly: true,
        tariffMissing: true,
        savingNotSustained: true,
      );
      expect(r.map((e) => e.ruleKey), contains('prioritize_verification'));
      expect(r.map((e) => e.ruleKey), contains('investigate_repeated_anomaly'));
      expect(r.map((e) => e.ruleKey), contains('update_tariff'));
      expect(r.map((e) => e.ruleKey), contains('review_persistence'));
      expect(r.every((e) => e.explanationFactors.isNotEmpty), isTrue);
    });
  });

  group('I — negative performance preserved', () {
    const verification = SavingsVerificationService();
    test('raw −150 preserved; verified 0; not in savings total', () {
      var record = MeasurementVerification(
        id: 'mv-i',
        siteId: 's1',
        opportunityId: 'o1',
        baselineId: 'b1',
        utilityType: 'water',
        verificationMethod: MvVerificationMethod.baselineComparison,
        calculationVersion: 1,
        prePeriodStart: DateTime(2026, 1, 1),
        prePeriodEnd: DateTime(2026, 1, 31),
        postPeriodStart: DateTime(2026, 2, 1),
        postPeriodEnd: DateTime(2026, 2, 28),
        baselineValue: 900,
        unitCode: 'm3',
        confidenceScore: 90,
        status: MvStatus.draft,
        dataCompleteness: 0.95,
      );
      record = verification.applyEstimation(
        record: record,
        actualPostValue: 1050,
      );
      expect(record.performanceChangeQuantity, -150);
      record = verification.prepareVerificationPending(record);
      final outcome = verification.verify(
        record: record,
        verifiedBy: 'admin',
        actorRole: 'site_admin',
        baselineStatus: ConservationBaselineStatus.approved,
        actionStatus: ActionStatus.completed,
        opportunityStatus: OpportunityStatus.resolved,
        hasPendingCriticalDq: false,
      );
      expect(outcome.record!.verifiedSavingQuantity, 0);
      expect(outcome.record!.performanceChangeQuantity, -150);
      final total = [outcome.record!.verifiedSavingQuantity!]
          .where((q) => q > 0)
          .fold<double>(0, (a, b) => a + b);
      expect(total, 0);
    });
  });
}
