import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import 'auth_provider.dart';

class AppPermissions {
  const AppPermissions({
    required this.role,
    required this.canAccessAdminApp,
    required this.canAccessEntryApp,
    required this.canAccessDashboardApp,
  });

  final UserRole? role;
  final bool canAccessAdminApp;
  final bool canAccessEntryApp;
  final bool canAccessDashboardApp;
}

final permissionsProvider = Provider<AppPermissions>((ref) {
  final profile = ref.watch(authProvider).profile;
  final role = profile?.role;
  final approved = profile?.isApprovedForAccess ?? false;

  return AppPermissions(
    role: role,
    canAccessAdminApp:
        approved && (role == UserRole.superAdmin || role == UserRole.siteAdmin),
    canAccessEntryApp:
        approved && (role == UserRole.technician || role == UserRole.siteAdmin),
    canAccessDashboardApp:
        approved && role != null && role != UserRole.technicianRequest,
  );
});
