import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/dashboard_date_range.dart';
import '../../utils/site_system_navigation.dart';
import 'utility_analytics_section.dart';

/// Defers chart mount by one frame so meter cards stay responsive.
class LazyUtilityAnalyticsSection extends ConsumerStatefulWidget {
  const LazyUtilityAnalyticsSection({
    super.key,
    required this.siteId,
    required this.system,
    required this.categoryId,
    required this.unitCode,
    required this.dateSelection,
    required this.onDateSelectionChanged,
    required this.useDesktop,
    this.embedded = false,
  });

  final String siteId;
  final UtilitySystemKey system;
  final String categoryId;
  final String unitCode;
  final DashboardDateSelection dateSelection;
  final ValueChanged<DashboardDateSelection> onDateSelectionChanged;
  final bool useDesktop;
  final bool embedded;

  @override
  ConsumerState<LazyUtilityAnalyticsSection> createState() =>
      _LazyUtilityAnalyticsSectionState();
}

class _LazyUtilityAnalyticsSectionState
    extends ConsumerState<LazyUtilityAnalyticsSection> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SizedBox(
        height: 48,
        child: Center(child: LinearProgressIndicator()),
      );
    }

    return RepaintBoundary(
      child: UtilityAnalyticsSection(
        siteId: widget.siteId,
        system: widget.system,
        categoryId: widget.categoryId,
        unitCode: widget.unitCode,
        dateSelection: widget.dateSelection,
        onDateSelectionChanged: widget.onDateSelectionChanged,
        useDesktop: widget.useDesktop,
        compactHeader: widget.embedded,
      ),
    );
  }
}
