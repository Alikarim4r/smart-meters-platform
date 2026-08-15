import '../domain/normalization_quality_gates.dart';
import '../domain/weather_sensitive_utilities.dart';
import '../models/weather_dataset.dart';

/// Build / gate normalization model metadata (explainable methods only).
class NormalizationModelService {
  const NormalizationModelService();

  ModelEvaluationResult evaluateDraft({
    required String utilityType,
    required String method,
    required int sampleCount,
    required DateTime trainingPeriodStart,
    required DateTime trainingPeriodEnd,
    required String dependentVariable,
    required List<String> weatherVariables,
    WeatherDataset? weatherDataset,
    double? goodnessOfFit,
    double? dataCompleteness,
    bool unitsCompatible = true,
    int criticalOutlierCount = 0,
    bool occupancyDataPresent = false,
    String? endUseTag,
    bool profileMarkedWeatherSensitive = false,
    Map<String, dynamic> coefficients = const {},
    int modelVersion = 1,
    String? createdBy,
  }) {
    final requiresWeather = method == 'degree_day' ||
        method == 'simple_linear_regression' ||
        method == 'weather_adjusted_baseline';
    final requiresOccupancy = method == 'occupancy_adjusted_baseline' ||
        method == 'operating_day_intensity';

    final weatherEligible = WeatherSensitiveUtilities.isEligible(
      utilityType: utilityType,
      endUseTag: endUseTag,
      profileMarkedWeatherSensitive: profileMarkedWeatherSensitive,
    );

    final failures = <String>[];
    if (requiresWeather && !weatherEligible) {
      failures.add('utility_not_weather_sensitive');
    }

    final gate = NormalizationQualityGates.evaluate(
      sampleCount: sampleCount,
      method: method,
      weatherApproved: weatherDataset?.status.isApproved ?? false,
      weatherPresent: weatherDataset != null && weatherVariables.isNotEmpty,
      unitsCompatible: unitsCompatible,
      goodnessOfFit: goodnessOfFit,
      dataCompleteness: dataCompleteness,
      criticalOutlierCount: criticalOutlierCount,
      occupancyDataPresent: occupancyDataPresent,
      requiresOccupancy: requiresOccupancy,
      requiresWeather: requiresWeather,
    );
    failures.addAll(gate.failures);

    final passed = failures.isEmpty;
    final confidence = !passed
        ? 'unreliable'
        : (goodnessOfFit != null && goodnessOfFit >= 0.7 && sampleCount >= 12)
            ? 'high'
            : (goodnessOfFit != null && goodnessOfFit >= 0.5)
                ? 'medium'
                : 'low';

    return ModelEvaluationResult(
      qualityGatePassed: passed,
      qualityGateFailures: failures,
      confidence: confidence,
      displayLabel: passed
          ? 'Model Ready'
          : NormalizationQualityGates.notReliableLabel,
      metadata: {
        'method': method,
        'training_period_start':
            trainingPeriodStart.toIso8601String().substring(0, 10),
        'training_period_end':
            trainingPeriodEnd.toIso8601String().substring(0, 10),
        'dependent_variable': dependentVariable,
        'weather_variables': weatherVariables,
        'sample_count': sampleCount,
        'goodness_of_fit': goodnessOfFit,
        'confidence': confidence,
        'version': modelVersion,
        'created_by': createdBy,
        'weather_dataset_id': weatherDataset?.id,
        'coefficients': coefficients,
        'warnings': passed ? <String>[] : failures,
        'calculated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
}

class ModelEvaluationResult {
  const ModelEvaluationResult({
    required this.qualityGatePassed,
    required this.qualityGateFailures,
    required this.confidence,
    required this.displayLabel,
    required this.metadata,
  });

  final bool qualityGatePassed;
  final List<String> qualityGateFailures;
  final String confidence;
  final String displayLabel;
  final Map<String, dynamic> metadata;
}
