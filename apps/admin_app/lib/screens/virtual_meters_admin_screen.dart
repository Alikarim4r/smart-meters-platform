import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';

final _siteVirtualMetersEnabledProvider =
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
  return flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.virtualMeters,
    siteId: siteId,
  );
});

final _siteVirtualMetersProvider =
    FutureProvider.autoDispose.family<List<Meter>, String>((ref, siteId) {
  return VirtualMeterRepository(ref.read(supabaseClientProvider))
      .listVirtualMetersForSite(siteId);
});

/// Admin UI for virtual meters (gated by conservation_module + virtual_meters).
class VirtualMetersAdminScreen extends ConsumerWidget {
  const VirtualMetersAdminScreen({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final enabledAsync = ref.watch(_siteVirtualMetersEnabledProvider(siteId));
    final canManage = ref.watch(canManageMetersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAr ? 'عدادات افتراضية' : 'Virtual meters'),
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
              ref.invalidate(_siteVirtualMetersEnabledProvider(siteId)),
        ),
        data: (enabled) {
          if (!enabled) {
            return CatalogEmptyState(
              title: s.isAr ? 'غير مفعّل' : 'Virtual meters disabled',
              message: s.isAr
                  ? 'فعّل conservation_module و virtual_meters.'
                  : 'Enable conservation_module and virtual_meters.',
              icon: Icons.flag_outlined,
            );
          }
          final listAsync = ref.watch(_siteVirtualMetersProvider(siteId));
          return listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => CatalogErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(_siteVirtualMetersProvider(siteId)),
            ),
            data: (meters) {
              if (meters.isEmpty) {
                return CatalogEmptyState(
                  title: s.isAr ? 'لا توجد عدادات افتراضية' : 'No virtual meters',
                  message: s.isAr
                      ? 'أنشئ sum_children أو parent_minus_children.'
                      : 'Create sum_children or parent_minus_children.',
                  icon: Icons.account_tree_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: meters.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final m = meters[index];
                  return Card(
                    child: ListTile(
                      title: Text('${m.nameEn} (${m.meterCode})'),
                      subtitle: Text(
                        '${m.calculationType.dbValue} · '
                        '${m.unitDisplayLabel} · virtual\n'
                        'Physical children stay enterable; derived only.',
                      ),
                      isThreeLine: true,
                      trailing: canManage
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                try {
                                  await VirtualMeterRepository(
                                    ref.read(supabaseClientProvider),
                                  ).deleteVirtualMeter(m.id);
                                  ref.invalidate(
                                    _siteVirtualMetersProvider(siteId),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }
                              },
                            )
                          : null,
                      onTap: () => _openPreview(context, ref, m),
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

  Future<void> _openPreview(
    BuildContext context,
    WidgetRef ref,
    Meter virtual,
  ) async {
    final repo = VirtualMeterRepository(ref.read(supabaseClientProvider));
    final memberIds = await repo.listMemberIds(virtual.id);
    final siteMeters =
        await ref.read(meterRepositoryProvider).getMetersForSite(siteId);
    final byId = {for (final m in siteMeters) m.id: m};
    final members = [for (final id in memberIds) if (byId[id] != null) byId[id]!];

    final validation = const VirtualMeterValidation().validateConfig(
      meterKind: virtual.meterKind,
      calculationType: virtual.calculationType,
      siteId: virtual.siteId,
      categoryId: virtual.categoryId,
      unitCode:
          virtual.baseUnit.isNotEmpty ? virtual.baseUnit : virtual.unit.dbValue,
      parentMeterId: virtual.parentMeterId,
      memberMeters: members,
      metersById: byId,
      virtualMeterId: virtual.id,
      memberIdsByVirtualId: await repo.listMemberIdsForSite(siteId),
    );

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(virtual.nameEn),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type: ${virtual.calculationType.dbValue}'),
              Text('Unit: ${virtual.unitDisplayLabel}'),
              Text('Members: ${members.map((m) => m.meterCode).join(', ')}'),
              if (virtual.parentMeterId != null)
                Text('Parent ref: ${virtual.parentMeterId}'),
              const SizedBox(height: 8),
              Text(
                validation.ok
                    ? 'Validation: OK (depth ${validation.hierarchyDepth})'
                    : 'Validation errors:\n- ${validation.issues.map((i) => i.message).join('\n- ')}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Residual naming: Residual / Balance Difference only (not Leak).',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
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
    if (physical.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isAr ? 'لا توجد عدادات فيزيائية' : 'No physical meters available',
          ),
        ),
      );
      return;
    }

    var calcType = CalculationType.sumChildren;
    final selected = <String>{};
    String? parentId;
    final codeCtrl = TextEditingController(text: 'VM_${physical.first.categoryCode}');
    final nameCtrl = TextEditingController(text: 'Virtual ${physical.first.categoryCode}');
    final sample = physical.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final sameCat = physical
                .where((m) => m.categoryId == sample.categoryId)
                .toList();
            return AlertDialog(
              title: Text(s.isAr ? 'عداد افتراضي' : 'Create virtual meter'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(labelText: 'Code'),
                      ),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      DropdownButtonFormField<CalculationType>(
                        initialValue: calcType,
                        items: const [
                          DropdownMenuItem(
                            value: CalculationType.sumChildren,
                            child: Text('sum_children'),
                          ),
                          DropdownMenuItem(
                            value: CalculationType.parentMinusChildren,
                            child: Text('parent_minus_children'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => calcType = v);
                        },
                      ),
                      if (calcType == CalculationType.parentMinusChildren)
                        DropdownButtonFormField<String>(
                          initialValue: parentId,
                          decoration: const InputDecoration(
                            labelText: 'Parent (main) meter',
                          ),
                          items: [
                            for (final m in sameCat)
                              DropdownMenuItem(
                                value: m.id,
                                child: Text('${m.meterCode} · ${m.nameEn}'),
                              ),
                          ],
                          onChanged: (v) => setLocal(() => parentId = v),
                        ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Children / members'),
                      ),
                      for (final m in sameCat)
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
                      const Text(
                        'Validation runs before save. Physical meters are not modified.',
                        style: TextStyle(fontSize: 11),
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
      await VirtualMeterRepository(ref.read(supabaseClientProvider))
          .createVirtualMeter(
        siteId: siteId,
        meterCode: codeCtrl.text.trim(),
        nameEn: nameCtrl.text.trim(),
        nameAr: nameCtrl.text.trim(),
        categoryId: sample.categoryId,
        sourceId: sample.sourceId,
        unitId: sample.unitId,
        calculationType: calcType,
        memberMeterIds: selected.toList(),
        parentMeterId:
            calcType == CalculationType.parentMinusChildren ? parentId : null,
      );
      ref.invalidate(_siteVirtualMetersProvider(siteId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.isAr ? 'تم الإنشاء' : 'Virtual meter created')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
