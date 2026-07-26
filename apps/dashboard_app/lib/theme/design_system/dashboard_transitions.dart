import 'package:flutter/material.dart';

import 'dashboard_motion.dart';

/// Page and overlay transitions.
abstract final class DashboardTransitions {
  static Widget fade({
    required Widget child,
    required Animation<double> animation,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: DashboardMotion.enter,
      ),
      child: child,
    );
  }

  static Route<T> dialogRoute<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return DialogRoute<T>(
      context: context,
      builder: builder,
      barrierColor: Colors.black.withValues(alpha: 0.72),
    );
  }
}
