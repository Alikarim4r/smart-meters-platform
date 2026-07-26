import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../system/lazy_utility_analytics_section.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import 'enterprise_section.dart';
import '../../utils/dashboard_date_range.dart';
import '../../utils/site_system_navigation.dart';

/// Independent analytics workspace — visually separated from meter cards.
class AnalyticsWorkspace extends StatelessWidget {
  const AnalyticsWorkspace({
    super.key,
    required this.siteId,
    required this.system,
    required this.categoryId,
    required this.unitCode,
    required this.dateSelection,
    required this.onDateSelectionChanged,
    required this.useDesktop,
  });

  final String siteId;
  final UtilitySystemKey system;
  final String categoryId;
  final String unitCode;
  final DashboardDateSelection dateSelection;
  final ValueChanged<DashboardDateSelection> onDateSelectionChanged;
  final bool useDesktop;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = DashboardColors.card(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(DashboardRadius.card),
        border: Border.all(
          color: DashboardColors.border(context).withValues(alpha: 0.35),
        ),
      ),
      padding: EdgeInsets.all(
        useDesktop ? DashboardSpacing.md : DashboardSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EnterpriseSection(
            title: s.utilityAnalytics(system),
            subtitle: s.independentWorkspace,
            bottomGap: false,
          ),
          const SizedBox(height: DashboardSpacing.md),
          LazyUtilityAnalyticsSection(
            siteId: siteId,
            system: system,
            categoryId: categoryId,
            unitCode: unitCode,
            dateSelection: dateSelection,
            onDateSelectionChanged: onDateSelectionChanged,
            useDesktop: useDesktop,
            embedded: true,
          ),
        ],
      ),
    );
  }
}
