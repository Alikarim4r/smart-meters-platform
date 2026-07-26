import 'partner_app_links.dart';
import 'partner_link_intent.dart';
import 'partner_link_parser.dart';
import 'partner_web_config.dart';

/// Converts native partner URIs to HTTPS launch URLs for web deployments.
Uri? partnerUriToWeb(Uri nativeUri) {
  final base = PartnerWebConfig.baseForScheme(nativeUri.scheme);
  if (base.isEmpty) return null;

  final params = <String, String>{};
  switch (nativeUri.scheme) {
    case PartnerAppLinks.dashboardScheme:
      if (nativeUri.host != 'site') return null;
      final siteId = _firstPathSegment(nativeUri);
      if (siteId == null) return null;
      params['site'] = siteId;
      _copyIfPresent(nativeUri.queryParameters, params, 'section', 'section');
      _copyIfPresent(nativeUri.queryParameters, params, 'date', 'date');
    case PartnerAppLinks.entryScheme:
      if (nativeUri.host != 'site') return null;
      final segments = _pathSegments(nativeUri);
      if (segments.isEmpty) return null;
      params['site'] = segments.first;
      if (segments.length >= 3 && segments[1] == 'meter') {
        params['meter'] = segments[2];
      }
      _copyIfPresent(nativeUri.queryParameters, params, 'category', 'category');
      _copyIfPresent(nativeUri.queryParameters, params, 'date', 'date');
    case PartnerAppLinks.adminScheme:
      if (nativeUri.host == 'site') {
        final siteId = _firstPathSegment(nativeUri);
        if (siteId == null) return null;
        params['site'] = siteId;
      } else if (nativeUri.host == 'meter') {
        final meterId = _firstPathSegment(nativeUri);
        if (meterId == null) return null;
        params['meter'] = meterId;
      } else {
        return null;
      }
    default:
      return null;
  }

  return Uri.parse(base).replace(queryParameters: params);
}

/// Parses `?site=` / `?meter=` query params when a web app is opened directly.
PartnerLinkIntent? parsePartnerWebQuery(
  Map<String, String> query, {
  required String expectedScheme,
}) {
  final siteId = query['site'];
  final meterId = query['meter'];
  final category = query['category'];
  final date = query['date'];
  final section = query['section'];

  return switch (expectedScheme) {
    PartnerAppLinks.dashboardScheme =>
      siteId == null || siteId.isEmpty
          ? null
          : PartnerLinkIntent(
              kind: PartnerLinkKind.dashboardSite,
              siteId: siteId,
              section: section,
              readingDate: date,
            ),
    PartnerAppLinks.entryScheme =>
      siteId == null || siteId.isEmpty
          ? null
          : meterId != null && meterId.isNotEmpty
          ? PartnerLinkIntent(
              kind: PartnerLinkKind.entryMeter,
              siteId: siteId,
              meterId: meterId,
              categoryCode: category,
              readingDate: date,
            )
          : PartnerLinkIntent(
              kind: PartnerLinkKind.entrySite,
              siteId: siteId,
              categoryCode: category,
            ),
    PartnerAppLinks.adminScheme =>
      meterId != null && meterId.isNotEmpty
          ? PartnerLinkIntent(
              kind: PartnerLinkKind.adminMeter,
              siteId: '',
              meterId: meterId,
            )
          : siteId != null && siteId.isNotEmpty
          ? PartnerLinkIntent(kind: PartnerLinkKind.adminSite, siteId: siteId)
          : null,
    _ => null,
  };
}

/// Accepts both custom-scheme and configured HTTPS partner links.
PartnerLinkIntent? parsePartnerLinkFlexible(Uri uri) {
  final native = parsePartnerLink(uri);
  if (native != null) return native;

  if (!PartnerWebConfig.isConfigured || uri.scheme != 'https') {
    return null;
  }

  final base = PartnerWebConfig.baseForScheme(PartnerAppLinks.dashboardScheme);
  if (uri.toString().startsWith(base)) {
    return parsePartnerWebQuery(
      uri.queryParameters,
      expectedScheme: PartnerAppLinks.dashboardScheme,
    );
  }

  final entryBase = PartnerWebConfig.baseForScheme(PartnerAppLinks.entryScheme);
  if (uri.toString().startsWith(entryBase)) {
    return parsePartnerWebQuery(
      uri.queryParameters,
      expectedScheme: PartnerAppLinks.entryScheme,
    );
  }

  final adminBase = PartnerWebConfig.baseForScheme(PartnerAppLinks.adminScheme);
  if (uri.toString().startsWith(adminBase)) {
    return parsePartnerWebQuery(
      uri.queryParameters,
      expectedScheme: PartnerAppLinks.adminScheme,
    );
  }

  return null;
}

void _copyIfPresent(
  Map<String, String> source,
  Map<String, String> target,
  String sourceKey,
  String targetKey,
) {
  final value = source[sourceKey];
  if (value != null && value.isNotEmpty) {
    target[targetKey] = value;
  }
}

String? _firstPathSegment(Uri uri) {
  final segments = _pathSegments(uri);
  return segments.isEmpty ? null : segments.first;
}

List<String> _pathSegments(Uri uri) {
  return uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
}
