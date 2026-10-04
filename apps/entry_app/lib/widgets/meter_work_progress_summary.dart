import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../models/meter_entry_status.dart';

class MeterWorkProgressSummary extends StatelessWidget {
  const MeterWorkProgressSummary({
    super.key,
    required this.summary,
    this.isArabic = false,
  });

  final MeterWorkSummary summary;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    String t(String en, String ar) => isArabic ? ar : en;
    return BrandMetricLedger(
      items: [
        BrandMetricItem(
          label: t('Total', 'الإجمالي'),
          value: '${summary.total}',
          icon: Icons.speed_outlined,
        ),
        BrandMetricItem(
          label: t('Pending', 'معلّق'),
          value: '${summary.pending}',
          tone: BrandStatusTone.warning,
        ),
        BrandMetricItem(
          label: t('Saved locally', 'محفوظ محلياً'),
          value: '${summary.savedLocally}',
          tone: BrandStatusTone.info,
        ),
        BrandMetricItem(
          label: t('Submitted', 'مُرسَل'),
          value: '${summary.submitted}',
          tone: BrandStatusTone.success,
        ),
        BrandMetricItem(
          label: t('Failed sync', 'فشل المزامنة'),
          value: '${summary.failedSync}',
          tone: BrandStatusTone.danger,
        ),
      ],
    );
  }
}

class MeterListFilterChips extends StatelessWidget {
  const MeterListFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.isArabic = false,
  });

  final MeterListFilter selected;
  final ValueChanged<MeterListFilter> onSelected;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: MeterListFilter.values.map((filter) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilterChip(
              label: Text(filter.localizedLabel(isArabic)),
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}
