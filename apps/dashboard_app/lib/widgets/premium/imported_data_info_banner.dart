import 'package:flutter/material.dart';

import '../../theme/dashboard_theme.dart';
import '../../utils/dashboard_filters.dart';

/// Subtle one-line hint for sites with imported historical readings.
class ImportedDataInfoBanner extends StatelessWidget {
  const ImportedDataInfoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.infoSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.infoBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: colors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAr ? kImportedReadingsHintAr : kImportedReadingsHint,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    height: 1.3,
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
