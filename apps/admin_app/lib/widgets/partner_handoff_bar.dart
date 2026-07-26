import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../navigation/admin_partner_navigation.dart';

class AdminPartnerHandoffBar extends StatelessWidget {
  const AdminPartnerHandoffBar({
    super.key,
    required this.siteId,
    this.meterId,
    this.categoryCode,
  });

  final String siteId;
  final String? meterId;
  final String? categoryCode;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => launchAdminPartnerApp(
            context,
            appLabel: 'Dashboard',
            action: () => PartnerAppLauncher.openDashboardSite(
              siteId,
              section: categoryCode,
            ),
          ),
          icon: const Icon(Icons.dashboard_outlined, size: 16),
          label: const Text('Open Dashboard'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => launchAdminPartnerApp(
            context,
            appLabel: 'Entry',
            action: () {
              if (meterId != null) {
                return PartnerAppLauncher.openEntryMeter(
                  siteId: siteId,
                  meterId: meterId!,
                  categoryCode: categoryCode,
                );
              }
              return PartnerAppLauncher.openEntrySite(
                siteId,
                categoryCode: categoryCode,
              );
            },
          ),
          icon: const Icon(Icons.edit_note_outlined, size: 16),
          label: const Text('Open Entry'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }
}
