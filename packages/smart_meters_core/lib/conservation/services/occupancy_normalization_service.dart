import '../models/occupancy_calendar.dart';

/// Occupancy / operating-calendar normalization. N/A without real data.
class OccupancyNormalizationService {
  const OccupancyNormalizationService();

  static const notAvailableLabel = 'Occupancy Normalization = Not Available';

  OccupancyNormalizationResult normalize({
    required double actualConsumption,
    required String unitCode,
    OccupancyProfile? profile,
    List<SiteOperatingCalendarEntry> calendar = const [],
    double? floorAreaM2,
    double? referenceOperatingDays,
    double? referenceOccupancy,
  }) {
    final approvedCalendar =
        calendar.where((e) => e.status == 'approved').toList();
    final hasProfile = profile != null && profile.isApproved;
    final hasCalendar = approvedCalendar.isNotEmpty;

    if (!hasProfile && !hasCalendar) {
      return OccupancyNormalizationResult.notAvailable(
        actualConsumption: actualConsumption,
        unitCode: unitCode,
      );
    }

    int? operatingDays = profile?.operatingDays;
    if (operatingDays == null && hasCalendar) {
      operatingDays =
          approvedCalendar.where((e) => e.isOperating).length;
    }

    final occupancy = profile?.averageOccupancy ??
        _avgOccupancy(approvedCalendar);

    final intensities = <String, double?>{};
    if (floorAreaM2 != null && floorAreaM2 > 0) {
      intensities['per_m2'] = actualConsumption / floorAreaM2;
    }
    if (operatingDays != null && operatingDays > 0) {
      intensities['per_occupied_day'] = actualConsumption / operatingDays;
    }
    if (occupancy != null && occupancy > 0) {
      intensities['per_person'] = actualConsumption / occupancy;
    }

    double? occupancyAdjusted;
    if (operatingDays != null &&
        operatingDays > 0 &&
        referenceOperatingDays != null &&
        referenceOperatingDays > 0) {
      occupancyAdjusted =
          (actualConsumption / operatingDays) * referenceOperatingDays;
    } else if (occupancy != null &&
        occupancy > 0 &&
        referenceOccupancy != null &&
        referenceOccupancy > 0) {
      occupancyAdjusted = (actualConsumption / occupancy) * referenceOccupancy;
    }

    if (intensities.isEmpty && occupancyAdjusted == null) {
      return OccupancyNormalizationResult.notAvailable(
        actualConsumption: actualConsumption,
        unitCode: unitCode,
      );
    }

    return OccupancyNormalizationResult(
      available: true,
      actualConsumption: actualConsumption,
      occupancyAdjustedBaseline: occupancyAdjusted,
      intensities: intensities,
      operatingDays: operatingDays,
      averageOccupancy: occupancy,
      unitCode: unitCode,
      displayLabel: 'Occupancy-adjusted',
      lineage: {
        'profile_id': profile?.id,
        'calendar_days': approvedCalendar.length,
        'operating_days': operatingDays,
        'average_occupancy': occupancy,
        'floor_area_m2': floorAreaM2,
      },
    );
  }

  double? _avgOccupancy(List<SiteOperatingCalendarEntry> days) {
    final vals = days
        .map((e) => e.occupancyCount ?? e.occupancyFactor)
        .whereType<num>()
        .map((n) => n.toDouble())
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }
}

class OccupancyNormalizationResult {
  const OccupancyNormalizationResult({
    required this.available,
    required this.actualConsumption,
    required this.occupancyAdjustedBaseline,
    required this.intensities,
    required this.operatingDays,
    required this.averageOccupancy,
    required this.unitCode,
    required this.displayLabel,
    required this.lineage,
  });

  final bool available;
  final double actualConsumption;
  final double? occupancyAdjustedBaseline;
  final Map<String, double?> intensities;
  final int? operatingDays;
  final double? averageOccupancy;
  final String unitCode;
  final String displayLabel;
  final Map<String, dynamic> lineage;

  factory OccupancyNormalizationResult.notAvailable({
    required double actualConsumption,
    required String unitCode,
  }) {
    return OccupancyNormalizationResult(
      available: false,
      actualConsumption: actualConsumption,
      occupancyAdjustedBaseline: null,
      intensities: const {},
      operatingDays: null,
      averageOccupancy: null,
      unitCode: unitCode,
      displayLabel: OccupancyNormalizationService.notAvailableLabel,
      lineage: const {'reason': 'occupancy_data_missing'},
    );
  }
}
