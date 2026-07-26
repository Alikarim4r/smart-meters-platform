import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'package:dashboard_app/utils/dashboard_filters.dart';
import 'package:dashboard_app/utils/dashboard_date_range.dart';

void main() {
  DashboardSiteOverview overviewOf({
    required String id,
    required String name,
    String? zoneId,
    SiteType type = SiteType.school,
  }) {
    return DashboardSiteOverview(
      site: Site(
        id: id,
        organizationId: 'org',
        nameEn: name,
        nameAr: name,
        siteType: type,
        zoneId: zoneId,
        isActive: true,
      ),
      meterCount: 3,
      activeMeterCount: 3,
      categories: const [],
      readingsSubmittedToday: 1,
      entryEligibleMeterCount: 2,
    );
  }

  test('searchDashboardSites matches name and location', () {
    final sites = [
      overviewOf(id: '1', name: 'MOEHE HQ', zoneId: null),
      overviewOf(id: '2', name: 'Test School A', zoneId: 'zone-north'),
    ];

    expect(searchDashboardSites(sites, 'school'), hasLength(1));
    expect(searchDashboardSites(sites, 'moehe'), hasLength(1));
  });

  test('filterDashboardSitesByZone supports No Zone', () {
    final sites = [
      overviewOf(id: '1', name: 'MOEHE HQ'),
      overviewOf(id: '2', name: 'Test School A', zoneId: 'zone-north'),
    ];

    final noZone = filterDashboardSitesByZone(sites, kNoZoneFilterValue);
    expect(noZone, hasLength(1));
    expect(noZone.first.site.nameEn, 'MOEHE HQ');
  });

  test('readingDateRangeForFilter returns today only for today filter', () {
    final today = DateTime(2026, 7, 4);
    final range = readingDateRangeForFilter(
      filter: DashboardReadingDateFilter.today,
      businessDate: today,
    );
    expect(range.from, today);
    expect(range.to, today);
  });

  test('readingDateRangeForFilter returns March 2026 range', () {
    final range = readingDateRangeForFilter(
      filter: DashboardReadingDateFilter.march2026,
      businessDate: DateTime(2026, 7, 4),
    );
    expect(range.from, DateTime(2026, 3, 1));
    expect(range.to, DateTime(2026, 3, 31));
  });

  test('chartBusinessDateForMonth anchors historical months', () {
    expect(
      chartBusinessDateForMonth(
        month: DashboardChartMonth.may2026,
        currentBusinessDate: DateTime(2026, 7, 4),
      ),
      DateTime(2026, 5, 31),
    );
    expect(
      chartBusinessDateForMonth(
        month: DashboardChartMonth.march2026,
        currentBusinessDate: DateTime(2026, 7, 4),
      ),
      DateTime(2026, 3, 31),
    );
    expect(
      chartBusinessDateForMonth(
        month: DashboardChartMonth.april2026,
        currentBusinessDate: DateTime(2026, 7, 4),
      ),
      DateTime(2026, 4, 30),
    );
  });

  test('MOEHE demo chart defaults are staging-only (APP_ENV default=production)', () {
    final selection = defaultDateSelectionForSite(kMoeheHqSiteId, DateTime(2026, 7, 4));
    expect(selection.selectedBusinessDate, DateTime(2026, 7, 4));
    expect(selection.isSingleDay, isTrue);
    expect(selection.preset, DashboardDatePreset.today);
    // Without --dart-define=APP_ENV=staging, demo UX is off.
    expect(siteHasImportedHistoricalMonths(kMoeheHqSiteId), isFalse);
    expect(
      defaultChartMonthForSite(kMoeheHqSiteId),
      DashboardChartMonth.current,
    );
    expect(
      defaultChartMonthForSite('other-site'),
      DashboardChartMonth.current,
    );
  });

  test('resolveBusinessDate returns override or fallback', () {
    final fallback = DateTime(2026, 7, 4);
    final override = DateTime(2026, 3, 31);
    expect(
      resolveBusinessDate(override: override, fallback: fallback),
      override,
    );
    expect(
      resolveBusinessDate(override: null, fallback: fallback),
      fallback,
    );
  });
}
