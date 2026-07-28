import '../models/enums.dart';

/// Platform owner (super-super-admin) email allowlist.
///
/// Passwords must never be stored in source. Ownership is email-based only.
const kPlatformOwnerEmails = <String>{
  'alikarim4r@gmail.com',
  'support@alimind.com',
};

bool isPlatformOwnerEmail(String? email) {
  if (email == null) return false;
  return kPlatformOwnerEmails.contains(email.trim().toLowerCase());
}

/// Which client apps a role can open after approval.
enum AppAccessCategory {
  admin,
  entry,
  dashboard,
}

extension UserRoleAppAccess on UserRole {
  /// Primary bucket for admin Users tab grouping.
  AppAccessCategory get primaryAppCategory {
    switch (this) {
      case UserRole.superAdmin:
      case UserRole.siteAdmin:
        return AppAccessCategory.admin;
      case UserRole.technician:
      case UserRole.technicianRequest:
        return AppAccessCategory.entry;
      case UserRole.viewer:
        return AppAccessCategory.dashboard;
    }
  }

  /// All apps this role may enter when approved + active.
  Set<AppAccessCategory> get accessibleApps {
    switch (this) {
      case UserRole.superAdmin:
        return {
          AppAccessCategory.admin,
          AppAccessCategory.entry,
          AppAccessCategory.dashboard,
        };
      case UserRole.siteAdmin:
        return {
          AppAccessCategory.admin,
          AppAccessCategory.entry,
          AppAccessCategory.dashboard,
        };
      case UserRole.technician:
        return {AppAccessCategory.entry, AppAccessCategory.dashboard};
      case UserRole.viewer:
        return {AppAccessCategory.dashboard};
      case UserRole.technicianRequest:
        return {};
    }
  }

  /// Registration source hint for pending accounts.
  String get registrationSourceLabelEn {
    switch (this) {
      case UserRole.technicianRequest:
        return 'Entry app registration';
      case UserRole.viewer:
        return 'Dashboard app registration';
      default:
        return 'Admin / invited';
    }
  }

  String get registrationSourceLabelAr {
    switch (this) {
      case UserRole.technicianRequest:
        return 'تسجيل من تطبيق الإدخال';
      case UserRole.viewer:
        return 'تسجيل من تطبيق العرض';
      default:
        return 'دعوة من الأدمن';
    }
  }
}

String appAccessCategoryLabel(
  AppAccessCategory category, {
  required bool isAr,
}) {
  switch (category) {
    case AppAccessCategory.admin:
      return isAr ? 'تطبيق الأدمن' : 'Admin app';
    case AppAccessCategory.entry:
      return isAr ? 'تطبيق الإدخال' : 'Entry app';
    case AppAccessCategory.dashboard:
      return isAr ? 'تطبيق العرض' : 'Dashboard app';
  }
}
