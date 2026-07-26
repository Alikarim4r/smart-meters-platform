import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../providers/zone_providers.dart';
import '../utils/user_validation.dart';
import '../widgets/catalog_widgets.dart';

/// Super-admin flow: create account, approve with app role, assign inherited
/// scope (organization / zone / site) + backdated entry permission.
class UserCreateScreen extends ConsumerStatefulWidget {
  const UserCreateScreen({
    super.key,
    this.lockedRole,
    this.lockedScopeKind,
    this.initialOrganizationId,
    this.initialZoneId,
    this.initialSiteId,
    this.lockScopeSelection = false,
  });

  final UserRole? lockedRole;
  final ScopeKind? lockedScopeKind;
  final String? initialOrganizationId;
  final String? initialZoneId;
  final String? initialSiteId;
  final bool lockScopeSelection;

  @override
  ConsumerState<UserCreateScreen> createState() => _UserCreateScreenState();
}

class _UserCreateScreenState extends ConsumerState<UserCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late UserRole _role;
  bool _allowBackdated = false;
  late ScopeKind _scopeKind;
  String? _organizationId;
  String? _zoneId;
  String? _siteId;
  bool _inheritChildren = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = widget.lockedRole ?? UserRole.technician;
    _scopeKind = widget.lockedScopeKind ??
        (widget.initialSiteId != null
            ? ScopeKind.site
            : widget.initialZoneId != null
            ? ScopeKind.zone
            : ScopeKind.organization);
    _organizationId = widget.initialOrganizationId;
    _zoneId = widget.initialZoneId;
    _siteId = widget.initialSiteId;
    _inheritChildren = _scopeKind != ScopeKind.site;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onScopeKindChanged(ScopeKind kind) {
    if (widget.lockScopeSelection) return;
    setState(() {
      _scopeKind = kind;
      _zoneId = null;
      _siteId = null;
      _inheritChildren = kind != ScopeKind.site;
    });
  }

  Future<void> _submit(AdminStrings s) async {
    if (!_formKey.currentState!.validate()) return;

    final scopeError = validateUserScope(
      kind: _scopeKind,
      organizationId: _organizationId,
      zoneId: _zoneId,
      siteId: _siteId,
    );
    if (scopeError != null) {
      setState(() => _error = scopeError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(userAdminRepositoryProvider);
      final userId = await repo.createUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      );

      // Approve with app gateway role; site rows optional (scopes cover access).
      await repo.approveUser(
        userId: userId,
        role: _role,
        siteIds: _scopeKind == ScopeKind.site && _siteId != null
            ? [_siteId!]
            : const [],
      );

      final scopeRole = await repo.getRoleByCode(
        UserAdminRepository.scopeRoleCodeFor(_role, kind: _scopeKind),
      );
      if (scopeRole == null) {
        throw StateError('Scope role not found for ${_role.dbValue}');
      }

      await repo.assignUserScope(
        userId: userId,
        roleId: scopeRole.id,
        organizationId: _scopeKind == ScopeKind.organization
            ? _organizationId
            : null,
        zoneId: _scopeKind == ScopeKind.zone ? _zoneId : null,
        siteId: _scopeKind == ScopeKind.site ? _siteId : null,
        inheritChildren: _scopeKind == ScopeKind.site
            ? false
            : _inheritChildren,
      );

      if (_allowBackdated) {
        await repo.setAllowBackdatedReadings(userId: userId, allowed: true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.userCreated)));
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
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final orgsAsync = ref.watch(adminOrganizationsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.addUser),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton(
              onPressed: _submitting ? null : () => _submit(s),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.createUser),
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
                title: s.accountSection,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: catalogFieldDecoration(labelText: s.fullName),
                    enabled: !_submitting,
                    textInputAction: TextInputAction.next,
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: catalogFieldDecoration(
                      labelText: '${s.email} *',
                    ),
                    enabled: !_submitting,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty || !email.contains('@')) {
                        return s.invalidEmail;
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration:
                        catalogFieldDecoration(
                          labelText: '${s.password} *',
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                    enabled: !_submitting,
                    obscureText: _obscurePassword,
                    validator: (value) => (value == null || value.length < 8)
                        ? s.passwordTooShort
                        : null,
                  ),
                ],
              ),
              CatalogFormSection(
                title: s.roleAndPermissions,
                children: [
                  DropdownButtonFormField<UserRole>(
                    initialValue: _role,
                    isExpanded: true,
                    decoration: catalogFieldDecoration(labelText: s.appRole),
                    items: [
                      DropdownMenuItem(
                        value: UserRole.technician,
                        child: Text(
                          s.roleTechnician,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: UserRole.viewer,
                        child: Text(
                          s.roleViewer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: UserRole.siteAdmin,
                        child: Text(
                          s.roleSiteAdmin,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((ref.watch(authProvider).profile?.isPlatformOwner ??
                              false) &&
                          (widget.lockedRole == null ||
                              widget.lockedRole == UserRole.superAdmin))
                        DropdownMenuItem(
                          value: UserRole.superAdmin,
                          child: Text(
                            s.roleSuperAdmin,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (_submitting || widget.lockedRole != null)
                        ? null
                        : (value) {
                            if (value != null) setState(() => _role = value);
                          },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.allowBackdated),
                    subtitle: Text(s.allowBackdatedHint),
                    value: _allowBackdated,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _allowBackdated = value),
                  ),
                ],
              ),
              CatalogFormSection(
                title: s.assignScope,
                subtitle: s.assignScopeHint,
                children: [
                  IgnorePointer(
                    ignoring: _submitting || widget.lockScopeSelection,
                    child: SegmentedButton<ScopeKind>(
                      segments: [
                        ButtonSegment(
                          value: ScopeKind.organization,
                          label: Text(s.scopeOrganization),
                        ),
                        ButtonSegment(
                          value: ScopeKind.zone,
                          label: Text(s.scopeZone),
                        ),
                        ButtonSegment(
                          value: ScopeKind.site,
                          label: Text(s.scopeSite),
                        ),
                      ],
                      selected: {_scopeKind},
                      onSelectionChanged: (value) =>
                          _onScopeKindChanged(value.first),
                    ),
                  ),
                  const SizedBox(height: 12),
                  orgsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text(friendlyUserAdminError(error)),
                    data: (orgs) {
                      return DropdownButtonFormField<String>(
                        initialValue: _organizationId,
                        isExpanded: true,
                        decoration: catalogFieldDecoration(
                          labelText: '${s.organization} *',
                          hintText: s.selectOrganization,
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
                        onChanged: (_submitting || widget.lockScopeSelection)
                            ? null
                            : (value) => setState(() {
                                _organizationId = value;
                                _zoneId = null;
                                _siteId = null;
                              }),
                        validator: (value) =>
                            value == null ? s.selectOrganization : null,
                      );
                    },
                  ),
                  if (_organizationId != null &&
                      _scopeKind == ScopeKind.zone) ...[
                    const SizedBox(height: 12),
                    _ZonePicker(
                      organizationId: _organizationId!,
                      zoneId: _zoneId,
                      enabled: !_submitting && !widget.lockScopeSelection,
                      strings: s,
                      onChanged: (id) => setState(() => _zoneId = id),
                    ),
                  ],
                  if (_organizationId != null &&
                      _scopeKind == ScopeKind.site) ...[
                    const SizedBox(height: 12),
                    _SitePicker(
                      organizationId: _organizationId!,
                      siteId: _siteId,
                      enabled: !_submitting && !widget.lockScopeSelection,
                      strings: s,
                      onChanged: (id) => setState(() => _siteId = id),
                    ),
                  ],
                  if (_scopeKind != ScopeKind.site)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.inheritChildren),
                      subtitle: Text(s.inheritChildrenHint),
                      value: _inheritChildren,
                      onChanged:
                          (_submitting || widget.lockScopeSelection)
                          ? null
                          : (value) => setState(() => _inheritChildren = value),
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZonePicker extends ConsumerWidget {
  const _ZonePicker({
    required this.organizationId,
    required this.zoneId,
    required this.enabled,
    required this.strings,
    required this.onChanged,
  });

  final String organizationId;
  final String? zoneId;
  final bool enabled;
  final AdminStrings strings;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(organizationZonesProvider(organizationId));
    return zonesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(friendlyUserAdminError(error)),
      data: (zones) {
        if (zones.isEmpty) {
          return Text(strings.noZonesInOrg);
        }
        return DropdownButtonFormField<String>(
          initialValue: zoneId,
          isExpanded: true,
          decoration: catalogFieldDecoration(
            labelText: '${strings.zone} *',
            hintText: strings.selectZone,
          ),
          items: [
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
          onChanged: enabled ? onChanged : null,
          validator: (value) => value == null ? strings.selectZone : null,
        );
      },
    );
  }
}

class _SitePicker extends ConsumerWidget {
  const _SitePicker({
    required this.organizationId,
    required this.siteId,
    required this.enabled,
    required this.strings,
    required this.onChanged,
  });

  final String organizationId;
  final String? siteId;
  final bool enabled;
  final AdminStrings strings;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(adminSitesProvider);
    return sitesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(friendlyUserAdminError(error)),
      data: (allSites) {
        final orgSites = allSites
            .where(
              (site) => site.isActive && site.organizationId == organizationId,
            )
            .toList();
        if (orgSites.isEmpty) {
          return Text(strings.noActiveSites);
        }
        return DropdownButtonFormField<String>(
          initialValue: siteId,
          isExpanded: true,
          decoration: catalogFieldDecoration(
            labelText: '${strings.site} *',
            hintText: strings.selectSites,
          ),
          items: [
            for (final site in orgSites)
              DropdownMenuItem(
                value: site.id,
                child: Text(
                  '${site.nameEn}${site.zone?.nameEn != null ? ' · ${site.zone!.nameEn}' : ''}',
                ),
              ),
          ],
          onChanged: enabled ? onChanged : null,
          validator: (value) => value == null ? strings.mustSelectSite : null,
        );
      },
    );
  }
}
