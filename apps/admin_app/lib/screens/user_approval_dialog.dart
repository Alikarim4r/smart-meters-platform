import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/admin_providers.dart';
import '../utils/user_validation.dart';
import '../widgets/catalog_widgets.dart';

/// Returns true when approval succeeded.
Future<bool?> showUserApprovalDialog(
  BuildContext context, {
  required AdminUser user,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => UserApprovalDialog(user: user),
  );
}

class UserApprovalDialog extends ConsumerStatefulWidget {
  const UserApprovalDialog({super.key, required this.user});

  final AdminUser user;

  @override
  ConsumerState<UserApprovalDialog> createState() => _UserApprovalDialogState();
}

class _UserApprovalDialogState extends ConsumerState<UserApprovalDialog> {
  late UserRole _role;
  final _noteController = TextEditingController();
  final _selectedSiteIds = <String>{};
  final _sitePermissions = <String, ({bool canRead, bool canWrite})>{};
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final pending = widget.user.profile.role;
    _role = switch (pending) {
      UserRole.viewer => UserRole.viewer,
      UserRole.siteAdmin => UserRole.siteAdmin,
      UserRole.superAdmin => UserRole.superAdmin,
      _ => UserRole.technician,
    };
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _applyRoleDefaults(UserRole role) {
    final defaults = defaultSitePermissionsForRole(role);
    for (final siteId in _selectedSiteIds) {
      _sitePermissions[siteId] = defaults;
    }
  }

  void _toggleSite(Site site, bool selected) {
    setState(() {
      if (selected) {
        _selectedSiteIds.add(site.id);
        _sitePermissions[site.id] = defaultSitePermissionsForRole(_role);
      } else {
        _selectedSiteIds.remove(site.id);
        _sitePermissions.remove(site.id);
      }
    });
  }

  Future<void> _submit() async {
    final validationError = validateApprovalSites(
      role: _role,
      selectedSiteIds: _selectedSiteIds,
    );
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(userAdminRepositoryProvider);
      await repo.approveUser(
        userId: widget.user.profile.id,
        role: _role,
        siteIds: _selectedSiteIds.toList(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      // Dual-layer: mirror each site into user_scope_assignments.
      final scopeRole = await repo.getRoleByCode(
        UserAdminRepository.scopeRoleCodeFor(
          _role,
          kind: ScopeKind.site,
        ),
      );
      if (scopeRole != null) {
        for (final siteId in _selectedSiteIds) {
          await repo.assignUserScope(
            userId: widget.user.profile.id,
            roleId: scopeRole.id,
            siteId: siteId,
            inheritChildren: false,
          );
        }
      }

      // Apply custom permissions if admin changed toggles from role defaults.
      if (_selectedSiteIds.isNotEmpty) {
        final defaults = defaultSitePermissionsForRole(_role);
        for (final siteId in _selectedSiteIds) {
          final perms = _sitePermissions[siteId] ?? defaults;
          if (perms.canRead != defaults.canRead ||
              perms.canWrite != defaults.canWrite) {
            final accessList = await repo.getUserSiteAccess(
              widget.user.profile.id,
            );
            final match = accessList
                .where((a) => a.siteId == siteId)
                .firstOrNull;
            if (match != null) {
              await repo.updateUserSiteAccess(
                accessId: match.id,
                canRead: perms.canRead,
                canWrite: perms.canWrite,
                role: _role,
              );
            }
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = friendlyUserAdminError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(adminSitesProvider);
    final activeSites = sitesAsync.maybeWhen(
      data: (sites) => sites.where((s) => s.isActive).toList(),
      orElse: () => <Site>[],
    );
    final actor = ref.watch(authProvider).profile;
    final isOwner = actor?.isPlatformOwner ?? false;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final source = isAr
        ? widget.user.profile.role.registrationSourceLabelAr
        : widget.user.profile.role.registrationSourceLabelEn;

    final roleItems = <DropdownMenuItem<UserRole>>[
      const DropdownMenuItem(
        value: UserRole.technician,
        child: Text('Technician — Entry + Dashboard'),
      ),
      const DropdownMenuItem(
        value: UserRole.viewer,
        child: Text('Viewer — Dashboard only'),
      ),
      const DropdownMenuItem(
        value: UserRole.siteAdmin,
        child: Text('Site Admin — Admin + Entry + Dashboard'),
      ),
      if (isOwner)
        const DropdownMenuItem(
          value: UserRole.superAdmin,
          child: Text('Super Admin — Admin + Dashboard'),
        ),
    ];

    return AlertDialog(
      title: Text(
        isAr
            ? 'اعتماد ${widget.user.displayName}'
            : 'Approve ${widget.user.displayName}',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.user.profile.email,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                source,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                isExpanded: true,
                decoration: catalogFieldDecoration(
                  labelText: isAr ? 'الصلاحية النهائية' : 'Final role',
                ),
                items: roleItems,
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _role = value;
                          _applyRoleDefaults(value);
                        });
                      },
              ),
              const SizedBox(height: 8),
              Text(
                userRolePermissionHint(_role, isAr: isAr),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                isAr ? 'تعيين المواقع' : 'Assign sites',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (sitesAsync.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (activeSites.isEmpty)
                Text(isAr ? 'لا توجد مواقع مفعّلة.' : 'No active sites available.')
              else
                ...activeSites.map((site) {
                  final selected = _selectedSiteIds.contains(site.id);
                  final perms =
                      _sitePermissions[site.id] ??
                      defaultSitePermissionsForRole(_role);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: selected,
                          onChanged: _submitting
                              ? null
                              : (value) => _toggleSite(site, value ?? false),
                          title: Text(site.nameEn),
                          subtitle: Text(
                            '${site.displayZoneName} · ${site.typeLabel(isAr: false)}'
                            '${site.location != null ? ' · ${site.location}' : ''}',
                          ),
                          secondary: site.isActive
                              ? null
                              : const Icon(Icons.block, size: 18),
                        ),
                        if (selected)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Read'),
                                    value: perms.canRead,
                                    onChanged: _submitting
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _sitePermissions[site.id] = (
                                                canRead: value,
                                                canWrite:
                                                    perms.canWrite && value,
                                              );
                                            });
                                          },
                                  ),
                                ),
                                Expanded(
                                  child: SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Write'),
                                    value: perms.canWrite,
                                    onChanged: _submitting || !perms.canRead
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _sitePermissions[site.id] = (
                                                canRead: perms.canRead,
                                                canWrite: value,
                                              );
                                            });
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                enabled: !_submitting,
                decoration: catalogFieldDecoration(
                  labelText: 'Approval note (optional)',
                ),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Approve'),
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
