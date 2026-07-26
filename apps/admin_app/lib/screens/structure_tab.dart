import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/structure_providers.dart';
import '../providers/zone_providers.dart';
import '../utils/delete_confirmations.dart';
import '../widgets/catalog_widgets.dart';
import 'meter_form_screen.dart';
import 'organizations_tab.dart';
import 'scope_control_screen.dart';
import 'settings_tab.dart';
import 'site_detail_screen.dart';
import 'sites_tab.dart';
import 'zones_tab.dart';

/// Merged Orgs / Zones / Sites into one Structure tree with master-detail.
class StructureTab extends ConsumerWidget {
  const StructureTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final treeAsync = ref.watch(structureTreeProvider);
    final selection = ref.watch(structureSelectionProvider);
    final canAddOrg = ref.watch(canAddOrganizationProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return treeAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => CatalogErrorView(
        message: '$error',
        onRetry: () => ref.invalidate(structureTreeProvider),
      ),
      data: (tree) {
        // Drop stale selection if the node disappeared after reload.
        if (selection != null) {
          final stillValid = switch (selection) {
            StructureOrgSelection(:final organizationId) =>
              tree.organizations.any((o) => o.id == organizationId),
            StructureSiteTypesSelection(:final organizationId) =>
              tree.organizations.any((o) => o.id == organizationId),
            StructureZoneSelection(:final zoneId) => tree.zonesByOrg.values
                .expand((z) => z)
                .any((z) => z.id == zoneId),
            StructureSiteSelection(:final siteId) => tree.sitesByOrg.values
                .expand((s) => s)
                .any((site) => site.id == siteId),
          };
          if (!stillValid) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(structureSelectionProvider.notifier).state = null;
            });
          }
        }
        final treePane = _StructureTreePane(
          tree: tree,
          selection: selection,
          strings: s,
          canAddOrganization: canAddOrg,
          onSelect: (value) {
            ref.read(structureSelectionProvider.notifier).state = value;
            if (!wide && value != null) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      StructureDetailScreen(selection: value, tree: tree),
                ),
              );
            }
          },
          onRefresh: () => ref.invalidate(structureTreeProvider),
        );

        if (!wide) {
          return treePane;
        }

        return Row(
          children: [
            SizedBox(
              width: 360,
              child: Material(elevation: 1, child: treePane),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: selection == null
                  ? Center(child: Text(s.selectTreeItem))
                  : StructureDetailBody(
                      selection: selection,
                      tree: tree,
                      embedded: true,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StructureTreePane extends ConsumerWidget {
  const _StructureTreePane({
    required this.tree,
    required this.selection,
    required this.strings,
    required this.canAddOrganization,
    required this.onSelect,
    required this.onRefresh,
  });

  final StructureTreeData tree;
  final StructureSelection? selection;
  final AdminStrings strings;
  final bool canAddOrganization;
  final ValueChanged<StructureSelection?> onSelect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  strings.structure,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: strings.retry,
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
              if (canAddOrganization)
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OrganizationFormScreen(),
                      ),
                    );
                    onRefresh();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(strings.addOrganization),
                ),
            ],
          ),
        ),
        Expanded(
          child: tree.organizations.isEmpty
              ? CatalogEmptyState(
                  title: strings.organizations,
                  message: canAddOrganization
                      ? strings.addOrganization
                      : strings.selectTreeItem,
                  icon: Icons.account_balance_outlined,
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    for (final org in tree.organizations)
                      _OrgExpansion(
                        org: org,
                        tree: tree,
                        selection: selection,
                        strings: strings,
                        onSelect: onSelect,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _OrgExpansion extends StatelessWidget {
  const _OrgExpansion({
    required this.org,
    required this.tree,
    required this.selection,
    required this.strings,
    required this.onSelect,
  });

  final Organization org;
  final StructureTreeData tree;
  final StructureSelection? selection;
  final AdminStrings strings;
  final ValueChanged<StructureSelection?> onSelect;

  @override
  Widget build(BuildContext context) {
    final roots = tree.rootZones(org.id);
    final directs = tree.directSites(org.id);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = strings.isAr && org.nameAr.trim().isNotEmpty
        ? org.nameAr
        : org.nameEn;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: BrandInkCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            leading: brandIconWell(
              context: context,
              icon: Icons.account_balance_rounded,
              size: 40,
              iconSize: 20,
            ),
            title: InkWell(
              onTap: () => onSelect(StructureOrgSelection(org.id)),
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: BrandChrome.titleColor(
                    isDark: isDark,
                    scheme: theme.colorScheme,
                  ),
                ),
              ),
            ),
            iconColor: BrandChrome.iconGlyph,
            collapsedIconColor: BrandChrome.inkMuted,
            children: [
              _StructureChildTile(
                icon: Icons.category_outlined,
                title: strings.siteTypesNode,
                subtitle: '${org.siteTypes.length}',
                selected:
                    selection is StructureSiteTypesSelection &&
                    (selection! as StructureSiteTypesSelection)
                            .organizationId ==
                        org.id,
                onTap: () => onSelect(StructureSiteTypesSelection(org.id)),
              ),
              for (final zone in roots)
                _ZoneNode(
                  zone: zone,
                  tree: tree,
                  selection: selection,
                  strings: strings,
                  onSelect: onSelect,
                  depth: 0,
                ),
              if (directs.isNotEmpty)
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Icon(
                      Icons.location_city_outlined,
                      size: 20,
                      color: BrandChrome.iconGlyph,
                    ),
                    title: Text(
                      strings.directSites,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: BrandChrome.titleColor(
                          isDark: isDark,
                          scheme: theme.colorScheme,
                        ),
                      ),
                    ),
                    children: [
                      for (final site in directs)
                        _StructureChildTile(
                          icon: Icons.place_outlined,
                          title: strings.isAr && site.nameAr.trim().isNotEmpty
                              ? site.nameAr
                              : site.nameEn,
                          selected:
                              selection is StructureSiteSelection &&
                              (selection! as StructureSiteSelection).siteId ==
                                  site.id,
                          indent: 12,
                          onTap: () =>
                              onSelect(StructureSiteSelection(site.id)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneNode extends StatelessWidget {
  const _ZoneNode({
    required this.zone,
    required this.tree,
    required this.selection,
    required this.strings,
    required this.onSelect,
    required this.depth,
  });

  final Zone zone;
  final StructureTreeData tree;
  final StructureSelection? selection;
  final AdminStrings strings;
  final ValueChanged<StructureSelection?> onSelect;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final children = tree.childZones(zone.id);
    final sites = tree.sitesInZone(zone.id);
    final selected =
        selection is StructureZoneSelection &&
        (selection! as StructureZoneSelection).zoneId == zone.id;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = strings.isAr && (zone.nameAr?.isNotEmpty ?? false)
        ? zone.nameAr!
        : zone.nameEn;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: 8.0 * depth, bottom: 6),
      child: BrandInkCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            leading: brandIconWell(
              context: context,
              icon: Icons.map_outlined,
              size: 36,
              iconSize: 18,
            ),
            title: InkWell(
              onTap: () => onSelect(StructureZoneSelection(zone.id)),
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: BrandChrome.titleColor(
                    isDark: isDark,
                    scheme: theme.colorScheme,
                  ),
                ),
              ),
            ),
            subtitle: zone.defaultSiteType == null
                ? null
                : Text(
                    zone.defaultSiteType!.label(isAr: strings.isAr),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BrandChrome.mutedColor(
                        isDark: isDark,
                        scheme: theme.colorScheme,
                      ),
                    ),
                  ),
            iconColor: BrandChrome.iconGlyph,
            collapsedIconColor: BrandChrome.inkMuted,
            children: [
              for (final child in children)
                _ZoneNode(
                  zone: child,
                  tree: tree,
                  selection: selection,
                  strings: strings,
                  onSelect: onSelect,
                  depth: depth + 1,
                ),
              for (final site in sites)
                _StructureChildTile(
                  icon: Icons.place_outlined,
                  title: strings.isAr && site.nameAr.trim().isNotEmpty
                      ? site.nameAr
                      : site.nameEn,
                  selected:
                      selection is StructureSiteSelection &&
                      (selection! as StructureSiteSelection).siteId == site.id,
                  indent: 8,
                  onTap: () => onSelect(StructureSiteSelection(site.id)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StructureChildTile extends StatelessWidget {
  const _StructureChildTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.indent = 0,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, bottom: 6),
      child: BrandInkCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            brandIconWell(context: context, icon: icon, size: 34, iconSize: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      color: BrandChrome.titleColor(
                        isDark: isDark,
                        scheme: theme.colorScheme,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BrandChrome.mutedColor(
                          isDark: isDark,
                          scheme: theme.colorScheme,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: BrandChrome.mutedColor(
                isDark: isDark,
                scheme: theme.colorScheme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StructureDetailScreen extends StatelessWidget {
  const StructureDetailScreen({
    super.key,
    required this.selection,
    required this.tree,
  });

  final StructureSelection selection;
  final StructureTreeData tree;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title(context))),
      body: StructureDetailBody(
        selection: selection,
        tree: tree,
        embedded: false,
      ),
    );
  }

  String _title(BuildContext context) {
    final s = AdminStrings(Localizations.localeOf(context));
    return switch (selection) {
      StructureOrgSelection() => s.organizations,
      StructureSiteTypesSelection() => s.siteTypes,
      StructureZoneSelection() => s.zones,
      StructureSiteSelection() => s.sites,
    };
  }
}

class StructureDetailBody extends ConsumerWidget {
  const StructureDetailBody({
    super.key,
    required this.selection,
    required this.tree,
    required this.embedded,
  });

  final StructureSelection selection;
  final StructureTreeData tree;
  final bool embedded;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(structureTreeProvider);
    ref.invalidate(adminAllOrganizationsProvider);
    ref.invalidate(adminZonesProvider);
    ref.invalidate(adminSitesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final canManage = ref.watch(canManageOrganizationsProvider);
    final isOwner = ref.watch(authProvider).profile?.isPlatformOwner ?? false;
    final isSuper = ref.watch(authProvider).profile?.isSuperAdmin ?? false;
    final isSiteAdmin = ref.watch(authProvider).profile?.isSiteAdmin ?? false;
    // Zone control: owner or super_admin (scoped by RLS).
    final canManageZoneUsers = isOwner || isSuper;
    // Site control: owner, super_admin, or regular admin.
    final canManageSiteUsers = isOwner || isSuper || isSiteAdmin;

    void onDeleted() {
      ref.read(structureSelectionProvider.notifier).state = null;
      if (!embedded && context.mounted) {
        Navigator.of(context).maybePop();
      }
    }

    return switch (selection) {
      StructureOrgSelection(:final organizationId) => _OrgDetail(
        org: tree.organizations.firstWhere((o) => o.id == organizationId),
        strings: s,
        canManage: canManage,
        canManageOrgControl: isOwner,
        canForceDelete: isOwner,
        onRefresh: () => _refresh(ref),
        onDeleted: onDeleted,
      ),
      StructureSiteTypesSelection(:final organizationId) => _SiteTypesDetail(
        org: tree.organizations.firstWhere((o) => o.id == organizationId),
        strings: s,
        canManage: canManage,
        onRefresh: () => _refresh(ref),
      ),
      StructureZoneSelection(:final zoneId) => _ZoneDetail(
        zone: tree.zonesByOrg.values
            .expand((z) => z)
            .firstWhere((z) => z.id == zoneId),
        tree: tree,
        strings: s,
        canManage: canManage || canManageZoneUsers,
        canManageUsers: canManageZoneUsers,
        canForceDelete: isOwner || isSuper,
        onRefresh: () => _refresh(ref),
        onDeleted: onDeleted,
      ),
      StructureSiteSelection(:final siteId) => _SiteDetailActions(
        site: tree.sitesByOrg.values
            .expand((s) => s)
            .firstWhere((site) => site.id == siteId),
        strings: s,
        canManage: canManage || canManageSiteUsers,
        canManageUsers: canManageSiteUsers,
        canForceDelete: isOwner || isSuper || isSiteAdmin,
        onRefresh: () => _refresh(ref),
        onDeleted: onDeleted,
      ),
    };
  }
}

class _OrgDetail extends ConsumerWidget {
  const _OrgDetail({
    required this.org,
    required this.strings,
    required this.canManage,
    required this.canManageOrgControl,
    required this.canForceDelete,
    required this.onRefresh,
    required this.onDeleted,
  });

  final Organization org;
  final AdminStrings strings;
  final bool canManage;
  /// Platform owner only — assign super_admins at organization level.
  final bool canManageOrgControl;
  final bool canForceDelete;
  final VoidCallback onRefresh;
  final VoidCallback onDeleted;

  Future<void> _forceDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmForceDelete(
      context: context,
      title: strings.deleteOrganizationTitle,
      entityName: org.nameEn,
    );
    if (confirmed != true) return;
    try {
      await ref.read(siteRepositoryProvider).forceDeleteOrganization(org.id);
      onRefresh();
      onDeleted();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${org.nameEn} deleted')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          strings.isAr && org.nameAr.trim().isNotEmpty
              ? org.nameAr
              : org.nameEn,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (org.nameAr.trim().isNotEmpty && !strings.isAr) Text(org.nameAr),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            catalogStatusChip(isActive: org.isActive),
            if (org.siteCount != null)
              catalogTypeChip(
                label: strings.sitesCount(org.siteCount!),
                icon: Icons.location_city,
              ),
          ],
        ),
        const SizedBox(height: 24),
        _ActionTile(
          icon: Icons.map_outlined,
          label: strings.addZone,
          enabled: canManage,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ZoneFormScreen(initialOrganizationId: org.id),
              ),
            );
            onRefresh();
          },
        ),
        _ActionTile(
          icon: Icons.location_city_outlined,
          label: strings.addDirectSite,
          enabled: canManage,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SiteFormScreen(initialOrganizationId: org.id),
              ),
            );
            onRefresh();
          },
        ),
        _ActionTile(
          icon: Icons.category_outlined,
          label: strings.manageSiteTypes,
          enabled: canManage,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OrganizationFormScreen(organization: org),
              ),
            );
            onRefresh();
          },
        ),
        if (canManageOrgControl)
          _ActionTile(
            icon: Icons.admin_panel_settings_outlined,
            label: strings.orgControlPermission,
            enabled: true,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ScopeControlScreen(
                    kind: ScopeKind.organization,
                    title: strings.orgControlPermission,
                    organizationId: org.id,
                  ),
                ),
              );
            },
          ),
        _ActionTile(
          icon: Icons.policy_outlined,
          label: strings.openPolicy,
          enabled: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(strings.policySettings)),
                  body: const SettingsTab(),
                ),
              ),
            );
          },
        ),
        if (canManage)
          _ActionTile(
            icon: Icons.edit_outlined,
            label: strings.editOrganization,
            enabled: true,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OrganizationFormScreen(organization: org),
                ),
              );
              onRefresh();
            },
          ),
        if (canForceDelete)
          _ActionTile(
            icon: Icons.delete_forever_outlined,
            label: strings.forceDelete,
            enabled: true,
            destructive: true,
            onTap: () => _forceDelete(context, ref),
          ),
      ],
    );
  }
}

