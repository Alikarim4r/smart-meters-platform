/// Rule-based recommendation engine. No BMS control. No AI verification.
class RecommendationEngine {
  const RecommendationEngine();

  List<RecommendationDraft> evaluate({
    required String siteId,
    String? organizationId,
    int verificationPending = 0,
    int actionsOverdue = 0,
    bool meterAlignmentPartial = false,
    bool missingWeatherData = false,
    bool missingOccupancyData = false,
    bool repeatedAnomaly = false,
    bool tariffMissing = false,
    bool baselineStale = false,
    bool savingNotSustained = false,
  }) {
    final out = <RecommendationDraft>[];

    if (verificationPending > 0) {
      out.add(RecommendationDraft(
        siteId: siteId,
        organizationId: organizationId,
        ruleKey: 'prioritize_verification',
        title: 'Prioritize verification',
        rationale: '$verificationPending verification(s) pending human review.',
        severity: verificationPending >= 3 ? 'high' : 'medium',
        explanationFactors: ['+ Verification backlog'],
      ));
    }
    if (actionsOverdue > 0) {
      out.add(RecommendationDraft(
        siteId: siteId,
        organizationId: organizationId,
        ruleKey: 'reinspect_action',
        title: 'Reinspect overdue action',
        rationale: '$actionsOverdue action(s) past due date.',
        severity: 'high',
        explanationFactors: ['+ Overdue conservation actions'],
      ));
    }
    if (meterAlignmentPartial) {
      out.add(RecommendationDraft(
        siteId: siteId,
        organizationId: organizationId,
        ruleKey: 'review_meter_alignment',
        title: 'Review meter alignment',
        rationale: 'Partial meter/period alignment reduces confidence.',
        severity: 'medium',
        explanationFactors: ['− Partial alignment'],
      ));
    }
    if (missingWeatherData) {
      out.add(RecommendationDraft(
        siteId: siteId,
        organizationId: organizationId,
        ruleKey: 'add_normalization_weather',
        title: 'Add missing normalization data (weather)',
        rationale: 'Weather-sensitive end-use lacks approved weather dataset.',
        severity: 'info',
        explanationFactors: ['− Missing approved weather'],
      ));
    }
    if (missingOccupancyData) {
      out.add(RecommendationDraft(
        siteId: siteId,
        organizationId: organizationId,
        ruleKey: 'add_normalization_occupancy',
        title: 'Add missing normalization data (occupancy)',
        rationale: 'Occupancy normalization not available without calendar/profile.',
        severity: 'info',
        explanationFactors: ['− Occupancy Not Available'],
      ));
    }
    if (repeatedAnomaly) {
      out.add(RecommendationDraft(
        siteId: siteId,
        organizationId: organizationId,
        ruleKey: 'investigate_repeated_anomaly',
        title: 'Investigate repeated anomaly',
        rationale: 'Repeated above-baseline / anomaly periods detected.',
        severity: 'high',
        explanationFactors: ['+ Repeated anomalies'],
      ));
    }
    if (tariffMissing) {
      out.add(RecommendationDraft(
        siteId: siteId,
        organizationId: organizationId,
        ruleKey: 'update_tariff',
        title: 'Update tariff',
        rationale: 'Cost Avoided / budget impact remains N/A without tariff.',
        severity: 'medium',
        explanationFactors: ['− Missing tariff'],
      ));
    }
    if (baselineStale) {
      out.add(RecommendationDraft(
        siteId: siteId,
        organizationId: organizationId,
        ruleKey: 'update_baseline',
        title: 'Update baseline',
        rationale: 'Bound baseline appears stale relative to current operations.',
        severity: 'medium',
        explanationFactors: ['− Stale baseline'],
      ));
    }
    if (savingNotSustained) {
      out.add(RecommendationDraft(
        siteId: siteId,
        organizationId: organizationId,
        ruleKey: 'review_persistence',
        title: 'Review saving persistence',
        rationale: 'Verified saving not sustained in follow-up window.',
        severity: 'high',
        explanationFactors: ['+ Saving Not Sustained'],
      ));
    }

    return out;
  }
}

class RecommendationDraft {
  const RecommendationDraft({
    required this.siteId,
    required this.ruleKey,
    required this.title,
    required this.rationale,
    required this.severity,
    required this.explanationFactors,
    this.organizationId,
  });

  final String siteId;
  final String? organizationId;
  final String ruleKey;
  final String title;
  final String rationale;
  final String severity;
  final List<String> explanationFactors;
}
