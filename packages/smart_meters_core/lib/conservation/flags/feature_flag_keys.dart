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

  // Phase 2 — keys only; missing row = OFF (never auto-enabled).
  static const waterBalance = 'water_balance';
  static const energyBalance = 'energy_balance';
  static const benchmarking = 'benchmarking';
  static const intensity = 'intensity';
  static const periodicAnomalies = 'periodic_anomalies';
  static const copConservation = 'cop_conservation';

  /// All known keys (structure only; never auto-enabled).
  static const all = <String>[
    conservationModule,
    dataQuality,
    periodCompare,
    targets,
    baseline,
    virtualMeters,
    waterBalance,
    energyBalance,
    benchmarking,
    intensity,
    periodicAnomalies,
    copConservation,
  ];
}
