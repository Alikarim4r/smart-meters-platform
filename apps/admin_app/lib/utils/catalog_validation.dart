import 'package:smart_meters_core/smart_meters_core.dart';

enum ActiveFilter { all, activeOnly, inactiveOnly }

String? validateCatalogCode(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Code is required';
  }
  final pattern = RegExp(r'^[a-z][a-z0-9_]*$');
  if (!pattern.hasMatch(trimmed)) {
    return 'Use lowercase snake_case (e.g. compressed_air)';
  }
  return null;
}

String? validateRequiredText(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return '$label is required';
  }
  return null;
}

String? validateSortOrder(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Sort order is required';
  }
  final parsed = int.tryParse(value.trim());
  if (parsed == null) {
    return 'Enter a valid number';
  }
  return null;
}

String? validateUnitFactor(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Conversion factor is required';
  }
  final parsed = double.tryParse(value.trim());
  if (parsed == null || parsed <= 0) {
    return 'Factor must be greater than 0';
  }
  return null;
}

List<T> filterByActive<T>({
  required List<T> items,
  required ActiveFilter filter,
  required bool Function(T item) isActive,
}) {
  return switch (filter) {
    ActiveFilter.all => items,
    ActiveFilter.activeOnly => items.where(isActive).toList(),
    ActiveFilter.inactiveOnly =>
      items.where((item) => !isActive(item)).toList(),
  };
}

List<MeterCategoryConfig> searchCategories(
  List<MeterCategoryConfig> items,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return items;
  }
  return items
      .where(
        (item) =>
            item.code.toLowerCase().contains(q) ||
            item.nameEn.toLowerCase().contains(q) ||
            (item.nameAr?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}

List<MeterUnitConfig> searchUnits(List<MeterUnitConfig> items, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return items;
  }
  return items
      .where(
        (item) =>
            item.code.toLowerCase().contains(q) ||
            item.nameEn.toLowerCase().contains(q) ||
            (item.nameAr?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}

List<MeterSourceConfig> searchSources(
  List<MeterSourceConfig> items,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return items;
  }
  return items
      .where(
        (item) =>
            item.code.toLowerCase().contains(q) ||
            item.nameEn.toLowerCase().contains(q) ||
            (item.nameAr?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}

String? validateSingleBaseUnit({
  required bool isBase,
  required String? editingUnitId,
  required List<MeterUnitConfig> existingUnits,
}) {
  if (!isBase) {
    return null;
  }
  final otherBase = existingUnits.where(
    (unit) => unit.isBase && unit.id != editingUnitId,
  );
  if (otherBase.isNotEmpty) {
    return 'Category already has base unit "${otherBase.first.code}". '
        'Unset the other base unit first.';
  }
  return null;
}
