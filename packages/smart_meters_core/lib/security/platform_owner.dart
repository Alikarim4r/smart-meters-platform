import '../models/enums.dart';

/// Secure configuration-based platform owner resolution.
///
/// Ownership is determined via build-time configuration `--dart-define=PLATFORM_OWNER_EMAILS=...`
/// which contains a comma-separated list of authorized platform owner emails.
/// Hardcoded personal emails are strictly prohibited.
bool isPlatformOwnerEmail(
  String? email, {
  String? configOverride,
}) {
  if (email == null || email.trim().isEmpty) return false;
  
  final configStr = configOverride ?? const String.fromEnvironment('PLATFORM_OWNER_EMAILS');
  if (configStr.trim().isEmpty) return false;
  
  final configuredEmails = configStr
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
      
  return configuredEmails.contains(email.trim().toLowerCase());
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
