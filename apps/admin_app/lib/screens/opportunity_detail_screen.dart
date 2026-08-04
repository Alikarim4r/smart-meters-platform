import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/user_providers.dart';
import '../widgets/catalog_widgets.dart';

final _opportunityDetailProvider = FutureProvider.autoDispose
    .family<ConservationOpportunity?, String>((ref, opportunityId) {
      return OpportunityRepository(
        ref.read(supabaseClientProvider),
      ).getById(opportunityId);
    });

final _opportunityInvestigationsProvider = FutureProvider.autoDispose
    .family<List<ConservationInvestigation>, String>((ref, opportunityId) {
      return InvestigationRepository(
        ref.read(supabaseClientProvider),
      ).listByOpportunity(opportunityId);
    });

final _opportunityActionsProvider = FutureProvider.autoDispose
    .family<List<ConservationAction>, String>((ref, opportunityId) {
      return ActionRepository(
        ref.read(supabaseClientProvider),
      ).listByOpportunity(opportunityId);
    });

final _opportunityEvidenceProvider = FutureProvider.autoDispose
    .family<List<ConservationEvidence>, String>((ref, opportunityId) {
      return EvidenceRepository(
        ref.read(supabaseClientProvider),
      ).listByOpportunity(opportunityId);
    });

final _siteInvestigationsFlagProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, siteId) async {
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
      final opportunities = await flags.isEnabled(
        organizationId: site.organizationId,
        flagKey: ConservationFeatureFlags.opportunities,
        siteId: siteId,
      );
      if (!opportunities) return false;
      return flags.isEnabled(
        organizationId: site.organizationId,
        flagKey: ConservationFeatureFlags.investigations,
        siteId: siteId,
      );
    });

final _siteActionsFlagProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, siteId) async {
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
      final opportunities = await flags.isEnabled(
        organizationId: site.organizationId,
        flagKey: ConservationFeatureFlags.opportunities,
        siteId: siteId,
      );
      if (!opportunities) return false;
      return flags.isEnabled(
        organizationId: site.organizationId,
        flagKey: ConservationFeatureFlags.actions,
        siteId: siteId,
      );
    });

final _siteEvidenceFlagProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, siteId) async {
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
      final opportunities = await flags.isEnabled(
        organizationId: site.organizationId,
        flagKey: ConservationFeatureFlags.opportunities,
        siteId: siteId,
      );
      if (!opportunities) return false;
      return flags.isEnabled(
        organizationId: site.organizationId,
        flagKey: ConservationFeatureFlags.evidence,
        siteId: siteId,
      );
    });

/// Assignees: approved + active profiles with site access.
final _siteAssignableProfilesProvider = FutureProvider.autoDispose
    .family<List<AdminUser>, String>((ref, siteId) async {
      final users = await ref.watch(usersProvider.future);
      final repo = ref.read(userAdminRepositoryProvider);
      final out = <AdminUser>[];
      for (final u in users) {
        if (!u.profile.isApprovedForAccess) continue;
        final access = await repo.getUserSiteAccess(u.profile.id);
        if (access.any((a) => a.siteId == siteId && a.canRead)) {
          out.add(u);
        }
      }
      return out;
    });

/// Opportunity detail — investigation / actions / evidence workflow.
class OpportunityDetailScreen extends ConsumerWidget {
  const OpportunityDetailScreen({
    super.key,
    required this.opportunityId,
    required this.siteId,
  });

