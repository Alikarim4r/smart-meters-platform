import 'site_conservation_profile.dart';

enum BenchmarkMetricKind {
  absoluteConsumption,
  intensityPerM2,
  intensityPerOccupant,
}

enum BenchmarkRankingCategory {
  /// Best by intensity when normalized — never by lowest absolute alone.
  bestPerforming,
  needsAttention,
  highestConsumption,
  highestIncrease,
  lowestConfidence,
}

/// Snapshot of one site for peer comparison (caller supplies consumption).
class BenchmarkSiteSnapshot {
  const BenchmarkSiteSnapshot({
    required this.siteId,
    required this.consumption,
    required this.unitCode,
    required this.confidenceScore,
    required this.completeness,
    this.floorAreaM2,
    this.occupancyCount,
    this.peerGroup,
    this.previousConsumption,
    this.label,
  });

  final String siteId;
  final String? label;
  final double consumption;
  final String unitCode;
  final int confidenceScore;
  final double completeness;
  final double? floorAreaM2;
  final int? occupancyCount;
  final ConservationPeerGroup? peerGroup;
  final double? previousConsumption;

  bool get hasFloorArea => floorAreaM2 != null && floorAreaM2! > 0;
  bool get hasOccupancy => occupancyCount != null && occupancyCount! > 0;
}

/// Intensity (normalized consumption). Never invents m² / occupancy.
class IntensityResult {
  const IntensityResult({
    required this.consumption,
    required this.missingNormalization,
    required this.message,
    this.perM2,
    this.perOccupant,
    this.floorAreaM2,
    this.occupancyCount,
  });

  static const normalizationMissingMessage = 'Normalization Data Missing';

  final double consumption;
  final double? perM2;
  final double? perOccupant;
  final double? floorAreaM2;
  final int? occupancyCount;

  /// True when floor area and/or occupancy needed for intensity is absent.
  final bool missingNormalization;
  final String message;

  bool get hasIntensity => perM2 != null || perOccupant != null;
}

class BenchmarkComparisonResult {
  const BenchmarkComparisonResult({
    required this.sites,
    required this.unitCode,
    required this.metricKind,
    required this.comparable,
    required this.warnings,
    required this.rankings,
    this.peerGroup,
    this.message,
  });

  final List<BenchmarkSiteSnapshot> sites;
  final String unitCode;
  final BenchmarkMetricKind metricKind;
  final ConservationPeerGroup? peerGroup;
  final bool comparable;
  final List<String> warnings;
  final Map<BenchmarkRankingCategory, List<String>> rankings;
  final String? message;
}
