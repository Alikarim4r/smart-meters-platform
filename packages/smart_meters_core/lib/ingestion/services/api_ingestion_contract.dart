/// API ingestion contract (authenticated; no public anon endpoint).
class ApiIngestItem {
  const ApiIngestItem({
    required this.meterId,
    required this.siteId,
    required this.readingDate,
    required this.rawValue,
    this.unitCode,
    this.externalReadingId,
    this.sourceTimestamp,
    this.sourceQuality,
    this.idempotencyKey,
  });

  final String meterId;
  final String siteId;
  final DateTime readingDate;
  final double rawValue;
  final String? unitCode;
  final String? externalReadingId;
  final DateTime? sourceTimestamp;
  final String? sourceQuality;
  final String? idempotencyKey;

  Map<String, dynamic> toJson() => {
        'meter_id': meterId,
        'site_id': siteId,
        'reading_date': readingDate.toIso8601String().substring(0, 10),
        'raw_value': rawValue,
        if (unitCode != null) 'unit_code': unitCode,
        if (externalReadingId != null) 'external_reading_id': externalReadingId,
        if (sourceTimestamp != null)
          'source_timestamp': sourceTimestamp!.toUtc().toIso8601String(),
        if (sourceQuality != null) 'source_quality': sourceQuality,
      };
}

class ApiIngestBatchRequest {
  const ApiIngestBatchRequest({
    required this.organizationId,
    required this.sourceSystem,
    required this.sourceType,
    required this.items,
    this.idempotencyKey,
  });

  final String organizationId;
  final String sourceSystem;
  final String sourceType;
  final String? idempotencyKey;
  final List<ApiIngestItem> items;
}

enum ApiIngestItemStatus { accepted, rejected, duplicated, conflict }

class ApiIngestItemResult {
  const ApiIngestItemResult({
    required this.index,
    required this.status,
    this.readingId,
    this.error,
  });

  final int index;
  final ApiIngestItemStatus status;
  final String? readingId;
  final String? error;
}

class ApiIngestBatchResult {
  const ApiIngestBatchResult({
    required this.accepted,
    required this.rejected,
    required this.duplicated,
    required this.conflicts,
    required this.results,
  });

  final int accepted;
  final int rejected;
  final int duplicated;
  final int conflicts;
  final List<ApiIngestItemResult> results;
}

class ApiIngestionValidationError {
  const ApiIngestionValidationError(this.code, this.message);
  final String code;
  final String message;
}

/// Pure contract validation — auth must be enforced by caller/RPC.
class ApiIngestionContract {
  const ApiIngestionContract({this.maxBatchSize = 500});

  final int maxBatchSize;

  static const allowedSourceTypes = {
    'api',
    'smart_meter',
    'bms',
    'iot',
    'csv_import',
    'excel_import',
  };

  List<ApiIngestionValidationError> validateRequest(ApiIngestBatchRequest req) {
    final errors = <ApiIngestionValidationError>[];
    if (req.organizationId.trim().isEmpty) {
      errors.add(const ApiIngestionValidationError(
        'missing_organization',
        'organization_id is required',
      ));
    }
    if (req.sourceSystem.trim().isEmpty) {
      errors.add(const ApiIngestionValidationError(
        'missing_source_system',
        'source_system is required',
      ));
    }
    if (!allowedSourceTypes.contains(req.sourceType)) {
      errors.add(ApiIngestionValidationError(
        'invalid_source_type',
        'source_type ${req.sourceType} not allowed',
      ));
    }
    if (req.items.isEmpty) {
      errors.add(const ApiIngestionValidationError(
        'empty_batch',
        'items must not be empty',
      ));
    }
    if (req.items.length > maxBatchSize) {
      errors.add(ApiIngestionValidationError(
        'batch_too_large',
        'max $maxBatchSize items',
      ));
    }
    for (var i = 0; i < req.items.length; i++) {
      final item = req.items[i];
      if (item.meterId.isEmpty || item.siteId.isEmpty) {
        errors.add(ApiIngestionValidationError(
          'item_missing_ids',
          'item[$i] missing meter_id or site_id',
        ));
      }
      if (item.rawValue < 0) {
        errors.add(ApiIngestionValidationError(
          'item_negative_value',
          'item[$i] raw_value must be >= 0',
        ));
      }
    }
    return errors;
  }

  /// Idempotency key recommended for retries; empty is allowed but not rate-limit safe.
  bool hasIdempotencyKey(ApiIngestBatchRequest req) =>
      req.idempotencyKey != null && req.idempotencyKey!.trim().isNotEmpty;

  ApiIngestBatchResult parseRpcResponse(Map<String, dynamic> json) {
    final results = <ApiIngestItemResult>[];
    final rawResults = json['results'];
    if (rawResults is List) {
      for (final r in rawResults) {
        final m = Map<String, dynamic>.from(r as Map);
        results.add(ApiIngestItemResult(
          index: (m['index'] as num).toInt(),
          status: _status(m['status'] as String?),
          readingId: m['reading_id'] as String?,
          error: m['error'] as String?,
        ));
      }
    }
    return ApiIngestBatchResult(
      accepted: (json['accepted'] as num?)?.toInt() ?? 0,
      rejected: (json['rejected'] as num?)?.toInt() ?? 0,
      duplicated: (json['duplicated'] as num?)?.toInt() ?? 0,
      conflicts: (json['conflicts'] as num?)?.toInt() ?? 0,
      results: results,
    );
  }

  ApiIngestItemStatus _status(String? raw) => switch (raw) {
        'accepted' => ApiIngestItemStatus.accepted,
        'duplicated' => ApiIngestItemStatus.duplicated,
        'conflict' => ApiIngestItemStatus.conflict,
        _ => ApiIngestItemStatus.rejected,
      };
}
