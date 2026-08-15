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
                      ? 'أنشئ عداد مجموع لمجموعة عدادات من نفس الفئة، أو رئيسي − الأبناء.'
                      : 'Create a sum-group of same-category meters, or parent − children.',
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
                      title: Text(
                        s.isAr
                            ? '${m.nameAr} (${m.meterCode})'
                            : '${m.nameEn} (${m.meterCode})',
                      ),
                      subtitle: Text(
                        s.isAr
                            ? '${m.calculationType.dbValue} · ${m.unitDisplayLabel} · افتراضي'
                            : '${m.calculationType.dbValue} · ${m.unitDisplayLabel} · virtual',
                      ),
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
        .where(
          (m) =>
              m.isActive &&
              m.meterKind == MeterKind.physical &&
              m.calculationType == CalculationType.directReading,
        )
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

    // Category options from physical meters on this site.
    final categories = <String, ({String id, String label, String code})>{};
    for (final m in physical) {
      final code = m.categoryConfig?.code ?? m.category.dbValue;
      categories.putIfAbsent(
        m.categoryId,
        () => (
          id: m.categoryId,
          code: code,
          label: s.isAr
              ? (m.categoryConfig?.nameAr ?? m.category.label)
              : (m.categoryConfig?.nameEn ?? m.category.label),
        ),
      );
    }
    final categoryIds = categories.keys.toList()
      ..sort((a, b) => categories[a]!.label.compareTo(categories[b]!.label));

    var categoryId = categoryIds.first;
    var calcType = CalculationType.sumChildren;
    var includeInDashboard = true;
    final selected = <String>{};
    String? parentId;
    final codeCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final nameArCtrl = TextEditingController();

    void applyCategoryDefaults(String catId) {
      final meta = categories[catId]!;
      final sample =
          physical.firstWhere((m) => m.categoryId == catId, orElse: () => physical.first);
      codeCtrl.text = 'VM-${meta.code.toUpperCase()}-SUM';
      nameEnCtrl.text = 'Sum of ${meta.label} meters';
      nameArCtrl.text = s.isAr
          ? 'مجموع عدادات ${meta.label}'
          : 'مجموع عدادات ${sample.categoryConfig?.nameAr ?? meta.label}';
      selected
        ..clear()
        ..addAll(
          physical.where((m) => m.categoryId == catId).map((m) => m.id),
        );
      parentId = null;
    }

    applyCategoryDefaults(categoryId);

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final sameCat =
                physical.where((m) => m.categoryId == categoryId).toList();
            return AlertDialog(
              title: Text(
                s.isAr
                    ? 'إنشاء عداد مجموع (مجموعة)'
                    : 'Create sum-group virtual meter',
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.isAr
                            ? 'اختر الفئة ثم أعضاء المجموعة من نفس الفئة والوحدة. يظهر المجموع في لوحة التحكم في صف منفصل أعلى العدادات.'
                            : 'Pick a category, then members of the same category/unit. The sum appears first on the dashboard in its own row.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: categoryId,
                        decoration: InputDecoration(
                          labelText: s.isAr ? 'الفئة / النظام' : 'Category',
                        ),
                        items: [
                          for (final id in categoryIds)
                            DropdownMenuItem(
                              value: id,
                              child: Text(categories[id]!.label),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() {
                            categoryId = v;
                            applyCategoryDefaults(v);
                          });
                        },
                      ),
                      TextField(
                        controller: codeCtrl,
                        decoration: InputDecoration(
                          labelText: s.isAr ? 'رمز العداد' : 'Meter code',
                        ),
                      ),
                      TextField(
                        controller: nameEnCtrl,
                        decoration: InputDecoration(
                          labelText: s.isAr ? 'الاسم (إنجليزي)' : 'Name (EN)',
                        ),
                      ),
                      TextField(
                        controller: nameArCtrl,
                        decoration: InputDecoration(
                          labelText: s.isAr ? 'الاسم (عربي)' : 'Name (AR)',
                        ),
                      ),
                      DropdownButtonFormField<CalculationType>(
                        initialValue: calcType,
                        decoration: InputDecoration(
                          labelText:
                              s.isAr ? 'طريقة الحساب' : 'Calculation type',
                        ),
                        items: [
                          DropdownMenuItem(
                            value: CalculationType.sumChildren,
                            child: Text(
                              s.isAr
                                  ? 'مجموع الأعضاء (sum_children)'
                                  : 'Sum of members (sum_children)',
                            ),
                          ),
                          DropdownMenuItem(
                            value: CalculationType.parentMinusChildren,
                            child: Text(
                              s.isAr
                                  ? 'رئيسي − الأبناء (parent_minus_children)'
                                  : 'Parent − children (parent_minus_children)',
                            ),
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
                          decoration: InputDecoration(
                            labelText: s.isAr
                                ? 'العداد الرئيسي (مرجع)'
                                : 'Parent (main) meter',
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
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.isAr
                              ? 'إظهار في لوحة التحكم'
                              : 'Show on dashboard',
                        ),
                        subtitle: Text(
                          s.isAr
                              ? 'يُثبَّت في الأعلى كصف مستقل'
                              : 'Pinned first in its own row',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                        value: includeInDashboard,
                        onChanged: (v) =>
                            setLocal(() => includeInDashboard = v),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            s.isAr
                                ? 'أعضاء المجموعة (${selected.length}/${sameCat.length})'
                                : 'Group members (${selected.length}/${sameCat.length})',
                            style: Theme.of(ctx).textTheme.titleSmall,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setLocal(() {
                              selected
                                ..clear()
                                ..addAll(sameCat.map((m) => m.id));
                            }),
                            child: Text(s.isAr ? 'تحديد الكل' : 'Select all'),
                          ),
                          TextButton(
                            onPressed: () => setLocal(() {
                              selected.clear();
                            }),
                            child: Text(s.isAr ? 'مسح' : 'Clear'),
                          ),
                        ],
                      ),
                      for (final m in sameCat)
                        CheckboxListTile(
                          dense: true,
                          value: selected.contains(m.id),
                          title: Text(
                            s.isAr
                                ? '${m.meterCode} · ${m.nameAr}'
                                : '${m.meterCode} · ${m.nameEn}',
                          ),
                          subtitle: Text(m.unitDisplayLabel),
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
                      Text(
                        s.isAr
                            ? 'التحقق يعمل قبل الحفظ. العدادات الفيزيائية لا تُعدَّل.'
                            : 'Validation runs before save. Physical meters are not modified.',
                        style: Theme.of(ctx).textTheme.bodySmall,
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
                  onPressed: selected.isEmpty
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

    if (ok != true) {
      codeCtrl.dispose();
      nameEnCtrl.dispose();
      nameArCtrl.dispose();
      return;
    }
    final members = physical
        .where((m) => selected.contains(m.id) && m.categoryId == categoryId)
        .toList();
    if (members.isEmpty) {
      codeCtrl.dispose();
      nameEnCtrl.dispose();
      nameArCtrl.dispose();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isAr ? 'اختر عضواً واحداً على الأقل' : 'Select at least one member',
          ),
        ),
      );
      return;
    }
    final sample = members.first;
    try {
      await VirtualMeterRepository(ref.read(supabaseClientProvider))
          .createVirtualMeter(
        siteId: siteId,
        meterCode: codeCtrl.text.trim(),
        nameEn: nameEnCtrl.text.trim(),
        nameAr: nameArCtrl.text.trim().isEmpty
            ? nameEnCtrl.text.trim()
            : nameArCtrl.text.trim(),
        categoryId: categoryId,
        sourceId: sample.sourceId,
        unitId: sample.unitId,
        calculationType: calcType,
        memberMeterIds: members.map((m) => m.id).toList(),
        parentMeterId:
            calcType == CalculationType.parentMinusChildren ? parentId : null,
        sortOrder: 0,
        includeInDashboard: includeInDashboard,
      );
      ref.invalidate(_siteVirtualMetersProvider(siteId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.isAr ? 'تم الإنشاء' : 'Virtual meter created')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      codeCtrl.dispose();
      nameEnCtrl.dispose();
      nameArCtrl.dispose();
    }
  }
}
