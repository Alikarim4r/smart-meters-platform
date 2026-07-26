import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('entry meter link encodes site, meter, category, and date', () {
    const siteId = '22222222-2222-4222-8222-222222222222';
    const meterId = 'meter-1';

    final uri = PartnerAppLinks.entryMeter(
      siteId: siteId,
      meterId: meterId,
      categoryCode: 'water',
      readingDate: '2026-07-03',
    );

    expect(uri.scheme, PartnerAppLinks.entryScheme);
    expect(uri.path, '/$siteId/meter/$meterId');
    expect(uri.queryParameters['category'], 'water');
    expect(uri.queryParameters['date'], '2026-07-03');
  });

  test('admin site link targets site host path', () {
    const siteId = 'site-a';
    final uri = PartnerAppLinks.adminSite(siteId);

    expect(uri.scheme, PartnerAppLinks.adminScheme);
    expect(uri.host, 'site');
    expect(uri.path, '/$siteId');
  });
}
