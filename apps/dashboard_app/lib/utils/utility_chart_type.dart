import 'package:smart_meters_core/smart_meters_core.dart';

import 'site_system_navigation.dart';

/// Per-utility chart view type — never mix units across utilities.
enum UtilityChartType {
  line,
  bar,
  area,
  step,
  cumulative,
  weekday,
  ranking,
  pie,
  stackedBar,
  sourceSplit,
}

extension UtilityChartTypeMeta on UtilityChartType {
  String get label => switch (this) {
        UtilityChartType.line => 'Line',
        UtilityChartType.bar => 'Bar',
        UtilityChartType.area => 'Area',
        UtilityChartType.step => 'Step',
        UtilityChartType.cumulative => 'Cumulative',
        UtilityChartType.weekday => 'Weekday',
        UtilityChartType.ranking => 'Ranking',
        UtilityChartType.pie => 'Pie',
        UtilityChartType.stackedBar => 'Stacked',
        UtilityChartType.sourceSplit => 'Split',
      };
}

/// Shared trend / ranking views available for every utility.
const List<UtilityChartType> _baseUtilityChartTypes = [
  UtilityChartType.line,
  UtilityChartType.bar,
  UtilityChartType.area,
  UtilityChartType.step,
  UtilityChartType.cumulative,
  UtilityChartType.weekday,
  UtilityChartType.ranking,
  UtilityChartType.pie,
];

List<UtilityChartType> chartTypesForUtility(
  UtilitySystemKey system, {
  ChartBucket? bucket,
  bool isComparing = false,
}) {
  var types = switch (system) {
    UtilitySystemKey.water => [
        ..._baseUtilityChartTypes,
        UtilityChartType.sourceSplit,
      ],
    UtilitySystemKey.electricity => [
        ..._baseUtilityChartTypes,
        UtilityChartType.sourceSplit,
      ],
    UtilitySystemKey.btu => [
        ..._baseUtilityChartTypes,
      ],
    UtilitySystemKey.fuel => [
        ..._baseUtilityChartTypes,
      ],
  };

  // Stacked is meaningful only when comparing multiple meters.
  if (isComparing) {
    types = [...types, UtilityChartType.stackedBar];
  }

  // Weekday profile needs daily buckets.
  if (bucket != null && bucket != ChartBucket.daily) {
    types = [
      for (final type in types)
        if (type != UtilityChartType.weekday) type,
    ];
  }

  return List.unmodifiable(types);
}

/// Chart types available after selecting a COP or EER card.
List<UtilityChartType> chartTypesForEfficiency({ChartBucket? bucket}) {
  var types = const [
    UtilityChartType.line,
    UtilityChartType.bar,
    UtilityChartType.area,
    UtilityChartType.step,
    UtilityChartType.cumulative,
    UtilityChartType.weekday,
  ];
  if (bucket != null && bucket != ChartBucket.daily) {
    types = [
      for (final type in types)
        if (type != UtilityChartType.weekday) type,
    ];
  }
  return List.unmodifiable(types);
}

/// Chart types for comparing meters of the **same** utility only.
List<UtilityChartType> comparisonChartTypesForUtility(
  UtilitySystemKey system, {
  ChartBucket? bucket,
}) {
  const comparable = {
    UtilityChartType.line,
    UtilityChartType.bar,
    UtilityChartType.area,
    UtilityChartType.step,
    UtilityChartType.cumulative,
    UtilityChartType.weekday,
    UtilityChartType.pie,
    UtilityChartType.stackedBar,
  };
  return chartTypesForUtility(
    system,
    bucket: bucket,
    isComparing: true,
  ).where(comparable.contains).toList(growable: false);
}

String utilityChartTypeKey(String siteId, String utilityCode) =>
    '$siteId::$utilityCode';
