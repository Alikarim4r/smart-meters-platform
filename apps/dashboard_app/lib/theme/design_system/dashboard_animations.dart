import 'package:flutter/material.dart';

import 'dashboard_motion.dart';

/// Reusable animation builders.
abstract final class DashboardAnimations {
  static Widget fadeScale({
    required Widget child,
    required Animation<double> animation,
  }) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1).animate(
          CurvedAnimation(parent: animation, curve: DashboardMotion.standard),
        ),
        child: child,
      ),
    );
  }

  static Widget chartFade({
    required Widget child,
    required Key key,
  }) {
    return AnimatedSwitcher(
      duration: DashboardMotion.chart,
      switchInCurve: DashboardMotion.enter,
      switchOutCurve: DashboardMotion.exit,
      transitionBuilder: (widget, animation) => fadeScale(
        child: widget,
        animation: animation,
      ),
      child: KeyedSubtree(key: key, child: child),
    );
  }
}
