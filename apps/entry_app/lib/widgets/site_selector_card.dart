import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

class SiteSelectorCard extends StatelessWidget {
  const SiteSelectorCard({
    super.key,
    required this.site,
    required this.onTap,
    this.isAr = false,
  });

  final Site site;
  final VoidCallback onTap;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = isAr && site.nameAr.trim().isNotEmpty
        ? site.nameAr
        : site.nameEn;
    final subtitleParts = <String>[
      site.displayZoneName,
      site.typeLabel(isAr: isAr),
      if (site.location != null && site.location!.isNotEmpty) site.location!,
    ];

    return BrandLedgerRow(
      title: title,
      subtitle: subtitleParts.join(' · '),
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(BrandRadius.chip),
        ),
        child: Icon(
          Icons.apartment_outlined,
          color: scheme.onPrimaryContainer,
          size: 21,
        ),
      ),
    );
  }
}
