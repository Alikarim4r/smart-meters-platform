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

  group('buildVirtualMeterReadingCardData', () {
    Meter virtualMeter() => Meter(
          id: 'vm1',
          siteId: 's1',
          meterCode: 'VM-SUM',
          nameEn: 'Sum',
          nameAr: 'مجموع',
          categoryId: 'c1',
          sourceId: 'src1',
          unitId: 'u1',
          category: MeterCategory.electricity,
          source: MeterSource.kahramaa,
          unit: MeterUnit.kwh,
          level: MeterLevel.main,
          unitToBaseFactor: 1,
          baseUnit: 'kwh',
          meterMultiplier: 1,
          meterKind: MeterKind.virtual,
          calculationType: CalculationType.sumChildren,
          isActive: true,
          includeInDashboard: true,
          sortOrder: 0,
        );

    MeterReading reading({
      required String id,
      required String meterId,
      required DateTime date,
      required double value,
    }) =>
        MeterReading(
          id: id,
          siteId: 's1',
          meterId: meterId,
          readingDate: date,
          rawValue: value,
          normalizedValue: value,
          enteredAt: date,
        );

    test('sums member latest/previous and consumption', () {
      final card = buildVirtualMeterReadingCardData(
        meter: virtualMeter(),
        memberIds: const ['a', 'b'],
        latestByMeter: {
          'a': reading(
            id: 'la',
            meterId: 'a',
            date: DateTime(2026, 4, 30),
            value: 100,
          ),
          'b': reading(
            id: 'lb',
            meterId: 'b',
            date: DateTime(2026, 4, 30),
            value: 50,
          ),
        },
        previousByMeter: {
          'a': reading(
            id: 'pa',
            meterId: 'a',
            date: DateTime(2026, 3, 31),
            value: 80,
          ),
          'b': reading(
            id: 'pb',
            meterId: 'b',
            date: DateTime(2026, 3, 31),
            value: 40,
          ),
        },
      );

      expect(card.isVirtual, isTrue);
      expect(card.latestValue, 150);
      expect(card.previousValue, 120);
      expect(card.consumptionValue, 30);
      expect(card.status, MeterReadingCardStatus.submittedOnDate);
    });

    test('pending when any member latest is missing', () {
      final card = buildVirtualMeterReadingCardData(
        meter: virtualMeter(),
        memberIds: const ['a', 'b'],
        latestByMeter: {
          'a': reading(
            id: 'la',
            meterId: 'a',
            date: DateTime(2026, 4, 30),
            value: 100,
          ),
        },
        previousByMeter: const {},
      );

      expect(card.latestValue, isNull);
      expect(card.status, MeterReadingCardStatus.pendingOnDate);
    });

    test('compareMeterReadingCards pins virtual first', () {
      const physical = MeterReadingCardData(
        meterId: 'p1',
        meterCode: 'AAA',
        meterName: 'A',
        categoryName: 'Electricity',
        sourceName: 'S',
        sourceCode: 's',
        unitLabel: 'kWh',
        status: MeterReadingCardStatus.submittedOnDate,
        isActive: true,
        isMain: true,
        isVirtual: false,
      );
      const virtual = MeterReadingCardData(
        meterId: 'v1',
        meterCode: 'ZZZ',
        meterName: 'Z',
        categoryName: 'Electricity',
        sourceName: 'S',
        sourceCode: 's',
        unitLabel: 'kWh',
        status: MeterReadingCardStatus.submittedOnDate,
        isActive: true,
        isMain: true,
        isVirtual: true,
      );
      expect(compareMeterReadingCards(virtual, physical, 'meter_code'), -1);
      expect(compareMeterReadingCards(physical, virtual, 'meter_code'), 1);
    });
  });
}
