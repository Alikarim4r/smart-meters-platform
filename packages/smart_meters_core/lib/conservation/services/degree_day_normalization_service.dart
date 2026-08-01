import '../domain/normalization_quality_gates.dart';
import '../domain/weather_sensitive_utilities.dart';
import '../models/weather_dataset.dart';

/// Degree-day normalization (explainable). Weather-sensitive utilities only.
class DegreeDayNormalizationService {
  const DegreeDayNormalizationService();

  static const method = 'degree_day';

  /// Normalize actual consumption to a reference degree-day total.
  ///
  /// ```
  /// intensity = actual / periodDd
  /// normalized = intensity × referenceDd
  /// ```
  DegreeDayNormalizationResult normalize({
    required String utilityType,
    String? endUseTag,
    bool profileMarkedWeatherSensitive = false,
    required double actualConsumption,
    required double periodDegreeDays,
    required double referenceDegreeDays,
    required WeatherDataset? dataset,
    required String unitCode,
    int sampleCount = 0,
    double? goodnessOfFit,
    double? dataCompleteness,
    bool unitsCompatible = true,
  }) {
    final warnings = <String>[];
    final eligible = WeatherSensitiveUtilities.isEligible(
      utilityType: utilityType,
      endUseTag: endUseTag,
      profileMarkedWeatherSensitive: profileMarkedWeatherSensitive,
    );
    if (!eligible) {
      return DegreeDayNormalizationResult.notApplicable(
        actualConsumption: actualConsumption,
        unitCode: unitCode,
        reason: 'utility_not_weather_sensitive',
      );
    }

    final weatherPresent = dataset != null && periodDegreeDays > 0;
    final weatherApproved = dataset?.status.isApproved ?? false;
    final gate = NormalizationQualityGates.evaluate(
      sampleCount: sampleCount,
      method: method,
      weatherApproved: weatherApproved,
      weatherPresent: weatherPresent,
      unitsCompatible: unitsCompatible,
      goodnessOfFit: goodnessOfFit,
      dataCompleteness: dataCompleteness,
      requiresWeather: true,
    );
    if (!gate.passed) {
      return DegreeDayNormalizationResult(
        canNormalize: false,
        actualConsumption: actualConsumption,
        normalizedConsumption: null,
        weatherAdjustedBaseline: null,
        unitCode: unitCode,
        reliability: 'unreliable',
        status: 'not_reliable',
        displayLabel: NormalizationQualityGates.notReliableLabel,
        failures: gate.failures,
        warnings: warnings,
        lineage: {
          'method': method,
          'weather_dataset_id': dataset?.id,
          'period_degree_days': periodDegreeDays,
          'reference_degree_days': referenceDegreeDays,
        },
      );
    }

    final intensity = actualConsumption / periodDegreeDays;
    final normalized = intensity * referenceDegreeDays;

    return DegreeDayNormalizationResult(
      canNormalize: true,
      actualConsumption: actualConsumption,
      normalizedConsumption: normalized,
      weatherAdjustedBaseline: referenceDegreeDays > 0
          ? (actualConsumption / periodDegreeDays) * referenceDegreeDays
          : null,
      unitCode: unitCode,
      reliability: 'ok',
      status: 'computed',
      displayLabel: 'Weather-adjusted consumption',
      failures: const [],
      warnings: warnings,
      lineage: {
        'method': method,
        'weather_dataset_id': dataset!.id,
        'weather_source': dataset.source,
        'location': dataset.locationLabel,
        'period_degree_days': periodDegreeDays,
        'reference_degree_days': referenceDegreeDays,
        'intensity_per_dd': intensity,
        'sample_count': sampleCount,
        'goodness_of_fit': goodnessOfFit,
      },
    );
  }
}

class DegreeDayNormalizationResult {
  const DegreeDayNormalizationResult({
    required this.canNormalize,
    required this.actualConsumption,
    required this.normalizedConsumption,
    required this.weatherAdjustedBaseline,
    required this.unitCode,
    required this.reliability,
    required this.status,
    required this.displayLabel,
    required this.failures,
    required this.warnings,
    required this.lineage,
  });

  final bool canNormalize;
  final double actualConsumption;
  final double? normalizedConsumption;
  final double? weatherAdjustedBaseline;
  final String unitCode;
  final String reliability;
  final String status;
  final String displayLabel;
  final List<String> failures;
  final List<String> warnings;
  final Map<String, dynamic> lineage;

  factory DegreeDayNormalizationResult.notApplicable({
    required double actualConsumption,
    required String unitCode,
    required String reason,
  }) {
    return DegreeDayNormalizationResult(
      canNormalize: false,
      actualConsumption: actualConsumption,
      normalizedConsumption: null,
      weatherAdjustedBaseline: null,
      unitCode: unitCode,
      reliability: 'not_available',
      status: 'not_available',
      displayLabel: 'Weather Normalization Not Applicable',
      failures: [reason],
      warnings: const [],
      lineage: {'reason': reason},
    );
  }
}
