import 'package:dashboard_app/theme/design_system/dashboard_layout.dart';
import 'package:dashboard_app/widgets/system/meter_readings_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('meter card layout', () {
    test('desktop wide layout uses enterprise card width', () {
      expect(
        meterCardLayoutWidth(maxWidth: 1500, useDesktop: true),
        DashboardLayout.meterCardWidth + 8,
      );
      expect(
        meterCardLayoutWidth(maxWidth: 1200, useDesktop: true),
        DashboardLayout.meterCardWidth,
      );
      expect(
        meterCardLayoutWidth(maxWidth: 900, useDesktop: true),
        320,
      );
      expect(
        meterCardLayoutWidth(maxWidth: 700, useDesktop: true),
        700,
      );
    });

    test('mobile layout uses full width', () {
      expect(
        meterCardLayoutWidth(maxWidth: 400, useDesktop: false),
        400,
      );
    });
  });
}
