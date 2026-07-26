import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/zone_providers.dart';
import '../utils/admin_validation.dart' show validateOrganizationId;
import '../utils/catalog_validation.dart';
import '../utils/delete_confirmations.dart';
import '../widgets/catalog_widgets.dart';

class ZonesTab extends ConsumerStatefulWidget {
  const ZonesTab({super.key});

  @override
  ConsumerState<ZonesTab> createState() => _ZonesTabState();
}

class _ZonesTabState extends ConsumerState<ZonesTab> {
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

  Future<void> _openAddForm() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ZoneFormScreen()));
    ref.invalidate(adminZonesProvider);
  }

  Future<void> _toggleActive(Zone zone) async {
    try {
      if (zone.isActive) {
        await ref.read(zoneRepositoryProvider).deactivateZone(zone.id);
      } else {
        await ref
            .read(zoneRepositoryProvider)
            .updateZone(zone.id, isActive: true);
      }
      ref.invalidate(adminZonesProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyZoneError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageZonesProvider);
    final canDelete = ref.watch(canDeleteEntitiesProvider);
    final canForceDelete = ref.watch(canForceDeleteProvider);
    final zonesAsync = ref.watch(adminZonesProvider);
    final listBottomPadding = catalogListBottomPadding(context);
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    return Scaffold(
      primary: false,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'admin_fab_zones',
              onPressed: _openAddForm,
              icon: const Icon(Icons.add),
              label: Text(s.addZone),
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
                hintText: s.searchZones,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: zonesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => CatalogErrorView(
                  message: friendlyZoneError(error),
                  onRetry: () => ref.invalidate(adminZonesProvider),
                ),
                data: (zones) {
                  final filtered = searchZones(
                    filterByActive(
                      items: zones,
                      filter: _filter,
                      isActive: (zone) => zone.isActive,
                    ),
                    _searchController.text,
                  );

                  if (filtered.isEmpty) {
                    return CatalogEmptyState(
                      title: 'No zones',
                      message: canManage
                          ? 'No zones match your filters. Tap Add zone to create one.'
                          : 'No zones match your filters.',
                      icon: Icons.map_outlined,
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, listBottomPadding),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final zone = filtered[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: canManage
                              ? () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          ZoneFormScreen(zone: zone),
                                    ),
                                  );
                                  ref.invalidate(adminZonesProvider);
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        zone.nameEn,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (zone.nameAr != null &&
                                          zone.nameAr!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(zone.nameAr!),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        'Code: ${zone.code}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.grey.shade700,
                                            ),
                                      ),
                                      if (zone.description != null &&
                                          zone.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          zone.description!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          catalogStatusChip(
                                            isActive: zone.isActive,
                                          ),
                                          if (zone.defaultSiteType != null)
                                            catalogTypeChip(
                                              label: zone.defaultSiteType!
                                                  .label(isAr: s.isAr),
                                              icon: Icons.category_outlined,
                                              color: Colors.teal,
                                            ),
                                          if (zone.siteCount != null)
                                            catalogTypeChip(
                                              label: s.sitesCount(
                                                zone.siteCount!,
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
                                          await Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  ZoneFormScreen(zone: zone),
                                            ),
                                          );
                                          ref.invalidate(adminZonesProvider);
                                        case 'toggle':
                                          await _toggleActive(zone);
                                        case 'delete':
                                          final confirmed = canForceDelete
                                              ? await confirmForceDelete(
                                                  context: context,
                                                  title: s.deleteZoneTitle,
                                                  entityName: zone.nameEn,
                                                )
                                              : await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: Text(
                                                      s.deleteZoneTitle,
                                                    ),
                                                    content: Text(
                                                      'Permanently delete "${zone.nameEn}"?\n'
                                                      'Sites in this zone will become unassigned.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              false,
                                                            ),
                                                        child: Text(s.cancel),
                                                      ),
                                                      FilledButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              true,
                                                            ),
                                                        child: Text(s.delete),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                          if (confirmed != true) return;
                                          try {
                                            final repo = ref.read(
                                              zoneRepositoryProvider,
                                            );
                                            if (canForceDelete) {
                                              await repo.forceDeleteZone(
                                                zone.id,
                                              );
                                            } else {
                                              await repo.deleteZone(zone.id);
                                            }
                                            ref.invalidate(adminZonesProvider);
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${zone.nameEn} deleted',
                                                ),
                                              ),
                                            );
                                          } catch (error) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(content: Text('$error')),
                                            );
                                          }
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
                                          zone.isActive
                                              ? s.deactivate
                                              : s.activate,
                                        ),
                                      ),
                                      if (canDelete)
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
}

