import 'package:dashboard_app/providers/chart_providers.dart';
import 'package:dashboard_app/providers/meter_reading_card_providers.dart';
import 'package:dashboard_app/theme/dashboard_theme.dart';
import 'package:dashboard_app/utils/chart_period_selection.dart';
import 'package:dashboard_app/utils/dashboard_date_range.dart';
import 'package:dashboard_app/utils/site_system_navigation.dart';
import 'package:dashboard_app/utils/utility_chart_type.dart';
import 'package:dashboard_app/widgets/chart_widgets.dart';
import 'package:dashboard_app/widgets/system/utility_analytics_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  testWidgets('comparison mode replaces the utility chart in the same card',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const siteId = 'site-1';
    const categoryId = 'water-cat';
    const comparisonKey = 'site-1::water-cat';
    const periodKey = 'site-1::water';
    const chartTypeKey = 'site-1::water';

    final dateSelection = defaultDateSelectionForSite(
      siteId,
      DateTime(2026, 5, 31),
    );

    final emptyBundle = CategoryChartBundle(
      categoryId: categoryId,
      categoryName: 'Water',
      unitCode: 'm3',
      trend: const CategoryConsumptionSeries(
        categoryId: categoryId,
        categoryName: 'Water',
        unitCode: 'm3',
        points: [],
      ),
      ranking: const [],
      submittedToday: 0,
      pendingToday: 0,
      meterCount: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meterComparisonSelectionProvider(comparisonKey)
              .overrideWith((ref) => {'meter-a', 'meter-b'}),
          utilityChartPeriodProvider(periodKey).overrideWith(
            (ref) => const UtilityChartPeriodState(
              kind: UtilityChartPeriodKind.last30Days,
            ),
          ),
          utilityChartTypeProvider(chartTypeKey)
              .overrideWith((ref) => UtilityChartType.line),
          categoryChartBundleProvider.overrideWith(
            (ref, query) async => emptyBundle,
          ),
          meterReadingCardsRawProvider.overrideWith(
            (ref, query) async => const <MeterReadingCardData>[],
          ),
          meterComparisonProvider.overrideWith(
            (ref, query) async => const MeterComparisonResult(
              series: [],
              baseUnit: 'm3',
              canCompare: false,
              warningMessage: 'Not enough readings',
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildDashboardLightTheme(),
          home: Scaffold(
            body: UtilityAnalyticsSection(
              siteId: siteId,
              system: UtilitySystemKey.water,
              categoryId: categoryId,
              unitCode: 'm3',
              dateSelection: dateSelection,
              onDateSelectionChanged: (_) {},
              useDesktop: true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(DashboardChartCard), findsOneWidget);
    expect(find.text('Water meter comparison'), findsOneWidget);
    expect(find.text('Water consumption trend'), findsNothing);
  });
}
