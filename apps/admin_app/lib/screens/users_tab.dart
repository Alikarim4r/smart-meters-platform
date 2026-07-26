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
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject user?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reject ${user.displayName}? They will not receive site access.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: catalogFieldDecoration(
                labelText: 'Note (optional)',
                hintText: 'Reason for rejection',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Reject'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User rejected')));
      await _refresh();
    } catch (error) {
      noteController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyUserAdminError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final pendingAsync = ref.watch(pendingUsersProvider);
    final approvalFilter = ref.watch(userApprovalFilterProvider);
    final roleFilter = ref.watch(userRoleFilterProvider);
    final searchQuery = ref.watch(userSearchQueryProvider);
    final canManage = ref.watch(canManageUsersProvider);
    final isSuperAdmin = ref.watch(authProvider).profile?.isSuperAdmin ?? false;
    final s = AdminStrings(ref.watch(adminLocaleProvider));
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
              title: 'Could not load users',
              subtitle: friendlyUserAdminError(error),
              icon: Icons.error_outline,
            ),
            data: (allUsers) {
              var users = filterUsersByApproval(
                users: allUsers,
                filter: approvalFilter,
              );
              users = filterUsersByRole(users: users, filter: roleFilter);
              users = searchUsers(users, searchQuery);

              final showPendingSection =
                  approvalFilter == UserApprovalFilter.all ||
                  approvalFilter == UserApprovalFilter.pending;

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
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          for (final filter in UserApprovalFilter.values)
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
                          labelText: s.roleFilter,
                          hintText: s.allRoles,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: UserRoleFilter.all,
                            child: Text(
                              s.allRoles,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: UserRoleFilter.technicianRequest,
                            child: Text(
                              s.roleTechnicianRequest,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: UserRoleFilter.technician,
                            child: Text(
                              s.roleTechnician,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: UserRoleFilter.viewer,
                            child: Text(
                              s.roleViewer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: UserRoleFilter.siteAdmin,
                            child: Text(
                              s.roleSiteAdmin,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: UserRoleFilter.superAdmin,
                            child: Text(
                              s.roleSuperAdmin,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                  if (showPendingSection)
                    pendingAsync.when(
                      loading: () =>
                          const SliverToBoxAdapter(child: SizedBox.shrink()),
                      error: (_, _) =>
                          const SliverToBoxAdapter(child: SizedBox.shrink()),
                      data: (pendingUsers) {
                        if (pendingUsers.isEmpty ||
                            approvalFilter != UserApprovalFilter.all &&
                                approvalFilter != UserApprovalFilter.pending) {
                          return const SliverToBoxAdapter(
                            child: SizedBox.shrink(),
                          );
                        }
                        final visiblePending =
                            approvalFilter == UserApprovalFilter.pending
                            ? users
                            : pendingUsers;

                        if (visiblePending.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: SizedBox.shrink(),
                          );
                        }

                        return SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  20,
                                  16,
                                  8,
                                ),
                                child: Text(
                                  s.pendingApprovals,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              for (final user in visiblePending)
                                UserListTileCard(
                                  user: user,
                                  onTap: () => _openUserDetail(user),
                                  subtitleExtra: canManage
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
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
                                        )
                                      : null,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (approvalFilter != UserApprovalFilter.pending)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          approvalFilter == UserApprovalFilter.all
                              ? s.allUsers
                              : _approvalFilterLabel(approvalFilter, s),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (users.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: UserEmptyState(
                        title: s.noUsersMatch,
                        subtitle: s.adjustFilters,
                      ),
                    )
                  else if (approvalFilter == UserApprovalFilter.pending)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => UserListTileCard(
                          user: users[index],
                          onTap: () => _openUserDetail(users[index]),
                          subtitleExtra: canManage
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _openApproveDialog(users[index]),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: Text(s.approve),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _rejectUser(users[index]),
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
                                )
                              : null,
                        ),
                        childCount: users.length,
                      ),
                    )
                  else if (approvalFilter != UserApprovalFilter.pending)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final user = users[index];
                        if (user.profile.approvalStatus ==
                            ApprovalStatus.pending) {
                          return const SizedBox.shrink();
                        }
                        return UserListTileCard(
                          user: user,
                          onTap: () => _openUserDetail(user),
                        );
                      }, childCount: users.length),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: listBottomPadding),
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
        return s.filterPending;
      case UserApprovalFilter.approved:
        return s.filterApproved;
      case UserApprovalFilter.rejected:
        return s.filterRejected;
      case UserApprovalFilter.suspended:
        return s.filterSuspended;
      case UserApprovalFilter.active:
        return s.active;
      case UserApprovalFilter.inactive:
        return s.inactive;
    }
  }
}
