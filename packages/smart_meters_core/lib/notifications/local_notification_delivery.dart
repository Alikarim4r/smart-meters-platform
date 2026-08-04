import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_models.dart';

/// Shows system notification shade alerts with Android channel sounds.
class LocalNotificationDelivery {
  LocalNotificationDelivery._();

  static final LocalNotificationDelivery instance = LocalNotificationDelivery._();

  static const defaultChannelId = 'alerts_default';
  static const criticalChannelId = 'alerts_critical';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  NotificationSoundPrefs _prefs = const NotificationSoundPrefs();
  void Function(String? payload)? onNotificationTapped;

  bool get isReady => _ready;
  NotificationSoundPrefs get prefs => _prefs;

  Future<void> initialize({
    String androidDefaultIcon = '@mipmap/ic_launcher',
    void Function(String? payload)? onTap,
  }) async {
    if (kIsWeb) return;
    onNotificationTapped = onTap;
    await _loadPrefs();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTapped?.call(response.payload);
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          defaultChannelId,
          'Alerts',
          description: 'Operational and integration alerts',
          importance: Importance.high,
          playSound: true,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          criticalChannelId,
          'Critical alerts',
          description: 'Critical meter and import alerts',
          importance: Importance.max,
          playSound: true,
        ),
      );
      await android?.requestNotificationsPermission();
    }

    _ready = true;
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    _prefs = NotificationSoundPrefs(
      soundEnabled: sp.getBool(NotificationSoundPrefs.storageKeySound) ?? true,
      minSeverity:
          sp.getString(NotificationSoundPrefs.storageKeyMinSeverity) ??
              'warning',
    );
  }

  Future<void> updatePrefs(NotificationSoundPrefs prefs) async {
    _prefs = prefs;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(NotificationSoundPrefs.storageKeySound, prefs.soundEnabled);
    await sp.setString(
      NotificationSoundPrefs.storageKeyMinSeverity,
      prefs.minSeverity,
    );
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  /// Shows a shade notification. Respects sound prefs for channel selection.
  Future<void> show({
    required String title,
    required String body,
    required String severity,
    String? payload,
    int? id,
  }) async {
    if (!_ready || kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final playSound = _prefs.allows(severity);
    final channelId =
        severity == 'critical' ? criticalChannelId : defaultChannelId;
    final channelName =
        severity == 'critical' ? 'Critical alerts' : 'Alerts';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Smart Meters platform alerts',
        importance:
            severity == 'critical' ? Importance.max : Importance.high,
        priority: severity == 'critical' ? Priority.max : Priority.high,
        playSound: playSound,
        enableVibration: playSound,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: playSound,
      ),
    );

    final notifId = id ??
        (title.hashCode ^ body.hashCode ^ severity.hashCode).abs() % 100000;

    await _plugin.show(
      notifId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showFromNotification(InAppNotification n) {
    return show(
      title: n.title,
      body: n.body,
      severity: n.severity,
      payload: n.id,
      id: n.id.hashCode.abs() % 100000,
    );
  }

  Future<void> showFromDraft(NotificationDraft d) {
    return show(
      title: d.title,
      body: d.body,
      severity: d.severity,
      payload: d.eventKey,
      id: d.eventKey.hashCode.abs() % 100000,
    );
  }
}
