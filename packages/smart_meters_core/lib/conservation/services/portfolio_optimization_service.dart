/// Portfolio aggregation + explainable ranking / priority score.
class PortfolioOptimizationService {
  const PortfolioOptimizationService();

  /// Aggregate site rows to org/zone. Verified savings only; skip negatives.
  PortfolioAggregate aggregate({
    required String organizationId,
    String? zoneId,
    required String scopeLevel,
    required List<PortfolioSiteInput> sites,
    int? limit,
  }) {
    final bounded = limit == null ? sites : sites.take(limit).toList();
    var verified = 0.0;
    var cost = 0.0;
    var hasCost = false;
    var carbon = 0.0;
    var hasCarbon = false;
    var openOpp = 0;
    var overdue = 0;
    var pending = 0;
    var notSustained = 0;
    var aboveTarget = 0;
    var confSum = 0.0;
    var confN = 0;

    for (final s in bounded) {
      if (s.verifiedSaving > 0) verified += s.verifiedSaving;
      if (s.costAvoided != null) {
        cost += s.costAvoided!;
        hasCost = true;
      }
      if (s.carbonAvoided != null) {
        carbon += s.carbonAvoided!;
        hasCarbon = true;
      }
      openOpp += s.openOpportunities;
      overdue += s.actionsOverdue;
      pending += s.verificationPending;
      notSustained += s.savingsNotSustained ? 1 : 0;
      if (s.aboveTarget) aboveTarget += 1;
      if (s.dataConfidence != null) {
        confSum += s.dataConfidence!;
        confN += 1;
      }
    }

    return PortfolioAggregate(
      organizationId: organizationId,
      zoneId: zoneId,
      scopeLevel: scopeLevel,
      verifiedSavingsTotal: verified,
      costAvoidedTotal: hasCost ? cost : null,
      carbonAvoidedTotal: hasCarbon ? carbon : null,
      openOpportunities: openOpp,
      actionsOverdue: overdue,
      verificationPending: pending,
      savingsNotSustained: notSustained,
      sitesAboveTarget: aboveTarget,
      dataConfidenceAvg: confN == 0 ? null : confSum / confN,
      siteCount: bounded.length,
    );
  }

