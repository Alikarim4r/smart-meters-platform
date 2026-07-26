/// Base URLs for the three Flutter web apps (GitHub Pages or custom hosting).
abstract final class PartnerWebConfig {
  static const dashboardUrl = String.fromEnvironment(
    'WEB_DASHBOARD_URL',
    defaultValue: '',
  );
  static const entryUrl = String.fromEnvironment(
    'WEB_ENTRY_URL',
    defaultValue: '',
  );
  static const adminUrl = String.fromEnvironment(
    'WEB_ADMIN_URL',
    defaultValue: '',
  );

  static bool get isConfigured =>
      dashboardUrl.isNotEmpty && entryUrl.isNotEmpty && adminUrl.isNotEmpty;

  static String baseForScheme(String scheme) {
    return switch (scheme) {
      'smartmeters-dashboard' => dashboardUrl,
      'smartmeters-entry' => entryUrl,
      'smartmeters-admin' => adminUrl,
      _ => '',
    };
  }
}
