import 'package:flutter/material.dart';

import 'brand_chrome.dart';

/// Compatibility aliases that follow the active [BrandChrome] palette.
/// Prefer [BrandChrome] directly in new code.
abstract final class AppColors {
  static Color get navy => BrandChrome.primary;
  static Color get navyMuted => BrandChrome.accentDeep;
  static Color get gold => BrandChrome.accent;
  static Color get goldSoft => BrandChrome.accentSoft;
  static Color get surface => BrandChrome.canvasLight;
  static const surfaceElevated = Color(0xFFFFFFFF);
  static Color get border => BrandChrome.borderLight;
  static Color get textMuted => BrandChrome.inkMuted;
}
