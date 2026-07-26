import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'l10n/admin_strings.dart';
import 'navigation/admin_shell_with_links.dart';
import 'providers/preferences_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase();
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(adminThemeModeProvider);
    final locale = ref.watch(adminLocaleProvider);
    final s = AdminStrings(locale);

    return MaterialApp(
      title: s.appTitle,
      locale: locale,
      localeResolutionCallback: (deviceLocale, supported) {
        for (final item in supported) {
          if (item.languageCode == locale.languageCode) return item;
        }
        return const Locale('en');
      },
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: themeMode,
      theme: BrandTheme.light(),
      darkTheme: BrandTheme.dark(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          BrandSurfaceBackground(child: child ?? const SizedBox.shrink()),
      home: AuthGate(
        appTitle: s.appTitle,
        brandMarkAsset: BrandMarkAssets.admin,
        locale: locale,
        onLocaleChanged: (next) =>
            ref.read(adminLocaleProvider.notifier).setLocale(next),
        allowedForProfile: (profile) =>
            profile.isSuperAdmin || profile.isSiteAdmin,
        accessDeniedMessage: 'Admin app requires super_admin or site_admin.',
        homeBuilder: (context) => const AdminHomeWithLinks(),
      ),
    );
  }
}
