import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/dashboard_date_range.dart';
import '../../utils/dashboard_filters.dart';
import '../../utils/site_system_navigation.dart';
import 'utility_analytics_section.dart';

/// Defers chart mount so meter cards stay responsive on large sites.
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
  bool _expanded = false;

  bool get _deferHeavy => siteHasImportedHistoricalMonths(widget.siteId);

  @override
  void initState() {
    super.initState();
    if (_deferHeavy) {
      // Large imports: wait for an explicit expand (keeps first paint light).
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (_deferHeavy && !_expanded) {
      return OutlinedButton.icon(
        onPressed: () => setState(() {
          _expanded = true;
          _ready = true;
        }),
        icon: const Icon(Icons.insights_outlined, size: 18),
        label: Text(isAr ? 'عرض التحليلات والمخططات' : 'Show analytics & charts'),
      );
    }

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
