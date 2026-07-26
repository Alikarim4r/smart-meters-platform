import 'package:smart_meters_core/smart_meters_core.dart';

class CachedMeter {
  const CachedMeter({
    required this.meterId,
    required this.siteId,
    required this.category,
    required this.categoryId,
    required this.nameEn,
    required this.meterCode,
    required this.unit,
    this.location,
    this.locationEn,
    this.locationAr,
    this.lastReadingValue,
    this.lastReadingDate,
  });

  final String meterId;
  final String siteId;
  final String category;
  final String categoryId;
  final String nameEn;
  final String meterCode;
  final String? location;
  final String? locationEn;
  final String? locationAr;
  final String unit;
  final double? lastReadingValue;
  final String? lastReadingDate;

  Meter toMeter() {
    return Meter(
      id: meterId,
      siteId: siteId,
      meterCode: meterCode,
      nameEn: nameEn,
      nameAr: nameEn,
      categoryId: categoryId,
      sourceId: '',
      unitId: '',
      category: MeterCategory.fromDb(category),
      source: MeterSource.other,
      unit: MeterUnit.fromDb(unit),
      level: MeterLevel.main,
      unitToBaseFactor: 1,
      baseUnit: '',
      meterMultiplier: 1,
      meterKind: MeterKind.physical,
      calculationType: CalculationType.directReading,
      isActive: true,
      includeInDashboard: true,
      sortOrder: 0,
      location: locationEn ?? location,
      locationEn: locationEn ?? location,
      locationAr: locationAr,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'meterId': meterId,
      'siteId': siteId,
      'category': category,
      'categoryId': categoryId,
      'nameEn': nameEn,
      'meterCode': meterCode,
      'location': location,
      'locationEn': locationEn,
      'locationAr': locationAr,
      'unit': unit,
      'lastReadingValue': lastReadingValue,
      'lastReadingDate': lastReadingDate,
    };
  }

  factory CachedMeter.fromMap(Map<dynamic, dynamic> map) {
    return CachedMeter(
      meterId: map['meterId'] as String,
      siteId: map['siteId'] as String,
      category: map['category'] as String,
      categoryId: map['categoryId'] as String? ?? '',
      nameEn: map['nameEn'] as String,
      meterCode: map['meterCode'] as String,
      location: map['location'] as String?,
      locationEn: map['locationEn'] as String? ?? map['location'] as String?,
      locationAr: map['locationAr'] as String?,
      unit: map['unit'] as String,
      lastReadingValue: map['lastReadingValue'] == null
          ? null
          : (map['lastReadingValue'] as num).toDouble(),
      lastReadingDate: map['lastReadingDate'] as String?,
    );
  }

  factory CachedMeter.fromMeter({
    required Meter meter,
    String? location,
    MeterReading? lastReading,
  }) {
    final en = meter.locationEn ?? meter.location ?? location;
    final ar = meter.locationAr;
    return CachedMeter(
      meterId: meter.id,
      siteId: meter.siteId,
      category: meter.categoryCode,
      categoryId: meter.categoryId,
      nameEn: meter.nameEn,
      meterCode: meter.meterCode,
      location: en,
      locationEn: en,
      locationAr: ar,
      unit: meter.unit.dbValue,
      lastReadingValue: lastReading?.rawValue,
      lastReadingDate: lastReading == null
          ? null
          : formatBusinessDate(lastReading.readingDate),
    );
  }
}

class CachedSite {
  const CachedSite({
    required this.id,
    required this.organizationId,
    required this.nameEn,
    this.location,
    this.zoneName,
  });

  final String id;
  final String organizationId;
  final String nameEn;
  final String? location;
  final String? zoneName;

  Site toSite() {
    return Site(
      id: id,
      organizationId: organizationId,
      nameEn: nameEn,
      nameAr: nameEn,
      siteType: SiteType.other,
      isActive: true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'organizationId': organizationId,
        'nameEn': nameEn,
        'location': location,
        'zoneName': zoneName,
      };

  factory CachedSite.fromMap(Map<dynamic, dynamic> map) => CachedSite(
        id: map['id'] as String,
        organizationId: map['organizationId'] as String? ?? '',
        nameEn: map['nameEn'] as String,
        location: map['location'] as String?,
        zoneName: map['zoneName'] as String?,
      );

  factory CachedSite.fromSite(Site site) => CachedSite(
        id: site.id,
        organizationId: site.organizationId,
        nameEn: site.nameEn,
        location: site.location,
        zoneName: site.zone?.nameEn,
      );
}
