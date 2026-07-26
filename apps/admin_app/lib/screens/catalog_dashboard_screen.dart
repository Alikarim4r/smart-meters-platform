import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'categories_tab.dart';
import 'sources_tab.dart';
import 'units_tab.dart';

/// Catalog tabs without outer scaffold — used inside [AdminHomeScreen].
class CatalogDashboardBody extends ConsumerStatefulWidget {
  const CatalogDashboardBody({super.key});

  @override
  ConsumerState<CatalogDashboardBody> createState() =>
      _CatalogDashboardBodyState();
}

class _CatalogDashboardBodyState extends ConsumerState<CatalogDashboardBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Units'),
            Tab(text: 'Sources'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [CategoriesTab(), UnitsTab(), SourcesTab()],
          ),
        ),
      ],
    );
  }
}

/// Standalone catalog screen (kept for tests / direct navigation).
class CatalogDashboardScreen extends StatelessWidget {
  const CatalogDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SafeArea(child: CatalogDashboardBody()));
  }
}
