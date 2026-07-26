import 'package:flutter/material.dart';

import '../../theme/design_system/dashboard_design_system.dart';

/// Visual section with enterprise breathing room.
class EnterpriseSection extends StatelessWidget {
  const EnterpriseSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.bottomGap = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final bool bottomGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap ? DashboardLayout.blockGap : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DashboardTypography.pageTitle(context)),
                    if (subtitle != null) ...[
                      const SizedBox(height: DashboardSpacing.xxs),
                      Text(
                        subtitle!,
                        style: DashboardTypography.label(context),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: DashboardSpacing.md),
            child!,
          ],
        ],
      ),
    );
  }
}
