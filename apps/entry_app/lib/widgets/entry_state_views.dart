import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';

class EntryLoadingCard extends StatelessWidget {
  const EntryLoadingCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      liveRegion: true,
      child: const BrandSkeletonLedger(rows: 4),
    );
  }
}

class EntryErrorCard extends StatelessWidget {
  const EntryErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return BrandEmptyState(
      icon: Icons.sync_problem_outlined,
      title: message,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(entryText(context, 'Retry', 'إعادة المحاولة')),
      ),
    );
  }
}

class EntryEmptyCard extends StatelessWidget {
  const EntryEmptyCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return BrandEmptyState(icon: Icons.inbox_outlined, title: message);
  }
}
