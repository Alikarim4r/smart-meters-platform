import 'package:smart_meters_core/smart_meters_core.dart';

enum AdminActiveFilter { all, activeOnly, inactiveOnly }

enum AdminMeterLevelFilter { all, mainOnly, subOnly, subSubOnly }

String? validateRequiredText(String? value, String fieldLabel) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldLabel is required';
  }
  return null;
}

String? validateSiteNameEn(String? value) =>
    validateRequiredText(value, 'English name');

String? validateOrganizationId(String? value) {
  if (value == null || value.isEmpty) {
    return 'Organization is required';
  }
  return null;
}

String? validateMeterCode(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Meter code is required';
  }
  return null;
}

String? validateMeterMultiplier(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Multiplier is required';
  }
  final parsed = double.tryParse(value.trim());
  if (parsed == null || parsed <= 0) {
    return 'Multiplier must be greater than 0';
  }
  return null;
}

String? validateSortOrder(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Sort order is required';
  }
  if (int.tryParse(value.trim()) == null) {
    return 'Sort order must be a whole number';
  }
  return null;
}

String? validateParentMeter({
  required MeterLevel level,
  String? parentMeterId,
}) {
  if (level.requiresParent &&
      (parentMeterId == null || parentMeterId.isEmpty)) {
    return level == MeterLevel.subSub
        ? 'Parent sub meter is required'
        : 'Parent main meter is required';
  }
  return null;
}

List<Site> searchSites(List<Site> sites, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return sites;
  }
  return sites
      .where(
        (site) =>
            site.nameEn.toLowerCase().contains(q) ||
            site.nameAr.toLowerCase().contains(q) ||
            (site.location?.toLowerCase().contains(q) ?? false) ||
            site.siteType.label.toLowerCase().contains(q),
      )
      .toList();
}

List<Site> filterSitesByActive({
  required List<Site> sites,
  required AdminActiveFilter filter,
}) {
  switch (filter) {
    case AdminActiveFilter.all:
      return sites;
    case AdminActiveFilter.activeOnly:
      return sites.where((site) => site.isActive).toList();
    case AdminActiveFilter.inactiveOnly:
      return sites.where((site) => !site.isActive).toList();
  }
}

List<Meter> searchMeters(List<Meter> meters, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return meters;
  }
  return meters
      .where(
        (meter) =>
            meter.nameEn.toLowerCase().contains(q) ||
            meter.nameAr.toLowerCase().contains(q) ||
            meter.meterCode.toLowerCase().contains(q) ||
            (meter.siteNameEn?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}

List<Meter> filterMetersByLevel({
  required List<Meter> meters,
  required AdminMeterLevelFilter filter,
}) {
  switch (filter) {
    case AdminMeterLevelFilter.all:
      return meters;
    case AdminMeterLevelFilter.mainOnly:
      return meters.where((m) => m.level == MeterLevel.main).toList();
    case AdminMeterLevelFilter.subOnly:
      return meters.where((m) => m.level == MeterLevel.sub).toList();
    case AdminMeterLevelFilter.subSubOnly:
      return meters.where((m) => m.level == MeterLevel.subSub).toList();
  }
}
