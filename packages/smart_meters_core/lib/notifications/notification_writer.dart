import 'package:supabase_flutter/supabase_flutter.dart';

import '../ingestion/services/notification_dedupe.dart';
import 'local_notification_delivery.dart';
import 'notification_models.dart';

/// Persists notifications (best-effort) and delivers to the system shade.
class NotificationWriter {
  NotificationWriter(this._client, {NotificationDedupe? dedupe})
      : _dedupe = dedupe ?? NotificationDedupe();

  final SupabaseClient _client;
  final NotificationDedupe _dedupe;

  /// Inserts when possible, always shows shade if [deliverLocal] is true.
  Future<InAppNotification?> emit(
    NotificationDraft draft, {
    bool deliverLocal = true,
    bool requireDedupe = true,
  }) async {
    if (requireDedupe && !_dedupe.shouldEmit(draft.eventKey)) {
      return null;
    }

    InAppNotification? saved;
    try {
      final row = await _client
          .from('in_app_notifications')
          .insert({
            'organization_id': draft.organizationId,
            if (draft.siteId != null) 'site_id': draft.siteId,
            if (draft.userId != null) 'user_id': draft.userId,
            'notification_type': draft.notificationType,
            'severity': draft.severity,
            'title': draft.title,
            'body': draft.body,
            'event_key': draft.eventKey,
            if (draft.relatedEntityType != null)
              'related_entity_type': draft.relatedEntityType,
            if (draft.relatedEntityId != null)
              'related_entity_id': draft.relatedEntityId,
            'payload': draft.payload,
            'is_read': false,
          })
          .select()
          .maybeSingle();
      if (row != null) {
        saved = InAppNotification.fromMap(Map<String, dynamic>.from(row));
        _dedupe.remember(draft.eventKey);
      }
    } catch (_) {
      // Unique / RLS — still deliver locally.
      _dedupe.remember(draft.eventKey);
    }

    if (deliverLocal) {
      if (saved != null) {
        await LocalNotificationDelivery.instance.showFromNotification(saved);
      } else {
        await LocalNotificationDelivery.instance.showFromDraft(draft);
      }
    }
    return saved;
  }
}
