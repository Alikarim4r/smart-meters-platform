import 'alert_models.dart';

/// Submission/readiness state for a meter on the selected business date.
enum MeterReadingCardStatus { submittedOnDate, pendingOnDate, noReadingOnDate }

/// Dashboard meter card row with previous/latest/consumption for one business date.
class MeterReadingCardData {
  const MeterReadingCardData({
    required this.meterId,
    required this.meterCode,
    required this.meterName,
    required this.categoryName,
    required this.sourceName,
    required this.sourceCode,
    required this.unitLabel,
    required this.status,
    required this.isActive,
    required this.isMain,
    this.meterNameAr = '',
    this.parentMeterId,
    this.parentMeterCode,
    this.parentMeterName,
    this.previousValue,
    this.previousDate,
    this.latestValue,
    this.latestDate,
    this.latestEnteredAt,
    this.consumptionValue,
    this.imageStoragePath,
    this.hasPhoto = false,
    this.previousImageStoragePath,
    this.previousHasPhoto = false,
    this.previousReadingId,
    this.hasAlert = false,
    this.alertSeverity,
    this.isCorrected = false,
    this.hasNegativeConsumption = false,
    this.latestReadingId,
  });

  final String meterId;
  final String meterCode;
  final String meterName;
  final String meterNameAr;
  final String categoryName;
  final String sourceName;
  final String sourceCode;
  final String unitLabel;
  final MeterReadingCardStatus status;
  final bool isActive;
  final bool isMain;
  final String? parentMeterId;
  final String? parentMeterCode;
  final String? parentMeterName;
  final double? previousValue;
  final DateTime? previousDate;
  final double? latestValue;
  final DateTime? latestDate;
  final DateTime? latestEnteredAt;
  final double? consumptionValue;
  final String? imageStoragePath;
  final bool hasPhoto;
  final String? previousImageStoragePath;
  final bool previousHasPhoto;
  final String? previousReadingId;
  final bool hasAlert;
  final AlertSeverity? alertSeverity;
  final bool isCorrected;
  final bool hasNegativeConsumption;
  final String? latestReadingId;

  bool get hasLatestOnDate => latestValue != null && latestDate != null;

  bool get hasPrevious => previousValue != null && previousDate != null;

  bool get hasConsumption =>
      consumptionValue != null && hasLatestOnDate && hasPrevious;

  MeterReadingCardData copyWithAlert({
    required bool hasAlert,
    AlertSeverity? alertSeverity,
  }) {
    return MeterReadingCardData(
      meterId: meterId,
      meterCode: meterCode,
      meterName: meterName,
      meterNameAr: meterNameAr,
      categoryName: categoryName,
      sourceName: sourceName,
      sourceCode: sourceCode,
      unitLabel: unitLabel,
      status: status,
      isActive: isActive,
      isMain: isMain,
      parentMeterId: parentMeterId,
      parentMeterCode: parentMeterCode,
      parentMeterName: parentMeterName,
      previousValue: previousValue,
      previousDate: previousDate,
      latestValue: latestValue,
      latestDate: latestDate,
      latestEnteredAt: latestEnteredAt,
      consumptionValue: consumptionValue,
      imageStoragePath: imageStoragePath,
      hasPhoto: hasPhoto,
      previousImageStoragePath: previousImageStoragePath,
      previousHasPhoto: previousHasPhoto,
      previousReadingId: previousReadingId,
      hasAlert: hasAlert,
      alertSeverity: alertSeverity,
      isCorrected: isCorrected,
      hasNegativeConsumption: hasNegativeConsumption,
      latestReadingId: latestReadingId,
    );
  }
}
