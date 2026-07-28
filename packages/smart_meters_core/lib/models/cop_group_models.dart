/// Admin/dashboard detail for a site COP/EER efficiency group.
class CopGroupDetail {
  const CopGroupDetail({
    required this.id,
    required this.siteId,
    required this.nameEn,
    required this.nameAr,
    this.description,
    this.isActive = true,
    this.btuMeterIds = const [],
    this.electricityMeterIds = const [],
  });

  final String id;
  final String siteId;
  final String nameEn;
  final String nameAr;
  final String? description;
  final bool isActive;
  final List<String> btuMeterIds;
  final List<String> electricityMeterIds;
}

class CopGroupUpsertInput {
  const CopGroupUpsertInput({
    this.id,
    required this.siteId,
    required this.nameEn,
    required this.nameAr,
    this.description,
    this.isActive = true,
    this.btuMeterIds = const [],
    this.electricityMeterIds = const [],
  });

  final String? id;
  final String siteId;
  final String nameEn;
  final String nameAr;
  final String? description;
  final bool isActive;
  final List<String> btuMeterIds;
  final List<String> electricityMeterIds;
}
