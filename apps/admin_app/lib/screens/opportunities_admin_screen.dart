import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';
import 'opportunity_detail_screen.dart';

final _siteOpportunitiesEnabledProvider = FutureProvider.autoDispose
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
      return flags.isEnabled(
        organizationId: site.organizationId,
        flagKey: ConservationFeatureFlags.opportunities,
        siteId: siteId,
      );
    });

final _siteOpportunitiesProvider = FutureProvider.autoDispose
    .family<List<ConservationOpportunity>, String>((ref, siteId) {
      return OpportunityRepository(
        ref.read(supabaseClientProvider),
      ).listForSite(siteId, limit: 100);
    });

enum _OppFilter {
  all,
  open,
  underInvestigation,
  actionsDue,
  monitoring,
  closed,
}

/// Admin list for conservation opportunities (gated by module + opportunities).
class OpportunitiesAdminScreen extends ConsumerStatefulWidget {
  const OpportunitiesAdminScreen({super.key, required this.siteId});

  final String siteId;

  @override
  ConsumerState<OpportunitiesAdminScreen> createState() =>
      _OpportunitiesAdminScreenState();
}

class _OpportunitiesAdminScreenState
    extends ConsumerState<OpportunitiesAdminScreen> {
  _OppFilter _filter = _OppFilter.open;
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final enabledAsync = ref.watch(
      _siteOpportunitiesEnabledProvider(widget.siteId),
    );
    final canManage = ref.watch(canManageMetersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAr ? 'فرص الترشيد' : 'Conservation opportunities'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: s.isAr ? 'تحديث من الإشارات' : 'Refresh from signals',
              onPressed: _refreshing
                  ? null
                  : () => _refreshFromSignals(context, s),
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
      ),
      floatingActionButton: enabledAsync.maybeWhen(
        data: (on) => on && canManage
            ? FloatingActionButton.extended(
                onPressed: () => _showManualCreate(context, s),
                icon: const Icon(Icons.add),
                label: Text(s.isAr ? 'يدوي' : 'Manual'),
              )
            : null,
        orElse: () => null,
      ),
      body: enabledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CatalogErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_siteOpportunitiesEnabledProvider(widget.siteId)),
        ),
        data: (enabled) {
          if (!enabled) {
            return CatalogEmptyState(
              title: s.isAr ? 'الفرص غير مفعّلة' : 'Opportunities disabled',
              message: s.isAr
                  ? 'فعّل conservation_module و opportunities.'
                  : 'Enable conservation_module and opportunities.',
              icon: Icons.flag_outlined,
            );
          }
          final listAsync = ref.watch(
            _siteOpportunitiesProvider(widget.siteId),
          );
          return listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => CatalogErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(_siteOpportunitiesProvider(widget.siteId)),
            ),
            data: (all) {
              final filtered = all.where(_matchesFilter).toList();
              return Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        for (final f in _OppFilter.values) ...[
                          FilterChip(
                            label: Text(_filterLabel(f, s)),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? CatalogEmptyState(
                            title: s.isAr ? 'لا توجد فرص' : 'No opportunities',
                            message: s.isAr
                                ? 'أنشئ يدوياً أو حدّث من الإشارات.'
                                : 'Create manually or refresh from signals.',
                            icon: Icons.lightbulb_outline,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final o = filtered[index];
                              return Card(
                                child: ListTile(
                                  title: Text(o.title),
                                  subtitle: Text(
                                    '${o.status.dbValue} · ${o.priority.dbValue} · '
                                    '${o.utilityType}\n'
                                    '${ConservationOpportunity.potentialExcessLabel}: '
                                    '${o.estimatedWasteQuantity?.toStringAsFixed(1) ?? '—'} '
                                    '${o.unitCode ?? ''}\n'
                                    '≠ Saving / Verified Saving',
                                  ),
                                  isThreeLine: true,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => OpportunityDetailScreen(
                                          opportunityId: o.id,
                                          siteId: widget.siteId,
                                        ),
                                      ),
                                    );
                                    ref.invalidate(
                                      _siteOpportunitiesProvider(widget.siteId),
                                    );
                                  },
                                  trailing: canManage
                                      ? PopupMenuButton<String>(
                                          onSelected: (action) =>
                                              _runWorkflowAction(
                                                context,
                                                s,
                                                o,
                                                action,
                                              ),
                                          itemBuilder: (_) => [
                                            if (OpportunityLifecycle.canTransition(
                                              o.status,
                                              OpportunityStatus.triaged,
                                            ))
                                              PopupMenuItem(
                                                value: 'triage',
                                                child: Text(
                                                  s.isAr ? 'فرز' : 'Triage',
                                                ),
                                              ),
                                            if (OpportunityLifecycle.canTransition(
                                              o.status,
                                              OpportunityStatus.resolved,
                                            ))
                                              PopupMenuItem(
                                                value: 'resolve',
                                                child: Text(
                                                  s.isAr ? 'إغلاق' : 'Resolve',
                                                ),
                                              ),
                                            if (OpportunityLifecycle.canTransition(
                                              o.status,
                                              OpportunityStatus.dismissed,
                                            ))
                                              PopupMenuItem(
                                                value: 'dismiss',
                                                child: Text(
                                                  s.isAr ? 'تجاهل' : 'Dismiss',
                                                ),
                                              ),
                                            if (o.status.isClosed)
                                              PopupMenuItem(
                                                value: 'reopen',
                                                child: Text(
                                                  s.isAr
                                                      ? 'إعادة فتح'
                                                      : 'Reopen',
                                                ),
                                              ),
                                          ],
                                        )
                                      : const Icon(Icons.chevron_right),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  bool _matchesFilter(ConservationOpportunity o) => switch (_filter) {
    _OppFilter.all => true,
    _OppFilter.open =>
      o.status == OpportunityStatus.detected ||
          o.status == OpportunityStatus.triaged,
    _OppFilter.underInvestigation =>
      o.status == OpportunityStatus.underInvestigation,
    _OppFilter.actionsDue => o.status == OpportunityStatus.actionRequired,
    _OppFilter.monitoring => o.status == OpportunityStatus.monitoring,
    _OppFilter.closed => o.status.isClosed,
  };

  String _filterLabel(_OppFilter f, AdminStrings s) => switch (f) {
    _OppFilter.all => s.isAr ? 'الكل' : 'All',
    _OppFilter.open => s.isAr ? 'مفتوحة' : 'Open',
    _OppFilter.underInvestigation =>
      s.isAr ? 'قيد التحقيق' : 'Under Investigation',
    _OppFilter.actionsDue => s.isAr ? 'إجراءات' : 'Actions Due',
    _OppFilter.monitoring => s.isAr ? 'متابعة' : 'Monitoring',
    _OppFilter.closed => s.isAr ? 'مغلقة' : 'Resolved',
  };

  OpportunityWorkflowService _workflow() {
    final client = ref.read(supabaseClientProvider);
    return OpportunityWorkflowService(
      opportunityRepository: OpportunityRepository(client),
      auditRepository: WorkflowAuditRepository(client),
    );
  }

  Future<void> _runWorkflowAction(
    BuildContext context,
    AdminStrings s,
    ConservationOpportunity o,
    String action,
  ) async {
    try {
      final wf = _workflow();
      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      switch (action) {
        case 'triage':
          await wf.triage(o.id);
        case 'resolve':
          await wf.resolve(o.id, resolutionReason: 'resolved_via_admin');
        case 'dismiss':
          await wf.dismiss(
            o.id,
            reason: OpportunityDismissReason.noActionRequired,
            dismissedBy: userId,
          );
        case 'reopen':
          await wf.reopen(o.id);
      }
      ref.invalidate(_siteOpportunitiesProvider(widget.siteId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.isAr ? 'تم' : 'Updated')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showManualCreate(BuildContext context, AdminStrings s) async {
    final titleCtrl = TextEditingController(text: 'Manual opportunity');
    final descCtrl = TextEditingController();
    var utility = 'water';
    var unit = 'm³';
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(s.isAr ? 'فرصة يدوية' : 'Manual opportunity'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'العنوان' : 'Title',
                      ),
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'الوصف' : 'Description',
                      ),
                      maxLines: 2,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: utility,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'المنفعة' : 'Utility',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'water', child: Text('water')),
                        DropdownMenuItem(
                          value: 'electricity',
                          child: Text('electricity'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() {
                          utility = v;
                          unit = v == 'water' ? 'm³' : 'kWh';
                        });
                      },
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
                  child: Text(s.isAr ? 'إنشاء' : 'Create'),
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
      final fingerprint = buildOpportunityFingerprint(
        siteId: widget.siteId,
        sourceType: OpportunitySourceType.manual.dbValue,
        sourceEntityKey: 'manual:${DateTime.now().millisecondsSinceEpoch}',
        periodStart: start,
        periodEnd: end,
        ruleVersion: OpportunitySignalRules.defaultRuleVersion,
      );
      await OpportunityRepository(client).insert(
        ConservationOpportunity(
          id: '',
          siteId: widget.siteId,
          utilityType: utility,
          origin: OpportunityOrigin.manual,
          sourceType: OpportunitySourceType.manual,
          sourceFingerprint: fingerprint,
          title: titleCtrl.text.trim().isEmpty
              ? 'Manual opportunity'
              : titleCtrl.text.trim(),
          description: descCtrl.text.trim(),
          detectedPeriodStart: start,
          detectedPeriodEnd: end,
          unitCode: unit,
          confidenceScore: 50,
          priority: OpportunityPriorityLevel.medium,
          status: OpportunityStatus.detected,
          possibleCauses: const ['unknown'],
          suggestedInvestigations: const [
            'Review site readings for the period',
          ],
          sourceSnapshot: const {
            'quantity_label': ConservationOpportunityLabels.potentialExcess,
            'manual': true,
          },
          ruleVersion: OpportunitySignalRules.defaultRuleVersion,
          createdBy: client.auth.currentUser?.id,
          detectedAt: DateTime.now().toUtc(),
        ),
      );
      ref.invalidate(_siteOpportunitiesProvider(widget.siteId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.isAr ? 'تم الإنشاء' : 'Created')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _refreshFromSignals(BuildContext context, AdminStrings s) async {
    setState(() => _refreshing = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final site = await ref.read(adminSiteProvider(widget.siteId).future);
      final flags = ConservationFeatureFlagRepository(client);
      final orgId = site.organizationId;

      Future<bool> flagOn(String key) => flags.isEnabled(
        organizationId: orgId,
        flagKey: key,
        siteId: widget.siteId,
      );

      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month, 1);
      final periodEnd = DateTime(now.year, now.month + 1, 0);

      final candidates = <OpportunityCandidate>[];
      const engine = OpportunityEngine();

      final waterBal = await flagOn(ConservationFeatureFlags.waterBalance);
      final energyBal = await flagOn(ConservationFeatureFlags.energyBalance);
      if (waterBal || energyBal) {
        final groups = await BalanceGroupRepository(
          client,
        ).listForSite(widget.siteId);
        final meters = await ref
            .read(meterRepositoryProvider)
            .getMetersForSite(widget.siteId);
        final metersById = {for (final meter in meters) meter.id: meter};
        final byMeter = await _loadReadings(
          widget.siteId,
          meters.map((m) => m.id).toList(),
          periodStart.subtract(const Duration(days: 1)),
          periodEnd,
        );
        const calculator = VirtualMeterCalculator();
        const balance = BalanceService();
        for (final g in groups) {
          if (g.status != BalanceGroupStatus.active) continue;
          final u = g.utilityCode.toLowerCase();
          if (u == 'water' && !waterBal) continue;
          if (u == 'electricity' && !energyBal) continue;
          final children = calculator.contributorsFromSeries(
            leaves: [
              for (final id in g.memberMeterIds)
                PeriodMeterReadingSeries.fromMeter(
                  meter: metersById[id]!,
                  unitCode: g.unitCode,
                  readings: byMeter[id] ?? const [],
                ),
            ],
            periodStart: periodStart,
            periodEnd: periodEnd,
          );
          final main = calculator
              .contributorsFromSeries(
                leaves: [
                  PeriodMeterReadingSeries.fromMeter(
                    meter: metersById[g.mainMeterId]!,
                    unitCode: g.unitCode,
                    readings: byMeter[g.mainMeterId] ?? const [],
                  ),
                ],
                periodStart: periodStart,
                periodEnd: periodEnd,
              )
              .single;
          final result = balance.evaluate(
            utilityCode: g.utilityCode,
            unitCode: g.unitCode,
            mainMeterId: g.mainMeterId,
            children: children,
            main: main,
            periodStart: periodStart,
            periodEnd: periodEnd,
            balanceGroupId: g.id,
          );
          candidates.addAll(
            engine.buildCandidatesFromSignals(
              siteId: widget.siteId,
              utilityType: u,
              balances: [result],
            ),
          );
        }
      }

      if (await flagOn(ConservationFeatureFlags.targets)) {
        final targets = await ConservationTargetRepository(
          client,
        ).listForSite(widget.siteId, status: ConservationTargetStatus.active);
        final meters = await ref
            .read(meterRepositoryProvider)
            .getMetersForSite(widget.siteId);
        final active = meters.where((m) => m.isActive).toList();
        final byMeter = await _loadReadings(
          widget.siteId,
          active.map((m) => m.id).toList(),
          periodStart.subtract(const Duration(days: 1)),
          periodEnd,
        );
        const service = ActualVsTargetService();
        for (final t in targets) {
          if (t.scopeType != ConservationTargetScopeType.site) continue;
          final series = [
            for (final m in active)
              PeriodMeterReadingSeries.fromMeter(
                meter: m,
                unitCode: t.unitCode,
                readings: byMeter[m.id] ?? const [],
              ),
          ];
          final r = service.evaluate(
            target: t,
            meters: series,
            analysisAsOf: periodEnd,
          );
          final utility = t.unitCode.toLowerCase().contains('kwh')
              ? 'electricity'
              : 'water';
          candidates.addAll(
            engine.buildCandidatesFromSignals(
              siteId: widget.siteId,
              utilityType: utility,
              actualVsTargets: [r],
            ),
          );
        }
      }

      if (await flagOn(ConservationFeatureFlags.baseline)) {
        final baselines = await ConservationBaselineRepository(
          client,
        ).listApprovedForSite(widget.siteId);
        final meters = await ref
            .read(meterRepositoryProvider)
            .getMetersForSite(widget.siteId);
        final active = meters.where((m) => m.isActive).toList();
        final byMeter = await _loadReadings(
          widget.siteId,
          active.map((m) => m.id).toList(),
          periodStart.subtract(const Duration(days: 1)),
          periodEnd,
        );
        const service = ActualVsBaselineService();
        for (final b in baselines) {
          if (b.scopeType != ConservationBaselineScopeType.site) continue;
          final series = [
            for (final m in active)
              PeriodMeterReadingSeries.fromMeter(
                meter: m,
                unitCode: b.unitCode,
                readings: byMeter[m.id] ?? const [],
              ),
          ];
          final r = service.evaluate(
            baseline: b,
            meters: series,
            analysisPeriodStart: periodStart,
            analysisPeriodEnd: periodEnd,
            analysisAsOf: periodEnd,
          );
          final utility = b.unitCode.toLowerCase().contains('kwh')
              ? 'electricity'
              : 'water';
          candidates.addAll(
            engine.buildCandidatesFromSignals(
              siteId: widget.siteId,
              utilityType: utility,
              actualVsBaselines: [r],
            ),
          );
        }
      }

      final generation =
          await OpportunityGenerationService(
            repository: OpportunityRepository(client),
          ).refreshForSite(
            siteId: widget.siteId,
            periodStart: periodStart,
            periodEnd: periodEnd,
            candidates: candidates,
            createdBy: client.auth.currentUser?.id,
          );
      ref.invalidate(_siteOpportunitiesProvider(widget.siteId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isAr
                ? 'تم: ${generation.created} جديد / ${generation.refreshed} محدّث'
                : 'Done: ${generation.created} created / '
                      '${generation.refreshed} refreshed '
                      '(${candidates.length} candidates)',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<Map<String, List<PeriodReadingPoint>>> _loadReadings(
    String siteId,
    List<String> meterIds,
    DateTime from,
    DateTime to,
  ) async {
    final client = ref.read(supabaseClientProvider);
    final byMeter = <String, List<PeriodReadingPoint>>{};
    if (meterIds.isEmpty) return byMeter;
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final rows = await client
        .from('meter_readings')
        .select('meter_id, reading_date, raw_value')
        .eq('site_id', siteId)
        .inFilter('meter_id', meterIds)
        .gte('reading_date', iso(from))
        .lte('reading_date', iso(to))
        .order('reading_date');
    for (final row in (rows as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['meter_id'] as String;
      byMeter
          .putIfAbsent(id, () => [])
          .add(
            PeriodReadingPoint(
              date: DateTime.parse(map['reading_date'] as String),
              value: (map['raw_value'] as num).toDouble(),
            ),
          );
    }
    return byMeter;
  }
}
