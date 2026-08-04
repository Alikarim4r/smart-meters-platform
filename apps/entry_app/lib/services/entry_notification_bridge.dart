import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../offline/offline_storage_service.dart';
import '../providers/entry_providers.dart';

/// Syncs Entry offline queue to shade (on failure/pending) + home widgets.
class EntryNotificationBridge extends ConsumerStatefulWidget {
  const EntryNotificationBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<EntryNotificationBridge> createState() =>
      _EntryNotificationBridgeState();
}

class _EntryNotificationBridgeState
    extends ConsumerState<EntryNotificationBridge> with WidgetsBindingObserver {
  String? _startedOrgId;
  int _lastNotifiedPending = -1;

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
      _syncWidgets();
    }
  }

  Future<void> _bootstrap() async {
    if (kIsWeb) return;
    final sites = ref.read(accessibleSitesProvider).valueOrNull;
    if (sites == null || sites.isEmpty) return;
    final orgId = sites.first.organizationId;
    if (_startedOrgId == orgId) {
      await _syncWidgets();
      return;
    }
    _startedOrgId = orgId;
    await ensureNotificationSession(
      ref,
      organizationId: orgId,
      androidWidgetNames: AppWidgetNames.entry,
    );
    await _syncWidgets();
  }

  Future<void> _syncWidgets() async {
    final ownerUserId = ref.read(authProvider).profile?.id;
    if (ownerUserId == null) {
      return;
    }
    final storage = OfflineStorageService.instance;
    final pending = storage.getPendingSyncDrafts(ownerUserId: ownerUserId);
    final last = storage.getLastSyncTime(ownerUserId: ownerUserId);
    final lastLabel = last == null
        ? 'لم تتم مزامنة بعد'
        : 'آخر مزامنة: ${last.toLocal().toString().substring(0, 16)}';

    await HomeWidgetSync(androidWidgetNames: AppWidgetNames.entry).syncEntry(
      pendingMeters: pending.length,
      queueHint: pending.isEmpty
          ? 'لا مسودات معلّقة'
          : '${pending.length} قراءة بانتظار المزامنة',
      offlinePending: pending.length,
      lastSync: lastLabel,
    );

    final session = ref.read(notificationSessionProvider);
    if (session != null &&
        pending.length >= 3 &&
        pending.length != _lastNotifiedPending) {
      _lastNotifiedPending = pending.length;
      await session.emit(
        NotificationDraft(
          organizationId: session.organizationId,
          notificationType: 'data_quality_review',
          severity: 'warning',
          title: 'قراءات Offline معلّقة',
          body: 'يوجد ${pending.length} قراءة بانتظار المزامنة',
          eventKey: 'entry|offline|${pending.length}|${DateTime.now().day}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accessibleSitesProvider, (prev, next) {
      next.whenData((_) => _bootstrap());
    });
    return widget.child;
  }
}
