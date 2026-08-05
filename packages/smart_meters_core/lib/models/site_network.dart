/// Legacy 031 site network graph models (nodes/edges).
///
/// Deprecated for new work: prefer UtilityNetworkSnapshot /
/// UtilityNetworkRepository (v2 Asset→Port→Connection). Kept for
/// Admin/Dashboard until Phase C UI cutover. No dual-write.

enum NetworkNodeKind {
  meter('meter'),
  tank('tank'),
  tankerDischarge('tanker_discharge'),
  groundDrain('ground_drain');

  const NetworkNodeKind(this.dbValue);
  final String dbValue;

  static NetworkNodeKind fromDb(String value) {
    return NetworkNodeKind.values.firstWhere(
      (k) => k.dbValue == value,
      orElse: () => throw ArgumentError('Unknown network_node_kind: $value'),
    );
  }

  String label({required bool isAr}) => switch (this) {
    NetworkNodeKind.meter => isAr ? 'عداد' : 'Meter',
    NetworkNodeKind.tank => isAr ? 'خزان' : 'Tank',
    NetworkNodeKind.tankerDischarge => isAr ? 'صرف تانكر' : 'Tanker discharge',
    NetworkNodeKind.groundDrain => isAr ? 'صرف أرضي' : 'Ground drain',
  };
}

enum NetworkEdgeKind {
  supply('supply'),
  pour('pour'),
  overflow('overflow'),
  discharge('discharge');

  const NetworkEdgeKind(this.dbValue);
  final String dbValue;

  static NetworkEdgeKind fromDb(String value) {
    return NetworkEdgeKind.values.firstWhere(
      (k) => k.dbValue == value,
      orElse: () => throw ArgumentError('Unknown network_edge_kind: $value'),
    );
  }
}

/// Infer edge kind from endpoint node kinds (v1 water topology).
NetworkEdgeKind inferNetworkEdgeKind({
  required NetworkNodeKind from,
  required NetworkNodeKind to,
}) {
  if (to == NetworkNodeKind.tankerDischarge ||
      to == NetworkNodeKind.groundDrain) {
    return NetworkEdgeKind.discharge;
  }
  if (from == NetworkNodeKind.meter && to == NetworkNodeKind.meter) {
    return NetworkEdgeKind.supply;
  }
  if (from == NetworkNodeKind.meter && to == NetworkNodeKind.tank) {
    return NetworkEdgeKind.pour;
  }
  if (from == NetworkNodeKind.tank) {
    return NetworkEdgeKind.overflow;
  }
  return NetworkEdgeKind.supply;
}

class SiteNetworkNode {
  const SiteNetworkNode({
    required this.id,
    required this.siteId,
    required this.categoryId,
    required this.kind,
    this.refMeterId,
    this.refTankId,
    this.labelEn,
    this.labelAr,
    required this.posX,
    required this.posY,
    this.isActive = true,
    this.meterCode,
    this.meterNameEn,
    this.meterNameAr,
    this.tankNameEn,
    this.tankNameAr,
  });

  final String id;
  final String siteId;
  final String categoryId;
  final NetworkNodeKind kind;
  final String? refMeterId;
  final String? refTankId;
  final String? labelEn;
  final String? labelAr;
  final double posX;
  final double posY;
  final bool isActive;
  final String? meterCode;
  final String? meterNameEn;
  final String? meterNameAr;
  final String? tankNameEn;
  final String? tankNameAr;

  String displayTitle({required bool isAr}) {
    switch (kind) {
      case NetworkNodeKind.meter:
        final name = isAr && (meterNameAr?.trim().isNotEmpty ?? false)
            ? meterNameAr!
            : (meterNameEn ?? meterCode ?? 'Meter');
        return name;
      case NetworkNodeKind.tank:
        final name = isAr && (tankNameAr?.trim().isNotEmpty ?? false)
            ? tankNameAr!
            : (tankNameEn ?? 'Tank');
        return name;
      case NetworkNodeKind.tankerDischarge:
      case NetworkNodeKind.groundDrain:
        final en = labelEn?.trim() ?? '';
        final ar = labelAr?.trim() ?? '';
        if (isAr && ar.isNotEmpty) return ar;
        if (en.isNotEmpty) return en;
        return kind.label(isAr: isAr);
    }
  }

