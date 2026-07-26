import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';
import '../models/user_scope_assignment.dart';
import '../models/user_site_access.dart';

class UserAdminRepository {
  UserAdminRepository(this._client);

  final SupabaseClient _client;

  static const _profileSelect = '*, user_site_access(count)';
  static const _accessSelect = '*, sites(*, zones(*))';
  static const _scopeSelect = '*, roles(*)';

  /// Maps legacy [UserRole] to RBAC role code for scope assignments.
  static String scopeRoleCodeFor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'system_admin';
      case UserRole.siteAdmin:
        return 'site_admin';
      case UserRole.technician:
      case UserRole.technicianRequest:
        return 'reading_entry';
      case UserRole.viewer:
        return 'viewer';
    }
  }

  Future<List<AdminUser>> getUsersForAdmin() async {
    final rows = await _client
        .from('profiles')
        .select(_profileSelect)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => AdminUser.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<AdminUser>> getPendingUsers() async {
    final rows = await _client
        .from('profiles')
        .select(_profileSelect)
        .eq('approval_status', ApprovalStatus.pending.dbValue)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => AdminUser.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<AdminUser> getUserById(String userId) async {
    final row = await _client
        .from('profiles')
        .select(_profileSelect)
        .eq('id', userId)
        .single();

    return AdminUser.fromJson(Map<String, dynamic>.from(row));
  }

  /// Creates a ready-to-login user (super_admin only). Returns the user id.
  /// The profile starts pending — call [approveUser] to grant role + sites.
  Future<String> createUser({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final result = await _client.rpc(
      'admin_create_user',
      params: {
        'p_email': email,
        'p_password': password,
        'p_full_name': fullName,
      },
    );
    return result as String;
  }

  /// Toggles per-user permission to enter readings for past dates.
  Future<void> setAllowBackdatedReadings({
    required String userId,
    required bool allowed,
  }) async {
    await _client.rpc(
      'admin_set_backdate_permission',
      params: {'p_user_id': userId, 'p_allowed': allowed},
    );
  }

  Future<void> approveUser({
    required String userId,
    required UserRole role,
    required List<String> siteIds,
    String? note,
  }) async {
    await _client.rpc(
      'admin_approve_user',
      params: {
        'p_user_id': userId,
        'p_role': role.dbValue,
        'p_site_ids': siteIds,
        'p_note': note,
      },
    );
  }

  Future<void> rejectUser({required String userId, String? note}) async {
    await _client.rpc(
      'admin_reject_user',
      params: {'p_user_id': userId, 'p_note': note},
    );
  }

  Future<void> suspendUser({required String userId, String? note}) async {
    await _client.rpc(
      'admin_suspend_user',
      params: {'p_user_id': userId, 'p_note': note},
    );
  }

  /// Super-admin only: permanently delete auth user + profile.
  Future<void> deleteUser({required String userId}) async {
    await _client.rpc('admin_delete_user', params: {'p_user_id': userId});
  }

  Future<List<UserSiteAccess>> getUserSiteAccess(String userId) async {
    final rows = await _client
        .from('user_site_access')
        .select(_accessSelect)
        .eq('user_id', userId)
        .order('created_at');

    return (rows as List)
        .map(
          (row) =>
              UserSiteAccess.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<UserSiteAccess> addUserSiteAccess({
    required String userId,
    required String siteId,
    required UserRole role,
    required bool canRead,
    required bool canWrite,
  }) async {
    final payload =
        UserSiteAccess(
          id: '',
          userId: userId,
          siteId: siteId,
          role: role,
          canRead: canRead,
          canWrite: canWrite,
          canManageMeters: role == UserRole.siteAdmin,
          createdAt: DateTime.now(),
        ).toInsertJson(
          userId: userId,
          siteId: siteId,
          role: role,
          canRead: canRead,
          canWrite: canWrite,
        );

    final row = await _client
        .from('user_site_access')
        .insert(payload)
        .select(_accessSelect)
        .single();

    return UserSiteAccess.fromJson(Map<String, dynamic>.from(row));
  }

  Future<UserSiteAccess> updateUserSiteAccess({
    required String accessId,
    required bool canRead,
    required bool canWrite,
    required UserRole role,
  }) async {
    final payload = {
      'can_read': canRead,
      'can_write': canWrite,
      'can_manage_meters': role == UserRole.siteAdmin,
    };

    final row = await _client
        .from('user_site_access')
        .update(payload)
        .eq('id', accessId)
        .select(_accessSelect)
        .single();

    return UserSiteAccess.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> removeUserSiteAccess(String accessId) async {
    await _client.from('user_site_access').delete().eq('id', accessId);
  }

  /// Upserts assignments for an approved user (skips duplicates via DB constraint).
  Future<void> replaceUserSiteAssignments({
    required String userId,
    required UserRole role,
    required Map<String, ({bool canRead, bool canWrite})> sitePermissions,
  }) async {
    for (final entry in sitePermissions.entries) {
      final perms = entry.value;
      await _client.from('user_site_access').upsert({
        'user_id': userId,
        'site_id': entry.key,
        'role': role.dbValue,
        'can_read': perms.canRead,
        'can_write': perms.canWrite,
        'can_manage_meters': role == UserRole.siteAdmin,
      }, onConflict: 'user_id,site_id');
    }
  }

  Future<List<AppRole>> getRoles({bool activeOnly = true}) async {
    var query = _client.from('roles').select();
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('sort_order');
    return (rows as List)
        .map((row) => AppRole.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<AppRole?> getRoleByCode(String code) async {
    final row = await _client
        .from('roles')
        .select()
        .eq('code', code)
        .maybeSingle();
    if (row == null) return null;
    return AppRole.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<UserScopeAssignment>> getUserScopeAssignments(
    String userId,
  ) async {
    final rows = await _client
        .from('user_scope_assignments')
        .select(_scopeSelect)
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at');

    return (rows as List)
        .map(
          (row) => UserScopeAssignment.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  /// Creates an org XOR zone XOR site scope assignment.
  Future<UserScopeAssignment> assignUserScope({
    required String userId,
    required String roleId,
    String? organizationId,
    String? zoneId,
    String? siteId,
    bool inheritChildren = true,
  }) async {
    final scoped = [
      if (organizationId != null) 1,
      if (zoneId != null) 1,
      if (siteId != null) 1,
    ];
    if (scoped.length != 1) {
      throw ArgumentError(
        'Exactly one of organizationId, zoneId, siteId is required',
      );
    }

    final row = await _client
        .from('user_scope_assignments')
        .insert({
          'user_id': userId,
          'role_id': roleId,
          'organization_id': organizationId,
          'zone_id': zoneId,
          'site_id': siteId,
          'inherit_children': inheritChildren,
          'status': 'active',
        })
        .select(_scopeSelect)
        .single();

    // Dual-layer: also mirror site-level scopes into user_site_access.
    if (siteId != null) {
      final roleCode = (row['roles'] is Map)
          ? (row['roles'] as Map)['code'] as String?
          : null;
      final legacyRole = switch (roleCode) {
        'site_admin' ||
        'org_admin' ||
        'zone_admin' ||
        'system_admin' => UserRole.siteAdmin,
        'viewer' || 'auditor' => UserRole.viewer,
        _ => UserRole.technician,
      };
      await _client.from('user_site_access').upsert({
        'user_id': userId,
        'site_id': siteId,
        'role': legacyRole.dbValue,
        'can_read': true,
        'can_write': legacyRole != UserRole.viewer,
        'can_manage_meters': legacyRole == UserRole.siteAdmin,
      }, onConflict: 'user_id,site_id');
    }

    return UserScopeAssignment.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deactivateUserScope(String assignmentId) async {
    await _client
        .from('user_scope_assignments')
        .update({'status': 'inactive'})
        .eq('id', assignmentId);
  }
}
