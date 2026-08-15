/// Quality gates for official weather/occupancy normalization models.
abstract final class NormalizationQualityGates {
  static const minSamplesDegreeDay = 6;
  static const minSamplesRegression = 8;
  static const minGoodnessOfFit = 0.4;
  static const minCompleteness = 0.8;

  static const notReliableLabel = 'Normalization Not Reliable';

  /// Evaluate whether a model may be approved for official use.
  static NormalizationGateResult evaluate({
    required int sampleCount,
    required String method,
    required bool weatherApproved,
    required bool weatherPresent,
    required bool unitsCompatible,
    double? goodnessOfFit,
    double? dataCompleteness,
    int criticalOutlierCount = 0,
    bool occupancyDataPresent = true,
    bool requiresOccupancy = false,
    bool requiresWeather = true,
  }) {
    final failures = <String>[];

    final minSamples = method == 'simple_linear_regression'
        ? minSamplesRegression
        : minSamplesDegreeDay;

    if (sampleCount < minSamples) {
      failures.add('insufficient_samples:$sampleCount<$minSamples');
    }
    if (dataCompleteness != null && dataCompleteness < minCompleteness) {
      failures.add('incomplete_data:$dataCompleteness');
    }
    if (goodnessOfFit != null && goodnessOfFit < minGoodnessOfFit) {
      failures.add('weak_statistical_fit:$goodnessOfFit');
    }
    if (criticalOutlierCount > 0) {
      failures.add('critical_outliers_unhandled:$criticalOutlierCount');
    }
    if (!unitsCompatible) {
      failures.add('incompatible_units');
    }
    if (requiresWeather) {
      if (!weatherPresent) failures.add('missing_weather');
      if (!weatherApproved) failures.add('unapproved_weather_data');
    }
    if (requiresOccupancy && !occupancyDataPresent) {
      failures.add('occupancy_not_available');
    }

    return NormalizationGateResult(
      passed: failures.isEmpty,
      failures: failures,
      displayLabel: failures.isEmpty ? 'Reliable' : notReliableLabel,
    );
  }
}

class NormalizationGateResult {
  const NormalizationGateResult({
    required this.passed,
    required this.failures,
    required this.displayLabel,
  });

  final bool passed;
  final List<String> failures;
  final String displayLabel;
}
