import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/admin_providers.dart';

/// Starts Admin shade session + syncs ops widgets from unread notifications.
class AdminNotificationBridge extends ConsumerStatefulWidget {
  const AdminNotificationBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdminNotificationBridge> createState() =>
      _AdminNotificationBridgeState();
}

class _AdminNotificationBridgeState
    extends ConsumerState<AdminNotificationBridge>
    with WidgetsBindingObserver {
  String? _startedOrgId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWidgets();
    }
  }

  Future<void> _bootstrap() async {
    if (kIsWeb) return;
    final sites = ref.read(adminSitesProvider).valueOrNull;
    if (sites == null || sites.isEmpty) return;
    final orgId = sites.first.organizationId;
    if (_startedOrgId == orgId) {
      await _refreshWidgets();
      return;
    }
    _startedOrgId = orgId;
    await ensureNotificationSession(
      ref,
      organizationId: orgId,
      androidWidgetNames: AppWidgetNames.admin,
    );
    await _refreshWidgets();
  }

  Future<void> _refreshWidgets() async {
    final session = ref.read(notificationSessionProvider);
    final profile = ref.read(authProvider).profile;
    if (session == null || profile == null) return;
    try {
      final unread = await NotificationRepository(session.client)
          .listUnread(profile.id);
      final top = unread.isEmpty ? null : unread.first;
      await HomeWidgetSync(androidWidgetNames: AppWidgetNames.admin).syncAdmin(
        unreadCount: unread.length,
        topTitle: top == null
            ? 'لا تنبيهات'
            : (top['title'] as String? ?? 'تنبيه'),
        importStatus: top == null
            ? 'idle'
            : (top['notification_type'] as String? ?? 'idle'),
        importHint: top == null
            ? 'لا دفعات حديثة'
            : (top['body'] as String? ?? ''),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(adminSitesProvider, (prev, next) {
      next.whenData((_) => _bootstrap());
    });
    return widget.child;
  }
}
