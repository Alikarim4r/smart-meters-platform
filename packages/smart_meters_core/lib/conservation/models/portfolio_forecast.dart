class PortfolioSummary {
  const PortfolioSummary({
    required this.id,
    required this.organizationId,
    required this.scopeLevel,
    required this.verifiedSavingsTotal,
    this.zoneId,
    this.siteId,
    this.periodStart,
    this.periodEnd,
    this.costAvoidedTotal,
    this.costCurrency,
    this.carbonAvoidedTotal,
    this.carbonUnit,
    this.openOpportunities = 0,
    this.actionsOverdue = 0,
    this.verificationPending = 0,
    this.savingsNotSustained = 0,
    this.sitesAboveTarget = 0,
    this.dataConfidenceAvg,
    this.priorityScore,
    this.rankingMethod,
    this.rankingExplanations = const [],
    this.metrics = const {},
    this.lineage = const {},
    this.refreshedAt,
  });

  final String id;
  final String organizationId;
  final String? zoneId;
  final String? siteId;
  final String scopeLevel;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double verifiedSavingsTotal;
  final double? costAvoidedTotal;
  final String? costCurrency;
  final double? carbonAvoidedTotal;
  final String? carbonUnit;
  final int openOpportunities;
  final int actionsOverdue;
  final int verificationPending;
  final int savingsNotSustained;
  final int sitesAboveTarget;
  final double? dataConfidenceAvg;
  final double? priorityScore;
  final String? rankingMethod;
  final List<dynamic> rankingExplanations;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> lineage;
  final DateTime? refreshedAt;

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) {
    return PortfolioSummary(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      zoneId: json['zone_id'] as String?,
      siteId: json['site_id'] as String?,
      scopeLevel: json['scope_level'] as String,
      periodStart: json['period_start'] != null
          ? DateTime.parse(json['period_start'] as String)
          : null,
      periodEnd: json['period_end'] != null
          ? DateTime.parse(json['period_end'] as String)
          : null,
      verifiedSavingsTotal:
          (json['verified_savings_total'] as num?)?.toDouble() ?? 0,
      costAvoidedTotal: (json['cost_avoided_total'] as num?)?.toDouble(),
      costCurrency: json['cost_currency'] as String?,
      carbonAvoidedTotal: (json['carbon_avoided_total'] as num?)?.toDouble(),
      carbonUnit: json['carbon_unit'] as String?,
      openOpportunities: json['open_opportunities'] as int? ?? 0,
      actionsOverdue: json['actions_overdue'] as int? ?? 0,
      verificationPending: json['verification_pending'] as int? ?? 0,
      savingsNotSustained: json['savings_not_sustained'] as int? ?? 0,
      sitesAboveTarget: json['sites_above_target'] as int? ?? 0,
      dataConfidenceAvg: (json['data_confidence_avg'] as num?)?.toDouble(),
      priorityScore: (json['priority_score'] as num?)?.toDouble(),
      rankingMethod: json['ranking_method'] as String?,
      rankingExplanations: List<dynamic>.from(
        (json['ranking_explanations'] as List?) ?? const [],
      ),
      metrics: Map<String, dynamic>.from((json['metrics'] as Map?) ?? const {}),
      lineage: Map<String, dynamic>.from((json['lineage'] as Map?) ?? const {}),
      refreshedAt: json['refreshed_at'] != null
          ? DateTime.parse(json['refreshed_at'] as String)
          : null,
    );
  }
}

class ForecastResult {
  const ForecastResult({
    required this.id,
    required this.siteId,
    required this.utilityType,
    required this.forecastHorizon,
    required this.method,
    required this.historyLength,
    required this.confidence,
    required this.status,
    this.expectedValue,
    this.expectedLow,
    this.expectedHigh,
    this.targetValue,
    this.expectedTargetExceedance,
    this.expectedBudgetImpact,
    this.budgetCurrency,
    this.seasonalityHandling,
    this.usesNormalized = false,
    this.warnings = const [],
    this.lineage = const {},
    this.calculatedAt,
  });

  final String id;
  final String siteId;
  final String utilityType;
  final String forecastHorizon;
  final String method;
  final int historyLength;
  final double? expectedValue;
  final double? expectedLow;
  final double? expectedHigh;
  final double? targetValue;
  final double? expectedTargetExceedance;
  final double? expectedBudgetImpact;
  final String? budgetCurrency;
  final String confidence;
  final String? seasonalityHandling;
  final bool usesNormalized;
  final String status;
  final List<dynamic> warnings;
  final Map<String, dynamic> lineage;
  final DateTime? calculatedAt;

  bool get isInsufficientHistory =>
      status == 'insufficient_history' || method == 'insufficient_history';

  factory ForecastResult.fromJson(Map<String, dynamic> json) {
    return ForecastResult(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      utilityType: json['utility_type'] as String,
      forecastHorizon: json['forecast_horizon'] as String,
      method: json['method'] as String,
      historyLength: json['history_length'] as int? ?? 0,
      expectedValue: (json['expected_value'] as num?)?.toDouble(),
      expectedLow: (json['expected_low'] as num?)?.toDouble(),
      expectedHigh: (json['expected_high'] as num?)?.toDouble(),
      targetValue: (json['target_value'] as num?)?.toDouble(),
      expectedTargetExceedance:
          (json['expected_target_exceedance'] as num?)?.toDouble(),
      expectedBudgetImpact: (json['expected_budget_impact'] as num?)?.toDouble(),
      budgetCurrency: json['budget_currency'] as String?,
      confidence: json['confidence'] as String? ?? 'low',
      seasonalityHandling: json['seasonality_handling'] as String?,
      usesNormalized: json['uses_normalized'] as bool? ?? false,
      status: json['status'] as String? ?? 'computed',
      warnings: List<dynamic>.from((json['warnings'] as List?) ?? const []),
      lineage: Map<String, dynamic>.from((json['lineage'] as Map?) ?? const {}),
      calculatedAt: json['calculated_at'] != null
          ? DateTime.parse(json['calculated_at'] as String)
          : null,
    );
  }
}

class ConservationRecommendation {
  const ConservationRecommendation({
    required this.id,
    required this.ruleKey,
    required this.title,
    required this.rationale,
    required this.severity,
    required this.status,
    this.organizationId,
    this.siteId,
    this.relatedEntityType,
    this.relatedEntityId,
    this.explanationFactors = const [],
    this.lineage = const {},
  });

  final String id;
  final String? organizationId;
  final String? siteId;
  final String ruleKey;
  final String title;
  final String rationale;
  final String severity;
  final String status;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final List<dynamic> explanationFactors;
  final Map<String, dynamic> lineage;

  factory ConservationRecommendation.fromJson(Map<String, dynamic> json) {
    return ConservationRecommendation(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String?,
      siteId: json['site_id'] as String?,
      ruleKey: json['rule_key'] as String,
      title: json['title'] as String,
      rationale: json['rationale'] as String,
      severity: json['severity'] as String? ?? 'info',
      status: json['status'] as String? ?? 'open',
      relatedEntityType: json['related_entity_type'] as String?,
      relatedEntityId: json['related_entity_id'] as String?,
      explanationFactors: List<dynamic>.from(
        (json['explanation_factors'] as List?) ?? const [],
      ),
      lineage: Map<String, dynamic>.from((json['lineage'] as Map?) ?? const {}),
    );
  }
}
