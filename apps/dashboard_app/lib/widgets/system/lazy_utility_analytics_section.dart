import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/dashboard_date_range.dart';
import '../../utils/site_system_navigation.dart';
import 'utility_analytics_section.dart';

/// Utility consumption charts — always visible on water / electricity / BTU / fuel.
///
/// Chart period chips stay independent of the meter-card date range (default:
/// last 7 days) so opening a historical meter period does not force a heavy
/// month-long chart scan.
class LazyUtilityAnalyticsSection extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return RepaintBoundary(
      child: UtilityAnalyticsSection(
        siteId: siteId,
        system: system,
        categoryId: categoryId,
        unitCode: unitCode,
        dateSelection: dateSelection,
        onDateSelectionChanged: onDateSelectionChanged,
        useDesktop: useDesktop,
        compactHeader: embedded,
      ),
    );
  }
}
