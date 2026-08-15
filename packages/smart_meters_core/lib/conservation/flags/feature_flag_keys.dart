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

  // Phase 3 — keys only; missing row = OFF (never auto-enabled).
  static const opportunities = 'opportunities';
  static const investigations = 'investigations';
  static const actions = 'actions';
  static const evidence = 'evidence';

  // Phase 4 — keys only; missing row = OFF (never auto-enabled).
  static const savingsEstimation = 'savings_estimation';
  static const savingsVerification = 'savings_verification';
  static const costRoi = 'cost_roi';
  static const conservationReports = 'conservation_reports';

  // Phase 5 — keys only; missing row = OFF (never auto-enabled).
  static const weatherNormalization = 'weather_normalization';
  static const occupancyNormalization = 'occupancy_normalization';
  static const savingPersistence = 'saving_persistence';
  static const carbonAccounting = 'carbon_accounting';
  static const portfolioOptimization = 'portfolio_optimization';
  static const forecasting = 'forecasting';
  static const recommendationEngine = 'recommendation_engine';

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
    opportunities,
    investigations,
    actions,
    evidence,
    savingsEstimation,
    savingsVerification,
    costRoi,
    conservationReports,
    weatherNormalization,
    occupancyNormalization,
    savingPersistence,
    carbonAccounting,
    portfolioOptimization,
    forecasting,
    recommendationEngine,
  ];
}
