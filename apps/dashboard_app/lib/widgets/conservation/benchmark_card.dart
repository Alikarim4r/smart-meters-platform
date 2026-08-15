import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/conservation_strings.dart';
import '../../providers/conservation_providers.dart';
import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// Intensity + optional peer median. Never invents m² / occupancy.
class BenchmarkCard extends StatelessWidget {
  const BenchmarkCard({
    super.key,
    required this.bundle,
  });

  final ConservationBenchmarkBundle bundle;

  @override
  Widget build(BuildContext context) {
    final s = ConservationStrings.of(context);
    final intensity = bundle.intensity;
    final missingNorm = intensity?.missingNormalization == true ||
        bundle.warnings.contains(IntensityResult.normalizationMissingMessage);
    return Card(
      elevation: 0,
      color: DashboardColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: DashboardPalette.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.utilityBenchmark(bundle.utilityLabel),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _kv(
              s.consumption,
              bundle.consumption == null
                  ? s.na
                  : '${_fmt(bundle.consumption!)} ${bundle.unitCode}',
            ),
            if (intensity != null) ...[
              _kv(
                s.intensityPerM2,
                intensity.perM2 == null
                    ? s.normalizationDataMissing
                    : '${_fmt(intensity.perM2!)} ${bundle.unitCode}/m²',
              ),
              _kv(
                s.intensityPerOccupant,
                intensity.perOccupant == null
                    ? s.normalizationDataMissing
                    : '${_fmt(intensity.perOccupant!)} ${bundle.unitCode}/occ',
              ),
            ],
            _kv(
              s.peerMedian,
              bundle.peerMedian == null
                  ? (bundle.peerProfileCount > 0
                      ? s.peerProfilesNa(bundle.peerProfileCount)
                      : s.na)
                  : '${_fmt(bundle.peerMedian!)} ${bundle.unitCode}',
            ),
            if (bundle.snapshot.peerGroup != null)
              _kv(s.peerGroup, bundle.snapshot.peerGroup!.dbValue),
            const SizedBox(height: 8),
            if (missingNorm)
              Text(
                s.normalizationDataMissing,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.brown.shade800,
                ),
              ),
            if (bundle.warnings.any(
              (w) => w.contains('Not normalized'),
            ))
              Text(
                s.notNormalized,
                style: TextStyle(
                  fontSize: 11,
                  color: DashboardPalette.textMuted,
                ),
              ),
            Text(
              '${s.confidenceLabel(bundle.snapshot.confidenceScore)} · '
              '${s.completenessPct((bundle.snapshot.completeness * 100).toStringAsFixed(0))}',
              style: TextStyle(fontSize: 11, color: DashboardPalette.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(fontSize: 12, color: DashboardPalette.textMuted),
            ),
          ),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
