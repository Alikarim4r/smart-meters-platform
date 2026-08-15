/// Versioned, explainable automation rules — suggestions only.
class AutomationRuleDefinition {
  const AutomationRuleDefinition({
    required this.ruleKey,
    required this.ruleVersion,
    required this.displayName,
    required this.explanation,
    required this.minConfidence,
    required this.repeatedPeriods,
    required this.enabled,
  });

  final String ruleKey;
  final int ruleVersion;
  final String displayName;
  final String explanation;
  final double minConfidence;
  final int repeatedPeriods;
  final bool enabled;
}

class AutomationTriggerContext {
  const AutomationTriggerContext({
    required this.anomalyHigh,
    required this.confidence,
    required this.repeatedPeriods,
    required this.meterId,
    required this.periodKey,
  });

  final bool anomalyHigh;
  final double confidence;
  final int repeatedPeriods;
  final String meterId;
  final String periodKey;
}

enum AutomationActionType {
  createSuggestedOpportunity,
  createInAppNotification,
  requestReview,
}

class AutomationFireResult {
  const AutomationFireResult({
    required this.fired,
    required this.firingKey,
    required this.actions,
    this.suppressedReason,
    this.confirmedDiagnosis = false,
    this.equipmentControl = false,
  });

  final bool fired;
  final String firingKey;
  final List<AutomationActionType> actions;
  final String? suppressedReason;

  /// Always false — Phase 6 restriction.
  final bool confirmedDiagnosis;

  /// Always false — Phase 6 restriction.
  final bool equipmentControl;
}

class AutomationRuleEngine {
  AutomationRuleEngine();

  final Set<String> _firedKeys = {};

  String firingKey(AutomationRuleDefinition rule, AutomationTriggerContext ctx) {
    return '${rule.ruleKey}:v${rule.ruleVersion}|${ctx.meterId}|${ctx.periodKey}';
  }

  AutomationFireResult evaluate({
    required AutomationRuleDefinition rule,
    required AutomationTriggerContext ctx,
  }) {
    final key = firingKey(rule, ctx);
    if (!rule.enabled) {
      return AutomationFireResult(
        fired: false,
        firingKey: key,
        actions: const [],
        suppressedReason: 'rule_disabled',
      );
    }
    if (ctx.confidence < rule.minConfidence) {
      return AutomationFireResult(
        fired: false,
        firingKey: key,
        actions: const [],
        suppressedReason: 'low_confidence',
      );
    }
    if (!ctx.anomalyHigh || ctx.repeatedPeriods < rule.repeatedPeriods) {
      return AutomationFireResult(
        fired: false,
        firingKey: key,
        actions: const [],
        suppressedReason: 'trigger_not_met',
      );
    }
    if (_firedKeys.contains(key)) {
      return AutomationFireResult(
        fired: false,
        firingKey: key,
        actions: const [],
        suppressedReason: 'idempotent_duplicate',
      );
    }
    _firedKeys.add(key);
    return AutomationFireResult(
      fired: true,
      firingKey: key,
      actions: const [
        AutomationActionType.createSuggestedOpportunity,
        AutomationActionType.createInAppNotification,
        AutomationActionType.requestReview,
      ],
    );
  }
}
