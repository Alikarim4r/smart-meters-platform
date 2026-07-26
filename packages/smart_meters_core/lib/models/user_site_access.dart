import 'enums.dart';
import 'profile.dart';
import 'site.dart';

/// Row in `user_site_access` with optional joined site (and zone).
class UserSiteAccess {
  const UserSiteAccess({
    required this.id,
    required this.userId,
    required this.siteId,
    required this.role,
    required this.canRead,
    required this.canWrite,
    required this.canManageMeters,
    required this.createdAt,
    this.site,
  });

  final String id;
  final String userId;
  final String siteId;
  final UserRole role;
  final bool canRead;
  final bool canWrite;
  final bool canManageMeters;
  final DateTime createdAt;
  final Site? site;

  factory UserSiteAccess.fromJson(Map<String, dynamic> json) {
    Site? site;
    final siteJson = json['sites'];
    if (siteJson is Map<String, dynamic>) {
      site = Site.fromJson(siteJson);
    }

    return UserSiteAccess(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      siteId: json['site_id'] as String,
      role: UserRole.fromDb(json['role'] as String),
      canRead: json['can_read'] as bool,
      canWrite: json['can_write'] as bool,
      canManageMeters: json['can_manage_meters'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      site: site,
    );
  }

  Map<String, dynamic> toInsertJson({
    required String userId,
    required String siteId,
    required UserRole role,
    required bool canRead,
    required bool canWrite,
  }) {
    return {
      'user_id': userId,
      'site_id': siteId,
      'role': role.dbValue,
      'can_read': canRead,
      'can_write': canWrite,
      'can_manage_meters': role == UserRole.siteAdmin,
    };
  }

  Map<String, dynamic> toUpdateJson({
    required bool canRead,
    required bool canWrite,
  }) {
    return {
      'can_read': canRead,
      'can_write': canWrite,
      'can_manage_meters': role == UserRole.siteAdmin,
    };
  }
}

/// Profile row for admin user management with assignment count.
class AdminUser {
  const AdminUser({required this.profile, required this.siteAssignmentCount});

  final Profile profile;
  final int siteAssignmentCount;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final access = json['user_site_access'];
    var count = 0;
    if (access is List && access.isNotEmpty) {
      final first = access.first;
      if (first is Map && first['count'] != null) {
        count = first['count'] as int;
      }
    }

    return AdminUser(
      profile: Profile.fromJson(json),
      siteAssignmentCount: count,
    );
  }

  String get displayName {
    final name = profile.fullName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return profile.email;
  }
}

/// Default read/write permissions when approving or assigning by role.
({bool canRead, bool canWrite}) defaultSitePermissionsForRole(UserRole role) {
  switch (role) {
    case UserRole.technician:
    case UserRole.siteAdmin:
      return (canRead: true, canWrite: true);
    case UserRole.viewer:
      return (canRead: true, canWrite: false);
    default:
      return (canRead: true, canWrite: false);
  }
}

/// Roles an admin may assign during approval.
const kApprovableRoles = [
  UserRole.technician,
  UserRole.viewer,
  UserRole.siteAdmin,
];
