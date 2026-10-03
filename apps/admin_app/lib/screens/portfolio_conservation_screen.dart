import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';
import '../l10n/admin_strings.dart';

/// Executive portfolio dashboard — limited cards, verified-only totals.
/// Visible only when portfolio_optimization flag is ON.
class PortfolioConservationScreen extends ConsumerWidget {
  const PortfolioConservationScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          adminText(context, 'Conservation Portfolio', 'محفظة الترشيد'),
        ),
      ),
      body: FutureBuilder<List<PortfolioSummary>>(
        future: PortfolioSummaryRepository(
          client,
        ).listForOrg(organizationId, limit: 50),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? const <PortfolioSummary>[];
          PortfolioSummary? org;
          for (final r in rows) {
            if (r.scopeLevel == 'organization') {
              org = r;
              break;
            }
          }
          final siteRows = rows
              .where((e) => e.scopeLevel == 'site')
              .take(20)
              .toList();

          // No cached rows ⇒ empty state (never invent 0 portfolio totals).
          if (rows.isEmpty || org == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No portfolio summary cached yet.\n'
                'Refresh on demand after verified savings exist.\n'
                'Totals are not invented as zero.',
                style: TextStyle(fontSize: 13),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                adminText(
                  context,
                  'Executive view — verified savings only. Refresh on demand.',
                  'عرض تنفيذي — الوفورات المتحقق منها فقط. حدّث عند الحاجة.',
                ),
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _card(
                    'Verified Savings',
                    org.verifiedSavingsTotal.toStringAsFixed(1),
                  ),
                  _card(
                    'Cost Avoided',
                    org.costAvoidedTotal == null
                        ? 'N/A'
                        : '${org.costAvoidedTotal!.toStringAsFixed(1)} '
                              '${org.costCurrency ?? 'QAR'}',
                  ),
                  _card(
                    'Carbon Avoided',
                    org.carbonAvoidedTotal == null
                        ? 'N/A'
                        : '${org.carbonAvoidedTotal!.toStringAsFixed(1)} '
                              '${org.carbonUnit ?? ''}',
                  ),
                  _card('Sites Above Target', '${org.sitesAboveTarget}'),
                  _card('Open High-Priority Opps', '${org.openOpportunities}'),
                  _card('Verification Pending', '${org.verificationPending}'),
                  _card('Savings Not Sustained', '${org.savingsNotSustained}'),
                  _card(
                    'Data Confidence',
                    org.dataConfidenceAvg == null
                        ? 'N/A'
                        : org.dataConfidenceAvg!.toStringAsFixed(0),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                adminText(
                  context,
                  'Site rankings (cached)',
                  'ترتيب المواقع (مخزن مؤقتًا)',
                ),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (siteRows.isEmpty)
                Text(
                  adminText(
                    context,
                    'No site summaries cached. Refresh portfolio manually.',
                    'لا توجد ملخصات مواقع مخزنة. حدّث المحفظة يدويًا.',
                  ),
                )
              else
                for (final s in siteRows)
                  ListTile(
                    dense: true,
                    title: Text(
                      s.siteId == null
                          ? 'Site —'
                          : 'Site ${s.siteId!.substring(0, 8)}…',
                    ),
                    subtitle: Text(
                      'Verified ${s.verifiedSavingsTotal.toStringAsFixed(1)} · '
                      'method ${s.rankingMethod ?? '—'}',
                    ),
                    trailing: Text(
                      s.priorityScore == null
                          ? '—'
                          : s.priorityScore!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(String title, String value) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
