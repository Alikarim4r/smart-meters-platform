import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';

final _siteBaselinesEnabledProvider = FutureProvider.autoDispose
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
        flagKey: ConservationFeatureFlags.baseline,
        siteId: siteId,
      );
    });

final _siteBaselineHistoryProvider = FutureProvider.autoDispose
    .family<List<ConservationBaseline>, String>((ref, siteId) {
      return ConservationBaselineRepository(
        ref.read(supabaseClientProvider),
      ).listHistoryForSite(siteId);
    });

/// Admin UI for versioned baselines (gated by conservation_module + baseline).
class BaselinesAdminScreen extends ConsumerWidget {
  const BaselinesAdminScreen({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final enabledAsync = ref.watch(_siteBaselinesEnabledProvider(siteId));
    final canManage = ref.watch(canManageMetersProvider);
    final profile = ref.watch(authProvider).profile;
    final canApprove =
        canManage &&
        (profile?.isSiteAdmin == true ||
            profile?.isSuperAdmin == true ||
            profile?.isPlatformOwner == true);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAr ? 'خطوط الأساس' : 'Conservation baselines'),
      ),
      floatingActionButton: enabledAsync.maybeWhen(
        data: (on) => on && canManage
            ? FloatingActionButton.extended(
                onPressed: () => _openCreateDraft(context, ref),
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
          onRetry: () => ref.invalidate(_siteBaselinesEnabledProvider(siteId)),
        ),
        data: (enabled) {
          if (!enabled) {
            return CatalogEmptyState(
              title: s.isAr ? 'Baselines غير مفعّلة' : 'Baselines disabled',
              message: s.isAr
                  ? 'فعّل conservation_module و baseline.'
                  : 'Enable conservation_module and baseline for this org/site.',
              icon: Icons.flag_outlined,
            );
          }
          final historyAsync = ref.watch(_siteBaselineHistoryProvider(siteId));
          return historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => CatalogErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(_siteBaselineHistoryProvider(siteId)),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return CatalogEmptyState(
                  title: s.isAr ? 'لا توجد خطوط أساس' : 'No baselines',
                  message: s.isAr
                      ? 'أنشئ مسودة، راجع الاكتمال والثقة، ثم اعتمد.'
                      : 'Create a draft, review completeness/confidence, then approve.',
                  icon: Icons.insights_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final b = rows[index];
                  final gate = BaselineApprovalService.checkGates(draft: b);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${b.label.isEmpty ? 'Baseline' : b.label} · '
                                  'v${b.versionNumber} · ${b.unitCode}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              _StatusBadge(status: b.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_iso(b.referencePeriodStart)} → ${_iso(b.referencePeriodEnd)} · '
                            '${b.calculationMethod.dbValue}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Value: ${b.baselineValue} ${b.unitCode} · '
                            'Completeness: ${((b.dataCompleteness ?? 0) * 100).toStringAsFixed(0)}% · '
                            'Confidence: ${b.confidenceScore ?? '—'} · '
                            'Boundary: ${b.boundaryQuality?.dbValue ?? '—'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (b.status == ConservationBaselineStatus.draft &&
                              !gate.allowed) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Approval blocked:\n- ${gate.reasons.join('\n- ')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                          if (b.status == ConservationBaselineStatus.draft &&
                              canApprove) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: FilledButton(
                                onPressed: !gate.allowed
                                    ? null
                                    : () async {
                                        try {
                                          await BaselineApprovalService(
                                            ref.read(supabaseClientProvider),
                                          ).approve(
                                            draftId: b.id,
                                            approvedBy: profile!.id,
                                          );
                                          ref.invalidate(
                                            _siteBaselineHistoryProvider(
                                              siteId,
                                            ),
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                s.isAr
                                                    ? 'تم الاعتماد (الإصدار السابق superseded)'
                                                    : 'Approved (previous approved superseded)',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                adminUserError(context),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                child: Text(s.isAr ? 'اعتماد' : 'Approve'),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  Future<void> _openCreateDraft(BuildContext context, WidgetRef ref) async {
    final s = AdminStrings(ref.read(adminLocaleProvider));
    var method = BaselineCalculationMethod.totalPeriod;
    final labelCtrl = TextEditingController(text: 'Baseline');
    final valueCtrl = TextEditingController(text: '100');
    final unitCtrl = TextEditingController(text: 'kWh');
    final now = DateTime.now();
    var start = DateTime(now.year, now.month - 1, 1);
    var end = DateTime(now.year, now.month, 0);

    BaselineCalculationResult? preview;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(s.isAr ? 'مسودة خط أساس' : 'Draft baseline'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'التسمية' : 'Label',
                      ),
                    ),
                    DropdownButtonFormField<BaselineCalculationMethod>(
                      initialValue: method,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'طريقة الحساب' : 'Method',
                      ),
                      items: [
                        for (final m in BaselineCalculationMethod.values)
                          DropdownMenuItem(value: m, child: Text(m.dbValue)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => method = v);
                      },
                    ),
                    TextField(
                      controller: unitCtrl,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'الوحدة' : 'Unit code',
                      ),
                    ),
                    if (method == BaselineCalculationMethod.customFixed)
                      TextField(
                        controller: valueCtrl,
                        decoration: InputDecoration(
                          labelText: s.isAr ? 'قيمة ثابتة' : 'Fixed value',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Reference: ${_iso(start)} → ${_iso(end)}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        // Preview for custom_fixed without readings; for
                        // reading-derived methods admin should rely on gates
                        // after save with completeness from a later calc pass.
                        final calc = const BaselineCalculationService()
                            .calculate(
                              method: method,
                              referencePeriodStart: start,
                              referencePeriodEnd: end,
                              unitCode: unitCtrl.text.trim().isEmpty
                                  ? 'kWh'
                                  : unitCtrl.text.trim(),
                              meters: const [],
                              customFixedValue: double.tryParse(
                                valueCtrl.text.trim(),
                              ),
                            );
                        setLocal(() => preview = calc);
                      },
                      child: Text(
                        s.isAr
                            ? 'معاينة (custom)'
                            : 'Preview (custom / empty meters)',
                      ),
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Preview value: ${preview!.baselineValue ?? 'N/A'} · '
                        'Completeness ${(preview!.completeness * 100).toStringAsFixed(0)}% · '
                        'Confidence ${preview!.confidenceScore} · '
                        '${preview!.boundaryQuality.dbValue}',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      if (preview!.warnings.isNotEmpty)
                        Text(
                          preview!.warnings.join('\n'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      s.isAr
                          ? 'Baseline ≠ Target. الاعتماد يتطلب حدود exact/pre-period واكتمال/ثقة كافيين.'
                          : 'Baseline ≠ Target. Approval requires exact/pre-period boundaries and quality gates.',
                      style: Theme.of(ctx).textTheme.bodySmall,
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
                  child: Text(s.isAr ? 'حفظ مسودة' : 'Save draft'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final unit = unitCtrl.text.trim();
    if (unit.isEmpty) return;

    // Prefer reading-derived calc when meters available.
    final meters = await ref
        .read(meterRepositoryProvider)
        .getMetersForSite(siteId);
    final active = meters.where((m) => m.isActive).toList();
    final matching = active.where((m) {
      final code = (m.categoryConfig?.code ?? m.category.dbValue).toLowerCase();
      if (unit == 'kWh' || unit.toLowerCase() == 'kwh') {
        return code.contains('electric');
      }
      if (unit == 'm³' || unit.toLowerCase().contains('m3')) {
        return code.contains('water');
      }
      return true;
    }).toList();

    final toIso =
        '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    final fetchFrom = start.subtract(const Duration(days: 1));
    final fetchFromIso =
        '${fetchFrom.year.toString().padLeft(4, '0')}-${fetchFrom.month.toString().padLeft(2, '0')}-${fetchFrom.day.toString().padLeft(2, '0')}';

    final byMeter = <String, List<PeriodReadingPoint>>{};
    if (matching.isNotEmpty &&
        method != BaselineCalculationMethod.customFixed) {
      final rows = await ref
          .read(supabaseClientProvider)
          .from('meter_readings')
          .select('meter_id, reading_date, raw_value')
          .eq('site_id', siteId)
          .inFilter('meter_id', matching.map((m) => m.id).toList())
          .gte('reading_date', fetchFromIso)
          .lte('reading_date', toIso)
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
    }

    final series = [
      for (final m in matching)
        PeriodMeterReadingSeries.fromMeter(
          meter: m,
          unitCode: unit,
          readings: byMeter[m.id] ?? const [],
        ),
    ];

    final calc = const BaselineCalculationService().calculate(
      method: method,
      referencePeriodStart: start,
      referencePeriodEnd: end,
      unitCode: unit,
      meters: series,
      customFixedValue: double.tryParse(valueCtrl.text.trim()),
    );

    final profile = ref.read(authProvider).profile;
    final value =
        calc.baselineValue ?? (double.tryParse(valueCtrl.text.trim()) ?? 0.0);

    await ConservationBaselineRepository(
      ref.read(supabaseClientProvider),
    ).createDraft(
      siteId: siteId,
      scopeType: ConservationBaselineScopeType.site,
      label: labelCtrl.text.trim(),
      referencePeriodStart: start,
      referencePeriodEnd: end,
      calculationMethod: method,
      baselineValue: value,
      unitCode: unit,
      notes: calc.message,
      dataCompleteness: calc.completeness,
      confidenceScore: calc.confidenceScore,
      boundaryQuality: calc.boundaryQuality,
      calculationMeta: calc.meta.toJson(),
      createdBy: profile?.id,
    );
    ref.invalidate(_siteBaselineHistoryProvider(siteId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          calc.isInsufficient
              ? (s.isAr
                    ? 'حُفظت مسودة ببيانات غير كافية (لا يمكن الاعتماد)'
                    : 'Draft saved with Insufficient Data (not approvable)')
              : (s.isAr ? 'تم حفظ المسودة' : 'Draft saved'),
        ),
      ),
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ConservationBaselineStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConservationBaselineStatus.draft => Colors.blueGrey,
      ConservationBaselineStatus.approved => Colors.green.shade700,
      ConservationBaselineStatus.superseded => Colors.orange.shade800,
      ConservationBaselineStatus.archived => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.dbValue,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
