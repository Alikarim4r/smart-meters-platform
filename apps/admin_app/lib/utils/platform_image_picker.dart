import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

const _desktopImageTypes = file_selector.XTypeGroup(
  label: 'images',
  extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'],
);

/// Whether gallery selection should use the operating system's file dialog.
bool usesDesktopImageFileSelector({
  required TargetPlatform platform,
  required bool isWeb,
}) {
  if (isWeb) return false;
  return platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

/// Picks an image using a native file dialog on desktop and ImagePicker on
/// mobile/web. ImagePicker's desktop implementations do not consistently
/// expose a usable gallery dialog, while file_selector does.
Future<file_selector.XFile?> pickPlatformImage({
  required ImageSource source,
  ImagePicker? picker,
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
  bool requestFullMetadata = true,
}) {
  if (usesDesktopImageFileSelector(
    platform: defaultTargetPlatform,
    isWeb: kIsWeb,
  )) {
    return file_selector.openFile(
      acceptedTypeGroups: const [_desktopImageTypes],
    );
  }
  return (picker ?? ImagePicker()).pickImage(
    source: source,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    imageQuality: imageQuality,
    requestFullMetadata: requestFullMetadata,
  );
}
