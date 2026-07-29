/// Conservation layer (Phase 1 + Phase 2) — additive, feature-flagged.
library;

export 'flags/feature_flag_keys.dart';
export 'flags/feature_flag_repository.dart';
export 'models/calculation_meta.dart';
export 'models/data_quality_result.dart';
export 'domain/data_quality_rules.dart';
export 'services/confidence_score.dart';
export 'services/data_quality_service.dart';
export 'services/period_comparison_service.dart';
export 'services/actual_vs_target_service.dart';
export 'services/baseline_calculation_service.dart';
export 'services/baseline_approval_service.dart';
export 'services/actual_vs_baseline_service.dart';
export 'services/virtual_meter_calculator.dart';
export 'models/period_comparison_result.dart';
export 'models/conservation_target.dart';
export 'models/actual_vs_target_result.dart';
export 'models/conservation_baseline.dart';
export 'models/actual_vs_baseline_result.dart';
export 'models/virtual_meter_result.dart';
export 'repositories/target_repository.dart';
export 'repositories/baseline_repository.dart';
export 'repositories/virtual_meter_repository.dart';
export 'domain/period_windows.dart';
export 'domain/baseline_approval_gates.dart';
export 'domain/virtual_meter_validation.dart';

// Phase 2
export 'domain/reading_alignment.dart';
export 'models/balance_result.dart';
export 'models/balance_classification.dart';
export 'models/site_conservation_profile.dart';
export 'models/benchmark_result.dart';
export 'models/anomaly_result.dart';
export 'services/balance_service.dart';
export 'services/benchmarking_service.dart';
export 'services/periodic_anomaly_service.dart';
export 'services/cop_trend_conservation_service.dart';
export 'repositories/site_conservation_profile_repository.dart';
export 'repositories/balance_group_repository.dart';
export 'repositories/balance_classification_repository.dart';
