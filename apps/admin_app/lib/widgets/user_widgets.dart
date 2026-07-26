import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/user_validation.dart';

class ApprovalStatusBadge extends StatelessWidget {
  const ApprovalStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final ApprovalStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ApprovalStatus.pending => ('Pending', Colors.orange.shade800),
      ApprovalStatus.approved => ('Approved', Colors.green.shade800),
      ApprovalStatus.rejected => ('Rejected', Colors.red.shade800),
      ApprovalStatus.suspended => ('Suspended', Colors.deepPurple.shade800),
    };

    return Chip(
      label: Text(label),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }
}

class UserRoleBadge extends StatelessWidget {
  const UserRoleBadge({super.key, required this.role, this.compact = false});

  final UserRole role;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      UserRole.superAdmin => Colors.indigo.shade800,
      UserRole.siteAdmin => Colors.blue.shade800,
      UserRole.technician => Colors.teal.shade800,
      UserRole.technicianRequest => Colors.brown.shade700,
      UserRole.viewer => Colors.blueGrey.shade700,
    };

    return Chip(
      label: Text(userRoleLabel(role)),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}

class ActiveStatusBadge extends StatelessWidget {
  const ActiveStatusBadge({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return const SizedBox.shrink();
    }
    return Chip(
      label: const Text('Inactive'),
      visualDensity: VisualDensity.compact,
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(color: Colors.grey.shade800),
    );
  }
}

class UserListTileCard extends StatelessWidget {
  const UserListTileCard({
    super.key,
    required this.user,
    this.trailing,
    this.onTap,
    this.subtitleExtra,
  });

  final AdminUser user;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? subtitleExtra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = user.profile;
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = BrandChrome.titleColor(
      isDark: isDark,
      scheme: theme.colorScheme,
    );
    final muted = BrandChrome.mutedColor(
      isDark: isDark,
      scheme: theme.colorScheme,
    );

    return BrandInkCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              brandIconWell(
                context: context,
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.email,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              UserRoleBadge(role: profile.role, compact: true),
              ApprovalStatusBadge(
                status: profile.approvalStatus,
                compact: true,
              ),
              ActiveStatusBadge(isActive: profile.isActive),
            ],
          ),
          if (subtitleExtra != null) ...[
            const SizedBox(height: 8),
            subtitleExtra!,
          ],
          const SizedBox(height: 8),
          Text(
            '${user.siteAssignmentCount} site(s) · Created ${formatAdminDateTime(profile.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class UserEmptyState extends StatelessWidget {
  const UserEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.people_outline,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
