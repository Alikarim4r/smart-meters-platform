import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  const siteId = '22222222-2222-4222-8222-222222222222';

  test('partnerUriToWeb encodes dashboard site handoff', () {
    final native = PartnerAppLinks.dashboardSite(
      siteId,
      section: 'water',
      date: '2026-07-03',
    );

    final webUri = partnerUriToWeb(native);

    expect(webUri, isNull, reason: 'Requires WEB_* dart-defines at runtime');
  });

  test('parsePartnerWebQuery restores entry meter intent', () {
    final intent = parsePartnerWebQuery({
      'site': siteId,
      'meter': 'meter-1',
      'category': 'water',
      'date': '2026-07-03',
    }, expectedScheme: PartnerAppLinks.entryScheme);

    expect(intent?.kind, PartnerLinkKind.entryMeter);
    expect(intent?.siteId, siteId);
    expect(intent?.meterId, 'meter-1');
    expect(intent?.categoryCode, 'water');
    expect(intent?.readingDate, '2026-07-03');
  });

  test('parsePartnerWebQuery restores admin site intent', () {
    final intent = parsePartnerWebQuery({
      'site': siteId,
    }, expectedScheme: PartnerAppLinks.adminScheme);

    expect(intent?.kind, PartnerLinkKind.adminSite);
    expect(intent?.siteId, siteId);
  });
}