  /// Rank sites with an explicit method and explanations.
  List<RankedSite> rankSites({
    required List<PortfolioSiteInput> sites,
    required PortfolioRankingMethod method,
    double? minConfidence,
  }) {
    final filtered = minConfidence == null
        ? sites
        : sites
            .where((s) => (s.dataConfidence ?? 0) >= minConfidence)
            .toList();

    final ranked = filtered.map((s) {
      final score = _score(s, method);
      return RankedSite(
        siteId: s.siteId,
        score: score.score,
        rankingMethod: method.dbValue,
        explanations: score.explanations,
        input: s,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return ranked;
  }

  _Scored _score(PortfolioSiteInput s, PortfolioRankingMethod method) {
    final explanations = <String>[];
    double score;

    switch (method) {
      case PortfolioRankingMethod.verifiedSavingAbsolute:
        score = s.verifiedSaving;
        if (s.verifiedSaving > 0) {
          explanations.add('+ High verified saving absolute');
        }
      case PortfolioRankingMethod.verifiedSavingIntensity:
        final area = s.floorAreaM2 ?? 0;
        score = area > 0 ? s.verifiedSaving / area : s.verifiedSaving;
        explanations.add('+ Verified saving intensity');
      case PortfolioRankingMethod.costAvoided:
        score = s.costAvoided ?? 0;
        if (s.costAvoided != null && s.costAvoided! > 0) {
          explanations.add('+ High QAR impact');
        } else {
          explanations.add('− Cost avoided N/A');
        }
      case PortfolioRankingMethod.targetVariance:
        score = s.targetVariance ?? 0;
        if ((s.targetVariance ?? 0) > 0) {
          explanations.add('+ Above target variance');
        }
      case PortfolioRankingMethod.opportunityRisk:
        score = s.openOpportunities * 10.0 +
            s.actionsOverdue * 15.0 +
            (s.savingsNotSustained ? 25.0 : 0);
        if (s.openOpportunities > 0) {
          explanations.add('+ Open opportunities');
        }
        if (s.actionsOverdue > 0) {
          explanations.add('+ Actions overdue');
        }
        if (s.savingsNotSustained) {
          explanations.add('+ Savings not sustained');
        }
      case PortfolioRankingMethod.confidenceAdjustedPriority:
        final mag = s.verifiedSaving;
        final conf = (s.dataConfidence ?? 50) / 100.0;
        score = mag * conf;
        score += s.openOpportunities * 5 * conf;
        score += (s.costAvoided ?? 0) * 0.01 * conf;
        if (s.repeatedAnomalies) {
          score += 20 * conf;
          explanations.add('+ Repeated anomalies');
        }
        if ((s.balanceDifference ?? 0).abs() > 0) {
          score += (s.balanceDifference!.abs() * 0.1) * conf;
          explanations.add('+ Balance difference magnitude');
        }
        if (conf >= 0.8) {
          explanations.add('+ High confidence');
        } else if (conf < 0.5) {
          explanations.add('− Low data confidence');
          score *= 0.7;
        }
        if (s.partialAlignment) {
          explanations.add('− Partial meter alignment');
          score *= 0.85;
        }
        if (s.verifiedSaving > 0) {
          explanations.add('+ Verified saving magnitude');
        }
        if (s.costAvoided != null && s.costAvoided! > 0) {
          explanations.add('+ High QAR impact');
        }
    }

    return _Scored(score: score, explanations: explanations);
  }
}

enum PortfolioRankingMethod {
  verifiedSavingAbsolute('verified_saving_absolute'),
  verifiedSavingIntensity('verified_saving_intensity'),
  costAvoided('cost_avoided'),
  targetVariance('target_variance'),
  opportunityRisk('opportunity_risk'),
  confidenceAdjustedPriority('confidence_adjusted_priority');

  const PortfolioRankingMethod(this.dbValue);
  final String dbValue;
}

class PortfolioSiteInput {
  const PortfolioSiteInput({
    required this.siteId,
    this.verifiedSaving = 0,
    this.costAvoided,
    this.carbonAvoided,
    this.openOpportunities = 0,
    this.actionsOverdue = 0,
    this.verificationPending = 0,
    this.savingsNotSustained = false,
    this.aboveTarget = false,
    this.dataConfidence,
    this.floorAreaM2,
    this.targetVariance,
    this.balanceDifference,
    this.repeatedAnomalies = false,
    this.partialAlignment = false,
  });

  final String siteId;
  final double verifiedSaving;
  final double? costAvoided;
  final double? carbonAvoided;
  final int openOpportunities;
  final int actionsOverdue;
  final int verificationPending;
  final bool savingsNotSustained;
  final bool aboveTarget;
  final double? dataConfidence;
  final double? floorAreaM2;
  final double? targetVariance;
  final double? balanceDifference;
  final bool repeatedAnomalies;
  final bool partialAlignment;
}

class PortfolioAggregate {
  const PortfolioAggregate({
    required this.organizationId,
    required this.scopeLevel,
    required this.verifiedSavingsTotal,
    required this.openOpportunities,
    required this.actionsOverdue,
    required this.verificationPending,
    required this.savingsNotSustained,
    required this.sitesAboveTarget,
    required this.siteCount,
    this.zoneId,
    this.costAvoidedTotal,
    this.carbonAvoidedTotal,
    this.dataConfidenceAvg,
  });

  final String organizationId;
  final String? zoneId;
  final String scopeLevel;
  final double verifiedSavingsTotal;
  final double? costAvoidedTotal;
  final double? carbonAvoidedTotal;
  final int openOpportunities;
  final int actionsOverdue;
  final int verificationPending;
  final int savingsNotSustained;
  final int sitesAboveTarget;
  final double? dataConfidenceAvg;
  final int siteCount;
}

class RankedSite {
  const RankedSite({
    required this.siteId,
    required this.score,
    required this.rankingMethod,
    required this.explanations,
    required this.input,
  });

  final String siteId;
  final double score;
  final String rankingMethod;
  final List<String> explanations;
  final PortfolioSiteInput input;
}

class _Scored {
  const _Scored({required this.score, required this.explanations});
  final double score;
  final List<String> explanations;
}
