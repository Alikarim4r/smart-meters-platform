import '../domain/reading_source.dart';

/// Adapter interface — readiness only; no BMS control; no fake vendor claims.
abstract class SourceAdapter {
  String get adapterKind;
  ReadingSource get sourceType;

  /// Manual connectivity probe. Implementations must not claim live vendor success
  /// without a real credentialed test.
  Future<AdapterConnectionResult> testConnection(AdapterConfig config);
}

class AdapterConfig {
  const AdapterConfig({
    required this.sourceKey,
    required this.connectionConfig,
    this.secretRef,
    this.mappingConfig = const {},
  });

  final String sourceKey;
  final Map<String, dynamic> connectionConfig;
  final String? secretRef;
  final Map<String, dynamic> mappingConfig;
}

class AdapterConnectionResult {
  const AdapterConnectionResult({
    required this.ok,
    required this.message,
    this.vendorVerified = false,
  });

  final bool ok;
  final String message;

  /// True only after a real vendor round-trip (never claimed by stubs).
  final bool vendorVerified;
}

class GenericApiAdapter implements SourceAdapter {
  @override
  String get adapterKind => 'generic_api';

  @override
  ReadingSource get sourceType => ReadingSource.api;

  @override
  Future<AdapterConnectionResult> testConnection(AdapterConfig config) async {
    if (config.secretRef == null || config.secretRef!.isEmpty) {
      return const AdapterConnectionResult(
        ok: false,
        message: 'Authentication required — secret_ref missing',
      );
    }
    final endpoint = config.connectionConfig['endpoint']?.toString();
    if (endpoint == null || endpoint.isEmpty) {
      return const AdapterConnectionResult(
        ok: false,
        message: 'endpoint missing in connection_config',
      );
    }
    return AdapterConnectionResult(
      ok: true,
      message:
          'Config looks ready for $endpoint. Vendor connectivity not verified in Phase 6 stub.',
      vendorVerified: false,
    );
  }
}

class SmartMeterAdapter implements SourceAdapter {
  @override
  String get adapterKind => 'smart_meter';

  @override
  ReadingSource get sourceType => ReadingSource.smartMeter;

  @override
  Future<AdapterConnectionResult> testConnection(AdapterConfig config) async {
    return const AdapterConnectionResult(
      ok: false,
      message:
          'Smart meter adapter ready. No live vendor integration tested in Phase 6.',
      vendorVerified: false,
    );
  }
}

class BmsAdapter implements SourceAdapter {
  @override
  String get adapterKind => 'bms';

  @override
  ReadingSource get sourceType => ReadingSource.bms;

  /// Explicitly read-only — no setpoints / start-stop / interlock override.
  bool get allowsEquipmentControl => false;

  @override
  Future<AdapterConnectionResult> testConnection(AdapterConfig config) async {
    return const AdapterConnectionResult(
      ok: false,
      message:
          'BMS adapter readiness only. No control commands. Vendor not verified.',
      vendorVerified: false,
    );
  }
}

class IotAdapter implements SourceAdapter {
  @override
  String get adapterKind => 'iot';

  @override
  ReadingSource get sourceType => ReadingSource.iot;

  @override
  Future<AdapterConnectionResult> testConnection(AdapterConfig config) async {
    return const AdapterConnectionResult(
      ok: false,
      message: 'IoT adapter ready. No live device tested in Phase 6.',
      vendorVerified: false,
    );
  }
}

class CsvImportAdapter implements SourceAdapter {
  @override
  String get adapterKind => 'csv_import';

  @override
  ReadingSource get sourceType => ReadingSource.csvImport;

  @override
  Future<AdapterConnectionResult> testConnection(AdapterConfig config) async {
    return const AdapterConnectionResult(
      ok: true,
      message: 'CSV import adapter available (file-based; no network).',
      vendorVerified: false,
    );
  }
}
