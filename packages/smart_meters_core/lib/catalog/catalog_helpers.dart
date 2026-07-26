import '../models/enums.dart';
import '../models/meter_category_config.dart';

/// System category codes seeded in migration 006 — must not be deleted.
const kProtectedSystemCategoryCodes = {'water', 'electricity', 'btu', 'fuel'};

bool isProtectedSystemCategory(MeterCategoryConfig category) {
  return category.isSystem ||
      kProtectedSystemCategoryCodes.contains(category.code);
}

/// Display label from a joined catalog row (`name_en` → `code` → legacy).
String joinedCatalogDisplayName(
  Map<String, dynamic>? json, {
  String? legacyFallback,
}) {
  if (json == null) {
    return legacyFallback ?? '';
  }
  final nameEn = json['name_en'] as String?;
  if (nameEn != null && nameEn.trim().isNotEmpty) {
    return nameEn.trim();
  }
  final code = json['code'] as String?;
  if (code != null && code.trim().isNotEmpty) {
    return code.trim();
  }
  return legacyFallback ?? '';
}

String legacyMeterCategoryLabel(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return '';
  }
  try {
    return MeterCategory.fromDb(value).label;
  } catch (_) {
    return value;
  }
}

String legacyMeterSourceLabel(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return '';
  }
  return MeterSource.fromDb(value).dbValue;
}

String legacyMeterUnitLabel(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return '';
  }
  try {
    return MeterUnit.fromDb(value).label;
  } catch (_) {
    return value;
  }
}

String friendlyCatalogError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('row-level security') ||
      message.contains('permission denied') ||
      message.contains('42501')) {
    return 'You do not have permission to perform this action.';
  }
  if (message.contains('foreign key') ||
      message.contains('23503') ||
      message.contains('still referenced')) {
    return 'Cannot delete this item because it is used by existing meters. '
        'Deactivate it instead.';
  }
  if (message.contains('duplicate key') || message.contains('23505')) {
    return 'A record with this code already exists for this category.';
  }
  if (error is Exception || error is Error) {
    final text = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Error: ', '');
    if (text.trim().isNotEmpty) return text;
  }
  return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
}

String friendlyMeterError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('after readings exist') ||
      message.contains('cannot change unit') ||
      message.contains('cannot change unit/category')) {
    return 'This meter has readings. Category and unit cannot be changed.';
  }
  if (message.contains('meter_multiplier')) {
    return 'This meter has readings. Multiplier cannot be changed from the app.';
  }
  if (message.contains('parent meter')) {
    return 'Invalid parent meter selection. Choose a main meter from the same site and category.';
  }
  if (message.contains('foreign key') ||
      message.contains('violates foreign key') ||
      message.contains('23503')) {
    return 'Cannot delete: this meter still has linked data '
        '(readings, audit logs, or network assets). Try force-delete again, '
        'or contact a super admin if it keeps failing.';
  }
  return friendlyCatalogError(error);
}

String friendlySiteError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('duplicate key') || message.contains('23505')) {
    return 'A site with this name may already exist.';
  }
  if (message.contains('foreign key') ||
      message.contains('violates foreign key') ||
      message.contains('23503')) {
    return 'Cannot delete: meters or other linked data still reference this site. '
        'Remove them first, or ask a super admin to force-delete.';
  }
  return friendlyCatalogError(error);
}

String friendlyZoneError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('duplicate key') || message.contains('23505')) {
    return 'A zone with this code already exists for this organization.';
  }
  if (message.contains('zones_code_format')) {
    return 'Zone code must be lowercase letters, numbers, and underscores.';
  }
  return friendlyCatalogError(error);
}

String friendlyUserAdminError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('cannot approve themselves') ||
      message.contains('cannot approve this user')) {
    return 'You cannot approve this user.';
  }
  if (message.contains('only pending users can be rejected')) {
    return 'Only pending users can be rejected.';
  }
  if (message.contains('not in approvable state')) {
    return 'This user is not in a state that can be approved.';
  }
  if (message.contains('technician approval requires')) {
    return 'Technician approval requires at least one site assignment.';
  }
  if (message.contains('cannot suspend super_admin')) {
    return 'Super admin accounts cannot be suspended.';
  }
  if (message.contains('cannot assign site')) {
    return 'You do not have permission to assign one or more selected sites.';
  }
  if (message.contains('duplicate key') || message.contains('23505')) {
    return 'This user is already assigned to that site.';
  }
  return friendlyCatalogError(error);
}
