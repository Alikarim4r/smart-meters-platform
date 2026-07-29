/// Feature flag keys for the Conservation layer.
///
/// Missing DB rows and `enabled=false` both mean OFF.
abstract final class ConservationFeatureFlags {
  static const conservationModule = 'conservation_module';
  static const dataQuality = 'data_quality';
  static const periodCompare = 'period_compare';
  static const targets = 'targets';
  static const baseline = 'baseline';
  static const virtualMeters = 'virtual_meters';

  /// All known keys (structure only; never auto-enabled).
  static const all = <String>[
    conservationModule,
    dataQuality,
    periodCompare,
    targets,
    baseline,
    virtualMeters,
  ];
}
