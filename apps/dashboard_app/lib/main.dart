import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'l10n/app_strings.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'screens/dashboard_app_shell.dart';
import 'theme/dashboard_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  await bootstrapSupabase(appKey: 'dashboard');
  runApp(const ProviderScope(child: DashboardApp()));
}

class DashboardApp extends ConsumerWidget {
  const DashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final s = AppStrings(locale);

    return MaterialApp(
      title: s.appTitle,
      locale: locale,
      localeResolutionCallback: (deviceLocale, supported) {
        // Prefer saved/app locale; default English when nothing matches.
        for (final item in supported) {
          if (item.languageCode == locale.languageCode) return item;
        }
        return const Locale('en');
      },
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildDashboardLightTheme(),
      darkTheme: buildDashboardDarkTheme(),
      builder: (context, child) => BrandSurfaceBackground(
        child: child ?? const SizedBox.shrink(),
      ),
      home: AuthGate(
        appTitle: s.appTitle,
        brandMarkAsset: BrandMarkAssets.dashboard,
        allowSelfRegistration: true,
        registrationRequestedRole: 'viewer',
        locale: locale,
        onLocaleChanged: (next) =>
            ref.read(localeProvider.notifier).setLocale(next),
        allowedForProfile: (profile) =>
            profile.isSuperAdmin ||
            profile.isSiteAdmin ||
            profile.isTechnician ||
            profile.isViewer,
        siteAccessRequirement: SiteAccessRequirement.read,
        homeBuilder: (context) => const DashboardAppShell(),
      ),
    );
  }
}
