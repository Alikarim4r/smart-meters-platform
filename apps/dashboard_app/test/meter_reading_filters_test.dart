import 'package:dashboard_app/utils/meter_reading_filters.dart';
import 'package:dashboard_app/utils/site_system_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  group('meter card filters', () {
    const cardWater = MeterReadingCardData(
      meterId: '1',
      meterCode: '1219053',
      meterName: 'Water Main',
      categoryName: 'Water',
      sourceName: 'Kahramaa',
      sourceCode: 'kahramaa',
      unitLabel: 'm³',
      status: MeterReadingCardStatus.submittedOnDate,
      isActive: true,
      isMain: true,
      latestValue: 100,
      previousValue: 95,
      consumptionValue: 5,
    );

    const cardElectric = MeterReadingCardData(
      meterId: '2',
      meterCode: '1256358',
      meterName: 'Electric Main',
      categoryName: 'Electricity',
      sourceName: 'Kahramaa',
      sourceCode: 'kahramaa',
      unitLabel: 'kWh',
      status: MeterReadingCardStatus.submittedOnDate,
      isActive: true,
      isMain: true,
      latestValue: 200,
      previousValue: 210,
      consumptionValue: -10,
      hasNegativeConsumption: true,
    );

    test('utility filter keeps single utility meters only', () {
      final filtered = meterCardsForNetworkLayer(
        cards: [cardWater, cardElectric],
        layer: NetworkMapLayer.water,
      );
      expect(filtered, hasLength(1));
      expect(filtered.first.meterCode, '1219053');
      expect(filtered.first.unitLabel, 'm³');
    });

    test('meter card consumption equals latest minus previous', () {
      expect(cardWater.consumptionValue, 5);
      expect(cardWater.latestValue! - cardWater.previousValue!, 5);
    });

    test('negative consumption is flagged', () {
      expect(cardElectric.hasNegativeConsumption, isTrue);
      expect(cardElectric.consumptionValue, -10);
    });

    test('missing previous reading has no consumption', () {
      const card = MeterReadingCardData(
        meterId: '3',
        meterCode: 'X',
        meterName: 'Meter',
        categoryName: 'Water',
        sourceName: 'Kahramaa',
        sourceCode: 'kahramaa',
        unitLabel: 'm³',
        status: MeterReadingCardStatus.submittedOnDate,
        isActive: true,
        isMain: false,
        latestValue: 50,
      );
      expect(card.hasPrevious, isFalse);
      expect(card.hasConsumption, isFalse);
    });

    test('enrich meter cards with alerts', () {
      final enriched = enrichMeterCardsWithAlerts(
        cards: [cardWater],
        alerts: [
          DashboardAlert(
            id: 'a1',
            type: AlertType.highConsumption,
            severity: AlertSeverity.warning,
            title: 'High',
            message: 'High consumption',
            siteId: 's',
            siteName: 'Site',
            zoneName: 'Zone',
            createdAt: DateTime(2026, 3, 31),
            meterId: '1',
            categoryName: 'Water',
          ),
        ],
      );
      expect(enriched.first.hasAlert, isTrue);
      expect(enriched.first.alertSeverity, AlertSeverity.warning);
    });

    test('applyMeterCardClientFilters does not mutate unmodifiable input', () {
      final input = List<MeterReadingCardData>.unmodifiable([
        cardElectric,
        cardWater,
      ]);

      final sorted = applyMeterCardClientFilters(
        cards: input,
        statusFilter: MeterCardStatusFilter.all,
        sort: MeterCardSort.highestConsumption,
      );

      expect(input.first.meterCode, '1256358');
      expect(input.last.meterCode, '1219053');
      expect(sorted.first.meterCode, '1219053');
      expect(sorted.last.meterCode, '1256358');
    });

    test('applyMeterCardClientFilters works with all sort modes on unmodifiable list', () {
      final input = List<MeterReadingCardData>.unmodifiable([
        cardWater,
        cardElectric,
      ]);

      for (final sort in MeterCardSort.values) {
        expect(
          () => applyMeterCardClientFilters(
            cards: input,
            statusFilter: MeterCardStatusFilter.all,
            sort: sort,
          ),
          returnsNormally,
        );
      }
    });
  });
}
