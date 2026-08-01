/// Notification event-key dedupe / cooldown.
class NotificationDedupe {
  NotificationDedupe({this.cooldown = const Duration(hours: 6)});

  final Duration cooldown;
  final Map<String, DateTime> _lastEmitted = {};

  String eventKey({
    required String notificationType,
    required String organizationId,
    String? siteId,
    String? relatedEntityId,
    String? extra,
  }) {
    return [
      notificationType,
      organizationId,
      siteId ?? '-',
      relatedEntityId ?? '-',
      extra ?? '-',
    ].join('|');
  }

  /// Returns true if a new notification should be created.
  bool shouldEmit(String eventKey, {DateTime? now}) {
    final t = now ?? DateTime.now().toUtc();
    final last = _lastEmitted[eventKey];
    if (last != null && t.difference(last) < cooldown) {
      return false;
    }
    _lastEmitted[eventKey] = t;
    return true;
  }

  void remember(String eventKey, {DateTime? at}) {
    _lastEmitted[eventKey] = at ?? DateTime.now().toUtc();
  }
}
