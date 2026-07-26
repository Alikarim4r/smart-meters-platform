import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/user_validation.dart';

final canManageUsersProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) {
    return false;
  }
  return profile.isPlatformOwner ||
      profile.isSuperAdmin ||
      profile.isSiteAdmin;
});

final usersProvider = FutureProvider.autoDispose<List<AdminUser>>((ref) async {
  return ref.read(userAdminRepositoryProvider).getUsersForAdmin();
});

final pendingUsersProvider = FutureProvider.autoDispose<List<AdminUser>>((
  ref,
) async {
  return ref.read(userAdminRepositoryProvider).getPendingUsers();
});

final userDetailsProvider = FutureProvider.autoDispose
    .family<AdminUser, String>((ref, userId) async {
      return ref.read(userAdminRepositoryProvider).getUserById(userId);
    });

final userSiteAccessProvider = FutureProvider.autoDispose
    .family<List<UserSiteAccess>, String>((ref, userId) async {
      return ref.read(userAdminRepositoryProvider).getUserSiteAccess(userId);
    });

final userApprovalFilterProvider = StateProvider<UserApprovalFilter>(
  (ref) => UserApprovalFilter.all,
);

final userRoleFilterProvider = StateProvider<UserRoleFilter>(
  (ref) => UserRoleFilter.all,
);

final userAppBucketFilterProvider = StateProvider<UserAppBucketFilter>(
  (ref) => UserAppBucketFilter.all,
);

final userSearchQueryProvider = StateProvider<String>((ref) => '');

final siteAssignmentZoneFilterProvider = StateProvider<String?>((ref) => null);

final siteAssignmentSearchProvider = StateProvider<String>((ref) => '');
