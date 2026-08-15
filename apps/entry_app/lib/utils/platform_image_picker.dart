import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

const _desktopImageTypes = file_selector.XTypeGroup(
  label: 'images',
  extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif', 'bmp'],
  uniformTypeIdentifiers: <String>['public.image'],
  mimeTypes: <String>['image/*'],
);

/// Web filter — [webWildCards] is the reliable accept attribute path.
const _webImageTypes = file_selector.XTypeGroup(
  label: 'images',
  extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
  mimeTypes: <String>['image/*'],
  webWildCards: <String>['image/*'],
);

/// True for macOS / Windows / Linux native apps (not browser).
bool usesDesktopImageFileSelector({
  required TargetPlatform platform,
  required bool isWeb,
}) {
  if (isWeb) return false;
  return platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

Future<file_selector.XFile?> _openDesktopStudio() {
  return file_selector.openFile(
    acceptedTypeGroups: const [_desktopImageTypes],
  );
}

Future<file_selector.XFile?> _openWebFiles() {
  return file_selector.openFile(
    acceptedTypeGroups: const [_webImageTypes],
  );
}

Future<bool> _ensureMobileCapturePermission(ImageSource source) async {
  if (kIsWeb) return true;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return true;
  }

  if (source == ImageSource.camera) {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  // Gallery / photos — Android 13+ uses photos; older uses storage.
  PermissionStatus status = await Permission.photos.request();
  if (status.isGranted || status.isLimited) return true;
  status = await Permission.storage.request();
  if (status.isGranted || status.isLimited) return true;
  if (status.isPermanentlyDenied) {
    await openAppSettings();
  }
  // On Android 13+ the system photo picker often works without storage
  // permission — allow the picker attempt anyway.
  return defaultTargetPlatform == TargetPlatform.android;
}

/// Picks an image for meter entry.
///
/// Must be the **first** await in a click/tap handler on web. Do not update
/// Riverpod/widget state before calling this — browsers cancel file dialogs
/// once the user-activation gesture is spent on a rebuild.
Future<XFile?> pickPlatformImage({
  required ImageSource source,
  ImagePicker? picker,
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
  bool requestFullMetadata = false,
}) async {
  final imagePicker = picker ?? ImagePicker();
  final desktop = usesDesktopImageFileSelector(
    platform: defaultTargetPlatform,
    isWeb: kIsWeb,
  );

  // Desktop apps: always OS file dialog (reliable Photos/Files picker).
  // Prefer gallery/files even if the UI asked for "camera".
  if (desktop) {
    try {
      return await _openDesktopStudio();
    } catch (_) {
      // Fallback: ImagePicker gallery on some macOS builds.
      try {
        return await imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: maxWidth ?? 1920,
          maxHeight: maxHeight ?? 1920,
          imageQuality: imageQuality ?? 85,
          requestFullMetadata: false,
        );
      } catch (_) {
        return null;
      }
    }
  }

  // Web: ImagePicker owns the reliable <input type=file> path.
  // Never open a second dialog after a cancel (null) — that loses gesture.
  if (kIsWeb) {
    try {
      return await imagePicker.pickImage(
        source: source == ImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: maxWidth ?? 1920,
        maxHeight: maxHeight ?? 1920,
        imageQuality: imageQuality ?? 85,
        requestFullMetadata: false,
      );
    } catch (_) {
      try {
        return await _openWebFiles();
      } catch (_) {
        return null;
      }
    }
  }

  // iOS / Android — request runtime permission, then open camera/gallery.
  final allowed = await _ensureMobileCapturePermission(source);
  if (!allowed) {
    throw PlatformException(
      code: 'permission_denied',
      message: 'Camera/gallery permission denied',
    );
  }

  try {
    return await imagePicker.pickImage(
      source: source,
      // Force size + JPEG recompression so watermark decode rarely fails (HEIC).
      maxWidth: maxWidth ?? 1920,
      maxHeight: maxHeight ?? 1920,
      imageQuality: imageQuality ?? 85,
      requestFullMetadata: requestFullMetadata,
    );
  } on PlatformException catch (error) {
    // Some OEMs cancel the first launch after a permission prompt — one retry.
    if (error.code == 'camera_access_denied' ||
        error.code == 'photo_access_denied') {
      rethrow;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return imagePicker.pickImage(
      source: source,
      maxWidth: maxWidth ?? 1920,
      maxHeight: maxHeight ?? 1920,
      imageQuality: imageQuality ?? 85,
      requestFullMetadata: false,
    );
  }
}
