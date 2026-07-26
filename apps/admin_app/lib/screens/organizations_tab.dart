import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/structure_providers.dart';
import '../utils/catalog_validation.dart';
import '../utils/delete_confirmations.dart';
import '../widgets/catalog_widgets.dart';

/// All organizations (ministries, compounds, companies…) with site counts.
final adminAllOrganizationsProvider =
    FutureProvider.autoDispose<List<Organization>>((ref) async {
      return ref.read(siteRepositoryProvider).getAllOrganizationsForAdmin();
    });

/// Create new organizations — platform owner only.
final canAddOrganizationProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).profile?.isPlatformOwner ?? false;
});

/// Edit structure within visible scopes (owner / scoped super_admin).
final canManageOrganizationsProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) return false;
  return profile.isPlatformOwner || profile.isSuperAdmin;
});

/// Zone/site user assignment (refined further per screen).
final canManageScopeUsersProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) return false;
  return profile.isPlatformOwner ||
      profile.isSuperAdmin ||
      profile.isSiteAdmin;
});

class OrganizationsTab extends ConsumerStatefulWidget {
  const OrganizationsTab({super.key});

  @override
  ConsumerState<OrganizationsTab> createState() => _OrganizationsTabState();
}

class _OrganizationsTabState extends ConsumerState<OrganizationsTab> {
  final _searchController = TextEditingController();
  ActiveFilter _filter = ActiveFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _invalidate() {
    ref.invalidate(adminAllOrganizationsProvider);
    ref.invalidate(adminOrganizationsProvider);
  }

