import '../models/benchmark_result.dart';
import '../models/site_conservation_profile.dart';

/// Intensity + peer benchmarking (read-only). Never invents m² / occupancy.
class BenchmarkingService {
  const BenchmarkingService();

  static const method = 'conservation_benchmarking_v1';
  static const notNormalizedWarning =
      'Not normalized / Different site characteristics';

  IntensityResult computeIntensity({
    required double consumption,
    double? floorAreaM2,
    int? occupancy,
  }) {
    final hasArea = floorAreaM2 != null && floorAreaM2 > 0;
    final hasOcc = occupancy != null && occupancy > 0;
    if (!hasArea && !hasOcc) {
      return IntensityResult(
        consumption: consumption,
        missingNormalization: true,
        message: IntensityResult.normalizationMissingMessage,
        floorAreaM2: floorAreaM2,
        occupancyCount: occupancy,
      );
    }
    return IntensityResult(
      consumption: consumption,
      perM2: hasArea ? consumption / floorAreaM2 : null,
      perOccupant: hasOcc ? consumption / occupancy : null,
      floorAreaM2: floorAreaM2,
      occupancyCount: occupancy,
      missingNormalization: !hasArea || !hasOcc,
      message: (!hasArea || !hasOcc)
          ? IntensityResult.normalizationMissingMessage
          : 'OK',
    );
  }

  /// Compare peer sites. Blocks when units differ. Warns when metadata missing.
  BenchmarkComparisonResult comparePeers({
    required List<BenchmarkSiteSnapshot> sites,
    ConservationPeerGroup? peerGroup,
  }) {
    final warnings = <String>[];
    if (sites.isEmpty) {
      return BenchmarkComparisonResult(
        sites: const [],
        unitCode: '',
        metricKind: BenchmarkMetricKind.absoluteConsumption,
        peerGroup: peerGroup,
        comparable: false,
        warnings: ['No sites provided for peer comparison.'],
        rankings: const {},
        message: 'Insufficient Data',
      );
    }

    final unitCodes = sites.map((s) => s.unitCode).toSet();
    if (unitCodes.length > 1) {
      return BenchmarkComparisonResult(
        sites: sites,
        unitCode: sites.first.unitCode,
        metricKind: BenchmarkMetricKind.absoluteConsumption,
        peerGroup: peerGroup,
        comparable: false,
        warnings: [
          'Incompatible units across sites (${unitCodes.join(', ')}) — '
          'cross-site compare blocked.',
        ],
        rankings: const {},
        message: 'Insufficient Data: units differ',
      );
    }
    final unitCode = sites.first.unitCode;

    var filtered = sites;
    if (peerGroup != null) {
      filtered = [
        for (final s in sites)
          if (s.peerGroup == null || s.peerGroup == peerGroup) s,
      ];
      final missingPeer = sites.where((s) => s.peerGroup == null).length;
      if (missingPeer > 0) {
        warnings.add(
          '$notNormalizedWarning — $missingPeer site(s) lack peer_group; '
          'included cautiously.',
        );
      }
    }

    final missingNorm = filtered
        .where((s) => !s.hasFloorArea && !s.hasOccupancy)
        .length;
    if (missingNorm > 0) {
      warnings.add(
        '$notNormalizedWarning — $missingNorm site(s) lack floor area / '
        'occupancy (${IntensityResult.normalizationMissingMessage}).',
      );
    }

    final allHaveArea = filtered.every((s) => s.hasFloorArea);
    final metric = allHaveArea
        ? BenchmarkMetricKind.intensityPerM2
        : BenchmarkMetricKind.absoluteConsumption;

    if (!allHaveArea) {
      warnings.add(
        'Ranking by absolute consumption only is not "best performing" — '
        'intensity requires normalization data.',
      );
    }

    final rankings = rankSites(
      sites: filtered,
      preferIntensity: allHaveArea,
    );

    return BenchmarkComparisonResult(
      sites: filtered,
      unitCode: unitCode,
      metricKind: metric,
      peerGroup: peerGroup,
      comparable: true,
      warnings: warnings,
      rankings: rankings,
      message: allHaveArea
          ? 'Comparable on intensity (per m²)'
          : 'Comparable on absolute consumption only (not normalized)',
    );
  }

  /// Rank sites into categories.
  ///
  /// [bestPerforming] uses intensity when [preferIntensity] is true; otherwise
  /// that category is empty (never treat lowest absolute as best).
  Map<BenchmarkRankingCategory, List<String>> rankSites({
    required List<BenchmarkSiteSnapshot> sites,
    bool preferIntensity = false,
  }) {
    if (sites.isEmpty) return {};

    final byConsumption = [...sites]
      ..sort((a, b) => b.consumption.compareTo(a.consumption));
    final highestConsumption = byConsumption.map((s) => s.siteId).toList();

    final withIncrease = [
      for (final s in sites)
        if (s.previousConsumption != null && s.previousConsumption! > 0)
          s,
    ]..sort((a, b) {
        final aPct =
            (a.consumption - a.previousConsumption!) / a.previousConsumption!;
        final bPct =
            (b.consumption - b.previousConsumption!) / b.previousConsumption!;
        return bPct.compareTo(aPct);
      });
    final highestIncrease = withIncrease.map((s) => s.siteId).toList();

    final byConfidence = [...sites]
      ..sort((a, b) => a.confidenceScore.compareTo(b.confidenceScore));
    final lowestConfidence = byConfidence.map((s) => s.siteId).toList();

    final needsAttention = [
      for (final s in sites)
        if (s.confidenceScore < 60 || s.completeness < 0.5) s.siteId,
    ];

    List<String> bestPerforming = const [];
    if (preferIntensity) {
      final withArea = [
        for (final s in sites)
          if (s.hasFloorArea) s,
      ]..sort((a, b) {
          final ai = a.consumption / a.floorAreaM2!;
          final bi = b.consumption / b.floorAreaM2!;
          return ai.compareTo(bi); // lower intensity = better
        });
      bestPerforming = withArea.map((s) => s.siteId).toList();
    }

    return {
      BenchmarkRankingCategory.bestPerforming: bestPerforming,
      BenchmarkRankingCategory.needsAttention: needsAttention,
      BenchmarkRankingCategory.highestConsumption: highestConsumption,
      BenchmarkRankingCategory.highestIncrease: highestIncrease,
      BenchmarkRankingCategory.lowestConfidence: lowestConfidence,
    };
  }
}
