import 'package:dashboard_app/utils/utility_chart_type.dart';
import 'package:dashboard_app/widgets/chart/chart_type_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'package:dashboard_app/utils/site_system_navigation.dart';

void main() {
  test('chart types stay utility-specific without mixed units', () {
    expect(chartTypesForUtility(UtilitySystemKey.water), contains(UtilityChartType.sourceSplit));
    expect(chartTypesForUtility(UtilitySystemKey.fuel), isNot(contains(UtilityChartType.sourceSplit)));
    expect(chartTypesForUtility(UtilitySystemKey.btu), contains(UtilityChartType.cop));
    expect(chartTypesForUtility(UtilitySystemKey.electricity), isNot(contains(UtilityChartType.cop)));
    expect(chartTypesForUtility(UtilitySystemKey.water), contains(UtilityChartType.pie));
    expect(
      chartTypesForUtility(UtilitySystemKey.electricity),
      isNot(contains(UtilityChartType.stackedBar)),
    );
    expect(
      chartTypesForUtility(UtilitySystemKey.electricity, isComparing: true),
      contains(UtilityChartType.stackedBar),
    );
    expect(
      comparisonChartTypesForUtility(UtilitySystemKey.water),
      isNot(contains(UtilityChartType.sourceSplit)),
    );
    expect(
      comparisonChartTypesForUtility(UtilitySystemKey.water),
      contains(UtilityChartType.pie),
    );
    expect(
      comparisonChartTypesForUtility(UtilitySystemKey.water),
      contains(UtilityChartType.stackedBar),
    );
  });

  test('weekday chart type is gated to daily buckets', () {
    expect(
      chartTypesForUtility(UtilitySystemKey.water, bucket: ChartBucket.daily),
      contains(UtilityChartType.weekday),
    );
    expect(
      chartTypesForUtility(UtilitySystemKey.water, bucket: ChartBucket.monthly),
      isNot(contains(UtilityChartType.weekday)),
    );
  });

  test('source split aggregates consumption by source', () {
    const cards = [
      MeterReadingCardData(
        meterId: '1',
        meterCode: 'A',
        meterName: 'A',
        categoryName: 'Water',
        sourceName: 'Kahramaa',
        sourceCode: 'kahramaa',
        unitLabel: 'm³',
        status: MeterReadingCardStatus.submittedOnDate,
        isActive: true,
        isMain: true,
        consumptionValue: 10,
      ),
      MeterReadingCardData(
        meterId: '2',
        meterCode: 'B',
        meterName: 'B',
        categoryName: 'Water',
        sourceName: 'TSE',
        sourceCode: 'tse',
        unitLabel: 'm³',
        status: MeterReadingCardStatus.submittedOnDate,
        isActive: true,
        isMain: false,
        consumptionValue: 5,
      ),
    ];

    final split = sourceSplitFromMeterCards(cards);
    expect(split, hasLength(2));
    expect(split.first.label, 'Kahramaa');
    expect(split.first.value, 10);
  });

  test('source split from ranking uses chart-period totals', () {
    const ranking = [
      CategoryRankingItem(
        meterId: '1',
        meterName: 'A',
        meterCode: 'A',
        totalConsumption: 100,
      ),
      CategoryRankingItem(
        meterId: '2',
        meterName: 'B',
        meterCode: 'B',
        totalConsumption: 40,
      ),
    ];
    const cards = [
      MeterReadingCardData(
        meterId: '1',
        meterCode: 'A',
        meterName: 'A',
        categoryName: 'Water',
        sourceName: 'Kahramaa',
        sourceCode: 'kahramaa',
        unitLabel: 'm³',
        status: MeterReadingCardStatus.submittedOnDate,
        isActive: true,
        isMain: true,
        consumptionValue: 1,
      ),
      MeterReadingCardData(
        meterId: '2',
        meterCode: 'B',
        meterName: 'B',
        categoryName: 'Water',
        sourceName: 'TSE',
        sourceCode: 'tse',
        unitLabel: 'm³',
        status: MeterReadingCardStatus.submittedOnDate,
        isActive: true,
        isMain: false,
        consumptionValue: 1,
      ),
    ];
    final split = sourceSplitFromRanking(ranking: ranking, cards: cards);
    expect(split.first.label, 'Kahramaa');
    expect(split.first.value, 100);
    expect(split.last.value, 40);
  });
}
