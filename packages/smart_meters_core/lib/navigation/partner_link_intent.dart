/// Parsed cross-app deep link target.
enum PartnerLinkKind {
  dashboardSite,
  entrySite,
  entryMeter,
  adminSite,
  adminMeter,
}

class PartnerLinkIntent {
  const PartnerLinkIntent({
    required this.kind,
    required this.siteId,
    this.meterId,
    this.categoryCode,
    this.readingDate,
    this.section,
  });

  final PartnerLinkKind kind;
  final String siteId;
  final String? meterId;
  final String? categoryCode;
  final String? readingDate;
  final String? section;
}