class _SiteTypesDetail extends ConsumerStatefulWidget {
  const _SiteTypesDetail({
    required this.org,
    required this.strings,
    required this.canManage,
    required this.onRefresh,
  });

  final Organization org;
  final AdminStrings strings;
  final bool canManage;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_SiteTypesDetail> createState() => _SiteTypesDetailState();
}

class _SiteTypesDetailState extends ConsumerState<_SiteTypesDetail> {
  final _en = TextEditingController();
  final _ar = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _en.dispose();
    _ar.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final en = _en.text.trim();
    final ar = _ar.text.trim();
    if (en.isEmpty || ar.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(zoneRepositoryProvider)
          .createSiteType(
            organizationId: widget.org.id,
            nameEn: en,
            nameAr: ar,
          );
      _en.clear();
      _ar.clear();
      widget.onRefresh();
      ref.invalidate(organizationSiteTypesProvider(widget.org.id));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(organizationSiteTypesProvider(widget.org.id));
    final s = widget.strings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.siteTypes, style: Theme.of(context).textTheme.titleLarge),
        Text(s.siteTypesHint),
        const SizedBox(height: 16),
        typesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (types) {
            if (types.isEmpty) {
              return Text(s.noSiteTypesYet);
            }
            return Column(
              children: [
                for (final type in types)
                  ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(type.nameEn),
                    subtitle: Text(type.nameAr),
                    trailing: widget.canManage
                        ? IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade700,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(zoneRepositoryProvider)
                                  .deleteSiteType(type.id);
                              widget.onRefresh();
                              ref.invalidate(
                                organizationSiteTypesProvider(widget.org.id),
                              );
                            },
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
        if (widget.canManage) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _en,
            decoration: catalogFieldDecoration(labelText: s.typeNameEn),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ar,
            decoration: catalogFieldDecoration(labelText: s.typeNameAr),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _add,
            icon: const Icon(Icons.add),
            label: Text(s.addSiteType),
          ),
        ],
      ],
    );
  }
}

