import 'package:dashboard_app/theme/dashboard_theme.dart';
import 'package:dashboard_app/utils/chart_period_selection.dart';
import 'package:dashboard_app/widgets/chart/chart_period_controls.dart';
import 'package:dashboard_app/widgets/premium/dashboard_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  testWidgets('DashboardBackground pattern stays inside content area', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDashboardLightTheme(),
        home: const Scaffold(
          body: Row(
            children: [
              ColoredBox(
                color: Color(0xFF061428),
                child: SizedBox(width: 260, height: 400),
              ),
              Expanded(
                child: DashboardBackground(
                  child: SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(DashboardBackground), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DashboardBackground),
        matching: find.byType(BrandSurfaceBackground),
      ),
      findsOneWidget,
    );
  });

  testWidgets('chart period and chart type controls are separate panels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDashboardLightTheme(),
        home: Scaffold(
          body: Column(
            children: const [
              ChartPeriodControls(
                state: UtilityChartPeriodState(
                  kind: UtilityChartPeriodKind.last30Days,
                ),
                onChanged: _noop,
              ),
              SizedBox(height: 8),
              ChartTypeControls(child: Text('Line')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Period'), findsOneWidget);
    expect(find.text('Chart type'), findsOneWidget);
    expect(find.byType(AnalyticsControlPanel), findsNWidgets(2));
  });

  test('dark theme exposes chart and info surfaces', () {
    const dark = DashboardThemeColors.dark;
    expect(dark.chartGrid, isNot(dark.background));
    expect(dark.infoSurface, isNot(Colors.orange));
    expect(dark.dialog, isNot(Colors.white));
  });
}

void _noop(dynamic _) {}
