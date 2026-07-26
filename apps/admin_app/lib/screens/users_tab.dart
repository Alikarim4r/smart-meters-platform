import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/preferences_providers.dart';
import '../providers/user_providers.dart';
import '../utils/user_validation.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/user_widgets.dart';
import 'user_approval_dialog.dart';
import 'user_create_screen.dart';
import 'user_detail_screen.dart';

class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});

  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    ref.read(userSearchQueryProvider.notifier).state = _searchController.text;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(usersProvider);
    ref.invalidate(pendingUsersProvider);
  }

  Future<void> _openUserDetail(AdminUser user) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserDetailScreen(userId: user.profile.id),
      ),
    );
    await _refresh();
  }

  Future<void> _openApproveDialog(AdminUser user) async {
    final approved = await showUserApprovalDialog(context, user: user);
    if (approved == true) {
      await _refresh();
    }
  }

  Future<void> _rejectUser(AdminUser user) async {
    final isAr = ref.read(adminLocaleProvider).languageCode == 'ar';
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAr ? 'رفض الحساب؟' : 'Reject user?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAr
                  ? 'رفض ${user.displayName}؟ لن يحصل على صلاحيات.'
                  : 'Reject ${user.displayName}? They will not receive site access.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: catalogFieldDecoration(
                labelText: isAr ? 'ملاحظة (اختياري)' : 'Note (optional)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(isAr ? 'رفض' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم رفض الحساب' : 'User rejected')),
      );
      await _refresh();
    } catch (error) {
      noteController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUserAdminError(error))));
    }
  }

  String _bucketLabel(UserAppBucketFilter bucket, AdminStrings s, bool isAr) {
    switch (bucket) {
      case UserAppBucketFilter.all:
        return isAr ? 'الكل' : 'All';
      case UserAppBucketFilter.pending:
        return isAr ? 'طلبات جديدة' : 'New requests';
      case UserAppBucketFilter.adminApp:
        return isAr ? 'تطبيق الأدمن' : 'Admin app';
      case UserAppBucketFilter.entryApp:
        return isAr ? 'تطبيق الإدخال' : 'Entry app';
      case UserAppBucketFilter.dashboardApp:
        return isAr ? 'تطبيق العرض' : 'Dashboard app';
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final approvalFilter = ref.watch(userApprovalFilterProvider);
    final roleFilter = ref.watch(userRoleFilterProvider);
    final appBucket = ref.watch(userAppBucketFilterProvider);
    final searchQuery = ref.watch(userSearchQueryProvider);
    final canManage = ref.watch(canManageUsersProvider);
    final isSuperAdmin = ref.watch(authProvider).profile?.isSuperAdmin ?? false;
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final isAr = ref.watch(adminLocaleProvider).languageCode == 'ar';
    final listBottomPadding = catalogListBottomPadding(context);

    return Scaffold(
      primary: false,
      floatingActionButton: isSuperAdmin
          ? FloatingActionButton.extended(
              heroTag: 'admin_fab_users',
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const UserCreateScreen()),
                );
                if (created == true) await _refresh();
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(s.addUser),
            )
          : null,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => UserEmptyState(
              title: isAr ? 'تعذر تحميل الحسابات' : 'Could not load users',
              subtitle: friendlyUserAdminError(error),
              icon: Icons.error_outline,
            ),
            data: (allUsers) {
              final pendingCount = allUsers
                  .where(
                    (u) => u.profile.approvalStatus == ApprovalStatus.pending,
                  )
                  .length;

              var users = filterUsersByAppBucket(
                users: allUsers,
                filter: appBucket,
              );
              users = filterUsersByApproval(
                users: users,
                filter: approvalFilter,
              );
              users = filterUsersByRole(users: users, filter: roleFilter);
              users = searchUsers(users, searchQuery);

              // Group by permission role inside the current bucket.
              final byRole = <UserRole, List<AdminUser>>{};
              for (final user in users) {
                byRole
                    .putIfAbsent(user.profile.role, () => <AdminUser>[])
                    .add(user);
              }
              final isOwner =
                  ref.watch(authProvider).profile?.isPlatformOwner ?? false;
              final roleOrder = [
                UserRole.technicianRequest,
                if (isOwner) UserRole.superAdmin,
                UserRole.siteAdmin,
                UserRole.technician,
                UserRole.viewer,
              ];

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: catalogFieldDecoration(
                          labelText: s.search,
                          hintText: s.searchUsers,
                        ).copyWith(prefixIcon: const Icon(Icons.search)),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        isAr
                            ? 'تصنيف حسب التطبيق'
                            : 'Category by app',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          for (final bucket in UserAppBucketFilter.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  bucket == UserAppBucketFilter.pending &&
                                          pendingCount > 0
                                      ? '${_bucketLabel(bucket, s, isAr)} ($pendingCount)'
                                      : _bucketLabel(bucket, s, isAr),
                                ),
                                selected: appBucket == bucket,
                                onSelected: (_) =>
                                    ref
                                            .read(
                                              userAppBucketFilterProvider
                                                  .notifier,
                                            )
                                            .state =
                                        bucket,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          for (final filter in [
                            UserApprovalFilter.all,
                            UserApprovalFilter.pending,
                            UserApprovalFilter.approved,
                            UserApprovalFilter.rejected,
                            UserApprovalFilter.suspended,
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(_approvalFilterLabel(filter, s)),
                                selected: approvalFilter == filter,
                                onSelected: (_) =>
                                    ref
                                            .read(
                                              userApprovalFilterProvider
                                                  .notifier,
                                            )
                                            .state =
                                        filter,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: DropdownButtonFormField<UserRoleFilter>(
                        initialValue: roleFilter,
                        isExpanded: true,
                        decoration: catalogFieldDecoration(
                          labelText: isAr
                              ? 'تصفية الصلاحية'
                              : s.roleFilter,
                          hintText: s.allRoles,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: UserRoleFilter.all,
                            child: Text(s.allRoles),
                          ),
                          DropdownMenuItem(
                            value: UserRoleFilter.technicianRequest,
                            child: Text(s.roleTechnicianRequest),
                          ),
                          DropdownMenuItem(
                            value: UserRoleFilter.technician,
                            child: Text(s.roleTechnician),
                          ),
                          DropdownMenuItem(
                            value: UserRoleFilter.viewer,
                            child: Text(s.roleViewer),
                          ),
                          DropdownMenuItem(
                            value: UserRoleFilter.siteAdmin,
                            child: Text(s.roleSiteAdmin),
                          ),
                          if (ref.watch(authProvider).profile?.isPlatformOwner ??
                              false)
                            DropdownMenuItem(
                              value: UserRoleFilter.superAdmin,
                              child: Text(s.roleSuperAdmin),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(userRoleFilterProvider.notifier).state =
                                value;
                          }
                        },
                      ),
                    ),
                  ),
                  if (users.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: UserEmptyState(
                        title: isAr ? 'لا توجد حسابات' : 'No users found',
                        subtitle: isAr
                            ? 'جرّب تغيير التصنيف أو البحث'
                            : 'Try another category or search',
                        icon: Icons.people_outline,
                      ),
                    )
                  else
                    for (final role in roleOrder)
                      if ((byRole[role] ?? const <AdminUser>[]).isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userRoleLabel(role),
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userRolePermissionHint(role, isAr: isAr),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate((context, i) {
                            final user = byRole[role]![i];
                            final isPending =
                                user.profile.approvalStatus ==
                                ApprovalStatus.pending;
                            return UserListTileCard(
                              user: user,
                              onTap: () => _openUserDetail(user),
                              subtitleExtra: isPending && canManage
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          isAr
                                              ? user.profile.role
                                                    .registrationSourceLabelAr
                                              : user.profile.role
                                                    .registrationSourceLabelEn,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton.icon(
                                                onPressed: () =>
                                                    _openApproveDialog(user),
                                                icon: const Icon(
                                                  Icons.check,
                                                  size: 18,
                                                ),
                                                label: Text(s.approve),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _rejectUser(user),
                                                icon: Icon(
                                                  Icons.close,
                                                  size: 18,
                                                  color: Colors.red.shade700,
                                                ),
                                                label: Text(
                                                  s.reject,
                                                  style: TextStyle(
                                                    color: Colors.red.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : null,
                            );
                          }, childCount: byRole[role]!.length),
                        ),
                      ],
                  SliverToBoxAdapter(
                    child: SizedBox(height: listBottomPadding + 72),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _approvalFilterLabel(UserApprovalFilter filter, AdminStrings s) {
    switch (filter) {
      case UserApprovalFilter.all:
        return s.all;
      case UserApprovalFilter.pending:
        return s.pendingApprovals;
      case UserApprovalFilter.approved:
        return s.approved;
      case UserApprovalFilter.rejected:
        return s.rejected;
      case UserApprovalFilter.suspended:
        return s.suspended;
      case UserApprovalFilter.active:
        return s.active;
      case UserApprovalFilter.inactive:
        return s.inactive;
    }
  }
}