class _ZoneDetail extends ConsumerWidget {
  const _ZoneDetail({
    required this.zone,
    required this.tree,
    required this.strings,
    required this.canManage,
    required this.canManageUsers,
    required this.canForceDelete,
    required this.onRefresh,
    required this.onDeleted,
  });

  final Zone zone;
  final StructureTreeData tree;
  final AdminStrings strings;
  final bool canManage;
  final bool canManageUsers;
  final bool canForceDelete;
  final VoidCallback onRefresh;
  final VoidCallback onDeleted;

  Future<void> _forceDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmForceDelete(
      context: context,
      title: strings.deleteZoneTitle,
      entityName: zone.nameEn,
    );
    if (confirmed != true) return;
    try {
      await ref.read(zoneRepositoryProvider).forceDeleteZone(zone.id);
      onRefresh();
      onDeleted();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${zone.nameEn} deleted')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          strings.isAr && (zone.nameAr?.isNotEmpty ?? false)
              ? zone.nameAr!
              : zone.nameEn,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (zone.defaultSiteType != null) ...[
          const SizedBox(height: 8),
          catalogTypeChip(
            label:
                '${strings.defaultSuggestedType}: ${zone.defaultSiteType!.label(isAr: strings.isAr)}',
            icon: Icons.category_outlined,
            color: Colors.teal,
          ),
        ],
        const SizedBox(height: 24),
        _ActionTile(
          icon: Icons.account_tree_outlined,
          label: strings.addSubZone,
          enabled: canManage,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ZoneFormScreen(
                  initialOrganizationId: zone.organizationId,
                  initialParentZoneId: zone.id,
                ),
              ),
            );
            onRefresh();
          },
        ),
        _ActionTile(
          icon: Icons.location_city_outlined,
          label: strings.addSite,
          enabled: canManage,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SiteFormScreen(
                  initialOrganizationId: zone.organizationId,
                  initialZoneId: zone.id,
                ),
              ),
            );
            onRefresh();
          },
        ),
        _ActionTile(
          icon: Icons.admin_panel_settings_outlined,
          label: strings.zoneControlPermission,
          enabled: canManageUsers,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScopeControlScreen(
                  kind: ScopeKind.zone,
                  title: strings.zoneControlPermission,
                  organizationId: zone.organizationId,
                  zoneId: zone.id,
                ),
              ),
            );
          },
        ),
        _ActionTile(
          icon: Icons.edit_outlined,
          label: strings.editZone,
          enabled: canManage,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ZoneFormScreen(zone: zone),
              ),
            );
            onRefresh();
          },
        ),
        if (canForceDelete)
          _ActionTile(
            icon: Icons.delete_forever_outlined,
            label: strings.forceDelete,
            enabled: true,
            destructive: true,
            onTap: () => _forceDelete(context, ref),
          ),
      ],
    );
  }
}

