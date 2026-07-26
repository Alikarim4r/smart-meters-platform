class MeterReading {
  const MeterReading({
    required this.id,
    required this.siteId,
    required this.meterId,
    required this.readingDate,
    required this.rawValue,
    required this.normalizedValue,
    this.note,
    this.imageStoragePath,
    required this.enteredAt,
  });

  final String id;
  final String siteId;
  final String meterId;
  final DateTime readingDate;
  final double rawValue;
  final double normalizedValue;
  final String? note;

  /// Storage object path in `meter-images` bucket (stored in `image_url` column).
  final String? imageStoragePath;
  final DateTime enteredAt;

  bool get hasPhoto =>
      imageStoragePath != null && imageStoragePath!.trim().isNotEmpty;

  factory MeterReading.fromJson(Map<String, dynamic> json) {
    return MeterReading(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      meterId: json['meter_id'] as String,
      readingDate: DateTime.parse(json['reading_date'] as String),
      rawValue: _toDouble(json['raw_value']),
      normalizedValue: _toDouble(json['normalized_value']),
      note: json['note'] as String?,
      imageStoragePath: json['image_url'] as String?,
      enteredAt: DateTime.parse(json['entered_at'] as String),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.parse(value as String);
  }
}