  Future<void> _openForm({Organization? organization}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrganizationFormScreen(organization: organization),
      ),
    );
    _invalidate();
  }

  Future<void> _toggleActive(Organization org) async {
    try {
      await ref
          .read(siteRepositoryProvider)
          .updateOrganization(org.id, isActive: !org.isActive);
      _invalidate();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _delete(Organization org) async {
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final canForce = ref.read(canForceDeleteProvider);
    final confirmed = canForce
        ? await confirmForceDelete(
            context: context,
            title: s.deleteOrganizationTitle,
            entityName: org.nameEn,
          )
        : await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(s.deleteOrganizationTitle),
              content: Text(
                'Permanently delete "${org.nameEn}"?\n'
                'Deletion fails while sites still belong to it.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(s.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(s.delete),
                ),
              ],
            ),
          );
    if (confirmed != true) return;
    try {
      final repo = ref.read(siteRepositoryProvider);
      if (canForce) {
        await repo.forceDeleteOrganization(org.id);
      } else {
        await repo.deleteOrganization(org.id);
      }
      _invalidate();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${org.nameEn} deleted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            canForce
                ? '$error'
                : 'Could not delete: sites still reference this organization.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAddOrg = ref.watch(canAddOrganizationProvider);
    final canManage = ref.watch(canManageOrganizationsProvider);
    final orgsAsync = ref.watch(adminAllOrganizationsProvider);
    final listBottomPadding = catalogListBottomPadding(context);
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    return Scaffold(
      primary: false,
      floatingActionButton: canAddOrg
          ? FloatingActionButton.extended(
              heroTag: 'admin_fab_organizations',
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: Text(s.addOrganization),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CatalogToolbar(
                searchController: _searchController,
                activeFilter: _filter,
                onFilterChanged: (value) => setState(() => _filter = value),
                hintText: s.searchOrganizations,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: orgsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => CatalogErrorView(
                  message: '$error',
                  onRetry: () => ref.invalidate(adminAllOrganizationsProvider),
                ),
                data: (orgs) {
                  final filtered = _search(
                    filterByActive(
                      items: orgs,
                      filter: _filter,
                      isActive: (org) => org.isActive,
                    ),
                    _searchController.text,
                  );

                  if (filtered.isEmpty) {
                    return CatalogEmptyState(
                      title: 'No organizations',
                      message: canManage
                          ? 'Add ministries, compounds, or companies that own sites.'
                          : 'No organizations match your filters.',
                      icon: Icons.account_balance_outlined,
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, listBottomPadding),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final org = filtered[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: canManage
                              ? () => _openForm(organization: org)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  child: const Icon(Icons.account_balance),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        org.nameEn,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (org.nameAr.trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(org.nameAr),
                                      ],
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          catalogStatusChip(
                                            isActive: org.isActive,
                                          ),
                                          for (final type
                                              in org.siteTypes
                                                  .where((t) => t.isActive)
                                                  .take(3))
                                            catalogTypeChip(
                                              label: s.isAr
                                                  ? type.nameAr
                                                  : type.nameEn,
                                              icon: Icons.category_outlined,
                                              color: Colors.teal,
                                            ),
                                          if (org.siteTypes.length > 3)
                                            catalogTypeChip(
                                              label:
                                                  '+${org.siteTypes.length - 3}',
                                              color: Colors.teal,
                                            ),
                                          if (org.siteCount != null)
                                            catalogTypeChip(
                                              label: s.sitesCount(
                                                org.siteCount!,
                                              ),
                                              icon: Icons.location_city,
                                              color: Colors.blueGrey,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (canManage)
                                  PopupMenuButton<String>(
                                    onSelected: (action) async {
                                      switch (action) {
                                        case 'edit':
                                          await _openForm(organization: org);
                                        case 'toggle':
                                          await _toggleActive(org);
                                        case 'delete':
                                          await _delete(org);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(s.edit),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(
                                          org.isActive
                                              ? s.deactivate
                                              : s.activate,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(s.delete),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Organization> _search(List<Organization> orgs, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return orgs;
    return orgs
        .where(
          (org) =>
              org.nameEn.toLowerCase().contains(q) ||
              org.nameAr.toLowerCase().contains(q),
        )
        .toList();
  }
}

class OrganizationFormScreen extends ConsumerStatefulWidget {
  const OrganizationFormScreen({super.key, this.organization});

  final Organization? organization;

  bool get isEditing => organization != null;

  @override
  ConsumerState<OrganizationFormScreen> createState() =>
      _OrganizationFormScreenState();
}

class _OrganizationFormScreenState
    extends ConsumerState<OrganizationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  late final TextEditingController _typeEnController;
  late final TextEditingController _typeArController;
  late bool _isActive;
  final _existingTypes = <OrganizationSiteType>[];
  final _draftTypes = <({String nameEn, String nameAr})>[];
  final _removedTypeIds = <String>{};
  String? _templateId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final org = widget.organization;
    _nameEnController = TextEditingController(text: org?.nameEn ?? '');
    _nameArController = TextEditingController(text: org?.nameAr ?? '');
    _typeEnController = TextEditingController();
    _typeArController = TextEditingController();
    _isActive = org?.isActive ?? true;
    _templateId = org?.templateId;
    if (org != null) {
      _existingTypes.addAll(org.siteTypes);
    }
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameArController.dispose();
    _typeEnController.dispose();
    _typeArController.dispose();
    super.dispose();
  }

  void _addDraftType(AdminStrings s) {
    final en = _typeEnController.text.trim();
    final ar = _typeArController.text.trim();
    if (en.isEmpty || ar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.typeNameEn} + ${s.typeNameAr}')),
      );
      return;
    }
    final duplicate = _visibleTypes.any(
      (t) => t.nameEn.toLowerCase() == en.toLowerCase(),
    );
    if (duplicate) return;
    setState(() {
      _draftTypes.add((nameEn: en, nameAr: ar));
      _typeEnController.clear();
      _typeArController.clear();
    });
  }

  List<({String id, String nameEn, String nameAr, bool existing})>
  get _visibleTypes {
    final items =
        <({String id, String nameEn, String nameAr, bool existing})>[];
    for (final t in _existingTypes) {
      if (_removedTypeIds.contains(t.id)) continue;
      items.add((id: t.id, nameEn: t.nameEn, nameAr: t.nameAr, existing: true));
    }
    for (var i = 0; i < _draftTypes.length; i++) {
      final d = _draftTypes[i];
      items.add((
        id: 'draft-$i',
        nameEn: d.nameEn,
        nameAr: d.nameAr,
        existing: false,
      ));
    }
    return items;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.isEditing) {
      if (!ref.read(canManageOrganizationsProvider)) return;
    } else {
      if (!ref.read(canAddOrganizationProvider)) return;
    }

    setState(() => _isSaving = true);
    final siteRepo = ref.read(siteRepositoryProvider);
    final zoneRepo = ref.read(zoneRepositoryProvider);

    try {
      final Organization org;
      if (widget.isEditing) {
        org = await siteRepo.updateOrganization(
          widget.organization!.id,
          nameEn: _nameEnController.text.trim(),
          nameAr: _nameArController.text.trim(),
          isActive: _isActive,
        );
      } else {
        var templateId = _templateId;
        if (templateId == null) {
          final templates = await ref.read(
            organizationTemplatesProvider.future,
          );
          final custom = templates.where((t) => t.code == 'custom');
          if (custom.isNotEmpty) templateId = custom.first.id;
        }
        org = await siteRepo.createOrganization(
          nameEn: _nameEnController.text.trim(),
          nameAr: _nameArController.text.trim(),
          isActive: _isActive,
          templateId: templateId,
        );
      }

      // When created from template, types are already copied — only add drafts.
      for (final id in _removedTypeIds) {
        await zoneRepo.deleteSiteType(id);
      }
      for (final draft in _draftTypes) {
        await zoneRepo.createSiteType(
          organizationId: org.id,
          nameEn: draft.nameEn,
          nameAr: draft.nameAr,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageOrganizationsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? s.editOrganization : s.addOrganization),
        actions: [
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(s.save),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
            children: [
              CatalogFormSection(
                title: s.organization,
                subtitle:
                    'A ministry, compound, or company that owns zones and sites',
                children: [
                  if (!widget.isEditing)
                    ref
                        .watch(organizationTemplatesProvider)
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('$e'),
                          data: (templates) {
                            return DropdownButtonFormField<String>(
                              initialValue:
                                  _templateId ??
                                  (templates
                                          .where((t) => t.code == 'custom')
                                          .isEmpty
                                      ? null
                                      : templates
                                            .where((t) => t.code == 'custom')
                                            .first
                                            .id),
                              isExpanded: true,
                              decoration: catalogFieldDecoration(
                                labelText: '${s.template} *',
                                hintText: s.selectTemplate,
                              ),
                              items: [
                                for (final t in templates)
                                  DropdownMenuItem(
                                    value: t.id,
                                    child: Text(
                                      '${t.label(isAr: s.isAr)}'
                                      '${t.siteTypes.isEmpty ? '' : ' (${t.siteTypes.length})'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: canManage
                                  ? (value) =>
                                        setState(() => _templateId = value)
                                  : null,
                              validator: (v) =>
                                  v == null ? s.selectTemplate : null,
                            );
                          },
                        ),
                  TextFormField(
                    controller: _nameEnController,
                    decoration: catalogFieldDecoration(
                      labelText: '${s.englishName} *',
                      hintText: 'e.g. Ministry of Education',
                    ),
                    enabled: canManage,
                    validator: (v) => validateRequiredText(v, 'English name'),
                  ),
                  TextFormField(
                    controller: _nameArController,
                    decoration: catalogFieldDecoration(
                      labelText: '${s.arabicName} *',
                      hintText: 'مثال: وزارة التعليم والتعليم العالي',
                    ),
                    enabled: canManage,
                    validator: (v) => validateRequiredText(v, 'Arabic name'),
                  ),
                ],
              ),
              CatalogFormSection(
                title: s.siteTypes,
                subtitle: s.siteTypesHint,
                children: [
                  if (_visibleTypes.isEmpty)
                    Text(
                      s.noSiteTypesYet,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  for (final type in _visibleTypes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.category_outlined),
                      title: Text(type.nameEn),
                      subtitle: Text(type.nameAr),
                      trailing: canManage
                          ? IconButton(
                              tooltip: s.delete,
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade700,
                              ),
                              onPressed: () => setState(() {
                                if (type.existing) {
                                  _removedTypeIds.add(type.id);
                                } else {
                                  _draftTypes.removeWhere(
                                    (d) =>
                                        d.nameEn == type.nameEn &&
                                        d.nameAr == type.nameAr,
                                  );
                                }
                              }),
                            )
                          : null,
                    ),
                  if (canManage) ...[
                    TextFormField(
                      controller: _typeEnController,
                      decoration: catalogFieldDecoration(
                        labelText: s.typeNameEn,
                        hintText: 'School',
                      ),
                    ),
                    TextFormField(
                      controller: _typeArController,
                      decoration: catalogFieldDecoration(
                        labelText: s.typeNameAr,
                        hintText: 'مدرسة',
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        onPressed: () => _addDraftType(s),
                        icon: const Icon(Icons.add),
                        label: Text(s.addSiteType),
                      ),
                    ),
                  ],
                ],
              ),
              CatalogFormSection(
                title: s.status,
                children: [
                  CatalogSwitchTile(
                    title: s.active,
                    subtitle:
                        'Inactive organizations are hidden from site and zone forms',
                    value: _isActive,
                    onChanged: canManage
                        ? (value) => setState(() => _isActive = value)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
