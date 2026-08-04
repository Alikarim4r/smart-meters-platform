import 'package:admin_app/utils/platform_image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop operating systems use the native file selector', () {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(
        usesDesktopImageFileSelector(platform: platform, isWeb: false),
        isTrue,
      );
    }
  });

  test('mobile and web keep the platform image picker', () {
    expect(
      usesDesktopImageFileSelector(
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      isFalse,
    );
    expect(
      usesDesktopImageFileSelector(platform: TargetPlatform.iOS, isWeb: false),
      isFalse,
    );
    expect(
      usesDesktopImageFileSelector(platform: TargetPlatform.macOS, isWeb: true),
      isFalse,
    );
  });
}