class _SiteDetailActions extends ConsumerWidget {
  const _SiteDetailActions({
    required this.site,
    required this.strings,
    required this.canManage,
    required this.canManageUsers,
    required this.canForceDelete,
    required this.onRefresh,
    required this.onDeleted,
  });

  final Site site;
  final AdminStrings strings;
  final bool canManage;
  final bool canManageUsers;
  final bool canForceDelete;
  final VoidCallback onRefresh;
  final VoidCallback onDeleted;

  Future<void> _forceDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmForceDelete(
      context: context,
      title: strings.deleteSiteTitle,
      entityName: site.nameEn,
    );
    if (confirmed != true) return;
    try {
      await ref.read(siteRepositoryProvider).forceDeleteSite(site.id);
      onRefresh();
      onDeleted();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${site.nameEn} deleted')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          strings.isAr && site.nameAr.trim().isNotEmpty
              ? site.nameAr
              : site.nameEn,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(site.typeLabel(isAr: strings.isAr)),
        const SizedBox(height: 24),
        _ActionTile(
          icon: Icons.speed_outlined,
          label: strings.addMeter,
          enabled: canManage || canForceDelete,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MeterFormScreen(siteId: site.id),
              ),
            );
            onRefresh();
          },
        ),
        _ActionTile(
          icon: Icons.admin_panel_settings_outlined,
          label: strings.siteControlPermission,
          enabled: canManageUsers,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScopeControlScreen(
                  kind: ScopeKind.site,
                  title: strings.siteControlPermission,
                  organizationId: site.organizationId,
                  siteId: site.id,
                ),
              ),
            );
          },
        ),
        _ActionTile(
          icon: Icons.list_alt,
          label: strings.viewMeters,
          enabled: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SiteDetailScreen(siteId: site.id),
              ),
            );
          },
        ),
        _ActionTile(
          icon: Icons.edit_outlined,
          label: strings.editSite,
          enabled: canManage,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SiteFormScreen(site: site),
              ),
            );
            onRefresh();
          },
        ),
        if (canForceDelete)
          _ActionTile(
            icon: Icons.delete_forever_outlined,
            label: strings.forceDelete,
            enabled: true,
            destructive: true,
            onTap: () => _forceDelete(context, ref),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red.shade700 : null;
    return BrandListCard(
      leadingIcon: icon,
      title: label,
      enabled: enabled,
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 8),
      trailing: Icon(
        destructive
            ? Icons.delete_forever_outlined
            : Icons.arrow_forward_ios_rounded,
        size: destructive ? 22 : 14,
        color:
            color ??
            BrandChrome.mutedColor(
              isDark: Theme.of(context).brightness == Brightness.dark,
              scheme: Theme.of(context).colorScheme,
            ),
      ),
    );
  }
}
