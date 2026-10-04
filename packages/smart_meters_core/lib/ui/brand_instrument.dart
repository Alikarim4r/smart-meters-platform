import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/brand_tokens.dart';

/// Semantic tones shared by all three products. Color always appears beside a
/// visible label or icon so status remains understandable without color.
enum BrandStatusTone { neutral, info, success, warning, danger }

Color brandStatusColor(BuildContext context, BrandStatusTone tone) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return switch (tone) {
    BrandStatusTone.neutral => theme.colorScheme.onSurfaceVariant,
    BrandStatusTone.info => theme.colorScheme.primary,
    BrandStatusTone.success => BrandStatus.success(isDark: isDark),
    BrandStatusTone.warning => BrandStatus.warning(isDark: isDark),
    BrandStatusTone.danger => BrandStatus.danger(isDark: isDark),
  };
}

const brandTabularFigures = <FontFeature>[FontFeature.tabularFigures()];

class BrandStatusMark extends StatelessWidget {
  const BrandStatusMark({
    super.key,
    required this.label,
    required this.tone,
    this.compact = false,
  });

  final String label;
  final BrandStatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = brandStatusColor(context, tone);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 7 : 8,
              height: compact ? 7 : 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(BrandRadius.badge / 2),
              ),
            ),
            const SizedBox(width: BrandSpace.xxs + 2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandContextField {
  const BrandContextField({
    required this.label,
    this.value,
    this.child,
    this.onTap,
    this.flex = 1,
    this.maxLines = 1,
    this.tabular = false,
  }) : assert(value != null || child != null);

  final String label;
  final String? value;
  final Widget? child;
  final VoidCallback? onTap;
  final int flex;
  final int maxLines;
  final bool tabular;
}

/// A compact ruled strip for site, date, utility, scope, and state context.
class BrandContextStrip extends StatelessWidget {
  const BrandContextStrip({
    super.key,
    required this.fields,
    this.loading = false,
    this.accentLine = true,
  }) : assert(fields.length > 0);

  final List<BrandContextField> fields;
  final bool loading;
  final bool accentLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.colorScheme.outlineVariant;
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth < 560 && fields.length > 2;
        final rows = <List<BrandContextField>>[];
        if (!split) {
          rows.add(fields);
        } else {
          rows.add(<BrandContextField>[fields.first]);
          for (var index = 1; index < fields.length; index += 2) {
            rows.add(fields.sublist(index, math.min(index + 2, fields.length)));
          }
        }
        return Material(
          color: theme.colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 1, color: divider),
              for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
                if (rowIndex > 0) Container(height: 1, color: divider),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var fieldIndex = 0;
                        fieldIndex < rows[rowIndex].length;
                        fieldIndex++
                      ) ...[
                        if (fieldIndex > 0) Container(width: 1, color: divider),
                        Expanded(
                          flex: rows[rowIndex][fieldIndex].flex,
                          child: _BrandContextCell(
                            field: rows[rowIndex][fieldIndex],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (accentLine)
                SizedBox(
                  height: 2,
                  child: loading
                      ? LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: theme.colorScheme.primaryContainer,
                        )
                      : ColoredBox(color: theme.colorScheme.primary),
                )
              else
                Container(height: 1, color: divider),
            ],
          ),
        );
      },
    );
  }
}

class _BrandContextCell extends StatelessWidget {
  const _BrandContextCell({required this.field});

  final BrandContextField field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value =
        field.child ??
        Text(
          field.value!,
          maxLines: field.maxLines,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: field.tabular ? brandTabularFigures : null,
          ),
        );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          BrandSpace.md,
          BrandSpace.xs,
          BrandSpace.sm,
          BrandSpace.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: BrandSpace.xxs),
                  value,
                ],
              ),
            ),
            if (field.onTap != null)
              Icon(
                Icons.expand_more,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
    if (field.onTap == null) return MergeSemantics(child: content);
    return Semantics(
      button: true,
      child: InkWell(onTap: field.onTap, child: content),
    );
  }
}

class BrandSectionHeader extends StatelessWidget {
  const BrandSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      BrandSpace.xxs,
      BrandSpace.xl,
      BrandSpace.xxs,
      BrandSpace.xs,
    ),
  });

  final String title;
  final int? count;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: BrandSpace.xs),
            Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: brandTabularFigures,
              ),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class BrandLedger extends StatelessWidget {
  const BrandLedger({
    super.key,
    required this.children,
    this.showOutline = true,
  });

  final List<Widget> children;
  final bool showOutline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandRadius.card),
        side: showOutline
            ? BorderSide(color: scheme.outlineVariant)
            : BorderSide.none,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                indent: BrandSpace.md,
                color: scheme.outlineVariant,
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

