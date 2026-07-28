import 'alert_models.dart';

enum CorrectionReason {
  wrongReading,
  duplicateMistake,
  meterPhotoMismatch,
  technicianMistake,
  clientRequest,
  abnormalConsumption,
  other,
}

extension CorrectionReasonLabel on CorrectionReason {
  String get label => switch (this) {
    CorrectionReason.wrongReading => 'Wrong reading',
    CorrectionReason.duplicateMistake => 'Duplicate / mistake',
    CorrectionReason.meterPhotoMismatch => 'Meter / photo mismatch',
    CorrectionReason.technicianMistake => 'Technician mistake',
    CorrectionReason.clientRequest => 'Client request',
    CorrectionReason.abnormalConsumption => 'Abnormal consumption',
    CorrectionReason.other => 'Other',
  };

  String get code => name;
}

/// Result of a completed admin correction.
class ReadingCorrection {
  const ReadingCorrection({
    required this.readingId,
    required this.meterId,
    required this.siteId,
    required this.oldValue,
    required this.newValue,
    this.oldNote,
    this.newNote,
    required this.reason,
    required this.correctedBy,
    required this.correctedAt,
    this.auditId,
  });

  final String readingId;
  final String meterId;
  final String siteId;
  final double oldValue;
  final double newValue;
  final String? oldNote;
  final String? newNote;
  final CorrectionReason reason;
  final String correctedBy;
  final DateTime correctedAt;
  final String? auditId;
}

enum ReadingAuditAction { create, update, delete, restore }

extension ReadingAuditActionLabel on ReadingAuditAction {
  String get label => switch (this) {
    ReadingAuditAction.create => 'Created',
    ReadingAuditAction.update => 'Corrected',
    ReadingAuditAction.delete => 'Deleted',
    ReadingAuditAction.restore => 'Restored',
  };
}

/// Audit log row for correction history UI.
class ReadingAuditEntry {
  const ReadingAuditEntry({
    required this.id,
    required this.readingId,
    required this.action,
    this.oldValue,
    this.newValue,
    this.oldNote,
    this.newNote,
    this.reason,
    this.changedByName,
    this.changedByEmail,
    required this.changedAt,
  });

  final String id;
  final String readingId;
  final ReadingAuditAction action;
  final double? oldValue;
  final double? newValue;
  final String? oldNote;
  final String? newNote;
  final CorrectionReason? reason;
  final String? changedByName;
  final String? changedByEmail;
  final DateTime changedAt;
}

/// Admin list row for submitted readings.
class AdminReadingRow {
  const AdminReadingRow({
    required this.readingId,
    required this.siteId,
    required this.siteName,
    required this.zoneName,
    required this.meterId,
    required this.meterName,
    required this.meterCode,
    required this.categoryName,
    required this.unitLabel,
    required this.readingDate,
    required this.rawValue,
    required this.normalizedValue,
    this.note,
    this.imageStoragePath,
    this.enteredByName,
    this.enteredByEmail,
    required this.enteredAt,
    this.isCorrected = false,
    this.alertTypes = const [],
  });

  final String readingId;
  final String siteId;
  final String siteName;
  final String zoneName;
  final String meterId;
  final String meterName;
  final String meterCode;
  final String categoryName;
  final String unitLabel;
  final DateTime readingDate;
  final double rawValue;
  final double normalizedValue;
  final String? note;
  final String? imageStoragePath;
  final String? enteredByName;
  final String? enteredByEmail;
  final DateTime enteredAt;
  final bool isCorrected;
  final List<AlertType> alertTypes;

  bool get hasPhoto =>
      imageStoragePath != null && imageStoragePath!.trim().isNotEmpty;
}

/// Full context for correction form.
class ReadingCorrectionDetails {
  const ReadingCorrectionDetails({
    required this.reading,
    required this.previousValue,
    required this.nextValue,
    required this.auditHistory,
    this.relatedAlerts = const [],
  });

  final AdminReadingRow reading;
  final double? previousValue;
  final double? nextValue;
  final List<ReadingAuditEntry> auditHistory;
  final List<AlertType> relatedAlerts;
}

class ReadingCorrectionFilters {
  const ReadingCorrectionFilters({
    this.siteId,
    this.zoneId,
    this.categoryId,
    this.fromDate,
    this.toDate,
    this.listFilter = CorrectionListFilter.all,
    this.limit = 200,
  });

  final String? siteId;
  final String? zoneId;
  final String? categoryId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final CorrectionListFilter listFilter;
  final int limit;
}

enum CorrectionListFilter {
  all,
  suspicious,
  withAlerts,
  corrected,
  withoutPhoto,
}

extension CorrectionListFilterLabel on CorrectionListFilter {
  String get label => switch (this) {
    CorrectionListFilter.all => 'All readings',
    CorrectionListFilter.suspicious => 'Suspicious readings',
    CorrectionListFilter.withAlerts => 'Readings with alerts',
    CorrectionListFilter.corrected => 'Corrected readings',
    CorrectionListFilter.withoutPhoto => 'Without photo',
  };
}

enum CorrectionDateFilter { today, last7Days, last30Days, all }

extension CorrectionDateFilterLabel on CorrectionDateFilter {
  String get label => switch (this) {
    CorrectionDateFilter.today => 'Today',
    CorrectionDateFilter.last7Days => 'Last 7 days',
    CorrectionDateFilter.last30Days => 'Last 30 days',
    CorrectionDateFilter.all => 'All dates',
  };
}
