import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../screens/meter_detail_screen.dart';
import '../screens/site_detail_screen.dart';

final pendingAdminPartnerLinkProvider = StateProvider<PartnerLinkIntent?>(
  (ref) => null,
);

Future<void> launchAdminPartnerApp(
  BuildContext context, {
  required Future<bool> Function() action,
  required String appLabel,
}) async {
  final launched = await action();
  if (!context.mounted || launched) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Could not open $appLabel.')));
}

void queueAdminPartnerLink(WidgetRef ref, PartnerLinkIntent intent) {
  ref.read(pendingAdminPartnerLinkProvider.notifier).state = intent;
}

Future<void> applyAdminPartnerLink(
  BuildContext context,
  PartnerLinkIntent intent, {
  required void Function(int sectionIndex) selectSection,
}) async {
  switch (intent.kind) {
    case PartnerLinkKind.adminSite:
      selectSection(0);
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SiteDetailScreen(siteId: intent.siteId),
        ),
      );
    case PartnerLinkKind.adminMeter:
      final meterId = intent.meterId;
      if (meterId == null || meterId.isEmpty) return;
      selectSection(1);
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MeterDetailScreen(meterId: meterId),
        ),
      );
    default:
      return;
  }
}
