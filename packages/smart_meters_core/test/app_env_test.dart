import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('APP_ENV defaults to production when unset', () {
    expect(AppEnv.current, AppEnv.production);
    expect(AppEnv.showStagingHints, isFalse);
    expect(AppEnv.showDemoSiteUx, isFalse);
  });
}
