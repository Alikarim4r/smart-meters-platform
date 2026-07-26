import 'package:smart_meters_core/smart_meters_core.dart';

enum ReadingPhotoSource {
  camera,
  gallery;

  String get label {
    switch (this) {
      case ReadingPhotoSource.camera:
        return 'Camera';
      case ReadingPhotoSource.gallery:
        return 'Gallery';
    }
  }

  static ReadingPhotoSource? fromDb(String? value) {
    if (value == null) {
      return null;
    }
    return ReadingPhotoSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => throw ArgumentError('Unknown photo source: $value'),
    );
  }
}

enum PhotoUploadStatus {
  none,
  attachedLocally,
  uploading,
  uploaded,
  failed;

  String get label {
    switch (this) {
      case PhotoUploadStatus.none:
        return 'No photo';
      case PhotoUploadStatus.attachedLocally:
        return 'Photo attached locally';
      case PhotoUploadStatus.uploading:
        return 'Uploading photo';
      case PhotoUploadStatus.uploaded:
        return 'Photo uploaded';
      case PhotoUploadStatus.failed:
        return 'Upload failed';
    }
  }

  static PhotoUploadStatus fromDb(String value) {
    return PhotoUploadStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PhotoUploadStatus.none,
    );
  }
}

class ReadingPhotoContext {
  const ReadingPhotoContext({
    this.organizationName,
    required this.siteName,
    required this.zoneName,
    required this.meterName,
    required this.meterCode,
    required this.categoryName,
    required this.readingDate,
    required this.technicianLabel,
    required this.source,
    required this.capturedAt,
  });

  final String? organizationName;
  final String siteName;
  final String zoneName;
  final String meterName;
  final String meterCode;
  final String categoryName;
  final String readingDate;
  final String technicianLabel;
  final ReadingPhotoSource source;
  final DateTime capturedAt;

  List<String> watermarkLines() {
    return [
      if (organizationName != null && organizationName!.trim().isNotEmpty)
        organizationName!.trim(),
      '$siteName | $zoneName',
      'Meter: $meterName ($meterCode)',
      'Category: $categoryName',
      'Reading date: $readingDate',
      'Captured: ${formatQatarCaptureTimestamp(capturedAt)}',
      'User: $technicianLabel',
      'Source: ${source.label}',
    ];
  }
}
