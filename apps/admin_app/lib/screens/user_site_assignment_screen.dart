import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/admin_providers.dart';
import '../providers/user_providers.dart';
import '../utils/admin_validation.dart';
import '../utils/user_validation.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/user_widgets.dart';
import '../l10n/admin_strings.dart';

class UserSiteAssignmentScreen extends ConsumerStatefulWidget {
  const UserSiteAssignmentScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserSiteAssignmentScreen> createState() =>
      _UserSiteAssignmentScreenState();
}

class _UserSiteAssignmentScreenState
    extends ConsumerState<UserSiteAssignmentScreen> {
  final _searchController = TextEditingController();
  bool _saving = false;

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

  Future<void> _refresh() async {
    ref.invalidate(userSiteAccessProvider(widget.userId));
    ref.invalidate(userDetailsProvider(widget.userId));
  }

  Future<void> _addAssignment(Site site, AdminUser user) async {
    final perms = defaultSitePermissionsForRole(user.profile.role);
    setState(() => _saving = true);
    try {
      await ref
          .read(userAdminRepositoryProvider)
          .addUserSiteAccess(
            userId: widget.userId,
            siteId: site.id,
            role: user.profile.role,
            canRead: perms.canRead,
            canWrite: perms.canWrite,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Added ${site.nameEn}')));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUserAdminError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updatePermissions(
    UserSiteAccess access, {
    required bool canRead,
    required bool canWrite,
  }) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(userAdminRepositoryProvider)
          .updateUserSiteAccess(
            accessId: access.id,
            canRead: canRead,
            canWrite: canWrite && canRead,
            role: access.role,
          );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUserAdminError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeAssignment(UserSiteAccess access) async {
    final siteName = access.site?.nameEn ?? 'this site';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(adminText(context, 'Remove assignment?', 'إزالة التعيين؟')),
        content: Text('Remove access to $siteName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(adminText(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(adminText(context, 'Remove', 'إزالة')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(userAdminRepositoryProvider)
          .removeUserSiteAccess(access.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            adminText(context, 'Assignment removed', 'تمت إزالة التعيين'),
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUserAdminError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userDetailsProvider(widget.userId));
    final accessAsync = ref.watch(userSiteAccessProvider(widget.userId));
    final sitesAsync = ref.watch(adminSitesProvider);
    final zoneFilter = ref.watch(siteAssignmentZoneFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: userAsync.maybeWhen(
          data: (user) => Text('Sites · ${user.displayName}'),
          orElse: () =>
              Text(adminText(context, 'Site assignments', 'تعيينات المواقع')),
        ),
      ),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => UserEmptyState(
            title: adminText(
              context,
              'Could not load user',
              'تعذّر تحميل المستخدم',
            ),
            subtitle: friendlyUserAdminError(error),
          ),
          data: (user) {
            if (!canEditSiteAssignments(user)) {
              return UserEmptyState(
                title: adminText(
                  context,
                  'Assignments unavailable',
                  'التعيينات غير متاحة',
                ),
                subtitle: adminText(
                  context,
                  'Only approved active users can receive site assignments.',
                  'يمكن تعيين المواقع للمستخدمين النشطين المعتمدين فقط.',
                ),
              );
            }

            return sitesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => UserEmptyState(
                title: adminText(
                  context,
                  'Could not load sites',
                  'تعذّر تحميل المواقع',
                ),
                subtitle: friendlySiteError(error),
              ),
              data: (allSites) {
                return accessAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => UserEmptyState(
                    title: adminText(
                      context,
                      'Could not load assignments',
                      'تعذّر تحميل التعيينات',
                    ),
                    subtitle: friendlyUserAdminError(error),
                  ),
                  data: (assignments) {
                    final assignedSiteIds = assignments
                        .map((a) => a.siteId)
                        .toSet();
                    var availableSites = allSites
                        .where(
                          (site) =>
                              site.isActive &&
                              !assignedSiteIds.contains(site.id),
                        )
                        .toList();
                    availableSites = searchSites(
                      availableSites,
                      _searchController.text,
                    );
                    availableSites = filterSitesByZoneId(
                      availableSites,
                      zoneFilter,
                    );
                    final groups = groupSitesByZone(availableSites);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_saving)
                          const LinearProgressIndicator(minHeight: 2),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(
                                adminText(
                                  context,
                                  'Current assignments',
                                  'التعيينات الحالية',
                                ),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              if (assignments.isEmpty)
                                Text(
                                  adminText(
                                    context,
                                    'No sites assigned yet.',
                                    'لا توجد مواقع معيّنة بعد.',
                                  ),
                                )
                              else
                                for (final access in assignments)
                                  Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            access.site?.nameEn ??
                                                'Unknown site',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          Text(
                                            '${access.site?.displayZoneName ?? kNoZoneLabel}'
                                            ' · ${access.site?.siteType.label ?? ''}'
                                            '${access.site?.location != null ? ' · ${access.site!.location}' : ''}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: SwitchListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(
                                                    adminText(
                                                      context,
                                                      'Read',
                                                      'قراءة',
                                                    ),
                                                  ),
                                                  value: access.canRead,
                                                  onChanged: _saving
                                                      ? null
                                                      : (value) =>
                                                            _updatePermissions(
                                                              access,
                                                              canRead: value,
                                                              canWrite: access
                                                                  .canWrite,
                                                            ),
                                                ),
                                              ),
                                              Expanded(
                                                child: SwitchListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(
                                                    adminText(
                                                      context,
                                                      'Write',
                                                      'كتابة',
                                                    ),
                                                  ),
                                                  value: access.canWrite,
                                                  onChanged:
                                                      _saving || !access.canRead
                                                      ? null
                                                      : (value) =>
                                                            _updatePermissions(
                                                              access,
                                                              canRead: access
                                                                  .canRead,
                                                              canWrite: value,
                                                            ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Align(
                                            alignment:
                                                AlignmentDirectional.centerEnd,
                                            child: TextButton.icon(
                                              onPressed: _saving
                                                  ? null
                                                  : () => _removeAssignment(
                                                      access,
                                                    ),
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: Colors.red.shade700,
                                              ),
                                              label: Text(
                                                adminText(
                                                  context,
                                                  'Remove',
                                                  'إزالة',
                                                ),
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              const SizedBox(height: 24),
                              Text(
                                adminText(
                                  context,
                                  'Add site assignment',
                                  'إضافة تعيين موقع',
                                ),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _searchController,
                                decoration:
                                    catalogFieldDecoration(
                                      labelText: adminText(
                                        context,
                                        'Search sites',
                                        'بحث في المواقع',
                                      ),
                                      hintText: adminText(
                                        context,
                                        'Name or location…',
                                        'الاسم أو الموقع…',
                                      ),
                                    ).copyWith(
                                      prefixIcon: const Icon(Icons.search),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                initialValue: zoneFilter,
                                isExpanded: true,
                                decoration: catalogFieldDecoration(
                                  labelText: adminText(
                                    context,
                                    'Zone filter',
                                    'تصفية المنطقة',
                                  ),
                                  hintText: adminText(
                                    context,
                                    'All zones',
                                    'كل المناطق',
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      adminText(
                                        context,
                                        'All zones',
                                        'كل المناطق',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const DropdownMenuItem<String?>(
                                    value: kNoZoneFilterValue,
                                    child: Text(
                                      kNoZoneLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  for (final zone
                                      in allSites
                                          .map((s) => s.zone)
                                          .whereType<Zone>()
                                          .toSet()
                                          .toList()
                                        ..sort(
                                          (a, b) =>
                                              a.nameEn.compareTo(b.nameEn),
                                        ))
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
                                  ref
                                          .read(
                                            siteAssignmentZoneFilterProvider
                                                .notifier,
                                          )
                                          .state =
                                      value;
                                },
                              ),
                              const SizedBox(height: 12),
                              if (groups.isEmpty)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    adminText(
                                      context,
                                      'No available sites match your search.',
                                      'لا توجد مواقع متاحة تطابق البحث.',
                                    ),
                                  ),
                                )
                              else
                                for (final group in groups) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 8,
                                      top: 8,
                                    ),
                                    child: Text(
                                      group.zoneName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  for (final site in group.sites)
                                    Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(site.nameEn),
                                        subtitle: Text(
                                          '${site.siteType.label}'
                                          '${site.location != null ? ' · ${site.location}' : ''}',
                                        ),
                                        trailing: FilledButton.tonal(
                                          onPressed: _saving
                                              ? null
                                              : () =>
                                                    _addAssignment(site, user),
                                          child: Text(
                                            adminText(context, 'Add', 'إضافة'),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
