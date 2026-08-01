/// Conservation layer (Phase 1 + Phase 2 + Phase 3 + Phase 4) — additive, feature-flagged.
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

// Phase 3 — Opportunities / Investigations / Actions / Evidence
export 'domain/opportunity_lifecycle.dart';
export 'domain/action_lifecycle.dart';
export 'domain/investigation_lifecycle.dart';
export 'domain/opportunity_fingerprint.dart';
export 'domain/opportunity_signal_rules.dart';
export 'models/conservation_opportunity.dart';
export 'models/conservation_investigation.dart';
export 'models/conservation_action.dart';
export 'models/conservation_evidence.dart';
export 'models/workflow_audit_entry.dart';
export 'services/opportunity_priority.dart';
export 'services/opportunity_engine.dart';
export 'services/opportunity_generation_service.dart';
export 'services/opportunity_workflow_service.dart';
export 'repositories/opportunity_repository.dart';
export 'repositories/investigation_repository.dart';
export 'repositories/action_repository.dart';
export 'repositories/evidence_repository.dart';
export 'repositories/workflow_audit_repository.dart';

// Phase 4 — Estimated / Verified Saving, Cost / ROI, M&V
export 'domain/savings_verification_gates.dart';
export 'domain/mv_lifecycle.dart';
export 'domain/double_count_rules.dart';
export 'models/measurement_verification.dart';
export 'models/utility_tariff.dart';
export 'services/savings_estimation_service.dart';
export 'services/savings_verification_service.dart';
export 'services/cost_roi_service.dart';
export 'services/tariff_lookup_service.dart';
export 'repositories/measurement_verification_repository.dart';
export 'repositories/utility_tariff_repository.dart';
