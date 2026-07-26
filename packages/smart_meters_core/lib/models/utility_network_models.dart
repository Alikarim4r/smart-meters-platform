import 'utility_network_lookups.dart';

String? _str(dynamic v) => v?.toString();
double? _dbl(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool _bool(dynamic v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v == null) return fallback;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

Map<String, dynamic> _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic v) {
  if (v is List) return v;
  return const [];
}

class FacilityArea {
  const FacilityArea({
    required this.id,
    required this.siteId,
    this.parentAreaId,
    required this.areaType,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String siteId;
  final String? parentAreaId;
  final UtilityLookup areaType;
  final String code;
  final String nameEn;
  final String nameAr;
  final int sortOrder;
  final bool isActive;

  factory FacilityArea.fromJson(Map<String, dynamic> json) {
    return FacilityArea(
      id: _str(json['id']) ?? '',
      siteId: _str(json['site_id']) ?? '',
      parentAreaId: _str(json['parent_area_id']),
      areaType: UtilityFacilityAreaType.parse(_str(json['area_type'])),
      code: _str(json['code']) ?? '',
      nameEn: _str(json['name_en']) ?? '',
      nameAr: _str(json['name_ar']) ?? '',
      sortOrder: _int(json['sort_order']) ?? 0,
      isActive: _bool(json['is_active'], fallback: true),
    );
  }
}

class UtilityNetworkMember {
  const UtilityNetworkMember({required this.networkId, required this.siteId});

  final String networkId;
  final String siteId;

  factory UtilityNetworkMember.fromJson(Map<String, dynamic> json) {
    return UtilityNetworkMember(
      networkId: _str(json['network_id']) ?? '',
      siteId: _str(json['site_id']) ?? '',
    );
  }
}

class UtilityNetwork {
  const UtilityNetwork({
    required this.id,
    required this.categoryId,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.draftRevisionId,
    this.publishedRevisionId,
    this.members = const [],
  });

  final String id;
  final String categoryId;
  final String code;
  final String nameEn;
  final String nameAr;
  final String? draftRevisionId;
  final String? publishedRevisionId;
  final List<UtilityNetworkMember> members;

  factory UtilityNetwork.fromJson(Map<String, dynamic> json) {
    return UtilityNetwork(
      id: _str(json['id'] ?? json['network_id']) ?? '',
      categoryId: _str(json['category_id']) ?? '',
      code: _str(json['code']) ?? '',
      nameEn: _str(json['name_en']) ?? '',
      nameAr: _str(json['name_ar']) ?? '',
      draftRevisionId: _str(json['draft_revision_id']),
      publishedRevisionId: _str(json['published_revision_id']),
      members: _list(
        json['members'],
      ).map((e) => UtilityNetworkMember.fromJson(_map(e))).toList(),
    );
  }
}

/// Compact network row returned by `list_utility_networks_for_site`.
class UtilityNetworkSummary {
  const UtilityNetworkSummary({
    required this.id,
    required this.categoryId,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    required this.status,
    this.draftRevisionId,
    this.publishedRevisionId,
    this.defaultViewId,
    this.memberCount = 0,
  });

  final String id;
  final String categoryId;
  final String code;
  final String nameEn;
  final String nameAr;
  final String status;
  final String? draftRevisionId;
  final String? publishedRevisionId;
  final String? defaultViewId;
  final int memberCount;

  factory UtilityNetworkSummary.fromJson(Map<String, dynamic> json) {
    return UtilityNetworkSummary(
      id: _str(json['id'] ?? json['network_id']) ?? '',
      categoryId: _str(json['category_id']) ?? '',
      code: _str(json['code']) ?? '',
      nameEn: _str(json['name_en']) ?? '',
      nameAr: _str(json['name_ar']) ?? '',
      status: _str(json['status']) ?? 'empty',
      draftRevisionId: _str(json['draft_revision_id']),
      publishedRevisionId: _str(json['published_revision_id']),
      defaultViewId: _str(json['default_view_id']),
      memberCount: _int(json['member_count']) ?? 0,
    );
  }
}

class UtilityNetworkRevision {
  const UtilityNetworkRevision({
    required this.id,
    required this.networkId,
    required this.status,
    required this.lockVersion,
    this.basedOnRevisionId,
    this.publishedAt,
    this.notes,
  });

  final String id;
  final String networkId;
  final UtilityLookup status;
  final int lockVersion;
  final String? basedOnRevisionId;
  final DateTime? publishedAt;
  final String? notes;

  bool get isDraft => status.dbValue == UtilityRevisionStatus.draft.dbValue;
  bool get isPublished =>
      status.dbValue == UtilityRevisionStatus.published.dbValue;

  factory UtilityNetworkRevision.fromJson(Map<String, dynamic> json) {
    return UtilityNetworkRevision(
      id: _str(json['id']) ?? '',
      networkId: _str(json['network_id']) ?? '',
      status: UtilityRevisionStatus.parse(_str(json['status'])),
      lockVersion: _int(json['lock_version']) ?? 1,
      basedOnRevisionId: _str(json['based_on_revision_id']),
      publishedAt: DateTime.tryParse(_str(json['published_at']) ?? ''),
      notes: _str(json['notes']),
    );
  }

  UtilityNetworkRevision copyWith({
    UtilityLookup? status,
    int? lockVersion,
    String? basedOnRevisionId,
    DateTime? publishedAt,
    String? notes,
  }) {
    return UtilityNetworkRevision(
      id: id,
      networkId: networkId,
      status: status ?? this.status,
      lockVersion: lockVersion ?? this.lockVersion,
      basedOnRevisionId: basedOnRevisionId ?? this.basedOnRevisionId,
      publishedAt: publishedAt ?? this.publishedAt,
      notes: notes ?? this.notes,
    );
  }
}

class UtilityAssetPort {
  const UtilityAssetPort({
    required this.id,
    required this.assetId,
    required this.code,
    required this.direction,
    required this.portRole,
    this.nameEn,
    this.nameAr,
    this.properties = const {},
  });

  final String id;
  final String assetId;
  final String code;
  final UtilityLookup direction;
  final UtilityLookup portRole;
  final String? nameEn;
  final String? nameAr;
  final Map<String, dynamic> properties;

  factory UtilityAssetPort.fromJson(Map<String, dynamic> json) {
    return UtilityAssetPort(
      id: _str(json['id']) ?? '',
      assetId: _str(json['asset_id']) ?? '',
      code: _str(json['code']) ?? '',
      direction: UtilityPortDirection.parse(_str(json['direction'])),
      portRole: UtilityPortRole.parse(_str(json['port_role'])),
      nameEn: _str(json['name_en']),
      nameAr: _str(json['name_ar']),
      properties: _map(json['properties']),
    );
  }
}

class UtilityAsset {
  const UtilityAsset({
    required this.id,
    required this.siteId,
    required this.assetType,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.serviceType,
    this.facilityAreaId,
    this.refMeterId,
    this.refTankId,
    this.meterRole,
    this.ports = const [],
    this.properties = const {},
  });

  final String id;
  final String siteId;
  final UtilityLookup assetType;
  final String code;
  final String nameEn;
  final String nameAr;
  final UtilityLookup? serviceType;
  final String? facilityAreaId;
  final String? refMeterId;
  final String? refTankId;
  final UtilityLookup? meterRole;
  final List<UtilityAssetPort> ports;
  final Map<String, dynamic> properties;

  factory UtilityAsset.fromJson(Map<String, dynamic> json) {
    final portsRaw = json['ports'] ?? json['asset_ports'];
    return UtilityAsset(
      id: _str(json['id'] ?? json['asset_id']) ?? '',
      siteId: _str(json['site_id']) ?? '',
      assetType: UtilityAssetType.parse(_str(json['asset_type'])),
      code: _str(json['code']) ?? '',
      nameEn: _str(json['name_en']) ?? '',
      nameAr: _str(json['name_ar']) ?? '',
      serviceType: json['service_type'] == null
          ? null
          : UtilityServiceType.parse(_str(json['service_type'])),
      facilityAreaId: _str(json['facility_area_id']),
      refMeterId: _str(json['ref_meter_id']),
      refTankId: _str(json['ref_tank_id']),
      meterRole: json['meter_role'] == null
          ? null
          : UtilityMeterRole.parse(_str(json['meter_role'])),
      ports: _list(
        portsRaw,
      ).map((e) => UtilityAssetPort.fromJson(_map(e))).toList(),
      properties: _map(json['properties']),
    );
  }
}

class UtilityRevisionNode {
  const UtilityRevisionNode({
    required this.id,
    required this.revisionId,
    required this.assetId,
    this.asset,
    this.legacyNodeId,
  });

  final String id;
  final String revisionId;
  final String assetId;
  final UtilityAsset? asset;
  final String? legacyNodeId;

  factory UtilityRevisionNode.fromJson(Map<String, dynamic> json) {
    final assetJson = json['asset'] ?? json['assets'];
    return UtilityRevisionNode(
      id: _str(json['id'] ?? json['node_id']) ?? '',
      revisionId: _str(json['revision_id']) ?? '',
      assetId: _str(json['asset_id']) ?? '',
      asset: assetJson == null
          ? (json['asset_type'] != null ? UtilityAsset.fromJson(json) : null)
          : UtilityAsset.fromJson(_map(assetJson)),
      legacyNodeId: _str(json['legacy_node_id']),
    );
  }
}

class UtilityConnection {
  const UtilityConnection({
    required this.id,
    required this.revisionId,
    required this.fromNodeId,
    required this.fromPortId,
    required this.toNodeId,
    required this.toPortId,
    required this.connectionKind,
    required this.transportMode,
    required this.operatingMode,
    required this.legacySyncStatus,
    this.waterType,
    this.isConsumptive = true,
    this.properties = const {},
  });

  final String id;
  final String revisionId;
  final String fromNodeId;
  final String fromPortId;
  final String toNodeId;
  final String toPortId;
  final UtilityLookup connectionKind;
  final UtilityLookup transportMode;
  final UtilityLookup operatingMode;
  final UtilityLookup legacySyncStatus;
  final String? waterType;
  final bool isConsumptive;
  final Map<String, dynamic> properties;

  factory UtilityConnection.fromJson(Map<String, dynamic> json) {
    return UtilityConnection(
      id: _str(json['id'] ?? json['connection_id']) ?? '',
      revisionId: _str(json['revision_id']) ?? '',
      fromNodeId: _str(json['from_node_id']) ?? '',
      fromPortId: _str(json['from_port_id']) ?? '',
      toNodeId: _str(json['to_node_id']) ?? '',
      toPortId: _str(json['to_port_id']) ?? '',
      connectionKind: UtilityConnectionKind.parse(
        _str(json['connection_kind']),
      ),
      transportMode: UtilityTransportMode.parse(_str(json['transport_mode'])),
      operatingMode: UtilityOperatingMode.parse(_str(json['operating_mode'])),
      legacySyncStatus: UtilityLegacySyncStatus.parse(
        _str(json['legacy_sync_status']),
      ),
      waterType: _str(json['water_type']),
      isConsumptive: _bool(json['is_consumptive'], fallback: true),
      properties: _map(json['properties']),
    );
  }
}

class UtilityNetworkView {
  const UtilityNetworkView({
    required this.id,
    required this.networkId,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.viewKind,
    this.isDefault = false,
  });

  final String id;
  final String networkId;
  final String code;
  final String nameEn;
  final String nameAr;
  final String? viewKind;
  final bool isDefault;

  factory UtilityNetworkView.fromJson(Map<String, dynamic> json) {
    return UtilityNetworkView(
      id: _str(json['id'] ?? json['view_id']) ?? '',
      networkId: _str(json['network_id']) ?? '',
      code: _str(json['code']) ?? '',
      nameEn: _str(json['name_en']) ?? '',
      nameAr: _str(json['name_ar']) ?? '',
      viewKind: _str(json['view_kind']),
      isDefault: _bool(json['is_default']),
    );
  }
}

class UtilityViewNode {
  const UtilityViewNode({
    required this.revisionId,
    required this.viewId,
    required this.nodeId,
    required this.posX,
    required this.posY,
    this.width,
    this.height,
    this.collapsed = false,
  });

  final String revisionId;
  final String viewId;
  final String nodeId;
  final double posX;
  final double posY;
  final double? width;
  final double? height;
  final bool collapsed;

  factory UtilityViewNode.fromJson(Map<String, dynamic> json) {
    return UtilityViewNode(
      revisionId: _str(json['revision_id']) ?? '',
      viewId: _str(json['view_id']) ?? '',
      nodeId: _str(json['node_id']) ?? '',
      posX: _dbl(json['pos_x']) ?? 0,
      posY: _dbl(json['pos_y']) ?? 0,
      width: _dbl(json['width']),
      height: _dbl(json['height']),
      collapsed: _bool(json['collapsed']),
    );
  }

  Map<String, dynamic> toRpcPosition() => {
    'node_id': nodeId,
    'pos_x': posX,
    'pos_y': posY,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    'collapsed': collapsed,
  };

  UtilityViewNode copyWith({
    double? posX,
    double? posY,
    double? width,
    double? height,
    bool? collapsed,
  }) {
    return UtilityViewNode(
      revisionId: revisionId,
      viewId: viewId,
      nodeId: nodeId,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      width: width ?? this.width,
      height: height ?? this.height,
      collapsed: collapsed ?? this.collapsed,
    );
  }
}

class UtilityNetworkSnapshot {
  const UtilityNetworkSnapshot({
    required this.network,
    required this.revision,
    this.nodes = const [],
    this.connections = const [],
    this.views = const [],
    this.placements = const [],
  });

  final UtilityNetwork network;
  final UtilityNetworkRevision revision;
  final List<UtilityRevisionNode> nodes;
  final List<UtilityConnection> connections;
  final List<UtilityNetworkView> views;
  final List<UtilityViewNode> placements;

  UtilityNetworkSnapshot copyWith({
    UtilityNetwork? network,
    UtilityNetworkRevision? revision,
    List<UtilityRevisionNode>? nodes,
    List<UtilityConnection>? connections,
    List<UtilityNetworkView>? views,
    List<UtilityViewNode>? placements,
  }) {
    return UtilityNetworkSnapshot(
      network: network ?? this.network,
      revision: revision ?? this.revision,
      nodes: nodes ?? this.nodes,
      connections: connections ?? this.connections,
      views: views ?? this.views,
      placements: placements ?? this.placements,
    );
  }

  factory UtilityNetworkSnapshot.fromJson(Map<String, dynamic> json) {
    final networkJson = _map(json['network'] ?? json);
    final revisionJson = _map(json['revision']);
    final revision = UtilityNetworkRevision.fromJson(
      revisionJson.isEmpty ? networkJson : revisionJson,
    );
    final network = UtilityNetwork.fromJson({
      ...networkJson,
      'members': json['members'] ?? networkJson['members'],
    });
    return UtilityNetworkSnapshot(
      network: network,
      revision: revision,
      nodes: _list(json['nodes']).map((e) {
        final m = _map(e);
        m.putIfAbsent('revision_id', () => revision.id);
        return UtilityRevisionNode.fromJson(m);
      }).toList(),
      connections: _list(json['connections']).map((e) {
        final m = _map(e);
        m.putIfAbsent('revision_id', () => revision.id);
        return UtilityConnection.fromJson(m);
      }).toList(),
      views: _list(
        json['views'],
      ).map((e) => UtilityNetworkView.fromJson(_map(e))).toList(),
      placements: _list(json['placements'] ?? json['view_nodes']).map((e) {
        final m = _map(e);
        m.putIfAbsent('revision_id', () => revision.id);
        return UtilityViewNode.fromJson(m);
      }).toList(),
    );
  }
}

class AvailableNetworkMeter {
  const AvailableNetworkMeter({
    required this.meterId,
    required this.siteId,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.state,
    this.facilityArea,
    this.meterRole,
    this.assetId,
    this.revisionNodeId,
    this.viewNodeId,
    this.upstreamMeter,
    this.downstreamCount = 0,
    this.legacySyncStatus,
  });

  final String meterId;
  final String siteId;
  final String code;
  final String nameAr;
  final String nameEn;
  final FacilityArea? facilityArea;
  final UtilityLookup? meterRole;
  final UtilityLookup state;
  final String? assetId;
  final String? revisionNodeId;
  final String? viewNodeId;
  final AvailableNetworkMeter? upstreamMeter;
  final int downstreamCount;
  final UtilityLookup? legacySyncStatus;

  factory AvailableNetworkMeter.fromJson(Map<String, dynamic> json) {
    final areaJson = json['facility_area'];
    final upstreamJson = json['upstream_meter'];
    return AvailableNetworkMeter(
      meterId: _str(json['meter_id'] ?? json['id']) ?? '',
      siteId: _str(json['site_id']) ?? '',
      code: _str(json['meter_code'] ?? json['code']) ?? '',
      nameAr: _str(json['name_ar']) ?? '',
      nameEn: _str(json['name_en']) ?? '',
      facilityArea: areaJson == null
          ? null
          : FacilityArea.fromJson(_map(areaJson)),
      meterRole: json['meter_role'] == null && json['meter_level'] == null
          ? null
          : UtilityMeterRole.parse(
              _str(json['meter_role'] ?? json['meter_level']),
            ),
      state: AvailableMeterState.parse(
        _str(json['availability_status'] ?? json['state']),
      ),
      assetId: _str(json['asset_id']),
      revisionNodeId: _str(json['node_id'] ?? json['revision_node_id']),
      viewNodeId: _str(json['view_node_id']),
      upstreamMeter: upstreamJson == null
          ? null
          : AvailableNetworkMeter.fromJson(_map(upstreamJson)),
      downstreamCount: _int(json['downstream_count']) ?? 0,
      legacySyncStatus: json['legacy_sync_status'] == null
          ? null
          : UtilityLegacySyncStatus.parse(_str(json['legacy_sync_status'])),
    );
  }
}

/// Tank picker row from [list_available_tanks_for_network].
class AvailableNetworkTank {
  const AvailableNetworkTank({
    required this.tankId,
    required this.siteId,
    required this.nameAr,
    required this.nameEn,
    required this.state,
    this.isActive = true,
    this.assetId,
    this.assetCode,
    this.serviceType,
    this.facilityAreaId,
    this.revisionNodeId,
  });

  final String tankId;
  final String siteId;
  final String nameAr;
  final String nameEn;
  final bool isActive;
  final String? assetId;
  final String? assetCode;
  final UtilityLookup? serviceType;
  final String? facilityAreaId;
  final String? revisionNodeId;
  final UtilityLookup state;

  factory AvailableNetworkTank.fromJson(Map<String, dynamic> json) {
    return AvailableNetworkTank(
      tankId: _str(json['tank_id'] ?? json['id']) ?? '',
      siteId: _str(json['site_id']) ?? '',
      nameAr: _str(json['name_ar']) ?? '',
      nameEn: _str(json['name_en']) ?? '',
      isActive: _bool(json['is_active'], fallback: true),
      assetId: _str(json['asset_id']),
      assetCode: _str(json['asset_code'] ?? json['code']),
      serviceType: json['service_type'] == null
          ? null
          : UtilityServiceType.parse(_str(json['service_type'])),
      facilityAreaId: _str(json['facility_area_id']),
      revisionNodeId: _str(json['node_id'] ?? json['revision_node_id']),
      state: AvailableMeterState.parse(
        _str(json['availability_status'] ?? json['state']),
      ),
    );
  }
}

class NetworkValidationIssue {
  const NetworkValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.connectionId,
    this.nodeId,
    this.details = const {},
  });

