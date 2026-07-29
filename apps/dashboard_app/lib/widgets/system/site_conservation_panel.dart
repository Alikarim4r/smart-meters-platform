import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/conservation_providers.dart';
import '../conservation/period_comparison_cards.dart';

/// Gated Conservation section body. Callers must only navigate here when
/// `conservation_module` AND `period_compare` are enabled.
class SiteConservationPanel extends ConsumerWidget {
  const SiteConservationPanel({
    super.key,
    required this.siteId,
    required this.useDesktop,
  });

  final String siteId;
  final bool useDesktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync =
        ref.watch(conservationPeriodCompareEnabledProvider(siteId));
    return enabledAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (enabled) {
        if (!enabled) {
          // Safety: never show comparison UI when flags are OFF.
          return const SizedBox.shrink();
        }
        final comparisonsAsync =
            ref.watch(conservationPeriodComparisonsProvider(siteId));
        return comparisonsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (bundles) {
            if (bundles.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No utility meters available for period comparison.',
                ),
              );
            }
            return ListView(
              padding: EdgeInsets.all(useDesktop ? 20 : 12),
              children: [
                const Text(
                  'Period comparisons',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Previous period and same period last year — derived only. '
                  'Not a saving claim.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                for (final b in bundles) ...[
                  PeriodComparisonCard(
                    title: 'Previous period',
                    utilityLabel: b.utilityLabel,
                    result: b.previous,
                  ),
                  const SizedBox(height: 8),
                  PeriodComparisonCard(
                    title: 'Compared with same period last year',
                    utilityLabel: b.utilityLabel,
                    result: b.yoy,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
