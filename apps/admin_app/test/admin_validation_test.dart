import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'package:admin_app/utils/admin_validation.dart';

void main() {
  // LEGACY (031 / meters.parent_meter_id): kept for schema helper coverage only.
  // UI no longer edits hierarchy; utility network v2 owns relationships.
  test('validateParentMeter requires parent for sub and sub-sub', () {
    expect(
      validateParentMeter(level: MeterLevel.sub, parentMeterId: null),
      isNotNull,
    );
    expect(
      validateParentMeter(level: MeterLevel.subSub, parentMeterId: null),
      isNotNull,
    );
    expect(
      validateParentMeter(level: MeterLevel.main, parentMeterId: null),
      isNull,
    );
    expect(
      validateParentMeter(level: MeterLevel.subSub, parentMeterId: 'p1'),
      isNull,
    );
  });

  test('searchSites matches English and Arabic names', () {
    final sites = [
      const Site(
        id: '1',
        organizationId: 'org',
        nameEn: 'Test School A',
        nameAr: 'مدرسة',
        siteType: SiteType.school,
        location: 'Doha, Qatar',
        isActive: true,
      ),
    ];

    expect(searchSites(sites, 'school'), hasLength(1));
    expect(searchSites(sites, 'doha'), hasLength(1));
    expect(searchSites(sites, 'office'), isEmpty);
  });

  test('filterSitesByActive respects active filter', () {
    final sites = [
      const Site(
        id: '1',
        organizationId: 'org',
        nameEn: 'Active',
        nameAr: 'Active',
        siteType: SiteType.school,
        isActive: true,
      ),
      const Site(
        id: '2',
        organizationId: 'org',
        nameEn: 'Inactive',
        nameAr: 'Inactive',
        siteType: SiteType.school,
        isActive: false,
      ),
    ];

    expect(
      filterSitesByActive(sites: sites, filter: AdminActiveFilter.activeOnly),
      hasLength(1),
    );
    expect(
      filterSitesByActive(sites: sites, filter: AdminActiveFilter.inactiveOnly),
      hasLength(1),
    );
  });
}
