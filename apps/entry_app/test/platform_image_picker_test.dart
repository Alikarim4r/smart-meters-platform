import 'package:entry_app/utils/platform_image_picker.dart';
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

  test('mobile keeps image picker; web is not classified as desktop selector',
      () {
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
    // Web uses file_selector via kIsWeb branch, not the desktop helper.
    expect(
      usesDesktopImageFileSelector(platform: TargetPlatform.macOS, isWeb: true),
      isFalse,
    );
  });
}
