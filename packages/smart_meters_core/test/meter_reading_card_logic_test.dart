import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  group('calculateMeterReadingConsumption', () {
    test('returns latest minus previous', () {
      expect(
        calculateMeterReadingConsumption(latestValue: 120, previousValue: 100),
        20,
      );
    });

    test('returns null when previous missing', () {
      expect(
        calculateMeterReadingConsumption(latestValue: 120, previousValue: null),
        isNull,
      );
    });

    test('detects negative consumption', () {
      final consumption = calculateMeterReadingConsumption(
        latestValue: 90,
        previousValue: 100,
      );
      expect(isNegativeMeterConsumption(consumption), isTrue);
    });
  });

  group('buildMeterReadingCardData', () {
    final meter = Meter(
      id: 'm1',
      siteId: 's1',
      meterCode: 'WM-01',
      nameEn: 'Water Main',
      nameAr: 'Water',
      categoryId: 'c1',
      sourceId: 'src1',
      unitId: 'u1',
      category: MeterCategory.water,
      source: MeterSource.kahramaa,
      unit: MeterUnit.m3,
      level: MeterLevel.main,
      unitToBaseFactor: 1,
      baseUnit: 'm3',
      meterMultiplier: 1,
      meterKind: MeterKind.physical,
      calculationType: CalculationType.directReading,
      isActive: true,
      includeInDashboard: true,
      sortOrder: 1,
    );

    test('maps submitted card with consumption', () {
      final card = buildMeterReadingCardData(
        meter: meter,
        businessDate: DateTime(2026, 3, 31),
        latestOnDate: MeterReading(
          id: 'r2',
          siteId: 's1',
          meterId: 'm1',
          readingDate: DateTime(2026, 3, 31),
          rawValue: 150,
          normalizedValue: 150,
          enteredAt: DateTime(2026, 3, 31, 10),
          imageStoragePath: 'site/meter.jpg',
        ),
        previousReading: MeterReading(
          id: 'r1',
          siteId: 's1',
          meterId: 'm1',
          readingDate: DateTime(2026, 3, 30),
          rawValue: 140,
          normalizedValue: 140,
          enteredAt: DateTime(2026, 3, 30, 10),
        ),
      );

      expect(card.status, MeterReadingCardStatus.submittedOnDate);
      expect(card.consumptionValue, 10);
      expect(card.hasPhoto, isTrue);
      expect(card.previousHasPhoto, isFalse);
      expect(card.previousReadingId, 'r1');
      expect(card.isMain, isTrue);
    });

    test('maps previous reading photo fields', () {
      final card = buildMeterReadingCardData(
        meter: meter,
        businessDate: DateTime(2026, 3, 31),
        latestOnDate: MeterReading(
          id: 'r2',
          siteId: 's1',
          meterId: 'm1',
          readingDate: DateTime(2026, 3, 31),
          rawValue: 150,
          normalizedValue: 150,
          enteredAt: DateTime(2026, 3, 31, 10),
        ),
        previousReading: MeterReading(
          id: 'r1',
          siteId: 's1',
          meterId: 'm1',
          readingDate: DateTime(2026, 3, 30),
          rawValue: 140,
          normalizedValue: 140,
          enteredAt: DateTime(2026, 3, 30, 10),
          imageStoragePath: 'site/prev.jpg',
        ),
      );

      expect(card.previousHasPhoto, isTrue);
      expect(card.previousImageStoragePath, 'site/prev.jpg');
      expect(card.previousReadingId, 'r1');
      expect(card.parentMeterId, isNull);
      expect(card.isMain, isTrue);
    });

    test('pending when active and no latest on date', () {
      final card = buildMeterReadingCardData(
        meter: meter,
        businessDate: DateTime(2026, 3, 31),
        latestOnDate: null,
        previousReading: MeterReading(
          id: 'r1',
          siteId: 's1',
          meterId: 'm1',
          readingDate: DateTime(2026, 3, 30),
          rawValue: 140,
          normalizedValue: 140,
          enteredAt: DateTime(2026, 3, 30, 10),
        ),
      );

      expect(card.status, MeterReadingCardStatus.pendingOnDate);
      expect(card.consumptionValue, isNull);
    });
  });

  group('matchesMeterReadingStatusFilter', () {
    const card = MeterReadingCardData(
      meterId: 'm1',
      meterCode: 'WM-01',
      meterName: 'Water',
      categoryName: 'Water',
      sourceName: 'Kahramaa',
      sourceCode: 'kahramaa',
      unitLabel: 'm³',
      status: MeterReadingCardStatus.submittedOnDate,
      isActive: true,
      isMain: true,
      consumptionValue: -2,
      hasNegativeConsumption: true,
      hasAlert: true,
      hasPhoto: false,
    );

    test('filters utility statuses', () {
      expect(
        matchesMeterReadingStatusFilter(card, 'negative_consumption'),
        isTrue,
      );
      expect(matchesMeterReadingStatusFilter(card, 'has_alert'), isTrue);
      expect(matchesMeterReadingStatusFilter(card, 'missing_photo'), isTrue);
    });
  });
}
