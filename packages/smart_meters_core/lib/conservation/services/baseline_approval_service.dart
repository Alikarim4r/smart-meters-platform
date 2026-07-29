import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/baseline_approval_gates.dart';
import '../models/conservation_baseline.dart';
import '../repositories/baseline_repository.dart';

/// Approves drafts with quality gates; supersedes previous approved.
///
/// ## Lifecycle (state transitions)
///
/// ```
/// draft ──approve──► approved ──new approve──► superseded
///   │                   │
///   └──archive──► archived ◄──archive─────────┘
/// ```
///
/// ## Permissions (service + RLS)
///
/// | Action       | Allowed roles                                      |
/// |--------------|----------------------------------------------------|
/// | Create Draft | site_admin (+can_manage_site), super_admin, owner  |
/// | Edit Draft   | same                                               |
/// | Approve      | same — **explicit** action; never auto on create   |
/// | Archive      | same                                               |
/// | Viewer/Tech  | SELECT only                                        |
class BaselineApprovalService {
  BaselineApprovalService(
    this._client, {
    this.gates = BaselineApprovalGates.standard,
  });

  final SupabaseClient _client;
  final BaselineApprovalGates gates;

  ConservationBaselineRepository get repository =>
      ConservationBaselineRepository(_client);

  Future<ConservationBaseline> approve({
    required String draftId,
    required String approvedBy,
    DateTime? validFrom,
    bool unitMismatch = false,
    bool crossSiteScope = false,
    bool hasCriticalDataQualityFindings = false,
  }) async {
    final row = await _client
        .from('conservation_baselines')
        .select()
        .eq('id', draftId)
        .single();
    final draft =
        ConservationBaseline.fromJson(Map<String, dynamic>.from(row));

    final gate = BaselineApprovalGateEvaluator(gates: gates).evaluate(
      status: draft.status,
      method: draft.calculationMethod,
      baselineValue: draft.baselineValue,
      completeness: draft.dataCompleteness,
      confidence: draft.confidenceScore,
      boundaryQuality: draft.boundaryQuality,
      referenceStart: draft.referencePeriodStart,
      referenceEnd: draft.referencePeriodEnd,
      unitCode: draft.unitCode,
      scopeType: draft.scopeType,
      scopeId: draft.scopeId,
      unitMismatch: unitMismatch,
      crossSiteScope: crossSiteScope,
      hasCriticalDataQualityFindings: hasCriticalDataQualityFindings,
    );
    if (!gate.allowed) {
      throw StateError(
        'Baseline approval blocked:\n- ${gate.reasons.join('\n- ')}',
      );
    }

    final from = DateTime(
      (validFrom ?? DateTime.now()).year,
      (validFrom ?? DateTime.now()).month,
      (validFrom ?? DateTime.now()).day,
    );

    var archiveQ = _client
        .from('conservation_baselines')
        .update({
          'status': ConservationBaselineStatus.superseded.dbValue,
          'valid_to': _iso(from.subtract(const Duration(days: 1))),
        })
        .eq('site_id', draft.siteId)
        .eq('scope_type', draft.scopeType.dbValue)
        .eq('unit_code', draft.unitCode)
        .eq('status', ConservationBaselineStatus.approved.dbValue);
    archiveQ = draft.scopeId == null
        ? archiveQ.isFilter('scope_id', null)
        : archiveQ.eq('scope_id', draft.scopeId!);
    await archiveQ;

    final activated = await _client
        .from('conservation_baselines')
        .update({
          'status': ConservationBaselineStatus.approved.dbValue,
          'valid_from': _iso(from),
          'valid_to': null,
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', draftId)
        .select()
        .single();
    return ConservationBaseline.fromJson(Map<String, dynamic>.from(activated));
  }

  static BaselineApprovalGateResult checkGates({
    required ConservationBaseline draft,
    BaselineApprovalGates gates = BaselineApprovalGates.standard,
    bool unitMismatch = false,
    bool crossSiteScope = false,
    bool hasCriticalDataQualityFindings = false,
  }) {
    return BaselineApprovalGateEvaluator(gates: gates).evaluate(
      status: draft.status,
      method: draft.calculationMethod,
      baselineValue: draft.baselineValue,
      completeness: draft.dataCompleteness,
      confidence: draft.confidenceScore,
      boundaryQuality: draft.boundaryQuality,
      referenceStart: draft.referencePeriodStart,
      referenceEnd: draft.referencePeriodEnd,
      unitCode: draft.unitCode,
      scopeType: draft.scopeType,
      scopeId: draft.scopeId,
      unitMismatch: unitMismatch,
      crossSiteScope: crossSiteScope,
      hasCriticalDataQualityFindings: hasCriticalDataQualityFindings,
    );
  }
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
