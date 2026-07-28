import 'package:smart_meters_core/smart_meters_core.dart';

enum UserApprovalFilter {
  all,
  pending,
  approved,
  rejected,
  suspended,
  active,
  inactive,
}

enum UserRoleFilter {
  all,
  technicianRequest,
  technician,
  viewer,
  siteAdmin,
  superAdmin,
}

/// Users tab primary grouping by client app.
enum UserAppBucketFilter {
  all,
  pending,
  adminApp,
  entryApp,
  dashboardApp,
}

List<AdminUser> filterUsersByAppBucket({
  required List<AdminUser> users,
  required UserAppBucketFilter filter,
}) {
  switch (filter) {
    case UserAppBucketFilter.all:
      return users;
    case UserAppBucketFilter.pending:
      return users
          .where((u) => u.profile.approvalStatus == ApprovalStatus.pending)
          .toList();
    case UserAppBucketFilter.adminApp:
      return users
          .where(
            (u) =>
                u.profile.approvalStatus != ApprovalStatus.pending &&
                (u.profile.isSuperAdmin || u.profile.isSiteAdmin),
          )
          .toList();
    case UserAppBucketFilter.entryApp:
      return users
          .where(
            (u) =>
                u.profile.role == UserRole.technician ||
                u.profile.role == UserRole.technicianRequest ||
                (u.profile.isSiteAdmin &&
                    u.profile.approvalStatus == ApprovalStatus.approved),
          )
          .toList();
    case UserAppBucketFilter.dashboardApp:
      return users
          .where(
            (u) =>
                u.profile.approvalStatus == ApprovalStatus.approved &&
                u.profile.role != UserRole.technicianRequest &&
                (u.profile.isViewer ||
                    u.profile.isTechnician ||
                    u.profile.isSiteAdmin ||
                    u.profile.isSuperAdmin),
          )
          .toList();
  }
}


List<AdminUser> searchUsers(List<AdminUser> users, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return users;
  }
  return users
      .where(
        (user) =>
            user.displayName.toLowerCase().contains(q) ||
            user.profile.email.toLowerCase().contains(q),
      )
      .toList();
}

List<AdminUser> filterUsersByApproval({
  required List<AdminUser> users,
  required UserApprovalFilter filter,
}) {
  switch (filter) {
    case UserApprovalFilter.all:
      return users;
    case UserApprovalFilter.pending:
      return users
          .where((u) => u.profile.approvalStatus == ApprovalStatus.pending)
          .toList();
    case UserApprovalFilter.approved:
      return users
          .where((u) => u.profile.approvalStatus == ApprovalStatus.approved)
          .toList();
    case UserApprovalFilter.rejected:
      return users
          .where((u) => u.profile.approvalStatus == ApprovalStatus.rejected)
          .toList();
    case UserApprovalFilter.suspended:
      return users
          .where((u) => u.profile.approvalStatus == ApprovalStatus.suspended)
          .toList();
    case UserApprovalFilter.active:
      return users.where((u) => u.profile.isActive).toList();
    case UserApprovalFilter.inactive:
      return users.where((u) => !u.profile.isActive).toList();
  }
}

List<AdminUser> filterUsersByRole({
  required List<AdminUser> users,
  required UserRoleFilter filter,
}) {
  if (filter == UserRoleFilter.all) {
    return users;
  }
  final role = switch (filter) {
    UserRoleFilter.technicianRequest => UserRole.technicianRequest,
    UserRoleFilter.technician => UserRole.technician,
    UserRoleFilter.viewer => UserRole.viewer,
    UserRoleFilter.siteAdmin => UserRole.siteAdmin,
    UserRoleFilter.superAdmin => UserRole.superAdmin,
    UserRoleFilter.all => UserRole.viewer,
  };
  return users.where((u) => u.profile.role == role).toList();
}

