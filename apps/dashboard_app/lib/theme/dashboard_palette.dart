import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

/// Dashboard Viewer palette — aligned with shared cream/gold brand language.
abstract final class DashboardPalette {
  static const navy = AppColors.navy;
  static const navyLight = Color(0xFF12233A);
  static const navyMuted = AppColors.navyMuted;
  static const gold = AppColors.gold;
  static const goldSoft = AppColors.goldSoft;
  static const background = BrandChrome.canvasLight;
  static const card = Color(0xFFFFFFFF);
  static const border = BrandChrome.borderLight;
  static const textMuted = BrandChrome.inkMuted;
  static const textPrimary = BrandChrome.ink;
  static const sidebarBorder = Color(0xFF0E2444);

  static const water = Color(0xFF2563EB);
  static const electricity = Color(0xFFD97706);
  static const btu = Color(0xFF7C3AED);
  static const fuel = Color(0xFFEA580C);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);

  static const cardRadius = 20.0;
  static const cardShadow = BoxShadow(
    color: Color(0x143F3426),
    blurRadius: 18,
    offset: Offset(0, 6),
  );
}
