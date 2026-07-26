/// Tolerant DB lookup values for utility network v2.
/// Unknown server values parse without throwing (isKnown == false).
class UtilityLookup {
  const UtilityLookup(this.dbValue, {this.isKnown = true});

  final String dbValue;
  final bool isKnown;

  @override
  bool operator ==(Object other) =>
      other is UtilityLookup && other.dbValue == dbValue;

  @override
  int get hashCode => dbValue.hashCode;

  @override
  String toString() => isKnown ? dbValue : 'UtilityLookup.unknown($dbValue)';
}

UtilityLookup _parseLookup(String? raw, Map<String, UtilityLookup> known) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) {
    return const UtilityLookup('', isKnown: false);
  }
  return known[value] ?? UtilityLookup(value, isKnown: false);
}

class UtilityAssetType {
  UtilityAssetType._();

  static const externalSource = UtilityLookup('external_source');
  static const meter = UtilityLookup('meter');
  static const tank = UtilityLookup('tank');
  static const pump = UtilityLookup('pump');
  static const filter = UtilityLookup('filter');
  static const treatmentUnit = UtilityLookup('treatment_unit');
  static const junction = UtilityLookup('junction');
  static const consumer = UtilityLookup('consumer');
  static const dischargePoint = UtilityLookup('discharge_point');
  static const tankerLoading = UtilityLookup('tanker_loading');
  static const buildingPortal = UtilityLookup('building_portal');
  static const coolingTower = UtilityLookup('cooling_tower');
  static const chiller = UtilityLookup('chiller');

