import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/admin_providers.dart';
import '../providers/user_providers.dart';
import '../utils/admin_validation.dart';
import '../utils/user_validation.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/user_widgets.dart';

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
        title: const Text('Remove assignment?'),
        content: Text('Remove access to $siteName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Remove'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Assignment removed')));
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
          orElse: () => const Text('Site assignments'),
        ),
      ),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => UserEmptyState(
            title: 'Could not load user',
            subtitle: friendlyUserAdminError(error),
          ),
          data: (user) {
            if (!canEditSiteAssignments(user)) {
              return const UserEmptyState(
                title: 'Assignments unavailable',
                subtitle:
                    'Only approved active users can receive site assignments.',
              );
            }

            return sitesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => UserEmptyState(
                title: 'Could not load sites',
                subtitle: friendlySiteError(error),
              ),
              data: (allSites) {
                return accessAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => UserEmptyState(
                    title: 'Could not load assignments',
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
                                'Current assignments',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              if (assignments.isEmpty)
                                const Text('No sites assigned yet.')
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
                                                  title: const Text('Read'),
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
                                                  title: const Text('Write'),
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
                                            alignment: Alignment.centerRight,
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
                                                'Remove',
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
                                'Add site assignment',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _searchController,
                                decoration:
                                    catalogFieldDecoration(
                                      labelText: 'Search sites',
                                      hintText: 'Name or location…',
                                    ).copyWith(
                                      prefixIcon: const Icon(Icons.search),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                initialValue: zoneFilter,
                                isExpanded: true,
                                decoration: catalogFieldDecoration(
                                  labelText: 'Zone filter',
                                  hintText: 'All zones',
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      'All zones',
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
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    'No available sites match your search.',
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
                                          child: const Text('Add'),
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
