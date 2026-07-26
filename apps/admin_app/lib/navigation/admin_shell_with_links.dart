import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../navigation/admin_partner_navigation.dart';
import '../screens/admin_home_screen.dart';

/// Admin shell with incoming partner deep-link handling.
class AdminHomeWithLinks extends ConsumerWidget {
  const AdminHomeWithLinks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PartnerLinkListener(
      expectedScheme: PartnerAppLinks.adminScheme,
      onLink: (intent) => queueAdminPartnerLink(ref, intent),
      child: const AdminHomeScreen(),
    );
  }
}
