import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../navigation/partner_app_launcher.dart';
import '../../theme/dashboard_palette.dart';
import '../../theme/dashboard_theme.dart';

enum PartnerAppsLayout { sidebar, inline }

/// Handoff to Entry / Admin sibling apps for the active site.
class PartnerAppsBar extends ConsumerWidget {
  const PartnerAppsBar({
    super.key,
    required this.siteId,
    this.layout = PartnerAppsLayout.inline,
    this.categoryCode,
  });

  final String siteId;
  final PartnerAppsLayout layout;
  final String? categoryCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).profile;
    if (profile == null) return const SizedBox.shrink();

    final canEntry =
        profile.isTechnician || profile.isSiteAdmin || profile.isSuperAdmin;
    final canAdmin = profile.isSiteAdmin || profile.isSuperAdmin;
    if (!canEntry && !canAdmin) return const SizedBox.shrink();

    if (layout == PartnerAppsLayout.sidebar) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canEntry)
              _SidebarPartnerButton(
                label: 'Data Entry',
                icon: Icons.edit_note_rounded,
                onTap: () => DashboardPartnerApps.launchOrSnackBar(
                  context,
                  appLabel: 'Entry',
                  action: () => PartnerAppLauncher.openEntrySite(
                    siteId,
                    categoryCode: categoryCode,
                  ),
                ),
              ),
            if (canEntry && canAdmin) const SizedBox(height: 6),
            if (canAdmin)
              _SidebarPartnerButton(
                label: 'Site Admin',
                icon: Icons.admin_panel_settings_outlined,
                accent: DashboardPalette.gold,
                onTap: () => DashboardPartnerApps.launchOrSnackBar(
                  context,
                  appLabel: 'Admin',
                  action: () => PartnerAppLauncher.openAdminSite(siteId),
                ),
              ),
          ],
        ),
      );
    }

    final colors = dashboardColors(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canEntry)
          _InlinePartnerButton(
            label: 'Data Entry',
            icon: Icons.edit_note_rounded,
            color: colors.navy,
            onTap: () => DashboardPartnerApps.launchOrSnackBar(
              context,
              appLabel: 'Entry',
              action: () => PartnerAppLauncher.openEntrySite(
                siteId,
                categoryCode: categoryCode,
              ),
            ),
          ),
        if (canAdmin)
          _InlinePartnerButton(
            label: 'Site Admin',
            icon: Icons.admin_panel_settings_outlined,
            color: DashboardPalette.gold,
            onTap: () => DashboardPartnerApps.launchOrSnackBar(
              context,
              appLabel: 'Admin',
              action: () => PartnerAppLauncher.openAdminSite(siteId),
            ),
          ),
      ],
    );
  }
}

class _SidebarPartnerButton extends StatelessWidget {
  const _SidebarPartnerButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = DashboardPalette.gold,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlinePartnerButton extends StatelessWidget {
  const _InlinePartnerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
