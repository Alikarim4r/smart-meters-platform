import 'enums.dart';
import 'meter_category_config.dart';
import 'meter_reading.dart';
import 'site.dart';

/// Site row for dashboard home with monitoring metadata.
class DashboardSiteOverview {
  const DashboardSiteOverview({
    required this.site,
    required this.meterCount,
    required this.activeMeterCount,
    required this.categories,
    required this.readingsSubmittedToday,
    required this.entryEligibleMeterCount,
    this.lastReadingDate,
  });

  final Site site;
  final int meterCount;
  final int activeMeterCount;
  final List<MeterCategoryConfig> categories;
  final int readingsSubmittedToday;
  final int entryEligibleMeterCount;
  final DateTime? lastReadingDate;

  int get pendingReadingsToday =>
      (entryEligibleMeterCount - readingsSubmittedToday).clamp(
        0,
        entryEligibleMeterCount,
      );

  String get todayProgressLabel {
    if (entryEligibleMeterCount == 0) {
      return 'No entry meters';
    }
    return '$readingsSubmittedToday/$entryEligibleMeterCount submitted today';
  }
}

class SiteDashboardSummary {
  const SiteDashboardSummary({
    required this.site,
    required this.totalMeters,
    required this.activeMeters,
    required this.readingsSubmittedToday,
    required this.pendingReadingsToday,
    required this.categoriesCount,
    required this.copGroupsCount,
    this.lastReadingDate,
  });

  final Site site;
  final int totalMeters;
  final int activeMeters;
  final int readingsSubmittedToday;
  final int pendingReadingsToday;
  final int categoriesCount;
  final int copGroupsCount;
  final DateTime? lastReadingDate;
}

class SiteCategorySummary {
  const SiteCategorySummary({
    required this.category,
    required this.meterCount,
    required this.readingsSubmittedToday,
    this.latestReadingAt,
    this.totalDailyConsumption,
  });

  final MeterCategoryConfig category;
  final int meterCount;
  final int readingsSubmittedToday;
  final DateTime? latestReadingAt;
  final double? totalDailyConsumption;

  int get pendingToday =>
      (meterCount - readingsSubmittedToday).clamp(0, meterCount);
}

class DashboardMeterRow {
  const DashboardMeterRow({
    required this.meterId,
    required this.meterCode,
    required this.nameEn,
    required this.categoryName,
    required this.categoryId,
    required this.sourceName,
    required this.unitLabel,
    required this.level,
    required this.isActive,
    required this.includeInDashboard,
    this.parentMeterName,
    this.parentMeterCode,
    this.latestRawValue,
    this.latestReadingDate,
    this.hasSubmittedToday = false,
  });

  final String meterId;
  final String meterCode;
  final String nameEn;
  final String categoryName;
  final String categoryId;
  final String sourceName;
  final String unitLabel;
  final MeterLevel level;
  final bool isActive;
  final bool includeInDashboard;
  final String? parentMeterName;
  final String? parentMeterCode;
  final double? latestRawValue;
  final DateTime? latestReadingDate;
  final bool hasSubmittedToday;

  bool get isSub => level == MeterLevel.sub || level == MeterLevel.subSub;
}

class DashboardReadingRow {
  const DashboardReadingRow({
    required this.reading,
    required this.meterName,
    required this.meterCode,
    required this.categoryName,
    required this.unitLabel,
    this.enteredByName,
    this.enteredByEmail,
  });

  final MeterReading reading;
  final String meterName;
  final String meterCode;
  final String categoryName;
  final String unitLabel;
  final String? enteredByName;
  final String? enteredByEmail;

  bool get hasPhoto => reading.hasPhoto;
}

class DashboardCopGroupSummary {
  const DashboardCopGroupSummary({
    required this.id,
    required this.nameEn,
    required this.isActive,
    required this.btuMeterCount,
    required this.electricityMeterCount,
  });

  final String id;
  final String nameEn;
  final bool isActive;
  final int btuMeterCount;
  final int electricityMeterCount;
}

class DashboardReadingFilters {
  const DashboardReadingFilters({
    this.fromDate,
    this.toDate,
    this.categoryId,
    this.meterId,
    this.hasPhoto,
    this.limit = 100,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final String? categoryId;
  final String? meterId;
  final bool? hasPhoto;
  final int limit;
}
