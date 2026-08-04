import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/notifications/notification_models.dart';

void main() {
  test('NotificationSoundPrefs.allows respects min severity', () {
    const prefs = NotificationSoundPrefs(
      soundEnabled: true,
      minSeverity: 'warning',
    );
    expect(prefs.allows('info'), isFalse);
    expect(prefs.allows('warning'), isTrue);
    expect(prefs.allows('critical'), isTrue);
  });

  test('disabled sound blocks all', () {
    const prefs = NotificationSoundPrefs(soundEnabled: false);
    expect(prefs.allows('critical'), isFalse);
  });
}
