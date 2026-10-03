import 'package:dashboard_app/theme/dashboard_theme.dart';
import 'package:dashboard_app/utils/dashboard_date_range.dart';
import 'package:dashboard_app/widgets/premium/dashboard_date_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Month prepares 12-month comparison range and Apply returns it',
      (tester) async {
    final today = DateTime(2026, 7, 10);
    final initial = DashboardDateSelection.singleDay(day: today);
    DashboardDateSelection? applied;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDashboardLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                applied = await showDialog<DashboardDateSelection>(
                  context: context,
                  builder: (_) => DashboardDatePickerPanel(initial: initial),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Select business date'), findsOneWidget);

    await tester.tap(find.text('12 months'));
    await tester.pumpAndSettle();

    // Dialog must stay open after selecting Month.
    expect(find.text('Select business date'), findsOneWidget);
    expect(find.textContaining('Preview:'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(applied, isNotNull);
    expect(applied!.isRangeMode, isTrue);
    expect(applied!.startDate, DateTime(2025, 8, 1));
    expect(applied!.endDate.month, 7);
    expect(applied!.endDate.day, 10);
  });

  testWidgets('embedded picker stays above system navigation without overflow',
      (tester) async {
    final initial = DashboardDateSelection.forPreset(
      preset: DashboardDatePreset.customRange,
      currentBusinessDate: DateTime(2026, 2, 28),
      customStart: DateTime(2026, 2, 5),
      customEnd: DateTime(2026, 2, 28),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDashboardLightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            padding: EdgeInsets.only(bottom: 32),
            viewPadding: EdgeInsets.only(bottom: 32),
            textScaler: TextScaler.linear(1.15),
          ),
          child: Scaffold(
            body: SizedBox(
              height: 600,
              child: DashboardDatePickerPanel(
                initial: initial,
                embedded: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(tester.getRect(find.text('Apply')).bottom, lessThan(568));
  });

}