  static final Map<String, UtilityLookup> _known = {
    for (final v in [
      externalSource,
      meter,
      tank,
      pump,
      filter,
      treatmentUnit,
      junction,
      consumer,
      dischargePoint,
      tankerLoading,
      buildingPortal,
      coolingTower,
      chiller,
    ])
      v.dbValue: v,
  };

  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class UtilityPortDirection {
  UtilityPortDirection._();
  static const inn = UtilityLookup('in');
  static const out = UtilityLookup('out');
  static const bidirectional = UtilityLookup('bidirectional');
  static final Map<String, UtilityLookup> _known = {
    inn.dbValue: inn,
    out.dbValue: out,
    bidirectional.dbValue: bidirectional,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class UtilityPortRole {
  UtilityPortRole._();
  static const inlet = UtilityLookup('inlet');
  static const outlet = UtilityLookup('outlet');
  static const product = UtilityLookup('product');
  static const reject = UtilityLookup('reject');
  static const overflow = UtilityLookup('overflow');
  static const washout = UtilityLookup('washout');
  static const drain = UtilityLookup('drain');
  static const emergency = UtilityLookup('emergency');
  static const tankerTransfer = UtilityLookup('tanker_transfer');
  static final Map<String, UtilityLookup> _known = {
    for (final v in [
      inlet,
      outlet,
      product,
      reject,
      overflow,
      washout,
      drain,
      emergency,
      tankerTransfer,
    ])
      v.dbValue: v,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class UtilityConnectionKind {
  UtilityConnectionKind._();
  static const supply = UtilityLookup('supply');
  static const transfer = UtilityLookup('transfer');
  static const overflow = UtilityLookup('overflow');
  static const washout = UtilityLookup('washout');
  static const drain = UtilityLookup('drain');
  static const discharge = UtilityLookup('discharge');
  static const tankerTransport = UtilityLookup('tanker_transport');
  static const bypass = UtilityLookup('bypass');
  static const recirculation = UtilityLookup('recirculation');

  /// Canonical DB values (matches site_utility_rev_conn_kind_check).
  static const List<UtilityLookup> values = [
    supply,
    transfer,
    overflow,
    washout,
    drain,
    discharge,
    tankerTransport,
    bypass,
    recirculation,
  ];

  static final Map<String, UtilityLookup> _known = {
    for (final v in values) v.dbValue: v,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class UtilityTransportMode {
  UtilityTransportMode._();
  static const pipe = UtilityLookup('pipe');
  static const tanker = UtilityLookup('tanker');
  static const openDrain = UtilityLookup('open_drain');
  static const other = UtilityLookup('other');

  /// Canonical DB values (matches site_utility_rev_conn_transport_check).
  static const List<UtilityLookup> values = [pipe, tanker, openDrain, other];

  static final Map<String, UtilityLookup> _known = {
    for (final v in values) v.dbValue: v,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class UtilityOperatingMode {
  UtilityOperatingMode._();
  static const normal = UtilityLookup('normal');
  static const standby = UtilityLookup('standby');
  static const emergency = UtilityLookup('emergency');
  static const seasonal = UtilityLookup('seasonal');
  static const maintenance = UtilityLookup('maintenance');

  /// Canonical DB values (matches site_utility_rev_conn_operating_check).
  static const List<UtilityLookup> values = [
    normal,
    standby,
    emergency,
    seasonal,
    maintenance,
  ];

  static final Map<String, UtilityLookup> _known = {
    for (final v in values) v.dbValue: v,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class UtilityLegacySyncStatus {
  UtilityLegacySyncStatus._();
  static const synced = UtilityLookup('synced');
  static const graphOnly = UtilityLookup('graph_only');
  static const conflict = UtilityLookup('conflict');
  static const unsupported = UtilityLookup('unsupported');
  static final Map<String, UtilityLookup> _known = {
    for (final v in [synced, graphOnly, conflict, unsupported]) v.dbValue: v,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class UtilityRevisionStatus {
  UtilityRevisionStatus._();
  static const draft = UtilityLookup('draft');
  static const published = UtilityLookup('published');
  static const archived = UtilityLookup('archived');
  static final Map<String, UtilityLookup> _known = {
    for (final v in [draft, published, archived]) v.dbValue: v,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class AvailableMeterState {
  AvailableMeterState._();
  static const notInNetwork = UtilityLookup('not_in_network');
  static const inNetworkNotInCurrentView = UtilityLookup(
    'in_network_not_in_current_view',
  );
  static const inCurrentView = UtilityLookup('in_current_view');
  static final Map<String, UtilityLookup> _known = {
    for (final v in [notInNetwork, inNetworkNotInCurrentView, inCurrentView])
      v.dbValue: v,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class UtilityValidationSeverity {
  UtilityValidationSeverity._();
  static const error = UtilityLookup('error');
  static const warning = UtilityLookup('warning');
  static final Map<String, UtilityLookup> _known = {
    error.dbValue: error,
    warning.dbValue: warning,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class UtilityFacilityAreaType {
  UtilityFacilityAreaType._();
  static const campus = UtilityLookup('campus');
  static const building = UtilityLookup('building');
  static const floor = UtilityLookup('floor');
  static const zone = UtilityLookup('zone');
  static const plantRoom = UtilityLookup('plant_room');
  static const outdoor = UtilityLookup('outdoor');
  static const common = UtilityLookup('common');
  static final Map<String, UtilityLookup> _known = {
    for (final v in [campus, building, floor, zone, plantRoom, outdoor, common])
      v.dbValue: v,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

class UtilityMeterRole {
  UtilityMeterRole._();
  static const boundary = UtilityLookup('boundary');
  static const main = UtilityLookup('main');
  static const submeter = UtilityLookup('submeter');
  static const check = UtilityLookup('check');
  static const billing = UtilityLookup('billing');
  static const process = UtilityLookup('process');
  static final Map<String, UtilityLookup> _known = {
    for (final v in [boundary, main, submeter, check, billing, process])
      v.dbValue: v,
  };
  static UtilityLookup parse(String? raw) => _parseLookup(raw, _known);
}

/// Alias used in API docs / models for service_type free text + known values.
class UtilityServiceType {
  UtilityServiceType._();
  static UtilityLookup parse(String? raw) =>
      _parseLookup(raw, const <String, UtilityLookup>{});
}
