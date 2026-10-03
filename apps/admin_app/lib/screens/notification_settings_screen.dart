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

  Future<void> _requestSystemPermission(AdminStrings s) async {
    await LocalNotificationDelivery.instance.initialize();
    final granted = await LocalNotificationDelivery.instance
        .requestPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? s.notificationPermissionGranted
              : s.notificationPermissionNotGranted,
        ),
      ),
    );
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
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(s.enableSystemNotifications),
            subtitle: Text(s.systemNotificationsHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _requestSystemPermission(s),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(s.text('Notification sound', 'صوت الإشعارات')),
          subtitle: Text(
            s.text(
              'Play sound for warning and critical alerts',
              'تشغيل الصوت عند تنبيهات التحذير والحرج',
            ),
          ),
          value: _prefs.soundEnabled,
          onChanged: (v) => _save(
            NotificationSoundPrefs(
              soundEnabled: v,
              minSeverity: _prefs.minSeverity,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.text('Minimum sound severity', 'أدنى شدة للصوت'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'info', label: Text(s.text('All', 'الكل'))),
            ButtonSegment(
              value: 'warning',
              label: Text(s.text('Warning+', 'تحذير+')),
            ),
            ButtonSegment(
              value: 'critical',
              label: Text(s.text('Critical only', 'حرج فقط')),
            ),
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
