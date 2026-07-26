/// Corner radii — 8-point design system.
abstract final class DashboardRadius {
  static const double chip = 8;
  static const double control = 12;
  static const double card = 18;
  static const double dialog = 16;
  static const double sheet = 20;
}

/// Legacy alias — prefer [DashboardRadius].
abstract final class DashboardRadii {
  static const double chip = DashboardRadius.chip;
  static const double control = DashboardRadius.control;
  static const double card = DashboardRadius.card;
  static const double dialog = DashboardRadius.dialog;
}
