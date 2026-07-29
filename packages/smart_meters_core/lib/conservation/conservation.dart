/// Conservation layer (Phase 1) — additive, feature-flagged, read-only metrics.
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
export 'models/period_comparison_result.dart';
export 'models/conservation_target.dart';
export 'models/actual_vs_target_result.dart';
export 'models/conservation_baseline.dart';
export 'models/actual_vs_baseline_result.dart';
export 'repositories/target_repository.dart';
export 'repositories/baseline_repository.dart';
export 'domain/period_windows.dart';
export 'domain/baseline_approval_gates.dart';
