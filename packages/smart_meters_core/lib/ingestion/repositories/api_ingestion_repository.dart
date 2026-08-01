import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_ingestion_contract.dart';

class ApiIngestionRepository {
  ApiIngestionRepository(this._client);

  final SupabaseClient _client;
  final _contract = const ApiIngestionContract();

  Future<ApiIngestBatchResult> ingestBatch(ApiIngestBatchRequest request) async {
    final errors = _contract.validateRequest(request);
    if (errors.isNotEmpty) {
      throw StateError(errors.map((e) => e.code).join(','));
    }
    final response = await _client.rpc(
      'ingest_readings_batch',
      params: {
        'p_organization_id': request.organizationId,
        'p_source_system': request.sourceSystem,
        'p_source_type': request.sourceType,
        'p_idempotency_key': request.idempotencyKey,
        'p_items': request.items.map((e) => e.toJson()).toList(),
      },
    );
    return _contract.parseRpcResponse(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
