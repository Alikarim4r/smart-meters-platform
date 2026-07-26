/// Runtime app environment via `--dart-define=APP_ENV=staging|production`.
///
/// Defaults to [AppEnv.production] when unset so release builds never show
/// staging validation hints unless scripts explicitly pass `APP_ENV=staging`.
enum AppEnv {
  staging,
  production;

  static AppEnv get current {
    const raw = String.fromEnvironment('APP_ENV', defaultValue: 'production');
    switch (raw.trim().toLowerCase()) {
      case 'staging':
      case 'stage':
      case 'dev':
      case 'development':
        return AppEnv.staging;
      default:
        return AppEnv.production;
    }
  }

  bool get isStaging => this == AppEnv.staging;
  bool get isProduction => this == AppEnv.production;

  /// When true, login screens may show validation-account hints.
  static bool get showStagingHints => current.isStaging;

  /// When true, MOEHE demo presets / import banners are allowed.
  static bool get showDemoSiteUx => current.isStaging;
}
