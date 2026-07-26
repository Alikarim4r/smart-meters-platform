import 'package:dashboard_app/theme/dashboard_theme.dart';
import 'package:dashboard_app/utils/dashboard_date_range.dart';
import 'package:dashboard_app/widgets/premium/dashboard_date_quick_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('yesterday preset still resolves for legacy callers', () {
    final today = DateTime(2026, 7, 3);
    final selection = DashboardDateSelection.forPreset(
      preset: DashboardDatePreset.yesterday,
      currentBusinessDate: today,
    );

    expect(selection.preset, DashboardDatePreset.yesterday);
    expect(selection.subsequentReadingDate.day, 2);
    expect(selection.previousReadingDate.day, 1);
  });

  testWidgets('quick bar shows only Today chip', (tester) async {
    final today = DateTime(2026, 7, 3);
    final selection = DashboardDateSelection.forPreset(
      preset: DashboardDatePreset.today,
      currentBusinessDate: today,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDashboardLightTheme(),
        home: Scaffold(
          body: DashboardDateQuickBar(
            selection: selection,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsNothing);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
  });
}
