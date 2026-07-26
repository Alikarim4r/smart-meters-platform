import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../navigation/entry_partner_navigation.dart';

class PartnerHandoffButton extends StatelessWidget {
  const PartnerHandoffButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}

class EntryPartnerHandoffBar extends ConsumerWidget {
  const EntryPartnerHandoffBar({
    super.key,
    required this.siteId,
    this.categoryCode,
  });

  final String siteId;
  final String? categoryCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        PartnerHandoffButton(
          label: 'Open Dashboard',
          icon: Icons.dashboard_outlined,
          onPressed: () => launchEntryPartnerApp(
            context,
            appLabel: 'Dashboard',
            action: () => PartnerAppLauncher.openDashboardSite(
              siteId,
              section: categoryCode,
            ),
          ),
        ),
        PartnerHandoffButton(
          label: 'Open Admin',
          icon: Icons.admin_panel_settings_outlined,
          onPressed: () => launchEntryPartnerApp(
            context,
            appLabel: 'Admin',
            action: () => PartnerAppLauncher.openAdminSite(siteId),
          ),
        ),
      ],
    );
  }
}
