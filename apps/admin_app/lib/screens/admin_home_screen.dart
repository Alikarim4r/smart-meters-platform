import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../navigation/admin_partner_navigation.dart';
import '../providers/preferences_providers.dart';
import '../widgets/admin_settings_drawer.dart';
import 'meters_tab.dart';
import 'network_tab.dart';
import 'structure_tab.dart';
import 'users_tab.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  static const _networkTabIndex = 2;
  int _index = 0;

  /// Lazy-build heavy tabs so post-login first paint only loads Structure.
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    applyAdminNetworkOrientation(networkTabActive: false);
  }

  @override
  void dispose() {
    applyAdminNetworkOrientation(networkTabActive: false);
    super.dispose();
  }

  Future<void> _selectTab(int value) async {
    setState(() {
      _index = value;
      _visitedTabs.add(value);
    });
    await applyAdminNetworkOrientation(
      networkTabActive: value == _networkTabIndex,
    );
  }

  Widget _tabBody(int i) {
    if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
    return switch (i) {
      0 => const StructureTab(),
      1 => const MetersTab(),
      2 => const NetworkTab(),
      _ => const UsersTab(),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PartnerLinkIntent?>(pendingAdminPartnerLinkProvider, (
      previous,
      next,
    ) async {
      if (next == null) return;
      await applyAdminPartnerLink(
        context,
        next,
        selectSection: (section) => _selectTab(section),
      );
      ref.read(pendingAdminPartnerLinkProvider.notifier).state = null;
    });

    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final titles = [s.structure, s.meters, s.network, s.users];
    final icons = const [
      Icons.account_tree_outlined,
      Icons.speed_outlined,
      Icons.hub_outlined,
      Icons.people_outline,
    ];
    final selectedIcons = const [
      Icons.account_tree,
      Icons.speed,
      Icons.hub,
      Icons.people,
    ];
    final useRail = MediaQuery.sizeOf(context).width >= 840;
    final content = BrandSurfaceBackground(
      showMotif: false,
      child: IndexedStack(
        index: _index,
        children: [_tabBody(0), _tabBody(1), _tabBody(2), _tabBody(3)],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        title: Row(
          children: [
            Icon(icons[_index], color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titles[_index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: const AdminSettingsDrawer(),
      body: useRail
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _selectTab,
                  extended: MediaQuery.sizeOf(context).width >= 1180,
                  labelType: MediaQuery.sizeOf(context).width >= 1180
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: [
                    for (var index = 0; index < titles.length; index++)
                      NavigationRailDestination(
                        icon: Icon(icons[index]),
                        selectedIcon: Icon(selectedIcons[index]),
                        label: Text(titles[index]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _selectTab,
              destinations: [
                for (var index = 0; index < titles.length; index++)
                  NavigationDestination(
                    icon: Icon(icons[index]),
                    selectedIcon: Icon(selectedIcons[index]),
                    label: titles[index],
                  ),
              ],
            ),
    );
  }
}
