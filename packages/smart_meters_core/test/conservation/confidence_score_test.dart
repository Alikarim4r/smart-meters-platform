import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

void main() {
  group('buildConfidenceBreakdown', () {
    test('starts at 100 with empty findings', () {
      final c = buildConfidenceBreakdown(const []);
      expect(c.base, 100);
      expect(c.finalScore, 100);
      expect(c.explanationLines, [
        'Base confidence: 100',
        'Final confidence: 100',
      ]);
    });

    test('applies deterministic stacked deductions with explanation', () {
      final findings = [
        const DataQualityFinding(
          code: DataQualityFindingCode.missingRequiredPhoto,
          severity: DataQualitySeverity.warning,
          title: 'Missing Required Photo',
          detail: 'x',
          meterId: 'm1',
          readingId: 'r1',
        ),
        const DataQualityFinding(
          code: DataQualityFindingCode.correctionInAnalysisPeriod,
          severity: DataQualitySeverity.info,
          title: 'Correction',
          detail: 'x',
          meterId: 'm1',
        ),
        const DataQualityFinding(
          code: DataQualityFindingCode.incompleteExpectedReadings,
          severity: DataQualitySeverity.warning,
          title: 'Incomplete',
          detail: 'x',
        ),
      ];

      final c = buildConfidenceBreakdown(findings);
      // 100 -20 -10 -15 = 55
      expect(c.finalScore, 55);
      expect(
        c.explanationLines,
        containsAll([
          'Base confidence: 100',
          'Missing required photo: -20',
          'Correction in analysis period: -10',
          'Incomplete expected readings: -15',
          'Final confidence: 55',
        ]),
      );
    });

    test('floors at 0', () {
      final findings = List.generate(
        20,
        (i) => DataQualityFinding(
          code: DataQualityFindingCode.unusualConsumptionChange,
          severity: DataQualitySeverity.warning,
          title: 'Unusual Consumption Change',
          detail: 'x',
          meterId: 'm$i',
          readingId: 'r$i',
        ),
      );
      final c = buildConfidenceBreakdown(findings);
      expect(c.finalScore, 0);
    });

    test('dedupes missing photo per reading', () {
      final findings = [
        const DataQualityFinding(
          code: DataQualityFindingCode.missingRequiredPhoto,
          severity: DataQualitySeverity.warning,
          title: 'Missing Required Photo',
          detail: 'x',
          meterId: 'm1',
          readingId: 'r1',
        ),
        const DataQualityFinding(
          code: DataQualityFindingCode.missingRequiredPhoto,
          severity: DataQualitySeverity.warning,
          title: 'Missing Required Photo',
          detail: 'x',
          meterId: 'm1',
          readingId: 'r1',
        ),
      ];
      final c = buildConfidenceBreakdown(findings);
      expect(c.finalScore, 80);
      expect(c.adjustments, hasLength(1));
    });
  });

  group('ConservationFeatureFlags', () {
    test('P1A keys present and default semantics are OFF via absence', () {
      expect(
        ConservationFeatureFlags.all,
        containsAll([
          ConservationFeatureFlags.conservationModule,
          ConservationFeatureFlags.dataQuality,
        ]),
      );
    });
  });
}