List<Zone> searchZones(List<Zone> zones, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return zones;
  }
  return zones
      .where(
        (zone) =>
            zone.nameEn.toLowerCase().contains(q) ||
            zone.code.toLowerCase().contains(q) ||
            (zone.nameAr?.toLowerCase().contains(q) ?? false) ||
            (zone.description?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}

class ZoneFormScreen extends ConsumerStatefulWidget {
  const ZoneFormScreen({
    super.key,
    this.zone,
    this.initialOrganizationId,
    this.initialParentZoneId,
  });

  final Zone? zone;
  final String? initialOrganizationId;
  final String? initialParentZoneId;

  bool get isEditing => zone != null;

  @override
  ConsumerState<ZoneFormScreen> createState() => _ZoneFormScreenState();
}

class _ZoneFormScreenState extends ConsumerState<ZoneFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _sortOrderController;
  late bool _isActive;
  String? _organizationId;
  String? _parentZoneId;
  String? _defaultSiteTypeId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final zone = widget.zone;
    _codeController = TextEditingController(text: zone?.code ?? '');
    _nameEnController = TextEditingController(text: zone?.nameEn ?? '');
    _nameArController = TextEditingController(text: zone?.nameAr ?? '');
    _descriptionController = TextEditingController(
      text: zone?.description ?? '',
    );
    _sortOrderController = TextEditingController(
      text: '${zone?.sortOrder ?? 0}',
    );
    _isActive = zone?.isActive ?? true;
    _organizationId = zone?.organizationId ?? widget.initialOrganizationId;
    _parentZoneId = zone?.parentZoneId ?? widget.initialParentZoneId;
    _defaultSiteTypeId = zone?.defaultSiteTypeId;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!ref.read(canManageZonesProvider)) {
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(zoneRepositoryProvider);
    final nameAr = _nameArController.text.trim();
    final description = _descriptionController.text.trim();
    final sortOrder = int.parse(_sortOrderController.text.trim());

    try {
      if (widget.isEditing) {
        await repo.updateZone(
          widget.zone!.id,
          code: _codeController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? '' : nameAr,
          description: description.isEmpty ? '' : description,
          isActive: _isActive,
          sortOrder: sortOrder,
          parentZoneId: _parentZoneId,
          clearParentZone: _parentZoneId == null,
          defaultSiteTypeId: _defaultSiteTypeId,
          clearDefaultSiteType: _defaultSiteTypeId == null,
        );
      } else {
        await repo.createZone(
          organizationId: _organizationId!,
          code: _codeController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? null : nameAr,
          description: description.isEmpty ? null : description,
          isActive: _isActive,
          sortOrder: sortOrder,
          parentZoneId: _parentZoneId,
          defaultSiteTypeId: _defaultSiteTypeId,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyZoneError(error))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageZonesProvider);
    final orgsAsync = ref.watch(adminOrganizationsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? s.editZone : s.addZone),
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
      body: BrandSurfaceBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
              children: [
                CatalogFormSection(
                  title: s.basicInformation,
                  children: [
                    if (!widget.isEditing)
                      orgsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        error: (error, _) => Text(friendlyZoneError(error)),
                        data: (orgs) {
                          _organizationId ??= orgs.isNotEmpty
                              ? orgs.first.id
                              : null;
                          return DropdownButtonFormField<String>(
                            initialValue: _organizationId,
                            isExpanded: true,
                            decoration: catalogFieldDecoration(
                              labelText: '${s.organization} *',
                            ),
                            items: [
                              for (final org in orgs)
                                DropdownMenuItem(
                                  value: org.id,
                                  child: Text(
                                    org.nameEn,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: canManage
                                ? (value) => setState(() {
                                    _organizationId = value;
                                    _defaultSiteTypeId = null;
                                    _parentZoneId = null;
                                  })
                                : null,
                            validator: (_) =>
                                validateOrganizationId(_organizationId),
                          );
                        },
                      ),
                    if (_organizationId != null)
                      ref
                          .watch(organizationZonesProvider(_organizationId!))
                          .when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                            data: (zones) {
                              final candidates = zones
                                  .where((z) => z.id != widget.zone?.id)
                                  .toList();
                              return DropdownButtonFormField<String?>(
                                key: ValueKey(
                                  'parent_$_organizationId$_parentZoneId',
                                ),
                                initialValue: _parentZoneId,
                                isExpanded: true,
                                decoration: catalogFieldDecoration(
                                  labelText: s.parentZone,
                                  hintText: s.noParentZone,
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      s.noParentZone,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  for (final z in candidates)
                                    DropdownMenuItem<String?>(
                                      value: z.id,
                                      child: Text(
                                        z.nameEn,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: canManage
                                    ? (value) =>
                                          setState(() => _parentZoneId = value)
                                    : null,
                              );
                            },
                          ),
                    TextFormField(
                      controller: _codeController,
                      decoration: catalogFieldDecoration(
                        labelText: '${s.code} *',
                        hintText: 'e.g. north_zone',
                      ),
                      enabled: canManage,
                      validator: validateCatalogCode,
                    ),
                    TextFormField(
                      controller: _nameEnController,
                      decoration: catalogFieldDecoration(
                        labelText: '${s.englishName} *',
                      ),
                      enabled: canManage,
                      validator: (v) => validateRequiredText(v, 'English name'),
                    ),
                    TextFormField(
                      controller: _nameArController,
                      decoration: catalogFieldDecoration(
                        labelText: s.arabicName,
                      ),
                      enabled: canManage,
                    ),
                    if (_organizationId == null)
                      Text(
                        s.selectOrganizationFirst,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      ref
                          .watch(
                            organizationSiteTypesProvider(_organizationId!),
                          )
                          .when(
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                            error: (error, _) => Text('$error'),
                            data: (types) {
                              final active = types
                                  .where((t) => t.isActive)
                                  .toList();
                              return DropdownButtonFormField<String?>(
                                key: ValueKey(
                                  'zone_type_$_organizationId$_defaultSiteTypeId',
                                ),
                                initialValue: _defaultSiteTypeId,
                                isExpanded: true,
                                decoration: catalogFieldDecoration(
                                  labelText: s.defaultSuggestedType,
                                  hintText: s.mixedOptional,
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      s.mixedOptional,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  for (final type in active)
                                    DropdownMenuItem<String?>(
                                      value: type.id,
                                      child: Text(
                                        '${type.nameEn} — ${type.nameAr}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: canManage
                                    ? (value) => setState(
                                        () => _defaultSiteTypeId = value,
                                      )
                                    : null,
                              );
                            },
                          ),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: catalogFieldDecoration(
                        labelText: s.description,
                      ),
                      enabled: canManage,
                      maxLines: 3,
                    ),
                    TextFormField(
                      controller: _sortOrderController,
                      decoration: catalogFieldDecoration(
                        labelText: '${s.sortOrder} *',
                      ),
                      keyboardType: TextInputType.number,
                      enabled: canManage,
                      validator: validateSortOrder,
                    ),
                  ],
                ),
                CatalogFormSection(
                  title: s.status,
                  children: [
                    CatalogSwitchTile(
                      title: s.active,
                      subtitle:
                          'Inactive zones are hidden from site assignment',
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
      ),
    );
  }
}
