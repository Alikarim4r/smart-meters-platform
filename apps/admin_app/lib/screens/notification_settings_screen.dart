import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/preferences_providers.dart';

/// Shade sound + severity settings for Admin.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationSoundPrefs _prefs = const NotificationSoundPrefs();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await LocalNotificationDelivery.instance.initialize();
    if (!mounted) return;
    setState(() {
      _prefs = LocalNotificationDelivery.instance.prefs;
      _loading = false;
    });
  }

  Future<void> _save(NotificationSoundPrefs next) async {
    await LocalNotificationDelivery.instance.updatePrefs(next);
    if (!mounted) return;
    setState(() => _prefs = next);
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          s.notificationSettings,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          s.notificationSettingsSubtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('صوت إشعارات الستارة'),
          subtitle: const Text('تشغيل الصوت عند تنبيهات التحذير والحرج'),
          value: _prefs.soundEnabled,
          onChanged: (v) => _save(
            NotificationSoundPrefs(
              soundEnabled: v,
              minSeverity: _prefs.minSeverity,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('أدنى شدة للصوت', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'info', label: Text('الكل')),
            ButtonSegment(value: 'warning', label: Text('تحذير+')),
            ButtonSegment(value: 'critical', label: Text('حرج فقط')),
          ],
          selected: {_prefs.minSeverity},
          onSelectionChanged: (set) => _save(
            NotificationSoundPrefs(
              soundEnabled: _prefs.soundEnabled,
              minSeverity: set.first,
            ),
          ),
        ),
      ],
    );
  }
}
