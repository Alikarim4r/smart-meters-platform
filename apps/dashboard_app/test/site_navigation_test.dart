import 'package:dashboard_app/utils/site_system_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('site navigation', () {
    test('main site nav excludes Network section', () {
      expect(
        mainSiteDashboardSections.contains(SiteDashboardSection.network),
        isFalse,
      );
      expect(
        mobileSiteDashboardSections.contains(SiteDashboardSection.network),
        isFalse,
      );
      expect(
        desktopSiteDashboardSections.contains(SiteDashboardSection.network),
        isFalse,
      );
    });

    test('normalizeSiteDashboardSection redirects network to water', () {
      expect(
        normalizeSiteDashboardSection(SiteDashboardSection.network),
        SiteDashboardSection.water,
      );
      expect(
        normalizeSiteDashboardSection(SiteDashboardSection.water),
        SiteDashboardSection.water,
      );
    });

    test('isNetworkSectionVisible hides network from active UI', () {
      expect(isNetworkSectionVisible(SiteDashboardSection.network), isFalse);
      expect(isNetworkSectionVisible(SiteDashboardSection.water), isTrue);
    });

    test('conservation nav appears only when flag gate is on', () {
      expect(
        siteDashboardSectionsForFlags(conservationVisible: false)
            .contains(SiteDashboardSection.conservation),
        isFalse,
      );
      expect(
        siteDashboardSectionsForFlags(conservationVisible: true)
            .contains(SiteDashboardSection.conservation),
        isTrue,
      );
      expect(
        siteDashboardSectionsForFlags(conservationVisible: false),
        mainSiteDashboardSections,
      );
    });

    test('normalize hides conservation when gate is off', () {
      expect(
        normalizeSiteDashboardSection(
          SiteDashboardSection.conservation,
          conservationVisible: false,
        ),
        SiteDashboardSection.overview,
      );
      expect(
        normalizeSiteDashboardSection(
          SiteDashboardSection.conservation,
          conservationVisible: true,
        ),
        SiteDashboardSection.conservation,
      );
    });
  });
}
