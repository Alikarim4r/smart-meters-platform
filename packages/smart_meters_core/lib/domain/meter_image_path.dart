/// Storage bucket for meter reading photos (private).
const kMeterImagesBucket = 'meter-images';

/// Watermark format version stamped into image metadata flow.
const kPhotoWatermarkVersion = 'v1';

/// Builds storage object path:
/// `{organization_id}/{site_id}/{category_code}/{reading_date}/{meter_id}/{timestamp}.jpg`
String buildMeterImageStoragePath({
  required String organizationId,
  required String siteId,
  required String categoryCode,
  required String readingDate,
  required String meterId,
  required DateTime capturedAt,
}) {
  final qatar = capturedAt.toUtc().add(const Duration(hours: 3));
  final y = qatar.year.toString().padLeft(4, '0');
  final m = qatar.month.toString().padLeft(2, '0');
  final d = qatar.day.toString().padLeft(2, '0');
  final h = qatar.hour.toString().padLeft(2, '0');
  final min = qatar.minute.toString().padLeft(2, '0');
  final sec = qatar.second.toString().padLeft(2, '0');
  final timestamp = '$y$m${d}_$h$min$sec';
  return '$organizationId/$siteId/$categoryCode/$readingDate/$meterId/$timestamp.jpg';
}

String formatQatarCaptureTimestamp(DateTime capturedAtUtc) {
  final qatar = capturedAtUtc.toUtc().add(const Duration(hours: 3));
  final y = qatar.year.toString().padLeft(4, '0');
  final m = qatar.month.toString().padLeft(2, '0');
  final d = qatar.day.toString().padLeft(2, '0');
  final h = qatar.hour.toString().padLeft(2, '0');
  final min = qatar.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min Asia/Qatar';
}
