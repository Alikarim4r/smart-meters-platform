import 'package:flutter/animation.dart';

/// Duration tokens for enterprise motion.
abstract final class DashboardMotion {
  static const Duration button = Duration(milliseconds: 120);
  static const Duration card = Duration(milliseconds: 150);
  static const Duration sidebar = Duration(milliseconds: 180);
  static const Duration dialog = Duration(milliseconds: 200);
  static const Duration chart = Duration(milliseconds: 200);
  static const Duration searchDebounce = Duration(milliseconds: 220);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
}
