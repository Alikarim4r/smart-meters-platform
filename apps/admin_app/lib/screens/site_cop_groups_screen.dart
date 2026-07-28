import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';
import 'cop_group_form_screen.dart';

final _siteCopGroupsProvider =
    FutureProvider.autoDispose.family<List<CopGroupDetail>, String>((
  ref,
  siteId,
) {
  return ref.watch(copGroupRepositoryProvider).listForSite(siteId);
});

/// Manage COP/EER efficiency groups for a site (BTU + electricity meters).
class SiteCopGroupsScreen extends ConsumerWidget {
  const SiteCopGroupsScreen({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final groupsAsync = ref.watch(_siteCopGroupsProvider(siteId));
    final canManage = ref.watch(canManageMetersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.copEerGroups),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CopGroupFormScreen(siteId: siteId),
                  ),
                );
                ref.invalidate(_siteCopGroupsProvider(siteId));
              },
              icon: const Icon(Icons.add),
              label: Text(s.addCopGroup),
            )
          : null,
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => CatalogErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(_siteCopGroupsProvider(siteId)),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return CatalogEmptyState(
              title: s.copEerGroups,
              message: s.copEerGroupsEmpty,
              icon: Icons.speed_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                child: ListTile(
                  title: Text(s.isAr ? group.nameAr : group.nameEn),
                  subtitle: Text(
                    s.copGroupMeterSummary(
                      btuCount: group.btuMeterIds.length,
                      elecCount: group.electricityMeterIds.length,
                    ),
                  ),
                  trailing: catalogStatusChip(isActive: group.isActive),
                  onTap: canManage
                      ? () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CopGroupFormScreen(
                                siteId: siteId,
                                existing: group,
                              ),
                            ),
                          );
                          ref.invalidate(_siteCopGroupsProvider(siteId));
                        }
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
