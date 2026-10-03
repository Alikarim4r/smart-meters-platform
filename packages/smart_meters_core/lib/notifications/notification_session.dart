import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_widget_sync.dart';
import 'local_notification_delivery.dart';
import 'notification_models.dart';
import 'notification_writer.dart';

/// Bootstraps shade notifications + optional Realtime after login.
class NotificationSession {
  NotificationSession({
    required this.client,
    required this.userId,
    required this.organizationId,
    this.widgetSync,
    this.onUnreadChanged,
    this.pollInterval = const Duration(minutes: 3),
  }) : writer = NotificationWriter(client);

  final SupabaseClient client;
  final String userId;
  final String organizationId;
  final HomeWidgetSync? widgetSync;
  final Future<void> Function(List<InAppNotification> unread)? onUnreadChanged;
  final Duration pollInterval;
  final NotificationWriter writer;

  RealtimeChannel? _channel;
  Timer? _pollTimer;
  final Set<String> _seenIds = {};
  bool _started = false;

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;

    // Initialize delivery without prompting. Permission is requested only from
    // an explicit user action in each app's notification/settings UI.
    await LocalNotificationDelivery.instance.initialize();
    await widgetSync?.configure();

    await _refreshFromServer(deliverNew: false);
    _subscribeRealtime();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(_refreshFromServer(deliverNew: true));
    });
  }

  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_channel != null) {
      await client.removeChannel(_channel!);
      _channel = null;
    }
    _started = false;
  }

  void _subscribeRealtime() {
    try {
      _channel = client
          .channel('in_app_notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'in_app_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final map = payload.newRecord;
              if (map.isEmpty) return;
              final n = InAppNotification.fromMap(
                Map<String, dynamic>.from(map),
              );
              if (_seenIds.add(n.id)) {
                unawaited(
                  LocalNotificationDelivery.instance.showFromNotification(n),
                );
              }
            },
          )
          .subscribe();
    } catch (_) {
      // Realtime optional — polling remains.
    }
  }

  Future<List<InAppNotification>> _refreshFromServer({
    required bool deliverNew,
  }) async {
    try {
      final rows = await client
          .from('in_app_notifications')
          .select()
          .eq('user_id', userId)
          .order('generated_at', ascending: false)
          .limit(50);
      final list = (rows as List)
          .map(
            (e) =>
                InAppNotification.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      for (final n in list) {
        final isNew = _seenIds.add(n.id);
        if (deliverNew && isNew && !n.isRead) {
          await LocalNotificationDelivery.instance.showFromNotification(n);
        }
      }

      final unread = list.where((n) => !n.isRead).toList();
      if (onUnreadChanged != null) {
        await onUnreadChanged!(unread);
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<InAppNotification?> emit(NotificationDraft draft) {
    final withUser = NotificationDraft(
      organizationId: draft.organizationId.isEmpty
          ? organizationId
          : draft.organizationId,
      siteId: draft.siteId,
      userId: draft.userId ?? userId,
      notificationType: draft.notificationType,
      severity: draft.severity,
      title: draft.title,
      body: draft.body,
      eventKey: draft.eventKey,
      relatedEntityType: draft.relatedEntityType,
      relatedEntityId: draft.relatedEntityId,
      payload: draft.payload,
    );
    return writer.emit(withUser);
  }
}
