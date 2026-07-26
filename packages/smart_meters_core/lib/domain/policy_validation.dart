import '../models/policy_settings.dart';

class PolicyValidationResult {
  const PolicyValidationResult({required this.isValid, this.blockingMessage});

  final bool isValid;
  final String? blockingMessage;
}

PolicyValidationResult validatePolicySettings(PolicySettings settings) {
  if (settings.highConsumptionMultiplier <= 0) {
    return const PolicyValidationResult(
      isValid: false,
      blockingMessage: 'High consumption multiplier must be greater than zero.',
    );
  }
  if (settings.highConsumptionCriticalMultiplier <= 0) {
    return const PolicyValidationResult(
      isValid: false,
      blockingMessage:
          'Critical high consumption multiplier must be greater than zero.',
    );
  }
  if (settings.highConsumptionCriticalMultiplier <
      settings.highConsumptionMultiplier) {
    return const PolicyValidationResult(
      isValid: false,
      blockingMessage:
          'Critical multiplier must be greater than or equal to warning multiplier.',
    );
  }
  if (settings.lowCompletionWarningPercent <= 0 ||
      settings.lowCompletionWarningPercent > 100) {
    return const PolicyValidationResult(
      isValid: false,
      blockingMessage: 'Completion warning must be between 1 and 100.',
    );
  }
  if (settings.lowCompletionCriticalPercent <= 0 ||
      settings.lowCompletionCriticalPercent > 100) {
    return const PolicyValidationResult(
      isValid: false,
      blockingMessage: 'Completion critical must be between 1 and 100.',
    );
  }
  if (settings.lowCompletionCriticalPercent >=
      settings.lowCompletionWarningPercent) {
    return const PolicyValidationResult(
      isValid: false,
      blockingMessage:
          'Critical completion threshold must be lower than warning threshold.',
    );
  }
  if (settings.lowCopWarningThreshold <= 0 ||
      settings.lowCopCriticalThreshold <= 0) {
    return const PolicyValidationResult(
      isValid: false,
      blockingMessage: 'COP thresholds must be greater than zero.',
    );
  }
  if (settings.lowCopCriticalThreshold >= settings.lowCopWarningThreshold) {
    return const PolicyValidationResult(
      isValid: false,
      blockingMessage:
          'Critical COP threshold must be lower than warning threshold.',
    );
  }
  if (settings.possibleLeakDaysWarning <= 0 ||
      settings.possibleLeakDaysCritical <= 0) {
    return const PolicyValidationResult(
      isValid: false,
      blockingMessage: 'Leak day thresholds must be greater than zero.',
    );
  }
  if (settings.possibleLeakDaysCritical < settings.possibleLeakDaysWarning) {
    return const PolicyValidationResult(
      isValid: false,
      blockingMessage:
          'Critical leak days must be greater than or equal to warning days.',
    );
  }
  return const PolicyValidationResult(isValid: true);
}
