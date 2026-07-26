import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'partner_app_links.dart';
import 'partner_web_config.dart';
import 'partner_web_links.dart';

/// Opens sibling Smart Meters apps via custom URL schemes.
abstract final class PartnerAppLauncher {
  static Future<bool> openDashboardSite(
    String siteId, {
    String? section,
    String? date,
  }) {
    return _launch(
      PartnerAppLinks.dashboardSite(siteId, section: section, date: date),
    );
  }

  static Future<bool> openEntrySite(String siteId, {String? categoryCode}) {
    return _launch(
      PartnerAppLinks.entrySite(siteId, categoryCode: categoryCode),
    );
  }

  static Future<bool> openEntryMeter({
    required String siteId,
    required String meterId,
    String? categoryCode,
    String? readingDate,
  }) {
    return _launch(
      PartnerAppLinks.entryMeter(
        siteId: siteId,
        meterId: meterId,
        categoryCode: categoryCode,
        readingDate: readingDate,
      ),
    );
  }

  static Future<bool> openAdminSite(String siteId) {
    return _launch(PartnerAppLinks.adminSite(siteId));
  }

  static Future<bool> openAdminMeter(String meterId) {
    return _launch(PartnerAppLinks.adminMeter(meterId));
  }

  static Future<bool> _launch(Uri uri) async {
    if (kIsWeb && PartnerWebConfig.isConfigured) {
      final webUri = partnerUriToWeb(uri);
      if (webUri != null) {
        return launchUrl(webUri, webOnlyWindowName: '_blank');
      }
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (_) {
      // Fall through to platform-specific handlers.
    }

    if (!kIsWeb && Platform.isMacOS) {
      return _launchOnMacOs(uri);
    }

    return await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> _launchOnMacOs(Uri uri) async {
    final appFolder = switch (uri.scheme) {
      PartnerAppLinks.entryScheme => 'entry_app',
      PartnerAppLinks.adminScheme => 'admin_app',
      PartnerAppLinks.dashboardScheme => 'dashboard_app',
      _ => null,
    };
    if (appFolder == null) return false;

    final appNames = switch (appFolder) {
      'entry_app' => const ['entry_app', 'Smart Meters Entry'],
      'admin_app' => const ['admin_app', 'Smart Meters Admin'],
      _ => const ['Smart Meters'],
    };

    for (final name in appNames) {
      final result = await Process.run('open', ['-a', name, uri.toString()]);
      if (result.exitCode == 0) return true;
    }

    for (final bundlePath in _macOsBundleCandidates(appFolder)) {
      if (!File(bundlePath).existsSync()) continue;
      final result = await Process.run('open', [
        '-a',
        bundlePath,
        uri.toString(),
      ]);
      if (result.exitCode == 0) return true;
    }

    return false;
  }

  static List<String> _macOsBundleCandidates(String appFolder) {
    final envRoot = Platform.environment['SMART_METERS_ROOT'];
    final home = Platform.environment['HOME'];
    final roots = <String>[
      if (envRoot != null && envRoot.isNotEmpty) envRoot,
      if (home != null && home.isNotEmpty)
        '$home/Downloads/smart-meters-platform',
    ];

    final paths = <String>[];
    for (final root in roots) {
      for (final mode in const ['Debug', 'Release']) {
        paths.add(
          '$root/apps/$appFolder/build/macos/Build/Products/$mode/$appFolder.app',
        );
      }
    }
    return paths;
  }
}