  final String opportunityId;
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final canManage = ref.watch(canManageMetersProvider);
    final oppAsync = ref.watch(_opportunityDetailProvider(opportunityId));
    final investigationsOn =
        ref.watch(_siteInvestigationsFlagProvider(siteId)).valueOrNull ?? false;
    final actionsOn =
        ref.watch(_siteActionsFlagProvider(siteId)).valueOrNull ?? false;
    final evidenceOn =
        ref.watch(_siteEvidenceFlagProvider(siteId)).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAr ? 'تفاصيل الفرصة' : 'Opportunity detail'),
      ),
      body: oppAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CatalogErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_opportunityDetailProvider(opportunityId)),
        ),
        data: (opp) {
          if (opp == null) {
            return CatalogEmptyState(
              title: s.isAr ? 'غير موجود' : 'Not found',
              message: opportunityId,
              icon: Icons.search_off,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opp.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(opp.description),
                      const SizedBox(height: 12),
                      Text(
                        '${ConservationOpportunity.potentialExcessLabel}: '
                        '${opp.estimatedWasteQuantity?.toStringAsFixed(1) ?? '—'} '
                        '${opp.unitCode ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Not Saving / Verified Saving / Confirmed Cause.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text('Status: ${opp.status.dbValue}'),
                      Text('Priority: ${opp.priority.dbValue}'),
                      Text('Source: ${opp.sourceType.dbValue}'),
                      Text('Confidence: ${opp.confidenceScore}'),
                      Text(
                        'Period: ${_iso(opp.detectedPeriodStart)} → '
                        '${_iso(opp.detectedPeriodEnd)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.isAr ? 'لقطة المصدر' : 'Source snapshot',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    opp.sourceSnapshot.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              if (canManage) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (investigationsOn &&
                        OpportunityLifecycle.canTransition(
                          opp.status,
                          OpportunityStatus.underInvestigation,
                        ))
                      OutlinedButton.icon(
                        onPressed: () => _startInvestigation(context, ref, opp),
                        icon: const Icon(Icons.search_outlined),
                        label: Text(
                          s.isAr ? 'بدء التحقيق' : 'Start investigation',
                        ),
                      ),
                    if (OpportunityLifecycle.canTransition(
                      opp.status,
                      OpportunityStatus.monitoring,
                    ))
                      OutlinedButton.icon(
                        onPressed: () => _startMonitoring(context, ref, opp),
                        icon: const Icon(Icons.monitor_heart_outlined),
                        label: Text(s.isAr ? 'متابعة' : 'Monitoring'),
                      ),
                    if (OpportunityLifecycle.canTransition(
                      opp.status,
                      OpportunityStatus.resolved,
                    ))
                      OutlinedButton.icon(
                        onPressed: () => _resolve(context, ref, opp),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(s.isAr ? 'إغلاق' : 'Resolve'),
                      ),
                    if (OpportunityLifecycle.canTransition(
                      opp.status,
                      OpportunityStatus.dismissed,
                    ))
                      OutlinedButton.icon(
                        onPressed: () => _dismiss(context, ref, opp),
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text(s.isAr ? 'تجاهل' : 'Dismiss'),
                      ),
                    if (opp.status.isClosed)
                      OutlinedButton.icon(
                        onPressed: () => _reopen(context, ref, opp),
                        icon: const Icon(Icons.restart_alt),
                        label: Text(s.isAr ? 'إعادة فتح' : 'Reopen'),
                      ),
                  ],
                ),
              ],
              if (investigationsOn) ...[
                const SizedBox(height: 20),
                Text(
                  s.isAr ? 'التحقيقات' : 'Investigations',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _InvestigationsBlock(
                  opportunityId: opportunityId,
                  siteId: siteId,
                  canManage: canManage,
                ),
              ],
              if (actionsOn) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.isAr ? 'الإجراءات' : 'Actions',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (canManage)
                      OutlinedButton.icon(
                        onPressed: () => _createAction(context, ref, opp),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(s.isAr ? 'إجراء' : 'Create action'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _ActionsBlock(
                  opportunityId: opportunityId,
                  canManage: canManage,
                ),
              ],
              if (evidenceOn) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.isAr ? 'الأدلة' : 'Evidence',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (canManage)
                      OutlinedButton.icon(
                        onPressed: () => _addEvidence(context, ref, opp),
                        icon: const Icon(Icons.note_add_outlined, size: 18),
                        label: Text(s.isAr ? 'ملاحظة/رابط' : 'Note / link'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _EvidenceBlock(opportunityId: opportunityId),
              ],
            ],
          );
        },
      ),
    );
  }

  OpportunityWorkflowService _workflow(WidgetRef ref) {
    final client = ref.read(supabaseClientProvider);
    return OpportunityWorkflowService(
      opportunityRepository: OpportunityRepository(client),
      auditRepository: WorkflowAuditRepository(client),
    );
  }

  Future<void> _startInvestigation(
    BuildContext context,
    WidgetRef ref,
    ConservationOpportunity opp,
  ) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await _workflow(ref).startInvestigation(opp.id);
      await InvestigationRepository(client).create(
        opportunityId: opp.id,
        siteId: opp.siteId,
        createdBy: client.auth.currentUser?.id,
      );
      _invalidateAll(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Investigation started')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _startMonitoring(
    BuildContext context,
    WidgetRef ref,
    ConservationOpportunity opp,
  ) async {
    try {
      await _workflow(ref).startMonitoring(opp.id);
      _invalidateAll(ref);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    ConservationOpportunity opp,
  ) async {
    try {
      await _workflow(ref).resolve(opp.id, resolutionReason: 'admin_resolve');
      _invalidateAll(ref);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _dismiss(
    BuildContext context,
    WidgetRef ref,
    ConservationOpportunity opp,
  ) async {
    try {
      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      await _workflow(ref).dismiss(
        opp.id,
        reason: OpportunityDismissReason.noActionRequired,
        dismissedBy: userId,
      );
      _invalidateAll(ref);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reopen(
    BuildContext context,
    WidgetRef ref,
    ConservationOpportunity opp,
  ) async {
    try {
      await _workflow(ref).reopen(opp.id);
      _invalidateAll(ref);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _createAction(
    BuildContext context,
    WidgetRef ref,
    ConservationOpportunity opp,
  ) async {
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final titleCtrl = TextEditingController(text: 'Follow-up action');
    var type = ConservationActionType.other;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isAr ? 'إجراء إجراء' : 'Create action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: s.isAr ? 'العنوان' : 'Title',
              ),
            ),
            DropdownButtonFormField<ConservationActionType>(
              initialValue: type,
              decoration: InputDecoration(labelText: s.isAr ? 'النوع' : 'Type'),
              items: [
                for (final t in ConservationActionType.values)
                  DropdownMenuItem(value: t, child: Text(t.dbValue)),
              ],
              onChanged: (v) {
                if (v != null) type = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.isAr ? 'إنشاء' : 'Create'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      final investigations = await InvestigationRepository(
        client,
      ).listByOpportunity(opp.id, limit: 1);
      await ActionRepository(client).create(
        opportunityId: opp.id,
        siteId: opp.siteId,
        title: titleCtrl.text.trim().isEmpty
            ? 'Follow-up action'
            : titleCtrl.text.trim(),
        actionType: type,
        investigationId: investigations.isEmpty
            ? null
            : investigations.first.id,
        priority: opp.priority,
        createdBy: client.auth.currentUser?.id,
      );
      if (OpportunityLifecycle.canTransition(
        opp.status,
        OpportunityStatus.actionRequired,
      )) {
        await _workflow(ref).markActionRequired(opp.id);
      }
      _invalidateAll(ref);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addEvidence(
    BuildContext context,
    WidgetRef ref,
    ConservationOpportunity opp,
  ) async {
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final titleCtrl = TextEditingController(text: 'Evidence note');
    final notesCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    var kind = ConservationEvidenceKind.note;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(s.isAr ? 'دليل' : 'Evidence'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<ConservationEvidenceKind>(
                      initialValue: kind,
                      items: [
                        DropdownMenuItem(
                          value: ConservationEvidenceKind.note,
                          child: Text(s.isAr ? 'ملاحظة' : 'Note'),
                        ),
                        DropdownMenuItem(
                          value: ConservationEvidenceKind.documentLink,
                          child: Text(s.isAr ? 'رابط' : 'Document link'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => kind = v);
                      },
                    ),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'العنوان' : 'Title',
                      ),
                    ),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'ملاحظات' : 'Notes',
                      ),
                      maxLines: 2,
                    ),
                    if (kind == ConservationEvidenceKind.documentLink)
                      TextField(
                        controller: urlCtrl,
                        decoration: const InputDecoration(labelText: 'URL'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.isAr ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(s.isAr ? 'حفظ' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await EvidenceRepository(client).insert(
        ConservationEvidence(
          id: '',
          siteId: opp.siteId,
          opportunityId: opp.id,
          evidenceKind: kind,
          evidencePhase: ConservationEvidencePhase.general,
          title: titleCtrl.text.trim().isEmpty
              ? 'Evidence'
              : titleCtrl.text.trim(),
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          externalUrl: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
          referenceJson: const {},
          uploadedBy: client.auth.currentUser?.id,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      ref.invalidate(_opportunityEvidenceProvider(opportunityId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(_opportunityDetailProvider(opportunityId));
    ref.invalidate(_opportunityInvestigationsProvider(opportunityId));
    ref.invalidate(_opportunityActionsProvider(opportunityId));
    ref.invalidate(_opportunityEvidenceProvider(opportunityId));
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _InvestigationsBlock extends ConsumerWidget {
  const _InvestigationsBlock({
    required this.opportunityId,
    required this.siteId,
    required this.canManage,
  });

  final String opportunityId;
  final String siteId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final async = ref.watch(_opportunityInvestigationsProvider(opportunityId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (items) {
        if (items.isEmpty) {
          return Text(s.isAr ? 'لا تحقيقات بعد' : 'No investigations yet');
        }
        return Column(
          children: [
            for (final inv in items) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.investigationStatus.dbValue,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (inv.assignedTo != null)
                        Text('Assigned: ${inv.assignedTo}'),
                      if (inv.findingSummary != null)
                        Text('Findings: ${inv.findingSummary}'),
                      if (inv.possibleCause != null)
                        Text('Possible cause: ${inv.possibleCause}'),
                      if (inv.confirmedCause != null)
                        Text(
                          'Confirmed cause (human): '
                          '${inv.confirmedCause!.dbValue}',
                        ),
                      if (canManage) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => _assign(context, ref, inv, s),
                              child: Text(
                                s.isAr ? 'تعيين فني' : 'Assign technician',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _findings(context, ref, inv, s),
                              child: Text(s.isAr ? 'نتائج' : 'Findings'),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  _confirmCause(context, ref, inv, s),
                              child: Text(
                                s.isAr ? 'تأكيد السبب' : 'Confirm cause',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    ConservationInvestigation inv,
    AdminStrings s,
  ) async {
    final assignees = await ref.read(
      _siteAssignableProfilesProvider(siteId).future,
    );
    if (!context.mounted) return;
    if (assignees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isAr
                ? 'لا مستخدمين معتمدين لهذا الموقع'
                : 'No approved users with site access',
          ),
        ),
      );
      return;
    }
    String? selected = assignees.first.profile.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isAr ? 'تعيين' : 'Assign'),
        content: DropdownButtonFormField<String>(
          initialValue: selected,
          items: [
            for (final u in assignees)
              DropdownMenuItem(value: u.profile.id, child: Text(u.displayName)),
          ],
          onChanged: (v) => selected = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.isAr ? 'تعيين' : 'Assign'),
          ),
        ],
      ),
    );
    if (ok != true || selected == null) return;
    try {
      final client = ref.read(supabaseClientProvider);
      final actor = client.auth.currentUser?.id;
      if (actor == null) throw StateError('Not signed in');
      await InvestigationRepository(
        client,
      ).assign(id: inv.id, assignedTo: selected!, assignedBy: actor);
      ref.invalidate(_opportunityInvestigationsProvider(opportunityId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _findings(
    BuildContext context,
    WidgetRef ref,
    ConservationInvestigation inv,
    AdminStrings s,
  ) async {
    final summaryCtrl = TextEditingController(text: inv.findingSummary ?? '');
    final causeCtrl = TextEditingController(text: inv.possibleCause ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isAr ? 'نتائج التحقيق' : 'Findings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: summaryCtrl,
              decoration: InputDecoration(
                labelText: s.isAr ? 'الملخص' : 'Summary',
              ),
              maxLines: 3,
            ),
            TextField(
              controller: causeCtrl,
              decoration: InputDecoration(
                labelText: s.isAr ? 'سبب محتمل' : 'Possible cause',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.isAr ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await InvestigationRepository(
        ref.read(supabaseClientProvider),
      ).updateFindings(
        id: inv.id,
        findingSummary: summaryCtrl.text.trim(),
        possibleCause: causeCtrl.text.trim().isEmpty
            ? null
            : causeCtrl.text.trim(),
      );
      ref.invalidate(_opportunityInvestigationsProvider(opportunityId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _confirmCause(
    BuildContext context,
    WidgetRef ref,
    ConservationInvestigation inv,
    AdminStrings s,
  ) async {
    var cause = ConfirmedCause.unknown;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(
                s.isAr
                    ? 'تأكيد السبب (بشري فقط)'
                    : 'Confirm cause (human only)',
              ),
              content: DropdownButtonFormField<ConfirmedCause>(
                initialValue: cause,
                items: [
                  for (final c in ConfirmedCause.values)
                    DropdownMenuItem(value: c, child: Text(c.dbValue)),
                ],
                onChanged: (v) {
                  if (v != null) setLocal(() => cause = v);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.isAr ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(s.isAr ? 'تأكيد' : 'Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    try {
      final client = ref.read(supabaseClientProvider);
      final actor = client.auth.currentUser?.id;
      if (actor == null) throw StateError('Not signed in');
      await InvestigationRepository(
        client,
      ).confirmCause(id: inv.id, cause: cause, confirmedBy: actor);
      ref.invalidate(_opportunityInvestigationsProvider(opportunityId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _ActionsBlock extends ConsumerWidget {
  const _ActionsBlock({required this.opportunityId, required this.canManage});
  final String opportunityId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_opportunityActionsProvider(opportunityId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (items) {
        if (items.isEmpty) return const Text('No actions yet');
        return Column(
          children: [
            for (final a in items) ...[
              Card(
                child: ListTile(
                  title: Text(a.title),
                  subtitle: Text(
                    '${a.actionType.dbValue} · ${a.status.dbValue} · '
                    '${a.priority.dbValue}'
                    '${a.dueDate == null ? '' : '\nDue ${_iso(a.dueDate!)}'}'
                    '\nImplementation cost: '
                    '${a.implementationCost == null ? 'N/A (ROI N/A)' : '${a.implementationCost} ${a.costCurrency ?? 'QAR'}'}',
                  ),
                  isThreeLine: true,
                  trailing: canManage
                      ? IconButton(
                          tooltip: 'Set implementation cost',
                          icon: const Icon(Icons.payments_outlined),
                          onPressed: () => _setCost(context, ref, a),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Future<void> _setCost(
    BuildContext context,
    WidgetRef ref,
    ConservationAction action,
  ) async {
    final costCtrl = TextEditingController(
      text: action.implementationCost?.toString() ?? '',
    );
    final currencyCtrl = TextEditingController(
      text: action.costCurrency ?? 'QAR',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Implementation cost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: costCtrl,
              decoration: const InputDecoration(
                labelText: 'Cost (empty = clear / ROI N/A)',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: currencyCtrl,
              decoration: const InputDecoration(labelText: 'Currency'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final raw = costCtrl.text.trim();
      await ActionRepository(ref.read(supabaseClientProvider)).updateCost(
        id: action.id,
        implementationCost: raw.isEmpty ? null : double.parse(raw),
        costCurrency: currencyCtrl.text.trim().isEmpty
            ? 'QAR'
            : currencyCtrl.text.trim(),
        costSource: 'site_admin',
      );
      ref.invalidate(_opportunityActionsProvider(opportunityId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Implementation cost saved')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _EvidenceBlock extends ConsumerWidget {
  const _EvidenceBlock({required this.opportunityId});
  final String opportunityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_opportunityEvidenceProvider(opportunityId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (items) {
        if (items.isEmpty) return const Text('No evidence yet');
        return Column(
          children: [
            for (final e in items) ...[
              Card(
                child: ListTile(
                  title: Text(e.title),
                  subtitle: Text(
                    '${e.evidenceKind.dbValue} · ${e.evidencePhase.dbValue}'
                    '${e.notes == null ? '' : '\n${e.notes}'}'
                    '${e.externalUrl == null ? '' : '\n${e.externalUrl}'}'
                    '${e.storagePath == null ? '' : '\n${e.storagePath}'}',
                  ),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
