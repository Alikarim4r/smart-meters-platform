import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

QualityReadingInput _r({
  required String id,
  required String meterId,
  required DateTime date,
  required double value,
  String? photo,
}) {
  return QualityReadingInput(
    readingId: id,
    meterId: meterId,
    readingDate: date,
    rawValue: value,
    normalizedValue: value,
    imageStoragePath: photo,
  );
}

void main() {
  group('DataQualityService', () {
    const service = DataQualityService();

    test('no frequency configured → no missing-reading findings, completeness null',
        () {
      final result = service.evaluate(
        DataQualityRuleContext(
          siteId: 'site-1',
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 10),
          photoRequired: false,
          highConsumptionMultiplier: 3,
          meters: [
            QualityMeterInput(
              meterId: 'm1',
              meterCode: 'W-1',
              isActive: true,
              includeInDashboard: true,
              // Only 2 readings → cannot infer interval; no explicit interval.
              readings: [
                _r(
                  id: 'a',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 2),
                  value: 100,
                ),
                _r(
                  id: 'b',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 8),
                  value: 120,
                ),
              ],
            ),
          ],
        ),
      );

      expect(result.meta.dataCompleteness, isNull);
      expect(
        result.findings.where(
          (f) =>
              f.code == DataQualityFindingCode.missingExpectedReading ||
              f.code == DataQualityFindingCode.incompleteExpectedReadings,
        ),
        isEmpty,
      );
      expect(result.sourceReadings, hasLength(2));
    });

    test('photo_required=false → missing photo does not reduce confidence', () {
      final result = service.evaluate(
        DataQualityRuleContext(
          siteId: 'site-1',
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 10),
          photoRequired: false,
          highConsumptionMultiplier: 3,
          meters: [
            QualityMeterInput(
              meterId: 'm1',
              meterCode: 'W-1',
              isActive: true,
              includeInDashboard: true,
              expectedIntervalDays: 7,
              readings: [
                _r(
                  id: 'a',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 2),
                  value: 100,
                ),
              ],
            ),
          ],
        ),
      );

      expect(
        result.findings.where(
          (f) => f.code == DataQualityFindingCode.missingRequiredPhoto,
        ),
        isEmpty,
      );
      expect(result.confidence.finalScore, 100);
    });

    test('photo_required=true without photo → finding and -20 confidence', () {
      final result = service.evaluate(
        DataQualityRuleContext(
          siteId: 'site-1',
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 10),
          photoRequired: true,
          highConsumptionMultiplier: 3,
          meters: [
            QualityMeterInput(
              meterId: 'm1',
              meterCode: 'W-1',
              isActive: true,
              includeInDashboard: true,
              expectedIntervalDays: 30,
              readings: [
                _r(
                  id: 'a',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 2),
                  value: 100,
                ),
              ],
            ),
          ],
        ),
      );

      expect(
        result.findings.any(
          (f) => f.code == DataQualityFindingCode.missingRequiredPhoto,
        ),
        isTrue,
      );
      expect(result.confidence.finalScore, 80);
      expect(
        result.confidence.explanationLines,
        containsAll([
          'Base confidence: 100',
          'Missing required photo: -20',
          'Final confidence: 80',
        ]),
      );
    });

    test('unreasonable jump labeled Unusual Consumption Change (not Leak)', () {
      final result = service.evaluate(
        DataQualityRuleContext(
          siteId: 'site-1',
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 30),
          photoRequired: false,
          highConsumptionMultiplier: 3,
          meters: [
            QualityMeterInput(
              meterId: 'm1',
              meterCode: 'W-1',
              isActive: true,
              includeInDashboard: true,
              expectedIntervalDays: 7,
              readings: [
                _r(
                  id: '1',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 1),
                  value: 100,
                ),
                _r(
                  id: '2',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 8),
                  value: 110,
                ),
                _r(
                  id: '3',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 15),
                  value: 120,
                ),
                _r(
                  id: '4',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 22),
                  value: 200,
                ),
              ],
            ),
          ],
        ),
      );

      final jump = result.findings.where(
        (f) => f.code == DataQualityFindingCode.unusualConsumptionChange,
      );
      expect(jump, isNotEmpty);
      expect(jump.first.title, 'Unusual Consumption Change');
      expect(jump.first.detail.toLowerCase(), isNot(contains('leak')));
      expect(jump.first.detail.toLowerCase(), isNot(contains('waste')));
      expect(jump.first.detail.toLowerCase(), isNot(contains('fault')));
    });

    test('lower reading with possible rollover → review, not invalid', () {
      final findings = evaluateDataQualityRules(
        DataQualityRuleContext(
          siteId: 'site-1',
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 30),
          photoRequired: false,
          highConsumptionMultiplier: 3,
          meters: [
            QualityMeterInput(
              meterId: 'm1',
              meterCode: 'W-1',
              isActive: true,
              includeInDashboard: true,
              meterMaxValue: 10000,
              readings: [
                _r(
                  id: '1',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 1),
                  value: 9900,
                ),
                _r(
                  id: '2',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 10),
                  value: 50,
                ),
              ],
            ),
          ],
        ),
      );

      expect(
        findings.any(
          (f) => f.code == DataQualityFindingCode.possibleRolloverOrReset,
        ),
        isTrue,
      );
      expect(
        findings.every((f) => f.title == 'Reading Requires Review'),
        isTrue,
      );
      expect(
        findings.any((f) => f.title.toLowerCase().contains('invalid')),
        isFalse,
      );
    });

    test('lower reading with correction history → requires review only', () {
      final findings = evaluateDataQualityRules(
        DataQualityRuleContext(
          siteId: 'site-1',
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 30),
          photoRequired: false,
          highConsumptionMultiplier: 3,
          meters: [
            QualityMeterInput(
              meterId: 'm1',
              meterCode: 'W-1',
              isActive: true,
              includeInDashboard: true,
              correctionCountInPeriod: 1,
              readings: [
                _r(
                  id: '1',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 1),
                  value: 200,
                ),
                _r(
                  id: '2',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 10),
                  value: 150,
                ),
              ],
            ),
          ],
        ),
      );

      final lower = findings.where(
        (f) =>
            f.code == DataQualityFindingCode.readingRequiresReview &&
            f.meterId == 'm1',
      );
      expect(lower, isNotEmpty);
      expect(
        lower.first.metadata['possible_cause'],
        'correction_history',
      );
    });

    test('low confidence still retains source readings', () {
      final result = service.evaluate(
        DataQualityRuleContext(
          siteId: 'site-1',
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 30),
          photoRequired: true,
          highConsumptionMultiplier: 3,
          meters: [
            QualityMeterInput(
              meterId: 'm1',
              meterCode: 'W-1',
              isActive: true,
              includeInDashboard: true,
              expectedIntervalDays: 7,
              correctionCountInPeriod: 2,
              readings: [
                _r(
                  id: '1',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 1),
                  value: 100,
                  photo: null,
                ),
                _r(
                  id: '2',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 20),
                  value: 500,
                  photo: null,
                ),
              ],
            ),
          ],
        ),
      );

      expect(result.confidence.finalScore, lessThan(100));
      expect(result.sourceReadings.length, 2);
      expect(result.sourceReadings.first.rawValue, 100);
    });

    test('explicit interval detects incomplete expected readings', () {
      final result = service.evaluate(
        DataQualityRuleContext(
          siteId: 'site-1',
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 28),
          photoRequired: false,
          highConsumptionMultiplier: 3,
          meters: [
            QualityMeterInput(
              meterId: 'm1',
              meterCode: 'W-1',
              isActive: true,
              includeInDashboard: true,
              expectedIntervalDays: 7,
              readings: [
                _r(
                  id: '1',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 1),
                  value: 10,
                ),
                _r(
                  id: '2',
                  meterId: 'm1',
                  date: DateTime(2026, 7, 25),
                  value: 20,
                ),
              ],
            ),
          ],
        ),
      );

      expect(
        result.findings.any(
          (f) => f.code == DataQualityFindingCode.incompleteExpectedReadings,
        ),
        isTrue,
      );
      expect(result.meta.dataCompleteness, isNotNull);
    });
  });

  group('looksLikePossibleRollover', () {
    test('detects sharp drop near capacity', () {
      expect(
        looksLikePossibleRollover(
          previous: 9500,
          current: 100,
          meterMaxValue: 10000,
        ),
        isTrue,
      );
    });

    test('normal decrease is not rollover', () {
      expect(
        looksLikePossibleRollover(previous: 200, current: 180),
        isFalse,
      );
    });
  });
}
