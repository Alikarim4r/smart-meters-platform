/// Weather normalization eligibility — do not weather-normalize every utility.
abstract final class WeatherSensitiveUtilities {
  /// Utility types that may use weather normalization when metadata says so.
  static const eligibleUtilityTypes = <String>{
    'electricity',
    'cooling',
  };

  /// End-use / profile tags that indicate weather sensitivity.
  static const weatherSensitiveTags = <String>{
    'cooling_electricity',
    'chilled_water',
    'hvac',
    'hvac_energy',
    'chw',
  };

  /// True only when utility is eligible AND (optional) tag confirms weather link.
  /// Water and non-HVAC electricity without a weather tag → false.
  static bool isEligible({
    required String utilityType,
    String? endUseTag,
    bool profileMarkedWeatherSensitive = false,
  }) {
    final u = utilityType.trim().toLowerCase();
    if (!eligibleUtilityTypes.contains(u)) return false;
    if (profileMarkedWeatherSensitive) return true;
    if (endUseTag == null || endUseTag.trim().isEmpty) {
      // Cooling utility is inherently weather-linked; bare electricity is not.
      return u == 'cooling';
    }
    final tag = endUseTag.trim().toLowerCase();
    return weatherSensitiveTags.contains(tag);
  }
}
