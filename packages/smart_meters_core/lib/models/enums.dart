/// Mirrors Postgres enums in `supabase/migrations/001_schema.sql`.
enum UserRole {
  superAdmin('super_admin'),
  siteAdmin('site_admin'),
  technician('technician'),
  technicianRequest('technician_request'),
  viewer('viewer');

  const UserRole(this.dbValue);

  final String dbValue;

  static UserRole fromDb(String value) {
    return UserRole.values.firstWhere(
      (role) => role.dbValue == value,
      orElse: () => throw ArgumentError('Unknown user_role: $value'),
    );
  }
}

/// Mirrors Postgres `approval_status` enum (`004_user_approval_enum.sql`).
enum ApprovalStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  suspended('suspended');

  const ApprovalStatus(this.dbValue);

  final String dbValue;

  static ApprovalStatus fromDb(String value) {
    return ApprovalStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => throw ArgumentError('Unknown approval_status: $value'),
    );
  }
}

/// Whether an app requires site assignment after approval.
enum SiteAccessRequirement {
  /// No site check (e.g. admin_app for super_admin).
  none,

  /// At least one site with `can_read` (dashboard_app).
  read,

  /// At least one site with `can_write` (entry_app).
  write,
}

enum SiteType {
  headquarters('headquarters'),
  school('school'),
  kindergarten('kindergarten'),
  mosque('mosque'),
  office('office'),
  warehouse('warehouse'),
  trainingCenter('training_center'),
  other('other');

  const SiteType(this.dbValue);

  final String dbValue;

  static SiteType fromDb(String value) {
    return SiteType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => throw ArgumentError('Unknown site_type: $value'),
    );
  }

  String get label {
    switch (this) {
      case SiteType.headquarters:
        return 'Headquarters';
      case SiteType.school:
        return 'School';
      case SiteType.kindergarten:
        return 'Kindergarten';
      case SiteType.mosque:
        return 'Mosque';
      case SiteType.office:
        return 'Office';
      case SiteType.warehouse:
        return 'Warehouse';
      case SiteType.trainingCenter:
        return 'Training center';
      case SiteType.other:
        return 'Other';
    }
  }

  String get labelAr {
    switch (this) {
      case SiteType.headquarters:
        return 'مقر رئيسي';
      case SiteType.school:
        return 'مدرسة';
      case SiteType.kindergarten:
        return 'روضة';
      case SiteType.mosque:
        return 'مسجد';
      case SiteType.office:
        return 'مكتب';
      case SiteType.warehouse:
        return 'مستودع';
      case SiteType.trainingCenter:
        return 'مركز تدريب';
      case SiteType.other:
        return 'أخرى';
    }
  }
}

enum MeterLevel {
  main('main'),
  sub('sub'),
  subSub('sub_sub');

  const MeterLevel(this.dbValue);

  final String dbValue;

  static MeterLevel fromDb(String value) {
    return MeterLevel.values.firstWhere(
      (level) => level.dbValue == value,
      orElse: () => throw ArgumentError('Unknown meter_level: $value'),
    );
  }

  String get label {
    switch (this) {
      case MeterLevel.main:
        return 'Main';
      case MeterLevel.sub:
        return 'Sub';
      case MeterLevel.subSub:
        return 'Sub-sub';
    }
  }

  /// Arabic / bilingual short label for admin UI.
  String get labelAr {
    switch (this) {
      case MeterLevel.main:
        return 'رئيسي';
      case MeterLevel.sub:
        return 'فرعي';
      case MeterLevel.subSub:
        return 'فرعي الفرعي';
    }
  }

  /// Locale-aware label (one language only).
  String localizedLabel({required bool isAr}) => isAr ? labelAr : label;

  /// Levels exposed in create/edit UI (main + sub only).
  static const List<MeterLevel> assignableLevels = [
    MeterLevel.main,
    MeterLevel.sub,
  ];

  /// Map legacy sub_sub into the assignable UI level.
  MeterLevel get asAssignable =>
      this == MeterLevel.subSub ? MeterLevel.sub : this;

