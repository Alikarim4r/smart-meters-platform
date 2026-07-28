import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../providers/meter_reading_card_providers.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../../utils/dashboard_date_range.dart';
import '../../utils/efficiency_metric.dart';
import '../../utils/site_system_navigation.dart';
import '../system/lazy_utility_analytics_section.dart';
import 'enterprise_section.dart';

/// Independent analytics workspace — visually separated from meter cards.
class AnalyticsWorkspace extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final efficiency = system == UtilitySystemKey.btu
        ? ref.watch(selectedEfficiencyMetricProvider(siteId))
        : null;
    final title = efficiency == null
        ? s.utilityAnalytics(system)
        : (s.isAr
            ? 'تحليلات ${efficiency.labelAr}'
            : '${efficiency.labelEn} analysis');
    final subtitle = efficiency == null
        ? s.independentWorkspace
        : (s.isAr
            ? 'مخططات الكفاءة — اختر نوع الرسم'
            : 'Efficiency charts — pick a chart type');
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
            title: title,
            subtitle: subtitle,
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
