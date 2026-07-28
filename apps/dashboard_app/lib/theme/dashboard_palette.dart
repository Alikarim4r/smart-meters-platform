import 'package:flutter/material.dart';

/// Dashboard Viewer palette — charcoal + cool slate, white canvas, no gold.
abstract final class DashboardPalette {
  static const navy = Color(0xFF1B2430);
  static const navyLight = Color(0xFF273141);
  static const navyMuted = Color(0xFF3D5A80);
  static const gold = Color(0xFF3D5A80); // legacy name; cool slate accent
  static const goldSoft = Color(0xFFD9E2EC);
  static const background = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E6EB);
  static const textMuted = Color(0xFF5C6775);
  static const textPrimary = Color(0xFF1B2430);
  static const sidebarBorder = Color(0xFF273141);

  static const water = Color(0xFF2563EB);
  static const electricity = Color(0xFFD97706);
  static const btu = Color(0xFF7C3AED);
  static const fuel = Color(0xFFEA580C);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);

  static const cardRadius = 20.0;
  static const cardShadow = BoxShadow(
    color: Color(0x141B2430),
    blurRadius: 18,
    offset: Offset(0, 6),
  );
}
