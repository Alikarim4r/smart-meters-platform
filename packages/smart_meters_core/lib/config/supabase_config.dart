import 'app_env.dart';

/// Runtime Supabase configuration via `--dart-define`.
///
/// Example:
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<anon-key>
/// ```
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  /// Verified non-production project refs that must never back a Production
  /// Smart Meters build.
  static const smartMetersStagingProjectRef = 'iqcxgtpcfhoapnklxdyl';
  static const dailyChecklistsProjectRef = 'xhdpyiklhouqwrtdwztn';

  final String url;
  final String anonKey;

  static const SupabaseConfig fromEnvironment = SupabaseConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
  bool get pointsToSmartMetersStaging =>
      url.contains(smartMetersStagingProjectRef);
  bool get pointsToDailyChecklists => url.contains(dailyChecklistsProjectRef);

  void validate({AppEnv? env}) {
    if (!isConfigured) {
      throw StateError(
        'Supabase is not configured. Pass SUPABASE_URL and SUPABASE_ANON_KEY '
        'via --dart-define.',
      );
    }

    final effectiveEnv = env ?? AppEnv.current;
    if (!effectiveEnv.isProduction) return;

    if (pointsToSmartMetersStaging) {
      throw StateError(
        'Production Smart Meters builds cannot use the Smart Meters staging '
        'Supabase project.',
      );
    }
    if (pointsToDailyChecklists) {
      throw StateError(
        'Production Smart Meters builds cannot use the Daily Checklists '
        'Supabase project.',
      );
    }
  }
}
