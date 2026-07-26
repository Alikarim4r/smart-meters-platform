import 'package:flutter/material.dart';

export 'package:smart_meters_core/smart_meters_core.dart'
    show PartnerAppLauncher, PartnerAppLinks;

/// Dashboard-specific snackbar when a sibling app cannot be opened.
abstract final class DashboardPartnerApps {
  static Future<void> launchOrSnackBar(
    BuildContext context, {
    required Future<bool> Function() action,
    required String appLabel,
  }) async {
    final launched = await action();
    if (!context.mounted) return;
    if (launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open $appLabel. Build it on macOS first '
          '(scripts/run_${appLabel.toLowerCase()}_macos.sh) or install the app.',
        ),
      ),
    );
  }
}
