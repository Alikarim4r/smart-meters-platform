import 'meter_reading.dart';

/// Reading row enriched for Excel/PDF export.
class DashboardExportReadingRow {
  const DashboardExportReadingRow({
    required this.reading,
    required this.siteName,
    required this.zoneName,
    required this.meterName,
    required this.meterCode,
    required this.categoryName,
    required this.unitLabel,
    required this.sourceName,
    this.enteredByName,
    this.enteredByEmail,
    this.dailyConsumption,
  });

  final MeterReading reading;
  final String siteName;
  final String zoneName;
  final String meterName;
  final String meterCode;
  final String categoryName;
  final String unitLabel;
  final String sourceName;
  final String? enteredByName;
  final String? enteredByEmail;
  final double? dailyConsumption;

  bool get hasPhoto => reading.hasPhoto;
}
