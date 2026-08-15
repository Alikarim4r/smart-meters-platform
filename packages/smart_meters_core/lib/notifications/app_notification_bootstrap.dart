import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/supabase_provider.dart';
import 'home_widget_sync.dart';
import 'notification_session.dart';

/// Per-app widget provider class names (Android).
abstract final class AppWidgetNames {
  static const dashboard = [
    'DashboardAlertsWidgetProvider',
    'DashboardSiteWidgetProvider',
  ];
  static const entry = [
    'EntryQueueWidgetProvider',
    'EntrySyncWidgetProvider',
  ];
  static const admin = [
    'AdminOpsWidgetProvider',
    'AdminImportWidgetProvider',
  ];
}

final notificationSessionProvider =
    StateProvider<NotificationSession?>((ref) => null);

/// Starts shade notifications after auth when profile + org are ready.
Future<void> ensureNotificationSession(
  WidgetRef ref, {
  required String organizationId,
  required List<String> androidWidgetNames,
}) async {
  if (kIsWeb) return;
  if (organizationId.isEmpty) return;
  final auth = ref.read(authProvider);
  final profile = auth.profile;
  if (!auth.isAuthenticated || profile == null) return;

  final existing = ref.read(notificationSessionProvider);
  if (existing != null &&
      existing.userId == profile.id &&
      existing.organizationId == organizationId) {
    return;
  }

  await existing?.stop();

  final client = ref.read(supabaseClientProvider);
  final sync = HomeWidgetSync(androidWidgetNames: androidWidgetNames);

  final session = NotificationSession(
    client: client,
    userId: profile.id,
    organizationId: organizationId,
    widgetSync: sync,
  );
  await session.start();
  ref.read(notificationSessionProvider.notifier).state = session;
}

Future<void> stopNotificationSession(WidgetRef ref) async {
  final existing = ref.read(notificationSessionProvider);
  await existing?.stop();
  ref.read(notificationSessionProvider.notifier).state = null;
}
