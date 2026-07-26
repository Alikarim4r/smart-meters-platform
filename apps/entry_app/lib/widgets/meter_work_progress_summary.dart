import 'package:flutter/material.dart';

import '../models/meter_entry_status.dart';

class MeterWorkProgressSummary extends StatelessWidget {
  const MeterWorkProgressSummary({
    super.key,
    required this.summary,
  });

  final MeterWorkSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatPill(label: 'Total', value: summary.total, color: Colors.blueGrey),
        _StatPill(label: 'Pending', value: summary.pending, color: Colors.orange),
        _StatPill(
          label: 'Saved locally',
          value: summary.savedLocally,
          color: Colors.indigo,
        ),
        _StatPill(label: 'Submitted', value: summary.submitted, color: Colors.green),
        _StatPill(
          label: 'Failed sync',
          value: summary.failedSync,
          color: Colors.red,
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color.shade900,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class MeterListFilterChips extends StatelessWidget {
  const MeterListFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final MeterListFilter selected;
  final ValueChanged<MeterListFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: MeterListFilter.values.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.label),
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}
