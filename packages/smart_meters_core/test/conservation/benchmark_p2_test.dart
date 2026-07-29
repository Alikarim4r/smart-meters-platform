import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

void main() {
  const service = BenchmarkingService();

  group('BenchmarkingService.computeIntensity', () {
    test('missing m2 and occupancy → Normalization Data Missing', () {
      final r = service.computeIntensity(consumption: 1000);
      expect(r.missingNormalization, isTrue);
      expect(r.message, IntensityResult.normalizationMissingMessage);
      expect(r.perM2, isNull);
      expect(r.perOccupant, isNull);
    });

    test('does not invent floor area', () {
      final r = service.computeIntensity(
        consumption: 500,
        floorAreaM2: null,
        occupancy: 10,
      );
      expect(r.perOccupant, closeTo(50, 1e-9));
      expect(r.perM2, isNull);
      expect(r.missingNormalization, isTrue);
      expect(r.message, IntensityResult.normalizationMissingMessage);
    });

    test('full normalization computes both intensities', () {
      final r = service.computeIntensity(
        consumption: 1000,
        floorAreaM2: 200,
        occupancy: 50,
      );
      expect(r.perM2, closeTo(5, 1e-9));
      expect(r.perOccupant, closeTo(20, 1e-9));
      expect(r.missingNormalization, isFalse);
    });
  });

  group('BenchmarkingService.comparePeers / rankSites', () {
    test('blocks compare when units differ', () {
      final r = service.comparePeers(
        sites: [
          const BenchmarkSiteSnapshot(
            siteId: 'a',
            consumption: 100,
            unitCode: 'm3',
            confidenceScore: 80,
            completeness: 1,
            floorAreaM2: 100,
          ),
          const BenchmarkSiteSnapshot(
            siteId: 'b',
            consumption: 200,
            unitCode: 'kWh',
            confidenceScore: 80,
            completeness: 1,
            floorAreaM2: 100,
          ),
        ],
      );
      expect(r.comparable, isFalse);
      expect(r.warnings.any((w) => w.contains('Incompatible units')), isTrue);
      expect(r.rankings, isEmpty);
    });

    test('warns Not normalized when peer metadata missing', () {
      final r = service.comparePeers(
        sites: [
          const BenchmarkSiteSnapshot(
            siteId: 'a',
            consumption: 100,
            unitCode: 'm3',
            confidenceScore: 80,
            completeness: 1,
          ),
          const BenchmarkSiteSnapshot(
            siteId: 'b',
            consumption: 200,
            unitCode: 'm3',
            confidenceScore: 70,
            completeness: 0.9,
          ),
        ],
        peerGroup: ConservationPeerGroup.school,
      );
      expect(r.comparable, isTrue);
      expect(
        r.warnings.any((w) => w.contains(BenchmarkingService.notNormalizedWarning)),
        isTrue,
      );
      // Without m2, bestPerforming must be empty (not lowest absolute).
      expect(
        r.rankings[BenchmarkRankingCategory.bestPerforming],
        isEmpty,
      );
      expect(
        r.rankings[BenchmarkRankingCategory.highestConsumption]!.first,
        'b',
      );
    });

    test('bestPerforming uses intensity when normalized — not lowest absolute', () {
      // Site a: low absolute but high intensity; site b: high absolute, low intensity.
      final r = service.comparePeers(
        sites: [
          const BenchmarkSiteSnapshot(
            siteId: 'small_high_intensity',
            consumption: 100,
            unitCode: 'm3',
            confidenceScore: 90,
            completeness: 1,
            floorAreaM2: 10, // intensity 10
            peerGroup: ConservationPeerGroup.office,
          ),
          const BenchmarkSiteSnapshot(
            siteId: 'large_low_intensity',
            consumption: 500,
            unitCode: 'm3',
            confidenceScore: 90,
            completeness: 1,
            floorAreaM2: 200, // intensity 2.5
            peerGroup: ConservationPeerGroup.office,
          ),
        ],
        peerGroup: ConservationPeerGroup.office,
      );
      expect(r.metricKind, BenchmarkMetricKind.intensityPerM2);
      expect(
        r.rankings[BenchmarkRankingCategory.bestPerforming]!.first,
        'large_low_intensity',
      );
      expect(
        r.rankings[BenchmarkRankingCategory.highestConsumption]!.first,
        'large_low_intensity',
      );
      // Lowest absolute is small_high_intensity — must NOT win bestPerforming.
      expect(
        r.rankings[BenchmarkRankingCategory.bestPerforming]!.first,
        isNot('small_high_intensity'),
      );
    });

    test('ranking categories include needsAttention / lowestConfidence / increase', () {
      final rankings = service.rankSites(
        sites: [
          const BenchmarkSiteSnapshot(
            siteId: 'low_conf',
            consumption: 100,
            unitCode: 'm3',
            confidenceScore: 40,
            completeness: 0.4,
            previousConsumption: 80,
            floorAreaM2: 50,
          ),
          const BenchmarkSiteSnapshot(
            siteId: 'rising',
            consumption: 200,
            unitCode: 'm3',
            confidenceScore: 90,
            completeness: 1,
            previousConsumption: 100,
            floorAreaM2: 50,
          ),
        ],
        preferIntensity: true,
      );
      expect(rankings[BenchmarkRankingCategory.needsAttention], contains('low_conf'));
      expect(rankings[BenchmarkRankingCategory.lowestConfidence]!.first, 'low_conf');
      expect(rankings[BenchmarkRankingCategory.highestIncrease]!.first, 'rising');
    });
  });
}
