import 'package:flutter/material.dart';

import 'dashboard_colors.dart';
import 'dashboard_motion.dart';
import 'dashboard_radius.dart';

/// Interactive state styling for enterprise controls.
abstract final class DashboardStates {
  static BorderSide border(BuildContext context, {bool focused = false}) {
    return BorderSide(
      color: focused
          ? DashboardColors.accent(context).withValues(alpha: 0.55)
          : DashboardColors.border(context).withValues(alpha: 0.55),
      width: focused ? 1.2 : 1,
    );
  }

  static BoxDecoration surface({
    required BuildContext context,
    bool hovered = false,
    bool pressed = false,
    bool selected = false,
  }) {
    final base = DashboardColors.card(context);
    return BoxDecoration(
      color: pressed
          ? DashboardColors.cardElevated(context)
          : hovered
              ? base.withValues(alpha: 0.96)
              : base,
      borderRadius: BorderRadius.circular(DashboardRadius.control),
      border: Border.all(
        color: selected
            ? DashboardColors.accent(context).withValues(alpha: 0.4)
            : DashboardColors.border(context).withValues(alpha: 0.45),
      ),
    );
  }

  static Duration get hoverDuration => DashboardMotion.button;
}
