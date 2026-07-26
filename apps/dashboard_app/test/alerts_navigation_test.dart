import 'package:dashboard_app/utils/site_system_navigation.dart';
import 'package:dashboard_app/providers/meter_reading_card_providers.dart';
import 'package:dashboard_app/utils/meter_reading_filters.dart';
import 'package:dashboard_app/widgets/alert_widgets.dart';
import 'package:dashboard_app/widgets/shell/dashboard_alert_bell.dart';
import 'package:dashboard_app/widgets/system/utility_system_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('MeterReadingCardsDataQuery excludes search and sort from equality', () {
    final base = MeterReadingCardsDataQuery(
      siteId: 'site',
      utilityKey: 'water',
      businessDate: DateTime(2026, 5, 31),
    );
    final withFilters = MeterReadingCardsQuery(
      siteId: 'site',
      utilityKey: 'water',
      businessDate: DateTime(2026, 5, 31),
      search: 'meter',
      sort: MeterCardSort.meterCode,
    );
    expect(withFilters.dataQuery, base);
  });

  testWidgets('utility panel does not render bottom alert list section', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: UtilitySystemPanel(
              siteId: 'test-site',
              system: UtilitySystemKey.water,
              useDesktop: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Water alerts'), findsNothing);
    expect(find.byType(AlertListTile), findsNothing);
  });

  testWidgets('alert bell button is present', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                DashboardAlertBellButton(siteId: 'site-id'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });
}
