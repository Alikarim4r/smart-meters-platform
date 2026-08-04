/// Row model for [in_app_notifications].
class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.organizationId,
    required this.notificationType,
    required this.severity,
    required this.title,
    required this.body,
    required this.eventKey,
    required this.isRead,
    required this.generatedAt,
    this.siteId,
    this.userId,
    this.relatedEntityType,
    this.relatedEntityId,
    this.payload = const {},
  });

  final String id;
  final String organizationId;
  final String? siteId;
  final String? userId;
  final String notificationType;
  final String severity;
  final String title;
  final String body;
  final String eventKey;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime generatedAt;

  bool get isCritical => severity == 'critical';
  bool get isWarningOrHigher =>
      severity == 'critical' || severity == 'warning';

  factory InAppNotification.fromMap(Map<String, dynamic> map) {
    return InAppNotification(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      siteId: map['site_id'] as String?,
      userId: map['user_id'] as String?,
      notificationType: map['notification_type'] as String,
      severity: map['severity'] as String? ?? 'info',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      eventKey: map['event_key'] as String? ?? '',
      relatedEntityType: map['related_entity_type'] as String?,
      relatedEntityId: map['related_entity_id'] as String?,
      payload: map['payload'] is Map
          ? Map<String, dynamic>.from(map['payload'] as Map)
          : const {},
      isRead: map['is_read'] as bool? ?? false,
      generatedAt: DateTime.tryParse(map['generated_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

/// Draft used by writers before persistence / local shade delivery.
class NotificationDraft {
  const NotificationDraft({
    required this.organizationId,
    required this.notificationType,
    required this.severity,
    required this.title,
    required this.body,
    required this.eventKey,
    this.siteId,
    this.userId,
    this.relatedEntityType,
    this.relatedEntityId,
    this.payload = const {},
  });

  final String organizationId;
  final String? siteId;
  final String? userId;
  final String notificationType;
  final String severity;
  final String title;
  final String body;
  final String eventKey;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final Map<String, dynamic> payload;
}

/// Local shade sound preference (SharedPreferences).
class NotificationSoundPrefs {
  const NotificationSoundPrefs({
    this.soundEnabled = true,
    this.minSeverity = 'warning',
  });

  final bool soundEnabled;

  /// One of: info, warning, critical.
  final String minSeverity;

  static const storageKeySound = 'notification_shade_sound_enabled';
  static const storageKeyMinSeverity = 'notification_shade_min_severity';

  int get minSeverityRank => severityRank(minSeverity);

  static int severityRank(String severity) => switch (severity) {
        'critical' => 3,
        'warning' => 2,
        _ => 1,
      };

  bool allows(String severity) {
    if (!soundEnabled) return false;
    return severityRank(severity) >= minSeverityRank;
  }
}