  String? displaySubtitle({required bool isAr}) {
    if (kind == NetworkNodeKind.meter && meterCode != null) {
      return meterCode;
    }
    return null;
  }

  SiteNetworkNode copyWith({
    double? posX,
    double? posY,
    String? labelEn,
    String? labelAr,
  }) {
    return SiteNetworkNode(
      id: id,
      siteId: siteId,
      categoryId: categoryId,
      kind: kind,
      refMeterId: refMeterId,
      refTankId: refTankId,
      labelEn: labelEn ?? this.labelEn,
      labelAr: labelAr ?? this.labelAr,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      isActive: isActive,
      meterCode: meterCode,
      meterNameEn: meterNameEn,
      meterNameAr: meterNameAr,
      tankNameEn: tankNameEn,
      tankNameAr: tankNameAr,
    );
  }

  factory SiteNetworkNode.fromJson(Map<String, dynamic> json) {
    final meterJson = json['meters'];
    final tankJson = json['site_tanks'];
    String? meterCode;
    String? meterNameEn;
    String? meterNameAr;
    String? tankNameEn;
    String? tankNameAr;
    if (meterJson is Map) {
      meterCode = meterJson['meter_code'] as String?;
      meterNameEn = meterJson['name_en'] as String?;
      meterNameAr = meterJson['name_ar'] as String?;
    }
    if (tankJson is Map) {
      tankNameEn = tankJson['name_en'] as String?;
      tankNameAr = tankJson['name_ar'] as String?;
    }
    return SiteNetworkNode(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      categoryId: json['category_id'] as String,
      kind: NetworkNodeKind.fromDb(json['kind'] as String),
      refMeterId: json['ref_meter_id'] as String?,
      refTankId: json['ref_tank_id'] as String?,
      labelEn: json['label_en'] as String?,
      labelAr: json['label_ar'] as String?,
      posX: (json['pos_x'] as num?)?.toDouble() ?? 0,
      posY: (json['pos_y'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      meterCode: meterCode,
      meterNameEn: meterNameEn,
      meterNameAr: meterNameAr,
      tankNameEn: tankNameEn,
      tankNameAr: tankNameAr,
    );
  }
}

class SiteNetworkEdge {
  const SiteNetworkEdge({
    required this.id,
    required this.siteId,
    required this.categoryId,
    required this.fromNodeId,
    required this.toNodeId,
    required this.edgeKind,
  });

  final String id;
  final String siteId;
  final String categoryId;
  final String fromNodeId;
  final String toNodeId;
  final NetworkEdgeKind edgeKind;

  factory SiteNetworkEdge.fromJson(Map<String, dynamic> json) {
    return SiteNetworkEdge(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      categoryId: json['category_id'] as String,
      fromNodeId: json['from_node_id'] as String,
      toNodeId: json['to_node_id'] as String,
      edgeKind: NetworkEdgeKind.fromDb(json['edge_kind'] as String),
    );
  }
}

class SiteNetworkViewport {
  const SiteNetworkViewport({
    required this.siteId,
    required this.categoryId,
    this.scale = 1,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final String siteId;
  final String categoryId;
  final double scale;
  final double offsetX;
  final double offsetY;

  factory SiteNetworkViewport.fromJson(Map<String, dynamic> json) {
    return SiteNetworkViewport(
      siteId: json['site_id'] as String,
      categoryId: json['category_id'] as String,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      offsetX: (json['offset_x'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offset_y'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SiteNetworkGraph {
  const SiteNetworkGraph({
    required this.nodes,
    required this.edges,
    this.viewport,
  });

  final List<SiteNetworkNode> nodes;
  final List<SiteNetworkEdge> edges;
  final SiteNetworkViewport? viewport;

  SiteNetworkNode? nodeById(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }
}