  bool get requiresParent => this != MeterLevel.main;

  /// Parent level required for this child level, if any.
  MeterLevel? get requiredParentLevel => switch (this) {
    MeterLevel.main => null,
    MeterLevel.sub => MeterLevel.main,
    MeterLevel.subSub => MeterLevel.sub,
  };
}

/// Legacy Postgres `meter_category` enum mirror.
/// Prefer [MeterCategoryConfig] + `meters.category_id` for new code.
enum MeterCategory {
  water('water'),
  electricity('electricity'),
  btu('btu'),
  fuel('fuel');

  const MeterCategory(this.dbValue);

  final String dbValue;

  static MeterCategory fromDb(String value) {
    return MeterCategory.values.firstWhere(
      (category) => category.dbValue == value,
      orElse: () => throw ArgumentError('Unknown meter_category: $value'),
    );
  }

  String get label {
    switch (this) {
      case MeterCategory.water:
        return 'Water';
      case MeterCategory.electricity:
        return 'Electricity';
      case MeterCategory.btu:
        return 'BTU';
      case MeterCategory.fuel:
        return 'Fuel';
    }
  }
}

/// Legacy Postgres `meter_source` enum mirror.
enum MeterSource {
  kahramaa('kahramaa'),
  tse('tse'),
  ro('ro'),
  tanker('tanker'),
  generator('generator'),
  solar('solar'),
  chilledWater('chilled_water'),
  coolingEnergy('cooling_energy'),
  other('other');

  const MeterSource(this.dbValue);

  final String dbValue;

  static MeterSource fromDb(String value) {
    return MeterSource.values.firstWhere(
      (source) => source.dbValue == value,
      orElse: () => MeterSource.other,
    );
  }
}

enum MeterKind {
  physical('physical'),
  virtual('virtual');

  const MeterKind(this.dbValue);

  final String dbValue;

  static MeterKind fromDb(String value) {
    return MeterKind.values.firstWhere(
      (kind) => kind.dbValue == value,
      orElse: () => throw ArgumentError('Unknown meter_kind: $value'),
    );
  }
}

enum CalculationType {
  directReading('direct_reading'),
  sumChildren('sum_children'),
  parentMinusChildren('parent_minus_children'),
  manualAdjustment('manual_adjustment');

  const CalculationType(this.dbValue);

  final String dbValue;

  static CalculationType fromDb(String value) {
    return CalculationType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => throw ArgumentError('Unknown calculation_type: $value'),
    );
  }
}

enum MeterUnit {
  m3('m3'),
  liter('liter'),
  dm3('dm3'),
  gallon('gallon'),
  kwh('kwh'),
  mwh('mwh'),
  wh('wh'),
  kvah('kvah'),
  kwhThermal('kwh_thermal'),
  btu('btu'),
  tonHour('ton_hour'),
  rtHour('rt_hour'),
  gj('gj');

  const MeterUnit(this.dbValue);

  final String dbValue;

  static MeterUnit fromDb(String value) {
    return MeterUnit.values.firstWhere(
      (unit) => unit.dbValue == value,
      orElse: () => throw ArgumentError('Unknown meter_unit: $value'),
    );
  }

  String get label {
    switch (this) {
      case MeterUnit.m3:
        return 'm³';
      case MeterUnit.liter:
        return 'L';
      case MeterUnit.dm3:
        return 'Dm3';
      case MeterUnit.gallon:
        return 'gal';
      case MeterUnit.kwh:
        return 'kWh';
      case MeterUnit.mwh:
        return 'MWh';
      case MeterUnit.wh:
        return 'Wh';
      case MeterUnit.kvah:
        return 'kVAh';
      case MeterUnit.kwhThermal:
        return 'kWh (thermal)';
      case MeterUnit.btu:
        return 'BTU';
      case MeterUnit.tonHour:
        return 'ton-hr';
      case MeterUnit.rtHour:
        return 'RT-hr';
      case MeterUnit.gj:
        return 'GJ';
    }
  }
}
