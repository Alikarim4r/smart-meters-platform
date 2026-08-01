import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';

final _siteMvUiEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final site = await ref.watch(adminSiteProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  final module = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.conservationModule,
    siteId: siteId,
  );
  if (!module) return false;
  final estimation = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.savingsEstimation,
    siteId: siteId,
  );
  if (estimation) return true;
  return flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.savingsVerification,
    siteId: siteId,
  );
});

final _siteMvListProvider = FutureProvider.autoDispose
    .family<List<MeasurementVerification>, String>((ref, siteId) {
  return MeasurementVerificationRepository(
    ref.read(supabaseClientProvider),
  ).listForSite(siteId, limit: 100);
});

/// Admin M&V workflow — site_admin oriented (technician cannot verify).
class MvAdminScreen extends ConsumerWidget {
  const MvAdminScreen({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final enabledAsync = ref.watch(_siteMvUiEnabledProvider(siteId));
    final canManage = ref.watch(canManageMetersProvider);
    final profile = ref.watch(authProvider).profile;
    final canVerify = canManage &&
        ConservationAuthorityPolicy.canVerifySaving(
          profile?.isPlatformOwner == true
              ? 'platform_owner'
              : profile?.role.dbValue,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAr ? 'القياس والتحقق' : 'Measurement & Verification'),
      ),
      floatingActionButton: enabledAsync.maybeWhen(
        data: (on) => on && canManage
            ? FloatingActionButton.extended(
                onPressed: () => _createDraft(context, ref),
                icon: const Icon(Icons.add),
                label: Text(s.isAr ? 'مسودة' : 'New draft'),
              )
            : null,
        orElse: () => null,
      ),
      body: enabledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CatalogErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_siteMvUiEnabledProvider(siteId)),
        ),
        data: (enabled) {
          if (!enabled) {
            return CatalogEmptyState(
              title: s.isAr ? 'M&V غير مفعّل' : 'M&V disabled',
              message: s.isAr
                  ? 'فعّل conservation_module و savings_estimation أو savings_verification.'
                  : 'Enable conservation_module and savings_estimation or savings_verification.',
              icon: Icons.flag_outlined,
            );
          }
          final listAsync = ref.watch(_siteMvListProvider(siteId));
          return listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => CatalogErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(_siteMvListProvider(siteId)),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return CatalogEmptyState(
                  title: s.isAr ? 'لا سجلات' : 'No M&V records',
                  message: s.isAr
                      ? 'أنشئ مسودة من فرصة + إجراء + خط أساس.'
                      : 'Create a draft from opportunity + action + baseline.',
                  icon: Icons.verified_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${row.utilityType} · ${row.status.dbValue} · '
                        'v${row.calculationVersion}',
                      ),
                      subtitle: Text(
                        '${ConservationSavingLabels.estimatedSaving}: '
                        '${row.estimatedSavingQuantity?.toStringAsFixed(2) ?? '—'} '
                        '${row.unitCode}\n'
                        '${ConservationSavingLabels.verifiedSaving}: '
                        '${row.status == MvStatus.verified ? (row.verifiedSavingQuantity?.toStringAsFixed(2) ?? '—') : '—'} '
                        '${row.unitCode}\n'
                        'Cost Avoided: '
                        '${row.costAvoided == null ? ConservationSavingLabels.costAvoidedNa : '${row.costAvoided!.toStringAsFixed(2)} ${row.costCurrency ?? 'QAR'}'}',
                      ),
                      isThreeLine: true,
                      trailing: canManage
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: canManage
                          ? () => _openDetail(
                                context,
                                ref,
                                row,
                                canVerify: canVerify,
                              )
                          : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createDraft(BuildContext context, WidgetRef ref) async {
    final client = ref.read(supabaseClientProvider);
    final opportunities =
        await OpportunityRepository(client).listForSite(siteId, limit: 100);
    final baselines = await ConservationBaselineRepository(client)
        .listApprovedForSite(siteId);
    final actions =
        await ActionRepository(client).listForSite(siteId, limit: 100);

    if (!context.mounted) return;
    if (opportunities.isEmpty || baselines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Need at least one opportunity and one approved baseline.',
          ),
        ),
      );
      return;
    }

    ConservationOpportunity? opp = opportunities.first;
    ConservationAction? action;
    ConservationBaseline baseline = baselines.first;
    final preStart = TextEditingController();
    final preEnd = TextEditingController();
    final postStart = TextEditingController();
    final postEnd = TextEditingController();
    final baselineValueCtrl = TextEditingController(
      text: baseline.baselineValue.toString(),
    );
    final actualPostCtrl = TextEditingController();
    var method = MvVerificationMethod.baselineComparison;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final oppActions =
                actions.where((a) => a.opportunityId == opp!.id).toList();
            return AlertDialog(
              title: const Text('Create M&V draft'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<ConservationOpportunity>(
                        initialValue: opp,
                        decoration:
                            const InputDecoration(labelText: 'Opportunity'),
                        items: [
                          for (final o in opportunities)
                            DropdownMenuItem(
                              value: o,
                              child: Text(
                                o.title.isEmpty ? o.id : o.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          opp = v;
                          action = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ConservationAction?>(
                        initialValue: action,
                        decoration: const InputDecoration(
                          labelText: 'Action (optional)',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— none —'),
                          ),
                          for (final a in oppActions)
                            DropdownMenuItem(
                              value: a,
                              child: Text(
                                a.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => action = v),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ConservationBaseline>(
                        initialValue: baseline,
                        decoration:
                            const InputDecoration(labelText: 'Baseline'),
                        items: [
                          for (final b in baselines)
                            DropdownMenuItem(
                              value: b,
                              child: Text(
                                'v${b.versionNumber} · ${b.unitCode} · '
                                '${b.baselineValue}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            baseline = v;
                            baselineValueCtrl.text =
                                v.baselineValue.toString();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<MvVerificationMethod>(
                        initialValue: method,
                        decoration: const InputDecoration(labelText: 'Method'),
                        items: [
                          for (final m in MvVerificationMethod.values)
                            DropdownMenuItem(
                              value: m,
                              child: Text(m.dbValue),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => method = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: baselineValueCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Baseline value',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: actualPostCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Actual post value (optional)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: preStart,
                        decoration: const InputDecoration(
                          labelText: 'Pre start (YYYY-MM-DD)',
                        ),
                      ),
                      TextField(
                        controller: preEnd,
                        decoration: const InputDecoration(
                          labelText: 'Pre end (YYYY-MM-DD)',
                        ),
                      ),
                      TextField(
                        controller: postStart,
                        decoration: const InputDecoration(
                          labelText: 'Post start (YYYY-MM-DD)',
                        ),
                      ),
                      TextField(
                        controller: postEnd,
                        decoration: const InputDecoration(
                          labelText: 'Post end (YYYY-MM-DD)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !context.mounted) return;
    try {
      DateTime parse(String t) => DateTime.parse(t.trim());
      final created = await MeasurementVerificationRepository(client)
          .createDraft(
        siteId: siteId,
        opportunityId: opp!.id,
        baselineId: baseline.id,
        utilityType: opp!.utilityType.isEmpty
            ? baseline.unitCode
            : opp!.utilityType,
        verificationMethod: method,
        prePeriodStart: parse(preStart.text),
        prePeriodEnd: parse(preEnd.text),
        postPeriodStart: parse(postStart.text),
        postPeriodEnd: parse(postEnd.text),
        baselineValue: double.parse(baselineValueCtrl.text),
        unitCode: baseline.unitCode,
        actionId: action?.id,
        meterId: opp!.meterId,
        balanceGroupId: opp!.balanceGroupId,
        actualPostValue: actualPostCtrl.text.trim().isEmpty
            ? null
            : double.parse(actualPostCtrl.text.trim()),
        confidenceScore: 50,
        createdBy: client.auth.currentUser?.id,
      );
      // Bind org for tariff later; site org from site.
      ref.invalidate(_siteMvListProvider(siteId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Draft created (${created.id.substring(0, 8)}…)')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    MeasurementVerification row, {
    required bool canVerify,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: _MvDetailSheet(
            siteId: siteId,
            record: row,
            canVerify: canVerify,
            onChanged: () => ref.invalidate(_siteMvListProvider(siteId)),
          ),
        );
      },
    );
  }
}

class _MvDetailSheet extends ConsumerStatefulWidget {
  const _MvDetailSheet({
    required this.siteId,
    required this.record,
    required this.canVerify,
    required this.onChanged,
  });

  final String siteId;
  final MeasurementVerification record;
  final bool canVerify;
  final VoidCallback onChanged;

  @override
  ConsumerState<_MvDetailSheet> createState() => _MvDetailSheetState();
}

class _MvDetailSheetState extends ConsumerState<_MvDetailSheet> {
  late MeasurementVerification _record;
  final _actualCtrl = TextEditingController();
  final _rejectCtrl = TextEditingController();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    if (_record.actualPostValue != null) {
      _actualCtrl.text = _record.actualPostValue!.toString();
    }
  }

  @override
  void dispose() {
    _actualCtrl.dispose();
    _rejectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = const SavingsVerificationService();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'M&V · ${_record.status.dbValue} · v${_record.calculationVersion}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '${ConservationSavingLabels.estimatedSaving}: '
            '${_record.estimatedSavingQuantity?.toStringAsFixed(2) ?? '—'} '
            '${_record.unitCode}',
          ),
          Text(
            '${ConservationSavingLabels.verifiedSaving}: '
            '${_record.status == MvStatus.verified ? (_record.verifiedSavingQuantity?.toStringAsFixed(2) ?? '—') : '—'} '
            '${_record.unitCode}',
          ),
          Text(
            'Cost Avoided: '
            '${_record.costAvoided == null ? ConservationSavingLabels.costAvoidedNa : '${_record.costAvoided} ${_record.costCurrency ?? 'QAR'}'}',
          ),
          Text('Confidence: ${_record.confidenceScore}'),
          Text('Baseline id: ${_record.baselineId}'),
          if (_record.status == MvStatus.verificationPending)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Ready for Verification',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          if (_record.verifiedBy != null)
            Text('Verified by: ${_record.verifiedBy}'),
          const SizedBox(height: 12),
          TextField(
            controller: _actualCtrl,
            decoration: const InputDecoration(
              labelText: 'Actual post value',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_record.status == MvStatus.draft ||
                  _record.status == MvStatus.estimated)
                FilledButton(
                  onPressed: _busy ? null : () => _estimate(svc),
                  child: const Text('Estimate'),
                ),
              if (_record.status == MvStatus.estimated)
                OutlinedButton(
                  onPressed: _busy ? null : () => _submitPending(svc),
                  child: const Text('Submit for verification'),
                ),
              if (_record.status == MvStatus.verificationPending &&
                  widget.canVerify)
                FilledButton(
                  onPressed: _busy ? null : () => _verify(svc),
                  child: const Text('Verify'),
                ),
              if ((_record.status == MvStatus.verificationPending ||
                      _record.status == MvStatus.estimated ||
                      _record.status == MvStatus.draft) &&
                  widget.canVerify)
                OutlinedButton(
                  onPressed: _busy ? null : () => _reject(svc),
                  child: const Text('Reject'),
                ),
              if (_record.status == MvStatus.verified ||
                  _record.status == MvStatus.estimated ||
                  _record.status == MvStatus.verificationPending ||
                  _record.status == MvStatus.rejected)
                OutlinedButton(
                  onPressed: _busy ? null : () => _recalculate(svc),
                  child: const Text('Recalculate / supersede'),
                ),
            ],
          ),
          if (!widget.canVerify) ...[
            const SizedBox(height: 8),
            const Text(
              'Technician cannot verify. Site admin / super admin required.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _rejectCtrl,
            decoration: const InputDecoration(
              labelText: 'Rejection reason (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _estimate(SavingsVerificationService svc) async {
    setState(() => _busy = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final repo = MeasurementVerificationRepository(client);
      final actual = double.parse(_actualCtrl.text.trim());
      final estimated = svc.applyEstimation(
        record: _record,
        actualPostValue: actual,
      );
      final saved = await repo.updateRow(estimated);
      setState(() => _record = saved);
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimated Saving applied')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitPending(SavingsVerificationService svc) async {
    setState(() => _busy = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final pending = svc.prepareVerificationPending(_record);
      final saved =
          await MeasurementVerificationRepository(client).updateRow(pending);
      setState(() => _record = saved);
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted — Ready for Verification')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(SavingsVerificationService svc) async {
    setState(() => _busy = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final profile = ref.read(authProvider).profile!;
      final site = await ref.read(adminSiteProvider(widget.siteId).future);
      final actorRole = profile.isPlatformOwner
          ? 'platform_owner'
          : profile.role.dbValue;

      ConservationBaselineStatus? baselineStatus;
      ActionStatus? actionStatus;
      OpportunityStatus? opportunityStatus;
      UtilityTariff? tariff;

      final baselineRow = await client
          .from('conservation_baselines')
          .select()
          .eq('id', _record.baselineId)
          .maybeSingle();
      if (baselineRow != null) {
        baselineStatus = ConservationBaseline.fromJson(
          Map<String, dynamic>.from(baselineRow),
        ).status;
      }

      final opp =
          await OpportunityRepository(client).getById(_record.opportunityId);
      opportunityStatus = opp?.status;

      if (_record.actionId != null) {
        final actions = await ActionRepository(client).listByOpportunity(
          _record.opportunityId,
        );
        final match =
            actions.where((a) => a.id == _record.actionId).firstOrNull;
        actionStatus = match?.status;
      }

      tariff = await UtilityTariffRepository(client).resolveApplicable(
        organizationId: site.organizationId,
        utilityType: _record.utilityType,
        onDate: _record.postPeriodEnd,
        siteId: widget.siteId,
        unitCode: _record.unitCode,
      );

      final existing = await MeasurementVerificationRepository(client)
          .listVerifiedOverlappingScope(
        siteId: widget.siteId,
        meterId: _record.meterId,
        balanceGroupId: _record.balanceGroupId,
      );

      final outcome = svc.verify(
        record: _record,
        verifiedBy: profile.id,
        actorRole: actorRole,
        baselineStatus: baselineStatus,
        actionStatus: actionStatus,
        opportunityStatus: opportunityStatus,
        hasPendingCriticalDq: false,
        tariff: tariff,
        existingVerified: [
          for (final e in existing)
            if (e.id != _record.id)
              DoubleCountCandidate(
                id: e.id,
                status: e.status,
                postPeriodStart: e.postPeriodStart,
                postPeriodEnd: e.postPeriodEnd,
                meterId: e.meterId,
                balanceGroupId: e.balanceGroupId,
              ),
        ],
      );

      if (!outcome.success || outcome.record == null) {
        throw StateError(
          outcome.blockReasons.isEmpty
              ? 'Verification blocked'
              : outcome.blockReasons.join('; '),
        );
      }

      final saved = await MeasurementVerificationRepository(client)
          .updateRow(outcome.record!);
      setState(() => _record = saved);
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verified Saving recorded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(SavingsVerificationService svc) async {
    setState(() => _busy = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final profile = ref.read(authProvider).profile!;
      final actorRole = profile.isPlatformOwner
          ? 'platform_owner'
          : profile.role.dbValue;
      final rejected = svc.reject(
        record: _record,
        rejectedBy: profile.id,
        actorRole: actorRole,
        rejectionReason: _rejectCtrl.text.trim().isEmpty
            ? null
            : _rejectCtrl.text.trim(),
      );
      final saved =
          await MeasurementVerificationRepository(client).updateRow(rejected);
      setState(() => _record = saved);
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recalculate(SavingsVerificationService svc) async {
    setState(() => _busy = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final actual = _actualCtrl.text.trim().isEmpty
          ? _record.actualPostValue
          : double.parse(_actualCtrl.text.trim());
      final versioning = svc.recalculateAsNewVersion(
        old: _record,
        newActualPostValue: actual,
        createdBy: client.auth.currentUser?.id,
      );
      final draft = await MeasurementVerificationRepository(client)
          .persistRecalculation(
        versioning,
        createdBy: client.auth.currentUser?.id,
      );
      setState(() => _record = draft);
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Superseded prior; new draft v${draft.calculationVersion}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
