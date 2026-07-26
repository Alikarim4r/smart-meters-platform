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

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      drawer: const AdminSettingsDrawer(),
      body: BrandSurfaceBackground(
        child: IndexedStack(
          index: _index,
          children: [
            _tabBody(0),
            _tabBody(1),
            _tabBody(2),
            _tabBody(3),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.account_tree_outlined),
            selectedIcon: const Icon(Icons.account_tree),
            label: s.structure,
          ),
          NavigationDestination(
            icon: const Icon(Icons.speed_outlined),
            selectedIcon: const Icon(Icons.speed),
            label: s.meters,
          ),
          NavigationDestination(
            icon: const Icon(Icons.hub_outlined),
            selectedIcon: const Icon(Icons.hub),
            label: s.network,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: s.users,
          ),
        ],
      ),
    );
  }
}
