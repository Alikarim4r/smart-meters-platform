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
  if (role == UserRole.technician && selectedSiteIds.isEmpty) {
    return 'Select at least one site for technician approval.';
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
  if (target.profile.isSuperAdmin) {
    return false;
  }
  if (actor.isSuperAdmin) {
    return true;
  }
  return actor.isSiteAdmin;
}

bool canEditSiteAssignments(AdminUser target) {
  return target.profile.approvalStatus == ApprovalStatus.approved &&
      target.profile.isActive;
}
