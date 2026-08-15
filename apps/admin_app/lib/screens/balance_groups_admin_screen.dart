import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';

final _siteBalanceGroupsEnabledProvider =
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
  final water = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.waterBalance,
    siteId: siteId,
  );
  if (water) return true;
  return flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.energyBalance,
    siteId: siteId,
  );
});

final _siteBalanceGroupsProvider =
    FutureProvider.autoDispose.family<List<BalanceGroup>, String>((ref, siteId) {
  return BalanceGroupRepository(ref.read(supabaseClientProvider))
      .listForSite(siteId);
});

/// Admin UI for balance groups (gated by conservation_module + water/energy_balance).
class BalanceGroupsAdminScreen extends ConsumerWidget {
  const BalanceGroupsAdminScreen({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final enabledAsync = ref.watch(_siteBalanceGroupsEnabledProvider(siteId));
    final canManage = ref.watch(canManageMetersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAr ? 'مجموعات التوازن' : 'Balance groups'),
      ),
      floatingActionButton: enabledAsync.maybeWhen(
        data: (on) => on && canManage
            ? FloatingActionButton.extended(
                onPressed: () => _openCreate(context, ref),
                icon: const Icon(Icons.add),
                label: Text(s.isAr ? 'إنشاء' : 'Create'),
              )
            : null,
        orElse: () => null,
      ),
      body: enabledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CatalogErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_siteBalanceGroupsEnabledProvider(siteId)),
        ),
        data: (enabled) {
          if (!enabled) {
            return CatalogEmptyState(
              title: s.isAr ? 'غير مفعّل' : 'Balance groups disabled',
              message: s.isAr
                  ? 'فعّل conservation_module و water_balance أو energy_balance.'
                  : 'Enable conservation_module and water_balance or energy_balance.',
              icon: Icons.flag_outlined,
            );
          }
          final listAsync = ref.watch(_siteBalanceGroupsProvider(siteId));
          return listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => CatalogErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(_siteBalanceGroupsProvider(siteId)),
            ),
            data: (groups) {
              if (groups.isEmpty) {
                return CatalogEmptyState(
                  title: s.isAr ? 'لا توجد مجموعات' : 'No balance groups',
                  message: s.isAr
                      ? 'أنشئ مجموعة رئيسية + عدادات فرعية.'
                      : 'Create a main + submeter balance group.',
                  icon: Icons.account_balance_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final g = groups[index];
                  return Card(
                    child: ListTile(
                      title: Text(g.name),
                      subtitle: Text(
                        '${g.utilityCode} · ${g.unitCode} · '
                        '${g.status.dbValue}\n'
                        'Main ${g.mainMeterId} · '
                        '${g.memberMeterIds.length} members\n'
                        'Balance Difference only — never auto Leak.',
                      ),
                      isThreeLine: true,
                      trailing: canManage
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: s.isAr
                                      ? 'تصنيف بشري'
                                      : 'Human classification',
                                  icon: const Icon(Icons.fact_check_outlined),
                                  onPressed: () =>
                                      _openClassification(context, ref, g),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    try {
                                      await BalanceGroupRepository(
                                        ref.read(supabaseClientProvider),
                                      ).delete(g.id);
                                      ref.invalidate(
                                        _siteBalanceGroupsProvider(siteId),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text('$e')),
                                      );
                                    }
                                  },
                                ),
                              ],
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

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final siteMeters =
        await ref.read(meterRepositoryProvider).getMetersForSite(siteId);
    final physical = siteMeters
        .where((m) =>
            m.isActive &&
            m.meterKind == MeterKind.physical &&
            m.calculationType == CalculationType.directReading)
        .toList();
    if (!context.mounted) return;
    if (physical.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isAr ? 'لا توجد عدادات فيزيائية' : 'No physical meters available',
          ),
        ),
      );
      return;
    }

    var utility = 'water';
    var unitCode = 'm³';
    String? mainId = physical.first.id;
    final selected = <String>{};
    final nameCtrl =
        TextEditingController(text: 'Balance ${physical.first.meterCode}');
    final unitCtrl = TextEditingController(text: unitCode);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final filtered = physical.where((m) {
              final code =
                  (m.categoryConfig?.code ?? m.category.dbValue).toLowerCase();
              return utility == 'water'
                  ? code.contains('water')
                  : code.contains('electric');
            }).toList();
            return AlertDialog(
              title: Text(s.isAr ? 'مجموعة توازن' : 'Create balance group'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: utility,
                        decoration: const InputDecoration(labelText: 'Utility'),
                        items: const [
                          DropdownMenuItem(
                            value: 'water',
                            child: Text('water'),
                          ),
                          DropdownMenuItem(
                            value: 'electricity',
                            child: Text('electricity'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() {
                            utility = v;
                            unitCode = v == 'water' ? 'm³' : 'kWh';
                            unitCtrl.text = unitCode;
                            mainId =
                                filtered.isNotEmpty ? filtered.first.id : null;
                            selected.clear();
                          });
                        },
                      ),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Unit'),
                        controller: unitCtrl,
                        onChanged: (v) => unitCode = v,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: mainId,
                        decoration:
                            const InputDecoration(labelText: 'Main meter'),
                        items: [
                          for (final m in filtered)
                            DropdownMenuItem(
                              value: m.id,
                              child: Text('${m.meterCode} · ${m.nameEn}'),
                            ),
                        ],
                        onChanged: (v) => setLocal(() => mainId = v),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Member submeters'),
                      ),
                      for (final m in filtered)
                        if (m.id != mainId)
                          CheckboxListTile(
                            dense: true,
                            value: selected.contains(m.id),
                            title: Text('${m.meterCode} · ${m.nameEn}'),
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  selected.add(m.id);
                                } else {
                                  selected.remove(m.id);
                                }
                              });
                            },
                          ),
                      const SizedBox(height: 8),
                      const Text(
                        'Labels: Balance Difference only — never auto Leak.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.isAr ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: mainId == null || selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: Text(s.isAr ? 'حفظ' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    unitCtrl.dispose();
    if (ok != true || mainId == null) return;
    try {
      await BalanceGroupRepository(ref.read(supabaseClientProvider)).create(
        siteId: siteId,
        name: name,
        utilityCode: utility,
        unitCode: unitCode,
        mainMeterId: mainId!,
        memberMeterIds: selected.toList(),
        status: BalanceGroupStatus.active,
        createdBy: ref.read(supabaseClientProvider).auth.currentUser?.id,
      );
      ref.invalidate(_siteBalanceGroupsProvider(siteId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openClassification(
    BuildContext context,
    WidgetRef ref,
    BalanceGroup group,
  ) async {
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final now = DateTime.now();
    final periodEnd = DateTime(now.year, now.month, now.day);
    final periodStart = DateTime(now.year, now.month, 1);
    var classification = BalanceClassificationType.unknown;
    final notesCtrl = TextEditingController();
    var humanReviewed = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(
                s.isAr ? 'تصنيف بشري' : 'Human classification',
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Period: ${periodStart.toIso8601String().substring(0, 10)}'
                      ' → ${periodEnd.toIso8601String().substring(0, 10)}',
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<BalanceClassificationType>(
                      initialValue: classification,
                      decoration: const InputDecoration(
                        labelText: 'Classification (human-reviewed)',
                      ),
                      items: [
                        for (final t in BalanceClassificationType.values)
                          DropdownMenuItem(
                            value: t,
                            child: Text(
                              t == BalanceClassificationType.confirmedLeak
                                  ? 'confirmed_leak (human-reviewed only)'
                                  : t.dbValue,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => classification = v);
                      },
                    ),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 2,
                    ),
                    CheckboxListTile(
                      dense: true,
                      value: humanReviewed,
                      title: const Text('Human reviewed'),
                      onChanged: (v) =>
                          setLocal(() => humanReviewed = v ?? false),
                    ),
                    const Text(
                      'Confirmed Leak is never auto-assigned.',
                      style: TextStyle(fontSize: 12),
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

    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    try {
      await BalanceClassificationRepository(ref.read(supabaseClientProvider))
          .upsert(
        siteId: siteId,
        balanceGroupId: group.id,
        periodStart: periodStart,
        periodEnd: periodEnd,
        classification: classification,
        humanReviewed: humanReviewed,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        unitCode: group.unitCode,
        classifiedBy: userId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isAr ? 'تم حفظ التصنيف' : 'Classification saved',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
