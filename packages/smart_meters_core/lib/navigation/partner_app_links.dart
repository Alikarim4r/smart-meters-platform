/// Deep-link style URIs for cross-app handoff between platform apps.
abstract final class PartnerAppLinks {
  static const dashboardScheme = 'smartmeters-dashboard';
  static const entryScheme = 'smartmeters-entry';
  static const adminScheme = 'smartmeters-admin';

  static Uri dashboardSite(String siteId, {String? section, String? date}) {
    return Uri(
      scheme: dashboardScheme,
      host: 'site',
      path: '/$siteId',
      queryParameters: {
        if (section != null && section.isNotEmpty) 'section': section,
        if (date != null && date.isNotEmpty) 'date': date,
      },
    );
  }

  static Uri entryMeter({
    required String siteId,
    required String meterId,
    String? categoryCode,
    String? readingDate,
  }) {
    return Uri(
      scheme: entryScheme,
      host: 'site',
      path: '/$siteId/meter/$meterId',
      queryParameters: {
        if (categoryCode != null && categoryCode.isNotEmpty)
          'category': categoryCode,
        if (readingDate != null && readingDate.isNotEmpty) 'date': readingDate,
      },
    );
  }

  static Uri entrySite(String siteId, {String? categoryCode}) {
    return Uri(
      scheme: entryScheme,
      host: 'site',
      path: '/$siteId',
      queryParameters: {
        if (categoryCode != null && categoryCode.isNotEmpty)
          'category': categoryCode,
      },
    );
  }

  static Uri adminSite(String siteId) {
    return Uri(scheme: adminScheme, host: 'site', path: '/$siteId');
  }

  static Uri adminMeter(String meterId) {
    return Uri(scheme: adminScheme, host: 'meter', path: '/$meterId');
  }
}
