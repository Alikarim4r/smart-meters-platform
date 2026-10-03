import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../l10n/admin_strings.dart';
import '../widgets/catalog_widgets.dart';

final _siteTargetsEnabledProvider = FutureProvider.autoDispose
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
        flagKey: ConservationFeatureFlags.targets,
        siteId: siteId,
      );
    });

final _siteTargetsProvider = FutureProvider.autoDispose
    .family<List<ConservationTarget>, String>((ref, siteId) {
      return ConservationTargetRepository(
        ref.read(supabaseClientProvider),
      ).listForSite(siteId);
    });

/// Admin CRUD for versioned conservation targets (gated by feature flags).
/// History is archived on activate — never overwritten in place for active rows.
class TargetsAdminScreen extends ConsumerWidget {
  const TargetsAdminScreen({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final enabledAsync = ref.watch(_siteTargetsEnabledProvider(siteId));
    final canManage = ref.watch(canManageMetersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAr ? 'أهداف الترشيد' : 'Conservation targets'),
      ),
      floatingActionButton: enabledAsync.maybeWhen(
        data: (on) => on && canManage
            ? FloatingActionButton.extended(
                onPressed: () => _showCreateDraftDialog(context, ref),
                icon: const Icon(Icons.add),
                label: Text(s.isAr ? 'مسودة هدف' : 'New draft'),
              )
            : null,
        orElse: () => null,
      ),
      body: enabledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CatalogErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_siteTargetsEnabledProvider(siteId)),
        ),
        data: (enabled) {
          if (!enabled) {
            return CatalogEmptyState(
              title: s.isAr ? 'الأهداف غير مفعّلة' : 'Targets disabled',
              message: s.isAr
                  ? 'فعّل conservation_module و targets لهذه الجهة/الموقع.'
                  : 'Enable conservation_module and targets for this org/site.',
              icon: Icons.flag_outlined,
            );
          }
          final targetsAsync = ref.watch(_siteTargetsProvider(siteId));
          return targetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => CatalogErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(_siteTargetsProvider(siteId)),
            ),
            data: (targets) {
              if (targets.isEmpty) {
                return CatalogEmptyState(
                  title: s.isAr ? 'لا توجد أهداف' : 'No targets',
                  message: s.isAr
                      ? 'أنشئ مسودة شهرية أو سنوية ثم فعّلها.'
                      : 'Create a monthly or annual draft, then activate it.',
                  icon: Icons.track_changes_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: targets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = targets[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${t.periodType.dbValue} · ${t.unitCode} · '
                        'v${t.version} · ${t.status.dbValue}',
                      ),
                      subtitle: Text(
                        '${_iso(t.periodStart)} → ${_iso(t.periodEnd)}\n'
                        'Target: ${t.targetValue} ${t.unitCode} '
                        '(≠ Baseline)',
                      ),
                      isThreeLine: true,
                      trailing:
                          t.status == ConservationTargetStatus.draft &&
                              canManage
                          ? TextButton(
                              onPressed: () async {
                                try {
                                  await ConservationTargetRepository(
                                    ref.read(supabaseClientProvider),
                                  ).activate(t.id);
                                  ref.invalidate(_siteTargetsProvider(siteId));
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        s.isAr
                                            ? 'تم التفعيل (الإصدار السابق مؤرشف)'
                                            : 'Activated (previous active archived)',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(adminUserError(context)),
                                    ),
                                  );
                                }
                              },
                              child: Text(s.isAr ? 'تفعيل' : 'Activate'),
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

  Future<void> _showCreateDraftDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final s = AdminStrings(ref.read(adminLocaleProvider));
    var periodType = ConservationTargetPeriodType.monthly;
    final valueCtrl = TextEditingController(text: '100');
    final unitCtrl = TextEditingController(text: 'kWh');
    final now = DateTime.now();
    var start = DateTime(now.year, now.month, 1);
    var end = DateTime(now.year, now.month + 1, 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(s.isAr ? 'مسودة هدف' : 'Draft target'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<ConservationTargetPeriodType>(
                      initialValue: periodType,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'النوع' : 'Period type',
                      ),
                      items: [
                        for (final p in ConservationTargetPeriodType.values)
                          DropdownMenuItem(value: p, child: Text(p.dbValue)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() {
                          periodType = v;
                          if (v == ConservationTargetPeriodType.annual) {
                            start = DateTime(now.year, 1, 1);
                            end = DateTime(now.year, 12, 31);
                          } else {
                            start = DateTime(now.year, now.month, 1);
                            end = DateTime(now.year, now.month + 1, 0);
                          }
                        });
                      },
                    ),
                    TextField(
                      controller: valueCtrl,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'قيمة الهدف' : 'Target value',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: unitCtrl,
                      decoration: InputDecoration(
                        labelText: s.isAr ? 'الوحدة' : 'Unit code',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_iso(start)} → ${_iso(end)}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.isAr
                          ? 'Target منفصل عن Baseline. لا يُستبدل التاريخ عند التفعيل.'
                          : 'Target ≠ Baseline. Activate archives history; no overwrite.',
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
                  child: Text(s.isAr ? 'حفظ' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;
    final value = double.tryParse(valueCtrl.text.trim());
    final unit = unitCtrl.text.trim();
    if (value == null || value <= 0 || unit.isEmpty) return;

    final profile = ref.read(authProvider).profile;
    await ConservationTargetRepository(
      ref.read(supabaseClientProvider),
    ).createDraft(
      siteId: siteId,
      scopeType: ConservationTargetScopeType.site,
      periodType: periodType,
      periodStart: start,
      periodEnd: end,
      targetValue: value,
      unitCode: unit,
      createdBy: profile?.id,
    );
    ref.invalidate(_siteTargetsProvider(siteId));
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