String? validateApprovalSites({
  required UserRole role,
  required Set<String> selectedSiteIds,
}) {
  // Entry/dashboard both require ≥1 site after approval (except super_admin).
  if (role == UserRole.superAdmin) {
    return null;
  }
  if (selectedSiteIds.isEmpty) {
    return switch (role) {
      UserRole.technician =>
        'Select at least one site for technician approval.',
      UserRole.siteAdmin =>
        'Select at least one site for site admin approval.',
      UserRole.viewer =>
        'Select at least one site for viewer approval (required to open Dashboard).',
      _ => 'Select at least one site before approving this user.',
    };
  }
  return null;
}

String? validateUserScope({
  required ScopeKind kind,
  String? organizationId,
  String? zoneId,
  String? siteId,
}) {
  if (organizationId == null || organizationId.isEmpty) {
    return 'Select an organization.';
  }
  switch (kind) {
    case ScopeKind.organization:
      return null;
    case ScopeKind.zone:
      if (zoneId == null || zoneId.isEmpty) {
        return 'Select a zone for this scope.';
      }
      return null;
    case ScopeKind.site:
      if (siteId == null || siteId.isEmpty) {
        return 'Select a site for this scope.';
      }
      return null;
  }
}

String formatAdminDateTime(DateTime? value) {
  if (value == null) {
    return '—';
  }
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

String userRoleLabel(UserRole role) {
  switch (role) {
    case UserRole.superAdmin:
      return 'Super Admin';
    case UserRole.siteAdmin:
      return 'Site Admin';
    case UserRole.technician:
      return 'Technician';
    case UserRole.technicianRequest:
      return 'Technician Request';
    case UserRole.viewer:
      return 'Viewer';
  }
}

String userRolePermissionHint(UserRole role, {required bool isAr}) {
  switch (role) {
    case UserRole.superAdmin:
      return isAr
          ? 'صلاحيات كاملة: أدمن + عرض'
          : 'Full access: Admin + Dashboard';
    case UserRole.siteAdmin:
      return isAr
          ? 'إدارة مواقع: أدمن + إدخال + عرض'
          : 'Site management: Admin + Entry + Dashboard';
    case UserRole.technician:
      return isAr
          ? 'إدخال قراءات + عرض'
          : 'Reading entry + Dashboard';
    case UserRole.viewer:
      return isAr ? 'عرض فقط' : 'Dashboard view only';
    case UserRole.technicianRequest:
      return isAr
          ? 'طلب جديد بانتظار الموافقة'
          : 'New request awaiting approval';
  }
}

String approvalStatusLabel(ApprovalStatus status) {
  switch (status) {
    case ApprovalStatus.pending:
      return 'Pending';
    case ApprovalStatus.approved:
      return 'Approved';
    case ApprovalStatus.rejected:
      return 'Rejected';
    case ApprovalStatus.suspended:
      return 'Suspended';
  }
}

bool canManageUserActions(Profile actor, AdminUser target) {
  if (target.profile.id == actor.id) {
    return false;
  }
  if (actor.isPlatformOwner) {
    return !target.profile.isPlatformOwner;
  }
  if (target.profile.isPlatformOwner || target.profile.isSuperAdmin) {
    return false;
  }
  if (actor.isSuperAdmin) {
    return true;
  }
  return actor.isSiteAdmin;
}

bool canDeleteUserAccount(Profile actor, AdminUser target) {
  if (target.profile.id == actor.id) return false;
  if (target.profile.isPlatformOwner) return false;
  if (actor.isPlatformOwner) return true;
  return actor.isSuperAdmin && !target.profile.isSuperAdmin;
}

bool canChangeUserRole(Profile actor, AdminUser target) {
  if (target.profile.id == actor.id) return false;
  if (target.profile.isPlatformOwner) return false;
  if (actor.isPlatformOwner) return true;
  return actor.isSuperAdmin && !target.profile.isSuperAdmin;
}

bool canEditSiteAssignments(AdminUser target) {
  return target.profile.approvalStatus == ApprovalStatus.approved &&
      target.profile.isActive;
}
