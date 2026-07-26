import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/preferences_providers.dart';
import '../providers/user_providers.dart';
import '../widgets/catalog_widgets.dart';
import 'user_create_screen.dart';

/// Hierarchy:
/// - Organization (owner only): assign Super Admins across apps.
/// - Zone (owner / super_admin): assign regular Admins + entry/dashboard.
/// - Site (owner / super / site_admin): assign entry technicians + dashboard viewers;
///   site-level admins only by owner/super.
class ScopeControlScreen extends ConsumerStatefulWidget {
  const ScopeControlScreen({
    super.key,
    required this.kind,
    required this.title,
    this.organizationId,
    this.zoneId,
    this.siteId,
  });

  final ScopeKind kind;
  final String title;
  final String? organizationId;
  final String? zoneId;
  final String? siteId;

  @override
  ConsumerState<ScopeControlScreen> createState() => _ScopeControlScreenState();
}

class _ScopeControlScreenState extends ConsumerState<ScopeControlScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<ScopeAssignee> _all = const [];
  bool _loading = true;
  String? _error;

  AppAccessCategory? _assignPickerApp;
  final _assignSearch = TextEditingController();

  static const _apps = [
    AppAccessCategory.dashboard,
    AppAccessCategory.admin,
    AppAccessCategory.entry,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _apps.length, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      if (_assignPickerApp != null) {
        setState(() {
          _assignPickerApp = null;
          _assignSearch.clear();
        });
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _assignSearch.dispose();
    super.dispose();
  }

  Profile? get _me => ref.read(authProvider).profile;
  bool get _isOwner => _me?.isPlatformOwner ?? false;
  bool get _isSuper => _me?.isSuperAdmin ?? false;
  bool get _isSiteAdmin => _me?.isSiteAdmin ?? false;

  /// Owner: org super-admins. Super: zone regular admins. Site admins: not on Admin tab.
  bool get _canAssignOnAdminTab {
    return switch (widget.kind) {
      ScopeKind.organization => _isOwner,
      ScopeKind.zone => _isOwner || _isSuper,
      ScopeKind.site => _isOwner || _isSuper,
    };
  }

  bool get _canAssignOnEntryOrDashboard {
    return _isOwner || _isSuper || _isSiteAdmin;
  }

  ({String? organizationId, String? zoneId, String? siteId}) get _rpcScope {
    return switch (widget.kind) {
      ScopeKind.organization => (
        organizationId: widget.organizationId,
        zoneId: null,
        siteId: null,
      ),
      ScopeKind.zone => (
        organizationId: null,
        zoneId: widget.zoneId,
        siteId: null,
      ),
      ScopeKind.site => (
        organizationId: null,
        zoneId: null,
        siteId: widget.siteId,
      ),
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = _rpcScope;
      final rows = await ref
          .read(userAdminRepositoryProvider)
          .listScopeAssigneesAt(
            organizationId: scope.organizationId,
            zoneId: scope.zoneId,
            siteId: scope.siteId,
          );
      if (!mounted) return;
      setState(() {
        // Owner never listed — automatic full access.
        _all = rows
            .where((a) => !isPlatformOwnerEmail(a.email))
            .toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  UserRole _createRoleForApp(AppAccessCategory app) {
    return switch (app) {
      AppAccessCategory.admin => switch (widget.kind) {
        ScopeKind.organization => UserRole.superAdmin,
        ScopeKind.zone || ScopeKind.site => UserRole.siteAdmin,
      },
      AppAccessCategory.entry => UserRole.technician,
      AppAccessCategory.dashboard => UserRole.viewer,
    };
  }

  List<ScopeAssignee> _forApp(AppAccessCategory app) {
    return _all.where((a) {
      final code = a.scopeRoleCode;
      final profile = a.profileRole;
      return switch (app) {
        AppAccessCategory.admin => switch (widget.kind) {
          ScopeKind.organization =>
            code == 'system_admin' ||
                code == 'org_admin' ||
                profile == 'super_admin',
          ScopeKind.zone || ScopeKind.site =>
            code == 'zone_admin' ||
                code == 'site_admin' ||
                code == 'org_admin' ||
                code == 'system_admin' ||
                profile == 'site_admin' ||
                profile == 'super_admin',
        },
        AppAccessCategory.entry =>
          code == 'reading_entry' ||
              code == 'meter_manager' ||
              profile == 'technician',
        // Dashboard tab: viewers only (admins appear under Admin tab).
        AppAccessCategory.dashboard =>
          code == 'viewer' ||
              code == 'auditor' ||
              profile == 'viewer',
      };
    }).toList();
  }

  bool _matchesAssignPool(AdminUser user, AppAccessCategory app) {
    if (!user.profile.isApprovedForAccess) return false;
    if (isPlatformOwnerEmail(user.profile.email)) return false;
    final role = user.profile.role;
    return switch (app) {
      AppAccessCategory.admin => switch (widget.kind) {
        // Owner assigns Super Admins only.
        ScopeKind.organization => role == UserRole.superAdmin,
        // Super Admin assigns regular Admins only (never other Super Admins).
        ScopeKind.zone || ScopeKind.site => role == UserRole.siteAdmin,
      },
      AppAccessCategory.entry => role == UserRole.technician,
      AppAccessCategory.dashboard => role == UserRole.viewer,
    };
  }

  bool _canOpenAssignPicker(AppAccessCategory app) {
    return switch (app) {
      AppAccessCategory.admin => _canAssignOnAdminTab,
      AppAccessCategory.entry ||
      AppAccessCategory.dashboard => _canAssignOnEntryOrDashboard,
    };
  }

  List<AdminUser> _assignCandidates(AppAccessCategory app) {
    final users = ref.read(usersProvider).valueOrNull ?? const <AdminUser>[];
    final assignedIds = _forApp(app).map((a) => a.userId).toSet();
    final q = _assignSearch.text.trim().toLowerCase();
    return users.where((u) {
      if (!_matchesAssignPool(u, app)) return false;
      if (assignedIds.contains(u.profile.id)) return false;
      if (q.isEmpty) return true;
      return u.displayName.toLowerCase().contains(q) ||
          u.profile.email.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _register(AppAccessCategory app) async {
    if (!_canOpenAssignPicker(app)) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserCreateScreen(
          lockedRole: _createRoleForApp(app),
          lockedScopeKind: widget.kind,
          initialOrganizationId: widget.organizationId,
          initialZoneId: widget.zoneId,
          initialSiteId: widget.siteId,
          lockScopeSelection: true,
        ),
      ),
    );
    if (created == true) await _load();
  }

  void _toggleAssignPicker(AppAccessCategory app) {
    if (!_canOpenAssignPicker(app)) return;
    setState(() {
      if (_assignPickerApp == app) {
        _assignPickerApp = null;
        _assignSearch.clear();
      } else {
        _assignPickerApp = app;
        _assignSearch.clear();
        ref.invalidate(usersProvider);
      }
    });
  }

  Future<void> _assignUser(AdminUser selected, AppAccessCategory app) async {
    try {
      final repo = ref.read(userAdminRepositoryProvider);
      final role = _createRoleForApp(app);
      final scopeRole = await repo.getRoleByCode(
        UserAdminRepository.scopeRoleCodeFor(role, kind: widget.kind),
      );
      if (scopeRole == null) {
        throw StateError('Scope role not found');
      }
      await repo.assignUserScope(
        userId: selected.profile.id,
        roleId: scopeRole.id,
        organizationId: widget.kind == ScopeKind.organization
            ? widget.organizationId
            : null,
        zoneId: widget.kind == ScopeKind.zone ? widget.zoneId : null,
        siteId: widget.kind == ScopeKind.site ? widget.siteId : null,
        inheritChildren: widget.kind != ScopeKind.site,
      );
      if (!mounted) return;
      setState(() {
        _assignPickerApp = null;
        _assignSearch.clear();
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _remove(ScopeAssignee assignee, AdminStrings s) async {
    if (!assignee.isDirect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.inheritedAccessCannotRemoveHere)),
      );
      return;
    }
    // Non-owners cannot remove super-admin / org-level grants.
    if (!_isOwner &&
        (assignee.profileRole == 'super_admin' ||
            assignee.scopeRoleCode == 'system_admin' ||
            assignee.scopeRoleCode == 'org_admin')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.onlyOwnerManagesSuperAdmins)),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.removeScopeAccess),
        content: Text(assignee.displayName(isAr: s.isAr)),
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
    if (ok != true) return;
    try {
      await ref
          .read(userAdminRepositoryProvider)
          .deactivateUserScope(assignee.assignmentId);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  String _assignPoolHint(AdminStrings s, AppAccessCategory app) {
    if (app == AppAccessCategory.admin) {
      return switch (widget.kind) {
        ScopeKind.organization => s.assignSuperAdminsHint,
        ScopeKind.zone || ScopeKind.site => s.assignAdminsHint,
      };
    }
    if (app == AppAccessCategory.entry) return s.assignTechniciansHint;
    return s.assignViewersHint;
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    ref.watch(usersProvider);

    // Org control is owner-only.
    if (widget.kind == ScopeKind.organization && !_isOwner) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(child: Text(s.onlyOwnerManagesSuperAdmins)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            for (final app in _apps)
              Tab(text: appAccessCategoryLabel(app, isAr: s.isAr)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? CatalogErrorView(message: _error!, onRetry: _load)
          : TabBarView(
              controller: _tabs,
              children: [
                for (final app in _apps)
                  _AppAssigneesPane(
                    strings: s,
                    kind: widget.kind,
                    app: app,
                    assignees: _forApp(app),
                    canAssign: _canOpenAssignPicker(app),
                    showAssignTable: _assignPickerApp == app,
                    assignSearchController: _assignSearch,
                    assignCandidates: _assignPickerApp == app
                        ? _assignCandidates(app)
                        : const [],
                    usersLoading: ref.watch(usersProvider).isLoading,
                    assignPoolHint: _assignPoolHint(s, app),
                    showSearch: widget.kind != ScopeKind.organization,
                    onRegister: () => _register(app),
                    onToggleAssign: () => _toggleAssignPicker(app),
                    onAssignSearchChanged: (_) => setState(() {}),
                    onAssignUser: (u) => _assignUser(u, app),
                    onRemove: (a) => _remove(a, s),
                  ),
              ],
            ),
    );
  }
}

class _AppAssigneesPane extends StatelessWidget {
  const _AppAssigneesPane({
    required this.strings,
    required this.kind,
    required this.app,
    required this.assignees,
    required this.canAssign,
    required this.showAssignTable,
    required this.assignSearchController,
    required this.assignCandidates,
    required this.usersLoading,
    required this.assignPoolHint,
    required this.showSearch,
    required this.onRegister,
    required this.onToggleAssign,
    required this.onAssignSearchChanged,
    required this.onAssignUser,
    required this.onRemove,
  });

  final AdminStrings strings;
  final ScopeKind kind;
  final AppAccessCategory app;
  final List<ScopeAssignee> assignees;
  final bool canAssign;
  final bool showAssignTable;
  final TextEditingController assignSearchController;
  final List<AdminUser> assignCandidates;
  final bool usersLoading;
  final String assignPoolHint;
  final bool showSearch;
  final VoidCallback onRegister;
  final VoidCallback onToggleAssign;
  final ValueChanged<String> onAssignSearchChanged;
  final ValueChanged<AdminUser> onAssignUser;
  final ValueChanged<ScopeAssignee> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ExpansionTile(
          initiallyExpanded: true,
          title: Text(strings.accountsWithPermission),
          children: [
            if (assignees.isEmpty)
              ListTile(
                dense: true,
                title: Text(strings.noAccountsInTab),
              )
            else
              for (final a in assignees)
                ListTile(
                  leading: Icon(
                    a.isDirect
                        ? Icons.person_outline
                        : Icons.account_tree_outlined,
                  ),
                  title: Text(a.displayName(isAr: strings.isAr)),
                  subtitle: Text(
                    [
                      a.email,
                      a.scopeRoleLabel(isAr: strings.isAr),
                      if (!a.isDirect) strings.inheritedAccessLabel,
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: a.isDirect && canAssign
                      ? IconButton(
                          tooltip: strings.removeScopeAccess,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => onRemove(a),
                        )
                      : !a.isDirect
                      ? Tooltip(
                          message: strings.inheritedAccessCannotRemoveHere,
                          child: Icon(
                            Icons.lock_outline,
                            color: scheme.outline,
                          ),
                        )
                      : null,
                ),
            if (canAssign) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: Text(strings.registerNewAccount),
                onTap: onRegister,
              ),
              ListTile(
                leading: Icon(
                  showAssignTable
                      ? Icons.keyboard_arrow_up
                      : Icons.group_add_outlined,
                ),
                title: Text(strings.assignExistingAccount),
                subtitle: Text(assignPoolHint),
                onTap: onToggleAssign,
              ),
              if (showAssignTable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showSearch)
                        TextField(
                          controller: assignSearchController,
                          onChanged: onAssignSearchChanged,
                          decoration: catalogFieldDecoration(
                            labelText: strings.search,
                            hintText: strings.searchUsers,
                          ).copyWith(
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: assignSearchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      assignSearchController.clear();
                                      onAssignSearchChanged('');
                                    },
                                  ),
                          ),
                        ),
                      if (showSearch) const SizedBox(height: 8),
                      if (usersLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (assignCandidates.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(strings.noEligibleAccounts),
                        )
                      else
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: scheme.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 40,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 64,
                              columns: [
                                DataColumn(label: Text(strings.fullName)),
                                DataColumn(label: Text(strings.email)),
                                DataColumn(label: Text(strings.appRole)),
                                DataColumn(
                                  label: Text(strings.assignExistingAccount),
                                ),
                              ],
                              rows: [
                                for (final u in assignCandidates)
                                  DataRow(
                                    cells: [
                                      DataCell(Text(u.displayName)),
                                      DataCell(Text(u.profile.email)),
                                      DataCell(
                                        Text(_roleLabel(u.profile.role, strings)),
                                      ),
                                      DataCell(
                                        FilledButton.tonal(
                                          onPressed: () => onAssignUser(u),
                                          child: Text(strings.assign),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (kind == ScopeKind.zone || kind == ScopeKind.site)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            strings.scopeInheritHint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
            ] else if (app == AppAccessCategory.admin)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  kind == ScopeKind.organization
                      ? strings.onlyOwnerManagesSuperAdmins
                      : strings.adminsAssignedBySuperHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _roleLabel(UserRole role, AdminStrings s) {
    return switch (role) {
      UserRole.superAdmin => s.roleSuperAdmin,
      UserRole.siteAdmin => s.roleSiteAdmin,
      UserRole.technician => s.roleTechnician,
      UserRole.viewer => s.roleViewer,
      UserRole.technicianRequest => s.roleTechnician,
    };
  }
}
