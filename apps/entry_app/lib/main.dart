import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'l10n/entry_strings.dart';
import 'navigation/entry_shell_with_links.dart';
import 'offline/offline_storage_service.dart';
import 'providers/preferences_providers.dart';
import 'theme/entry_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BrandChrome.use(AppBrandPalette.entry);
  await bootstrapSupabase(appKey: 'entry');
  await OfflineStorageService.init();
  runApp(const ProviderScope(child: EntryApp()));
}

class EntryApp extends ConsumerWidget {
  const EntryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(entryThemeModeProvider);
    final locale = ref.watch(entryLocaleProvider);
    final s = EntryStrings(locale);

    return MaterialApp(
      title: s.appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localeResolutionCallback: (deviceLocale, supported) {
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
      themeMode: themeMode,
      theme: EntryTheme.light(),
      darkTheme: EntryTheme.dark(),
      builder: (context, child) => BrandSurfaceBackground(
        child: child ?? const SizedBox.shrink(),
      ),
      home: AuthGate(
        appTitle: s.appTitle,
        brandMarkAsset: BrandMarkAssets.entry,
        allowSelfRegistration: true,
        locale: locale,
        onLocaleChanged: (next) =>
            ref.read(entryLocaleProvider.notifier).setLocale(next),
        allowedForProfile: (profile) =>
            profile.isTechnician ||
            profile.isSiteAdmin ||
            profile.isSuperAdmin,
        siteAccessRequirement: SiteAccessRequirement.write,
        accessDeniedMessageBuilder: (profile) {
          if (profile.isViewer) {
            return 'This account is a Viewer (Dashboard only). '
                'Ask an admin to approve it as Technician to use Entry.';
          }
          return 'Entry app requires technician, site_admin, or super_admin '
              'with at least one writable site.';
        },
        homeBuilder: (context) => const EntryShellWithLinks(),
      ),
    );
  }
}
