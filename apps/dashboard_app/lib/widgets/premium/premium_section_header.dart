import 'package:flutter/material.dart';

import '../../theme/dashboard_theme.dart';

class PremiumSectionHeader extends StatelessWidget {
  const PremiumSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showDivider = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = dashboardColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        SizedBox(height: showDivider ? 14 : 12),
        if (showDivider) Divider(height: 1, color: colors.border),
      ],
    );
  }
}
