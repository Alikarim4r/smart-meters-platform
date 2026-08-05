import 'package:supabase_flutter/supabase_flutter.dart';

class ImportBatchRepository {
  ImportBatchRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> createPreviewBatch({
    required String organizationId,
    String? siteId,
    required String sourceType,
    required String fileFingerprint,
    String? fileName,
    String? storagePath,
    Map<String, dynamic>? columnMapping,
    required String importedBy,
  }) async {
    final row = await _client.from('import_batches').insert({
      'organization_id': organizationId,
      'site_id': siteId,
      'source_type': sourceType,
      'file_fingerprint': fileFingerprint,
      'file_name': fileName,
      'storage_path': storagePath,
      'column_mapping': columnMapping ?? {},
      'status': 'preview',
      'dry_run': true,
      'imported_by': importedBy,
    }).select().single();
    return Map<String, dynamic>.from(row);
  }

  Future<bool> hasCommittedFingerprint({
    required String organizationId,
    required String fileFingerprint,
  }) async {
    final rows = await _client
        .from('import_batches')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('file_fingerprint', fileFingerprint)
        .inFilter('status', ['committed', 'partial'])
        .isFilter('reversed_at', null)
        .limit(1);
    return (rows as List).isNotEmpty;
  }
}

class ExternalDataSourceRepository {
  ExternalDataSourceRepository(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listForOrg(String organizationId) async {
    final rows = await _client
        .from('external_data_sources')
        .select()
        .eq('organization_id', organizationId)
        .order('display_name');
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

class NotificationRepository {
  NotificationRepository(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listForUser(String userId) async {
    final rows = await _client
        .from('in_app_notifications')
        .select()
        .eq('user_id', userId)
        .order('generated_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listUnread(String userId) async {
    final rows = await _client
        .from('in_app_notifications')
        .select()
        .eq('user_id', userId)
        .eq('is_read', false)
        .order('generated_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> markRead(String id) async {
    await _client.from('in_app_notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<Map<String, dynamic>?> insertNotification({
    required String organizationId,
    required String notificationType,
    required String severity,
    required String title,
    required String body,
    required String eventKey,
    String? siteId,
    String? userId,
    String? relatedEntityType,
    String? relatedEntityId,
    Map<String, dynamic> payload = const {},
  }) async {
    final row = await _client
        .from('in_app_notifications')
        .insert({
          'organization_id': organizationId,
          if (siteId != null) 'site_id': siteId,
          if (userId != null) 'user_id': userId,
          'notification_type': notificationType,
          'severity': severity,
          'title': title,
          'body': body,
          'event_key': eventKey,
          if (relatedEntityType != null)
            'related_entity_type': relatedEntityType,
          if (relatedEntityId != null) 'related_entity_id': relatedEntityId,
          'payload': payload,
          'is_read': false,
        })
        .select()
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> listPreferences({
    required String userId,
    required String organizationId,
  }) async {
    final rows = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .eq('organization_id', organizationId);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> upsertPreference({
    required String userId,
    required String organizationId,
    required String notificationType,
    required bool enabled,
    String minSeverity = 'info',
    String? siteId,
  }) async {
    await _client.from('notification_preferences').upsert({
      'user_id': userId,
      'organization_id': organizationId,
      'notification_type': notificationType,
      'enabled': enabled,
      'min_severity': minSeverity,
      if (siteId != null) 'site_id': siteId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
