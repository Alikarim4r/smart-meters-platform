import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('parses dashboard site link with section and date', () {
    final intent = parsePartnerLink(
      Uri.parse(
        'smartmeters-dashboard://site/site-1?section=water&date=2026-07-03',
      ),
    );

    expect(intent?.kind, PartnerLinkKind.dashboardSite);
    expect(intent?.siteId, 'site-1');
    expect(intent?.section, 'water');
    expect(intent?.readingDate, '2026-07-03');
  });

  test('parses entry meter link', () {
    final intent = parsePartnerLink(
      PartnerAppLinks.entryMeter(
        siteId: 'site-1',
        meterId: 'meter-9',
        categoryCode: 'water',
        readingDate: '2026-07-03',
      ),
    );

    expect(intent?.kind, PartnerLinkKind.entryMeter);
    expect(intent?.siteId, 'site-1');
    expect(intent?.meterId, 'meter-9');
    expect(intent?.categoryCode, 'water');
  });

  test('parses admin meter link', () {
    final intent = parsePartnerLink(PartnerAppLinks.adminMeter('meter-42'));

    expect(intent?.kind, PartnerLinkKind.adminMeter);
    expect(intent?.meterId, 'meter-42');
  });
}