class BrandLedgerTile extends StatelessWidget {
  const BrandLedgerTile({
    super.key,
    required this.child,
    required this.isFirst,
    required this.isLast,
  });

  final Widget child;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(BrandRadius.card);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? radius : Radius.zero,
          bottom: isLast ? radius : Radius.zero,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          if (!isLast)
            Divider(
              height: 1,
              indent: BrandSpace.md,
              color: scheme.outlineVariant,
            ),
        ],
      ),
    );
  }
}

class BrandMeta extends StatelessWidget {
  const BrandMeta(this.text, {super.key, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: tint,
      fontFeatures: brandTabularFigures,
    );
    if (icon == null) return Text(text, style: style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: tint),
        const SizedBox(width: BrandSpace.xxs),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}

class BrandLedgerRow extends StatelessWidget {
  const BrandLedgerRow({
    super.key,
    required this.title,
    this.subtitle,
    this.meta = const <Widget>[],
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.busy = false,
    this.titleMaxLines = 2,
  });

  final String title;
  final String? subtitle;
  final List<Widget> meta;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool busy;
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = AnimatedContainer(
      duration: BrandMotion.resolve(context, BrandMotion.quick),
      curve: BrandMotion.curve,
      color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpace.md,
        BrandSpace.sm,
        BrandSpace.sm,
        BrandSpace.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: BrandSpace.sm),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: BrandSpace.xxs + 2),
                  Wrap(
                    spacing: BrandSpace.md,
                    runSpacing: BrandSpace.xxs,
                    children: meta,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: BrandSpace.xs),
            Flexible(child: trailing!),
          ],
          if (busy)
            const Padding(
              padding: EdgeInsetsDirectional.only(start: BrandSpace.xs),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (onTap != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: BrandSpace.xxs),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: onTap == null
          ? MergeSemantics(child: row)
          : InkWell(onTap: busy ? null : onTap, child: row),
    );
  }
}

class BrandMetricItem {
  const BrandMetricItem({
    required this.label,
    required this.value,
    this.detail,
    this.icon,
    this.tone = BrandStatusTone.neutral,
    this.accent,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String? detail;
  final IconData? icon;
  final BrandStatusTone tone;
  final Color? accent;
  final bool emphasize;
}

class BrandMetricLedger extends StatelessWidget {
  const BrandMetricLedger({super.key, required this.items});

  final List<BrandMetricItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandRadius.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = math.min(
            items.length,
            constraints.maxWidth >= 960
                ? 4
                : constraints.maxWidth >= 640
                ? 3
                : 2,
          );
          final rows = <List<BrandMetricItem>>[
            for (var index = 0; index < items.length; index += columns)
              items.sublist(index, math.min(index + columns, items.length)),
          ];
          return Column(
            children: [
              for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
                if (rowIndex > 0)
                  Divider(height: 1, color: scheme.outlineVariant),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0)
                          Container(width: 1, color: scheme.outlineVariant),
                        Expanded(
                          child: column < rows[rowIndex].length
                              ? _BrandMetricCell(item: rows[rowIndex][column])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BrandMetricCell extends StatelessWidget {
  const _BrandMetricCell({required this.item});

  final BrandMetricItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = item.accent ?? brandStatusColor(context, item.tone);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(BrandSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 18, color: accent),
                  const SizedBox(width: BrandSpace.xs),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BrandSpace.xs),
            Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: item.emphasize ? FontWeight.w600 : FontWeight.w400,
                fontFeatures: brandTabularFigures,
              ),
            ),
            if (item.detail != null && item.detail!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.detail!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BrandSkeletonLedger extends StatelessWidget {
  const BrandSkeletonLedger({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: BrandLedger(
        children: [
          for (var index = 0; index < rows; index++)
            SizedBox(
              height: 72,
              child: Padding(
                padding: const EdgeInsets.all(BrandSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: index.isEven ? 0.62 : 0.48,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            BrandRadius.badge,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: BrandSpace.xs),
                    FractionallySizedBox(
                      widthFactor: 0.34,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            BrandRadius.badge,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BrandEmptyState extends StatelessWidget {
  const BrandEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandSpace.xl,
        vertical: BrandSpace.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: BrandSpace.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: BrandSpace.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: BrandSpace.md),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
