import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'entry_partner_navigation.dart';
import '../screens/entry_shell_screen.dart';

/// Entry shell with incoming partner deep-link handling.
class EntryShellWithLinks extends ConsumerWidget {
  const EntryShellWithLinks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<PartnerLinkIntent?>(pendingEntryPartnerLinkProvider,
        (previous, next) async {
      if (next == null) return;
      await applyEntryPartnerLink(ref, context, next);
      ref.read(pendingEntryPartnerLinkProvider.notifier).state = null;
    });

    return PartnerLinkListener(
      expectedScheme: PartnerAppLinks.entryScheme,
      onLink: (intent) {
        ref.read(pendingEntryPartnerLinkProvider.notifier).state = intent;
      },
      child: const EntryShellScreen(),
    );
  }
}
