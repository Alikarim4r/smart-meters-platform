/// Data frequency classification for capability gating.
enum DataFrequency {
  periodicManual,
  monthly,
  weekly,
  daily,
  hourly,
  interval15m,
  eventBased;

  String get wireValue => switch (this) {
        DataFrequency.periodicManual => 'periodic_manual',
        DataFrequency.monthly => 'monthly',
        DataFrequency.weekly => 'weekly',
        DataFrequency.daily => 'daily',
        DataFrequency.hourly => 'hourly',
        DataFrequency.interval15m => 'interval_15m',
        DataFrequency.eventBased => 'event_based',
      };

  static DataFrequency? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    for (final v in DataFrequency.values) {
      if (v.wireValue == raw) return v;
    }
    return null;
  }

  /// NULL meter frequency → periodic_manual (mechanical first-class).
  static DataFrequency resolveDefault(String? raw) =>
      tryParse(raw) ?? DataFrequency.periodicManual;
}
