import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/locale_provider.dart';
import '../../providers/shell_providers.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../../utils/site_system_navigation.dart';
import 'dashboard_settings_sheet.dart';

enum DashboardShellSection { sites, alerts }

final dashboardShellSectionProvider =
    StateProvider<DashboardShellSection>((ref) => DashboardShellSection.sites);

final selectedSiteIdProvider = StateProvider<String?>((ref) => null);

class DashboardSidebar extends ConsumerWidget {
  const DashboardSidebar({
    super.key,
    required this.onSignOut,
    this.asDrawer = false,
  });

  final VoidCallback onSignOut;

  /// When true, fill the drawer width and never collapse.
  final bool asDrawer;

  static const double _expandedWidth = DashboardLayout.sidebarExpanded;
  static const double _collapsedWidth = DashboardLayout.sidebarCollapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = asDrawer ? false : ref.watch(sidebarCollapsedProvider);
    final profile = ref.watch(authProvider).profile;
    final selectedSiteId = ref.watch(selectedSiteIdProvider);
    final siteSection = ref.watch(siteDashboardSectionProvider);
    final shellSection = ref.watch(dashboardShellSectionProvider);
    final s = AppStrings(ref.watch(localeProvider));
    final siteSummary = selectedSiteId == null
        ? null
        : ref.watch(siteDashboardSummaryProvider(selectedSiteId)).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void closeDrawerIfNeeded() {
      if (asDrawer && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    void goHome() {
      ref.read(selectedSiteIdProvider.notifier).state = null;
      ref.read(dashboardShellSectionProvider.notifier).state =
          DashboardShellSection.sites;
      closeDrawerIfNeeded();
    }

    void openSiteSection(SiteDashboardSection section) {
      if (selectedSiteId == null) return;
      ref.read(siteDashboardSectionProvider.notifier).state = section;
      ref.read(dashboardShellSectionProvider.notifier).state =
          DashboardShellSection.sites;
      closeDrawerIfNeeded();
    }

    void openSettings() {
      closeDrawerIfNeeded();
      showDashboardSettingsSheet(context, onSignOut: onSignOut);
    }

    final utilityNavItems = [
      _NavMeta(
        section: SiteDashboardSection.overview,
        label: s.overview,
        icon: Icons.dashboard_rounded,
      ),
      _NavMeta(
        section: SiteDashboardSection.water,
        label: s.water,
        icon: Icons.water_drop_rounded,
      ),
      _NavMeta(
        section: SiteDashboardSection.electricity,
        label: s.electricity,
        icon: Icons.bolt_rounded,
      ),
      _NavMeta(
        section: SiteDashboardSection.btuCooling,
        label: s.btuCooling,
        icon: Icons.ac_unit_rounded,
      ),
      _NavMeta(
        section: SiteDashboardSection.fuel,
        label: s.fuelDiesel,
        icon: Icons.local_gas_station_rounded,
      ),
    ];

    final brandFg = isDark ? BrandChrome.textDark : BrandChrome.ink;
    final mutedFg =
        isDark ? BrandChrome.textDarkMuted : BrandChrome.inkMuted;

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: DashboardMotion.sidebar,
        curve: DashboardMotion.standard,
        width: asDrawer
            ? null
            : (collapsed ? _collapsedWidth : _expandedWidth),
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        BrandChrome.surfaceDark.withValues(alpha: 0.97),
                        BrandChrome.canvasDark.withValues(alpha: 0.98),
                      ]
                    : [
                        Colors.white,
                        Colors.white,
                      ],
              ),
              border: asDrawer
                  ? null
                  : BorderDirectional(
                      end: BorderSide(
                        color: isDark
                            ? BrandChrome.borderDark
                            : const Color(0xFFC5CCD6),
                        width: 1.5,
                      ),
                    ),
            ),
            child: SafeArea(
              right: false,
              left: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: EdgeInsets.fromLTRB(
                      collapsed ? 8 : 12,
                      8,
                      collapsed ? 8 : 12,
                      8,
                    ),
                    padding: EdgeInsets.fromLTRB(
                      collapsed ? 8 : 12,
                      12,
                      collapsed ? 8 : 12,
                      12,
                    ),
                    decoration: BoxDecoration(
                      gradient: BrandChrome.cardWash(isDark: isDark),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: BrandChrome.border(
                          isDark: isDark,
                          scheme: Theme.of(context).colorScheme,
                        ),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, brandConstraints) {
                        final showBrandText =
                            !collapsed && brandConstraints.maxWidth >= 140;
                        return Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                collapsed ? 6 : 8,
                              ),
                              child: Image.asset(
                                'assets/branding/app_icon_simple.png',
                                width: collapsed ? 22 : 28,
                                height: collapsed ? 22 : 28,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                            if (showBrandText) ...[
                              const SizedBox(width: DashboardSpacing.sm),
                              Expanded(
                                child: Text(
                                  s.smartMetersBrand,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: brandFg,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                ),
                              ),
                              if (!asDrawer)
                                IconButton(
                                  tooltip: s.collapseSidebar,
                                  onPressed: () => ref
                                      .read(sidebarCollapsedProvider.notifier)
                                      .state = true,
                                  icon: Icon(
                                    Icons.chevron_left_rounded,
                                    color: mutedFg,
                                    size: 20,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  if (collapsed && !asDrawer)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: DashboardSpacing.xs),
                      child: IconButton(
                        tooltip: s.expandSidebar,
                        onPressed: () => ref
                            .read(sidebarCollapsedProvider.notifier)
                            .state = false,
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: mutedFg,
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        if (!collapsed) _SidebarGroupLabel(label: s.dashboard),
                        _SidebarItem(
                          icon: Icons.dashboard_rounded,
                          label: s.dashboard,
                          collapsed: collapsed,
                          selected: selectedSiteId == null &&
                              shellSection == DashboardShellSection.sites,
                          onTap: goHome,
                        ),
                        if (!collapsed &&
                            selectedSiteId != null &&
                            siteSummary != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              DashboardSpacing.md,
                              DashboardSpacing.sm,
                              DashboardSpacing.md,
                              DashboardSpacing.xs,
                            ),
                            child: Text(
                              s.localizedName(
                                en: siteSummary.site.nameEn,
                                ar: siteSummary.site.nameAr,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: brandFg,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (selectedSiteId != null) ...[
                          if (!collapsed)
                            _SidebarGroupLabel(label: s.utilities),
                          for (final item in utilityNavItems)
                            _SidebarItem(
                              icon: item.icon,
                              label: item.label,
                              collapsed: collapsed,
                              selected: siteSection == item.section,
                              enabled: true,
                              onTap: () => openSiteSection(item.section),
                            ),
                        ],
                        if (!collapsed) _SidebarGroupLabel(label: s.reports),
                        _SidebarItem(
                          icon: Icons.summarize_rounded,
                          label: s.reports,
                          collapsed: collapsed,
                          selected: selectedSiteId != null &&
                              siteSection == SiteDashboardSection.reports,
                          enabled: selectedSiteId != null,
                          onTap: () =>
                              openSiteSection(SiteDashboardSection.reports),
                        ),
                        if (!collapsed) _SidebarGroupLabel(label: s.account),
                        _SidebarItem(
                          icon: DashboardIcons.settings,
                          label: s.settings,
                          collapsed: collapsed,
                          selected: false,
                          enabled: true,
                          onTap: openSettings,
                        ),
                        if (profile != null && !collapsed)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                            child: BrandInkCard(
                              onTap: openSettings,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: BrandChrome.accent
                                        .withValues(alpha: 0.18),
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: BrandChrome.accent,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: DashboardSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.fullName.trim().isEmpty
                                              ? profile.email
                                              : profile.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: brandFg,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          profile.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: mutedFg,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: mutedFg,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      collapsed ? 8 : 12,
                      0,
                      collapsed ? 8 : 12,
                      8,
                    ),
                    child: collapsed
                        ? Tooltip(
                            message: s.signOut,
                            child: IconButton(
                              onPressed: () {
                                closeDrawerIfNeeded();
                                onSignOut();
                              },
                              style: IconButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                                side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error
                                      .withValues(alpha: 0.45),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.logout_rounded),
                            ),
                          )
                        : OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .error
                                    .withValues(alpha: 0.45),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              closeDrawerIfNeeded();
                              onSignOut();
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: Text(s.signOut),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarGroupLabel extends StatelessWidget {
  const _SidebarGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DashboardSpacing.lg,
        DashboardSpacing.sm,
        DashboardSpacing.md,
        DashboardSpacing.xxs,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isDark
              ? BrandChrome.textDarkMuted.withValues(alpha: 0.75)
              : BrandChrome.inkMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _NavMeta {
  const _NavMeta({
    required this.section,
    required this.label,
    required this.icon,
  });

  final SiteDashboardSection section;
  final String label;
  final IconData icon;
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.collapsed,
    this.selected = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool collapsed;
  final bool selected;
  final bool enabled;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = !widget.enabled
        ? (isDark ? Colors.white38 : BrandChrome.inkMuted.withValues(alpha: 0.5))
        : widget.selected
            ? (isDark ? AppColors.goldSoft : BrandChrome.ink)
            : (isDark ? BrandChrome.textDarkMuted : BrandChrome.inkMuted);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? 0 : DashboardSpacing.sm,
        vertical: DashboardSpacing.xxs,
      ),
      child: Tooltip(
        message: widget.collapsed ? widget.label : '',
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: widget.selected && widget.enabled
                  ? BrandChrome.accent.withValues(alpha: isDark ? 0.22 : 0.18)
                  : _hovered && widget.enabled
                      ? BrandChrome.accent.withValues(alpha: 0.08)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: widget.selected && widget.enabled && !widget.collapsed
                  ? Border(
                      left: BorderSide(color: BrandChrome.accent, width: 3),
                    )
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: widget.collapsed
                      ? Center(
                          child: Icon(
                            widget.icon,
                            size: 20,
                            color: widget.selected
                                ? (isDark
                                    ? AppColors.goldSoft
                                    : BrandChrome.iconGlyph)
                                : fg,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DashboardSpacing.md,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.icon,
                                size: 20,
                                color: widget.selected
                                    ? (isDark
                                        ? AppColors.goldSoft
                                        : BrandChrome.iconGlyph)
                                    : fg,
                              ),
                              const SizedBox(width: DashboardSpacing.sm),
                              Expanded(
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: fg,
                                    fontWeight: widget.selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String shellUserRoleLabel(UserRole role) => shellUserRoleLabelEn(role);
