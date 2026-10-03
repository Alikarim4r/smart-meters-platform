import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/preferences_providers.dart';
import '../providers/user_providers.dart';
import '../utils/delete_confirmations.dart';
import '../utils/user_validation.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/user_widgets.dart';
import 'user_approval_dialog.dart';
import 'user_site_assignment_screen.dart';

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(userDetailsProvider(userId));
    ref.invalidate(userSiteAccessProvider(userId));
    ref.invalidate(usersProvider);
    ref.invalidate(pendingUsersProvider);
  }

  Future<void> _rejectUser(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
  ) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(adminText(context, 'Reject user?', 'رفض المستخدم؟')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reject ${user.displayName}?'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: catalogFieldDecoration(
                labelText: adminText(
                  context,
                  'Note (optional)',
                  'ملاحظة (اختياري)',
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(adminText(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(adminText(context, 'Reject', 'رفض')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      noteController.dispose();
      return;
    }

    try {
      await ref
          .read(userAdminRepositoryProvider)
          .rejectUser(
            userId: user.profile.id,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
          );
      noteController.dispose();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(adminText(context, 'User rejected', 'تم رفض المستخدم')),
        ),
      );
      await _refresh(ref);
    } catch (error) {
      noteController.dispose();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUserAdminError(error))));
    }
  }

  Future<void> _suspendUser(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
  ) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(adminText(context, 'Suspend user?', 'تعليق المستخدم؟')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Suspend ${user.displayName}? They will lose access to app data.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: catalogFieldDecoration(
                labelText: adminText(
                  context,
                  'Note (optional)',
                  'ملاحظة (اختياري)',
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(adminText(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: Text(adminText(context, 'Suspend', 'تعليق')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      noteController.dispose();
      return;
    }

    try {
      await ref
          .read(userAdminRepositoryProvider)
          .suspendUser(
            userId: user.profile.id,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
          );
      noteController.dispose();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            adminText(context, 'User suspended', 'تم تعليق المستخدم'),
          ),
        ),
      );
      await _refresh(ref);
    } catch (error) {
      noteController.dispose();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUserAdminError(error))));
    }
  }

  Future<void> _deleteUser(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
  ) async {
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final confirmed = await confirmForceDelete(
      context: context,
      title: s.deleteUserTitle,
      entityName: user.displayName,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(userAdminRepositoryProvider)
          .deleteUser(userId: user.profile.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${user.displayName} deleted')));
      ref.invalidate(usersProvider);
      ref.invalidate(pendingUsersProvider);
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUserAdminError(error))));
    }
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
  ) async {
    final actor = ref.read(authProvider).profile!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    var selected = user.profile.role == UserRole.technicianRequest
        ? UserRole.technician
        : user.profile.role;
    final confirmed = await showDialog<UserRole>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final items = <DropdownMenuItem<UserRole>>[
              DropdownMenuItem(
                value: UserRole.technician,
                child: Text(userRoleLabel(UserRole.technician)),
              ),
              DropdownMenuItem(
                value: UserRole.viewer,
                child: Text(userRoleLabel(UserRole.viewer)),
              ),
              DropdownMenuItem(
                value: UserRole.siteAdmin,
                child: Text(userRoleLabel(UserRole.siteAdmin)),
              ),
              if (actor.isPlatformOwner)
                DropdownMenuItem(
                  value: UserRole.superAdmin,
                  child: Text(userRoleLabel(UserRole.superAdmin)),
                ),
            ];
            return AlertDialog(
              title: Text(isAr ? 'تعديل الصلاحية' : 'Change role'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<UserRole>(
                    initialValue: selected,
                    items: items,
                    onChanged: (v) {
                      if (v != null) setLocal(() => selected = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(userRolePermissionHint(selected, isAr: isAr)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isAr ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: Text(isAr ? 'حفظ' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed == null || !context.mounted) return;
    try {
      await ref
          .read(userAdminRepositoryProvider)
          .changeUserRole(userId: user.profile.id, role: confirmed);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم تحديث الصلاحية' : 'Role updated')),
      );
      await _refresh(ref);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUserAdminError(error))));
    }
  }

  Future<void> _removeAssignment(
    BuildContext context,
    WidgetRef ref,
    UserSiteAccess access,
  ) async {
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

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(userAdminRepositoryProvider)
          .removeUserSiteAccess(access.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            adminText(
              context,
              'Site assignment removed',
              'تمت إزالة تعيين الموقع',
            ),
          ),
        ),
      );
      await _refresh(ref);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUserAdminError(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDetailsProvider(userId));
    final accessAsync = ref.watch(userSiteAccessProvider(userId));
    final actor = ref.watch(authProvider).profile!;
    final canManage = ref.watch(canManageUsersProvider);
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    return Scaffold(
      appBar: AppBar(
        title: userAsync.maybeWhen(
          data: (user) => Text(user.displayName),
          orElse: () =>
              Text(adminText(context, 'User details', 'تفاصيل المستخدم')),
        ),
        actions: [
          IconButton(
            tooltip: adminText(context, 'Refresh', 'تحديث'),
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
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
            icon: Icons.error_outline,
          ),
          data: (user) {
            final profile = user.profile;
            final showActions = canManage && canManageUserActions(actor, user);

            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      UserRoleBadge(role: profile.role),
                      ApprovalStatusBadge(status: profile.approvalStatus),
                      ActiveStatusBadge(isActive: profile.isActive),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(label: 'Email', value: profile.email),
                  _InfoRow(
                    label: 'Display name',
                    value: profile.fullName.trim().isEmpty
                        ? '—'
                        : profile.fullName,
                  ),
                  _InfoRow(
                    label: 'Created',
                    value: formatAdminDateTime(profile.createdAt),
                  ),
                  if (profile.approvedAt != null)
                    _InfoRow(
                      label: 'Approved',
                      value: formatAdminDateTime(profile.approvedAt),
                    ),
                  if (profile.rejectedAt != null)
                    _InfoRow(
                      label: 'Rejected',
                      value: formatAdminDateTime(profile.rejectedAt),
                    ),
                  if (profile.approvalNote != null &&
                      profile.approvalNote!.trim().isNotEmpty)
                    _InfoRow(label: 'Note', value: profile.approvalNote!),
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.history_outlined),
                      title: Text(s.allowBackdated),
                      subtitle: Text(s.allowBackdatedHint),
                      value: profile.allowBackdatedReadings,
                      onChanged: actor.isSuperAdmin
                          ? (value) async {
                              try {
                                await ref
                                    .read(userAdminRepositoryProvider)
                                    .setAllowBackdatedReadings(
                                      userId: profile.id,
                                      allowed: value,
                                    );
                                await _refresh(ref);
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      friendlyUserAdminError(error),
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(adminText(context, 'Site assignments', 'تعيينات المواقع'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (showActions && canEditSiteAssignments(user))
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    UserSiteAssignmentScreen(userId: userId),
                              ),
                            );
                            await _refresh(ref);
                          },
                          icon: const Icon(Icons.edit_location_alt_outlined),
                          label: Text(adminText(context, 'Manage', 'إدارة')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  accessAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text(friendlyUserAdminError(error)),
                    data: (assignments) {
                      if (assignments.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            adminText(
                              context,
                              'No site assignments yet.',
                              'لا توجد تعيينات مواقع بعد.',
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final access in assignments)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  access.site?.nameEn ?? 'Unknown site',
                                ),
                                subtitle: Text(
                                  '${access.site?.displayZoneName ?? kNoZoneLabel}'
                                  '${access.site?.location != null ? ' · ${access.site!.location}' : ''}',
                                ),
                                trailing:
                                    showActions && canEditSiteAssignments(user)
                                    ? IconButton(
                                        tooltip: adminText(
                                          context,
                                          'Remove',
                                          'إزالة',
                                        ),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.shade700,
                                        ),
                                        onPressed: () => _removeAssignment(
                                          context,
                                          ref,
                                          access,
                                        ),
                                      )
                                    : null,
                                isThreeLine: true,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (showActions) ...[
                    const SizedBox(height: 24),
                    if (profile.approvalStatus == ApprovalStatus.pending) ...[
                      FilledButton.icon(
                        onPressed: () async {
                          final approved = await showUserApprovalDialog(
                            context,
                            user: user,
                          );
                          if (approved == true) {
                            await _refresh(ref);
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: Text(
                          adminText(context, 'Approve user', 'اعتماد المستخدم'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _rejectUser(context, ref, user),
                        icon: Icon(Icons.close, color: Colors.red.shade700),
                        label: Text(adminText(context, 'Reject user', 'رفض المستخدم'),
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                    if (profile.approvalStatus == ApprovalStatus.approved &&
                        profile.isActive)
                      OutlinedButton.icon(
                        onPressed: () => _suspendUser(context, ref, user),
                        icon: const Icon(Icons.pause_circle_outline),
                        label: Text(
                          adminText(context, 'Suspend user', 'تعليق المستخدم'),
                        ),
                      ),
                    if (profile.approvalStatus == ApprovalStatus.suspended)
                      FilledButton.icon(
                        onPressed: () async {
                          final approved = await showUserApprovalDialog(
                            context,
                            user: user,
                          );
                          if (approved == true) {
                            await _refresh(ref);
                          }
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: Text(
                          adminText(
                            context,
                            'Re-approve user',
                            'إعادة اعتماد المستخدم',
                          ),
                        ),
                      ),
                    if (canChangeUserRole(actor, user) &&
                        profile.approvalStatus == ApprovalStatus.approved) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _changeRole(context, ref, user),
                        icon: const Icon(Icons.manage_accounts_outlined),
                        label: Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'تعديل الصلاحية'
                              : 'Change role / permissions',
                        ),
                      ),
                    ],
                    if (canDeleteUserAccount(actor, user)) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _deleteUser(context, ref, user),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: Text(s.forceDelete),
                      ),
                    ],
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
