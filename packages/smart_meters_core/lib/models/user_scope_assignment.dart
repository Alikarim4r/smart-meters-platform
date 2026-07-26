/// App role row from `roles` (RBAC layer; distinct from profiles.role enum).
class AppRole {
  const AppRole({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.isSystem = true,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameAr;
  final bool isSystem;
  final bool isActive;
  final int sortOrder;

  String label({required bool isAr}) =>
      isAr && nameAr.trim().isNotEmpty ? nameAr : nameEn;

  factory AppRole.fromJson(Map<String, dynamic> json) {
    return AppRole(
      id: json['id'] as String,
      code: json['code'] as String,
      nameEn: json['name_en'] as String,
      nameAr: (json['name_ar'] as String?) ?? '',
      isSystem: json['is_system'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

enum ScopeKind { organization, zone, site }

/// Row in `user_scope_assignments`.
class UserScopeAssignment {
  const UserScopeAssignment({
    required this.id,
    required this.userId,
    required this.roleId,
    this.organizationId,
    this.zoneId,
    this.siteId,
    this.inheritChildren = true,
    this.status = 'active',
    this.role,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String roleId;
  final String? organizationId;
  final String? zoneId;
  final String? siteId;
  final bool inheritChildren;
  final String status;
  final AppRole? role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ScopeKind get kind {
    if (organizationId != null) return ScopeKind.organization;
    if (zoneId != null) return ScopeKind.zone;
    return ScopeKind.site;
  }

  factory UserScopeAssignment.fromJson(Map<String, dynamic> json) {
    AppRole? role;
    final rawRole = json['roles'];
    if (rawRole is Map) {
      role = AppRole.fromJson(Map<String, dynamic>.from(rawRole));
    }
    return UserScopeAssignment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      roleId: json['role_id'] as String,
      organizationId: json['organization_id'] as String?,
      zoneId: json['zone_id'] as String?,
      siteId: json['site_id'] as String?,
      inheritChildren: json['inherit_children'] as bool? ?? true,
      status: (json['status'] as String?) ?? 'active',
      role: role,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}
