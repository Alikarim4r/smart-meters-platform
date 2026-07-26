import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/zone_providers.dart';
import '../utils/admin_validation.dart';
import '../utils/catalog_validation.dart';
import '../utils/delete_confirmations.dart';
import '../widgets/catalog_widgets.dart';
import 'site_detail_screen.dart';

class SitesTab extends ConsumerStatefulWidget {
  const SitesTab({super.key});

  @override
  ConsumerState<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends ConsumerState<SitesTab> {
  final _searchController = TextEditingController();
  AdminActiveFilter _filter = AdminActiveFilter.all;

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
    ).push(MaterialPageRoute<void>(builder: (_) => const SiteFormScreen()));
    ref.invalidate(adminSitesProvider);
  }

  Future<void> _toggleActive(Site site) async {
    try {
      if (site.isActive) {
        await ref.read(siteRepositoryProvider).deactivateSite(site.id);
      } else {
        await ref
            .read(siteRepositoryProvider)
            .updateSite(site.id, isActive: true);
      }
      ref.invalidate(adminSitesProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlySiteError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canCreateSitesProvider);
    final canEdit = ref.watch(canEditSitesProvider);
    final canDelete = ref.watch(canDeleteEntitiesProvider);
    final canForceDelete = ref.watch(canForceDeleteProvider);
    final sitesAsync = ref.watch(adminSitesProvider);
    final zonesAsync = ref.watch(adminZonesProvider);
    final zoneFilter = ref.watch(selectedSiteZoneFilterProvider);
    final listBottomPadding = catalogListBottomPadding(context);
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    return Scaffold(
      primary: false,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'admin_fab_sites',
              onPressed: _openAddForm,
              icon: const Icon(Icons.add),
              label: Text(s.addSite),
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
                activeFilter: _toCatalogFilter(_filter),
                onFilterChanged: (value) =>
                    setState(() => _filter = _fromCatalogFilter(value)),
                hintText: s.searchSites,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: zonesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (zones) {
                  return DropdownButtonFormField<String?>(
                    initialValue: zoneFilter,
                    isExpanded: true,
                    decoration: catalogFieldDecoration(
                      labelText: s.zoneFilter,
                      hintText: s.allZones,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          s.allZones,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem<String?>(
                        value: kNoZoneFilterValue,
                        child: Text(
                          s.noZone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final zone in zones)
                        DropdownMenuItem(
                          value: zone.id,
                          child: Text(
                            zone.nameEn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      ref.read(selectedSiteZoneFilterProvider.notifier).state =
                          value;
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: sitesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => CatalogErrorView(
                  message: friendlySiteError(error),
                  onRetry: () => ref.invalidate(adminSitesProvider),
                ),
                data: (sites) {
                  final filtered = searchSites(
                    filterSitesByZoneId(
                      filterSitesByActive(sites: sites, filter: _filter),
                      zoneFilter,
                    ),
                    _searchController.text,
                  );

                  if (filtered.isEmpty) {
                    return CatalogEmptyState(
                      title: 'No sites',
                      message: canCreate
                          ? 'No sites match your filters. Tap Add site to create one.'
                          : 'No sites match your filters.',
                      icon: Icons.location_city_outlined,
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, listBottomPadding),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final site = filtered[index];
                      return BrandInkCard(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SiteDetailScreen(siteId: site.id),
                            ),
                          );
                          ref.invalidate(adminSitesProvider);
                        },
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            brandIconWell(
                              context: context,
                              icon: Icons.apartment_rounded,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    site.nameEn,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: BrandChrome.titleColor(
                                            isDark:
                                                Theme.of(context).brightness ==
                                                Brightness.dark,
                                            scheme: Theme.of(
                                              context,
                                            ).colorScheme,
                                          ),
                                        ),
                                  ),
                                  if (site.nameAr.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      site.nameAr,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: BrandChrome.mutedColor(
                                              isDark:
                                                  Theme.of(
                                                    context,
                                                  ).brightness ==
                                                  Brightness.dark,
                                              scheme: Theme.of(
                                                context,
                                              ).colorScheme,
                                            ),
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    '${site.typeLabel(isAr: false)}'
                                    '${site.location != null ? ' · ${site.location}' : ''}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: BrandChrome.mutedColor(
                                            isDark:
                                                Theme.of(context).brightness ==
                                                Brightness.dark,
                                            scheme: Theme.of(
                                              context,
                                            ).colorScheme,
                                          ),
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      catalogStatusChip(
                                        isActive: site.isActive,
                                      ),
                                      catalogTypeChip(
                                        label: site.displayZoneName,
                                        icon: Icons.map_outlined,
                                        color: site.zoneId == null
                                            ? Colors.brown
                                            : Colors.amber,
                                      ),
                                      if (site.meterCount != null)
                                        catalogTypeChip(
                                          label:
                                              '${site.meterCount} meter${site.meterCount == 1 ? '' : 's'}',
                                          icon: Icons.speed,
                                          color: Colors.orange,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (canEdit)
                              PopupMenuButton<String>(
                                onSelected: (action) async {
                                  switch (action) {
                                    case 'edit':
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              SiteFormScreen(site: site),
                                        ),
                                      );
                                      ref.invalidate(adminSitesProvider);
                                    case 'toggle':
                                      await _toggleActive(site);
                                    case 'meters':
                                      ref
                                              .read(
                                                selectedAdminSiteIdProvider
                                                    .notifier,
                                              )
                                              .state =
                                          site.id;
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Open the Meters tab for ${site.nameEn}',
                                          ),
                                        ),
                                      );
                                    case 'delete':
                                      final confirmed = canForceDelete
                                          ? await confirmForceDelete(
                                              context: context,
                                              title: 'Force-delete site?',
                                              entityName: site.nameEn,
                                            )
                                          : await confirmRestrictedDelete(
                                              context: context,
                                              title: 'Delete site?',
                                              entityName: site.nameEn,
                                              restrictionMessage:
                                                  'Not allowed while meters, tanks, or other linked data still reference this site. '
                                                  'Remove dependents first, or ask a super admin to force-delete.',
                                            );
                                      if (confirmed != true) return;
                                      try {
                                        final repo = ref.read(
                                          siteRepositoryProvider,
                                        );
                                        if (canForceDelete) {
                                          await repo.forceDeleteSite(site.id);
                                        } else {
                                          await repo.deleteSite(site.id);
                                        }
                                        ref.invalidate(adminSitesProvider);
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              friendlySiteError(error),
                                            ),
                                          ),
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
                                      site.isActive ? s.deactivate : s.activate,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'meters',
                                    child: Text(s.viewMeters),
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

  ActiveFilter _toCatalogFilter(AdminActiveFilter filter) {
    switch (filter) {
      case AdminActiveFilter.all:
        return ActiveFilter.all;
      case AdminActiveFilter.activeOnly:
        return ActiveFilter.activeOnly;
      case AdminActiveFilter.inactiveOnly:
        return ActiveFilter.inactiveOnly;
    }
  }

  AdminActiveFilter _fromCatalogFilter(ActiveFilter filter) {
    switch (filter) {
      case ActiveFilter.all:
        return AdminActiveFilter.all;
      case ActiveFilter.activeOnly:
        return AdminActiveFilter.activeOnly;
      case ActiveFilter.inactiveOnly:
        return AdminActiveFilter.inactiveOnly;
    }
  }
}

class SiteFormScreen extends ConsumerStatefulWidget {
  const SiteFormScreen({
    super.key,
    this.site,
    this.initialOrganizationId,
    this.initialZoneId,
  });

  final Site? site;
  final String? initialOrganizationId;
  final String? initialZoneId;

  bool get isEditing => site != null;

  @override
  ConsumerState<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends ConsumerState<SiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  late final TextEditingController _locationController;
  late bool _isActive;
  String? _organizationId;
  String? _zoneId;
  String? _siteTypeId;
  bool _isSaving = false;

  bool get _canCreate => ref.read(canCreateSitesProvider);

  @override
  void initState() {
    super.initState();
    final site = widget.site;
    _nameEnController = TextEditingController(text: site?.nameEn ?? '');
    _nameArController = TextEditingController(text: site?.nameAr ?? '');
    _locationController = TextEditingController(text: site?.location ?? '');
    _siteTypeId = site?.siteTypeId;
    _isActive = site?.isActive ?? true;
    _organizationId = site?.organizationId ?? widget.initialOrganizationId;
    _zoneId = site?.zoneId ?? widget.initialZoneId;
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameArController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(siteRepositoryProvider);
    final nameAr = _nameArController.text.trim();
    final location = _locationController.text.trim();

    try {
      if (widget.isEditing) {
        await repo.updateSite(
          widget.site!.id,
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? _nameEnController.text.trim() : nameAr,
          siteTypeId: _siteTypeId,
          location: location.isEmpty ? '' : location,
          zoneId: _zoneId,
          clearZone: _zoneId == null,
          isActive: _isActive,
        );
      } else {
        if (!_canCreate) {
          throw Exception('You do not have permission to create sites.');
        }
        if (_siteTypeId == null) {
          throw Exception('Select a site type.');
        }
        await repo.createSite(
          organizationId: _organizationId!,
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? _nameEnController.text.trim() : nameAr,
          siteTypeId: _siteTypeId!,
          location: location.isEmpty ? null : location,
          zoneId: _zoneId,
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlySiteError(error))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(canCreateSitesProvider);
    final canEdit =
        widget.isEditing || canCreate || ref.watch(canEditSitesProvider);
    final orgsAsync = ref.watch(adminOrganizationsProvider);
    final orgId = _organizationId ?? widget.site?.organizationId;
    final zonesAsync = orgId == null
        ? const AsyncValue<List<Zone>>.data([])
        : ref.watch(organizationZonesProvider(orgId));
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? s.editSite : s.addSite),
        actions: [
          if (canEdit)
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
                title: s.basicInformation,
                children: [
                  if (!widget.isEditing)
                    orgsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Text(friendlySiteError(error)),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: canCreate
                              ? (value) => setState(() {
                                  _organizationId = value;
                                  _zoneId = null;
                                  _siteTypeId = null;
                                })
                              : null,
                          validator: (_) =>
                              validateOrganizationId(_organizationId),
                        );
                      },
                    ),
                  TextFormField(
                    controller: _nameEnController,
                    decoration: catalogFieldDecoration(
                      labelText: '${s.englishName} *',
                    ),
                    enabled: canEdit,
                    validator: validateSiteNameEn,
                  ),
                  TextFormField(
                    controller: _nameArController,
                    decoration: catalogFieldDecoration(labelText: s.arabicName),
                    enabled: canEdit,
                  ),
                  if (_organizationId == null)
                    Text(
                      s.selectOrganizationFirst,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    ref
                        .watch(organizationSiteTypesProvider(_organizationId!))
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (error, _) => Text('$error'),
                          data: (types) {
                            final active = types
                                .where((t) => t.isActive)
                                .toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    'site_type_$_organizationId$_siteTypeId',
                                  ),
                                  initialValue: _siteTypeId,
                                  isExpanded: true,
                                  decoration: catalogFieldDecoration(
                                    labelText: '${s.siteType} *',
                                    hintText: s.selectSiteType,
                                  ),
                                  items: [
                                    for (final type in active)
                                      DropdownMenuItem(
                                        value: type.id,
                                        child: Text(
                                          '${type.nameEn} — ${type.nameAr}',
                                        ),
                                      ),
                                  ],
                                  onChanged: canEdit
                                      ? (value) =>
                                            setState(() => _siteTypeId = value)
                                      : null,
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? s.selectSiteType
                                      : null,
                                ),
                                if (canEdit)
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        final created =
                                            await _showAddSiteTypeDialog(
                                              context,
                                              ref,
                                              s,
                                              _organizationId!,
                                            );
                                        if (created != null && mounted) {
                                          setState(() => _siteTypeId = created);
                                          ref.invalidate(
                                            organizationSiteTypesProvider(
                                              _organizationId!,
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.add, size: 18),
                                      label: Text(s.addTypeInline),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                  TextFormField(
                    controller: _locationController,
                    decoration: catalogFieldDecoration(
                      labelText: s.locationAddress,
                      hintText: 'e.g. Doha, Qatar',
                    ),
                    enabled: canEdit,
                    maxLines: 2,
                  ),
                ],
              ),
              CatalogFormSection(
                title: s.zone,
                subtitle: 'Optional — headquarters may have no zone',
                children: [
                  zonesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text(friendlyZoneError(error)),
                    data: (zones) {
                      return DropdownButtonFormField<String?>(
                        initialValue: _zoneId,
                        isExpanded: true,
                        decoration: catalogFieldDecoration(
                          labelText: s.zone,
                          hintText: s.noZone,
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              s.noZone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final zone in zones)
                            DropdownMenuItem(
                              value: zone.id,
                              child: Text(
                                zone.defaultSiteType == null
                                    ? (s.isAr &&
                                              (zone.nameAr?.isNotEmpty ?? false)
                                          ? zone.nameAr!
                                          : zone.nameEn)
                                    : '${s.isAr && (zone.nameAr?.isNotEmpty ?? false) ? zone.nameAr! : zone.nameEn} · ${zone.defaultSiteType!.label(isAr: s.isAr)}',
                              ),
                            ),
                        ],
                        onChanged: canEdit
                            ? (value) => setState(() {
                                _zoneId = value;
                                if (value != null) {
                                  final zone = zones
                                      .where((z) => z.id == value)
                                      .toList();
                                  final zoneTypeId = zone.isEmpty
                                      ? null
                                      : zone.first.defaultSiteTypeId;
                                  if (zoneTypeId != null) {
                                    _siteTypeId = zoneTypeId;
                                  }
                                }
                              })
                            : null,
                      );
                    },
                  ),
                ],
              ),
              CatalogFormSection(
                title: s.status,
                children: [
                  CatalogSwitchTile(
                    title: s.active,
                    subtitle: 'Inactive sites are hidden from entry apps',
                    value: _isActive,
                    onChanged: canEdit
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

Future<String?> _showAddSiteTypeDialog(
  BuildContext context,
  WidgetRef ref,
  AdminStrings s,
  String organizationId,
) async {
  final en = TextEditingController();
  final ar = TextEditingController();
  final created = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.addSiteType),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: en,
            decoration: catalogFieldDecoration(labelText: s.typeNameEn),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ar,
            decoration: catalogFieldDecoration(labelText: s.typeNameAr),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
        FilledButton(
          onPressed: () async {
            final nameEn = en.text.trim();
            final nameAr = ar.text.trim();
            if (nameEn.isEmpty || nameAr.isEmpty) return;
            try {
              final type = await ref
                  .read(zoneRepositoryProvider)
                  .createSiteType(
                    organizationId: organizationId,
                    nameEn: nameEn,
                    nameAr: nameAr,
                  );
              if (ctx.mounted) Navigator.pop(ctx, type.id);
            } catch (error) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text('$error')));
              }
            }
          },
          child: Text(s.save),
        ),
      ],
    ),
  );
  en.dispose();
  ar.dispose();
  return created;
}