  final UtilityLookup severity;
  final String code;
  final String message;
  final String? connectionId;
  final String? nodeId;
  final Map<String, dynamic> details;

  factory NetworkValidationIssue.fromJson(Map<String, dynamic> json) {
    return NetworkValidationIssue(
      severity: UtilityValidationSeverity.parse(
        _str(json['severity'] ?? json['level']),
      ),
      code: _str(json['code']) ?? '',
      message: _str(json['message']) ?? '',
      connectionId: _str(json['connection_id']),
      nodeId: _str(json['node_id']),
      details: _map(json['details'] ?? json),
    );
  }
}

class NetworkMutationResult {
  const NetworkMutationResult({
    required this.lockVersion,
    this.status,
    this.meterId,
    this.assetId,
    this.nodeId,
    this.connectionId,
    this.raw = const {},
  });

  final int lockVersion;
  final String? status;
  final String? meterId;
  final String? assetId;
  final String? nodeId;
  final String? connectionId;
  final Map<String, dynamic> raw;

  factory NetworkMutationResult.fromJson(Map<String, dynamic> json) {
    return NetworkMutationResult(
      lockVersion: _int(json['lock_version']) ?? 0,
      status: _str(json['status']),
      meterId: _str(json['meter_id']),
      assetId: _str(json['asset_id']),
      nodeId: _str(json['node_id']),
      connectionId: _str(json['connection_id']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}
