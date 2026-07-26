import 'partner_app_links.dart';
import 'partner_link_intent.dart';

/// Parses `smartmeters-*://` URIs into a [PartnerLinkIntent].
PartnerLinkIntent? parsePartnerLink(Uri uri) {
  return switch (uri.scheme) {
    PartnerAppLinks.dashboardScheme => _parseDashboardSite(uri),
    PartnerAppLinks.entryScheme => _parseEntry(uri),
    PartnerAppLinks.adminScheme => _parseAdmin(uri),
    _ => null,
  };
}

PartnerLinkIntent? _parseDashboardSite(Uri uri) {
  if (uri.host != 'site') return null;
  final siteId = _firstPathSegment(uri);
  if (siteId == null) return null;
  return PartnerLinkIntent(
    kind: PartnerLinkKind.dashboardSite,
    siteId: siteId,
    section: uri.queryParameters['section'],
    readingDate: uri.queryParameters['date'],
  );
}

PartnerLinkIntent? _parseEntry(Uri uri) {
  if (uri.host == 'site') {
    final segments = _pathSegments(uri);
    if (segments.isEmpty) return null;
    final siteId = segments.first;
    if (segments.length >= 3 && segments[1] == 'meter') {
      return PartnerLinkIntent(
        kind: PartnerLinkKind.entryMeter,
        siteId: siteId,
        meterId: segments[2],
        categoryCode: uri.queryParameters['category'],
        readingDate: uri.queryParameters['date'],
      );
    }
    return PartnerLinkIntent(
      kind: PartnerLinkKind.entrySite,
      siteId: siteId,
      categoryCode: uri.queryParameters['category'],
    );
  }
  return null;
}

PartnerLinkIntent? _parseAdmin(Uri uri) {
  if (uri.host == 'site') {
    final siteId = _firstPathSegment(uri);
    if (siteId == null) return null;
    return PartnerLinkIntent(kind: PartnerLinkKind.adminSite, siteId: siteId);
  }
  if (uri.host == 'meter') {
    final meterId = _firstPathSegment(uri);
    if (meterId == null) return null;
    return PartnerLinkIntent(
      kind: PartnerLinkKind.adminMeter,
      siteId: '',
      meterId: meterId,
    );
  }
  return null;
}

String? _firstPathSegment(Uri uri) {
  final segments = _pathSegments(uri);
  return segments.isEmpty ? null : segments.first;
}

List<String> _pathSegments(Uri uri) {
  return uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
}
