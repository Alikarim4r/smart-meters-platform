import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Shared keys written for Android home-screen widgets.
abstract final class HomeWidgetKeys {
  static const unreadCount = 'unread_count';
  static const topTitle = 'top_title';
  static const topSeverity = 'top_severity';
  static const siteName = 'site_name';
  static const siteSummary = 'site_summary';
  static const pendingMeters = 'pending_meters';
  static const queueHint = 'queue_hint';
  static const offlinePending = 'offline_pending';
  static const lastSync = 'last_sync';
  static const importStatus = 'import_status';
  static const importHint = 'import_hint';
  static const updatedAt = 'updated_at';
}

/// Writes widget payloads and triggers Android App Widget updates.
class HomeWidgetSync {
  HomeWidgetSync({
    required this.androidWidgetNames,
    this.appGroupId,
  });

  /// Fully-qualified or simple class names registered in the AndroidManifest.
  final List<String> androidWidgetNames;
  final String? appGroupId;

  Future<void> configure() async {
    if (kIsWeb) return;
    if (appGroupId != null) {
      await HomeWidget.setAppGroupId(appGroupId!);
    }
  }

  Future<void> saveAll(Map<String, String> values) async {
    if (kIsWeb) return;
    for (final entry in values.entries) {
      await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
    }
    await HomeWidget.saveWidgetData<String>(
      HomeWidgetKeys.updatedAt,
      DateTime.now().toIso8601String(),
    );
    await updateAll();
  }

  Future<void> updateAll() async {
    if (kIsWeb) return;
    for (final name in androidWidgetNames) {
      try {
        await HomeWidget.updateWidget(name: name, androidName: name);
      } catch (_) {}
    }
  }

  Future<void> syncDashboard({
    required int unreadCount,
    required String topTitle,
    required String topSeverity,
    String siteName = '—',
    String siteSummary = '—',
  }) {
    return saveAll({
      HomeWidgetKeys.unreadCount: '$unreadCount',
      HomeWidgetKeys.topTitle: topTitle,
      HomeWidgetKeys.topSeverity: topSeverity,
      HomeWidgetKeys.siteName: siteName,
      HomeWidgetKeys.siteSummary: siteSummary,
    });
  }

  Future<void> syncEntry({
    required int pendingMeters,
    required String queueHint,
    required int offlinePending,
    required String lastSync,
  }) {
    return saveAll({
      HomeWidgetKeys.pendingMeters: '$pendingMeters',
      HomeWidgetKeys.queueHint: queueHint,
      HomeWidgetKeys.offlinePending: '$offlinePending',
      HomeWidgetKeys.lastSync: lastSync,
    });
  }

  Future<void> syncAdmin({
    required int unreadCount,
    required String topTitle,
    required String importStatus,
    required String importHint,
  }) {
    return saveAll({
      HomeWidgetKeys.unreadCount: '$unreadCount',
      HomeWidgetKeys.topTitle: topTitle,
      HomeWidgetKeys.importStatus: importStatus,
      HomeWidgetKeys.importHint: importHint,
    });
  }
}
