class SiteOperatingCalendarEntry {
  const SiteOperatingCalendarEntry({
    required this.id,
    required this.siteId,
    required this.periodDate,
    required this.operatingStatus,
    required this.source,
    required this.status,
    this.operatingHours,
    this.occupancyFactor,
    this.occupancyCount,
    this.holidayEventType,
    this.approvedBy,
    this.approvedAt,
    this.notes,
  });

  final String id;
  final String siteId;
  final DateTime periodDate;
  final String operatingStatus;
  final double? operatingHours;
  final double? occupancyFactor;
  final int? occupancyCount;
  final String? holidayEventType;
  final String source;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;

  bool get isOperating =>
      operatingStatus == 'operating' || operatingStatus == 'partial';

  factory SiteOperatingCalendarEntry.fromJson(Map<String, dynamic> json) {
    return SiteOperatingCalendarEntry(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      periodDate: DateTime.parse(json['period_date'] as String),
      operatingStatus: json['operating_status'] as String? ?? 'operating',
      operatingHours: (json['operating_hours'] as num?)?.toDouble(),
      occupancyFactor: (json['occupancy_factor'] as num?)?.toDouble(),
      occupancyCount: json['occupancy_count'] as int?,
      holidayEventType: json['holiday_event_type'] as String?,
      source: json['source'] as String? ?? 'manual',
      status: json['status'] as String? ?? 'draft',
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }
}

class OccupancyProfile {
  const OccupancyProfile({
    required this.id,
    required this.siteId,
    required this.label,
    required this.periodStart,
    required this.periodEnd,
    required this.source,
    required this.status,
    this.operatingDays,
    this.averageOccupancy,
    this.hoursOfOperation,
    this.approvedBy,
    this.approvedAt,
    this.notes,
  });

  final String id;
  final String siteId;
  final String label;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int? operatingDays;
  final double? averageOccupancy;
  final double? hoursOfOperation;
  final String source;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;

  bool get isApproved => status == 'approved';

  factory OccupancyProfile.fromJson(Map<String, dynamic> json) {
    return OccupancyProfile(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      label: json['label'] as String,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      operatingDays: json['operating_days'] as int?,
      averageOccupancy: (json['average_occupancy'] as num?)?.toDouble(),
      hoursOfOperation: (json['hours_of_operation'] as num?)?.toDouble(),
      source: json['source'] as String,
      status: json['status'] as String? ?? 'draft',
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }
}
