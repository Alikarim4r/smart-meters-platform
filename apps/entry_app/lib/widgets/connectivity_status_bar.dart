import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/entry_strings.dart';
import '../providers/connectivity_provider.dart';
import '../providers/entry_providers.dart';
import '../providers/preferences_providers.dart';
import '../theme/entry_chrome.dart';

/// Slim sync strip (~48–56px) for enterprise entry UI.
class ConnectivityStatusBar extends ConsumerWidget {
  const ConnectivityStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final sync = ref.watch(syncProvider);
    final s = EntryStrings(ref.watch(entryLocaleProvider));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accent = isOnline
        ? (isDark ? const Color(0xFF6EE7B7) : Colors.green.shade700)
        : (isDark ? const Color(0xFFFBBF24) : Colors.orange.shade800);
    final bg = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline.withValues(alpha: 0.35);

    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: EntryChrome.accent.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: isOnline ? s.online : s.offline,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sync.lastError != null && sync.lastError!.isNotEmpty) ...[
                    TextSpan(
                      text: ' · ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    TextSpan(
                      text: sync.lastError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (isOnline && sync.lastSyncTime != null) ...[
                    TextSpan(
                      text: ' · ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    TextSpan(
                      text: s.syncedAt(_formatTime(sync.lastSyncTime!)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ] else if (!isOnline) ...[
                    TextSpan(
                      text: ' · ${s.offlineHint}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accent.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: accent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: sync.isSyncing || !isOnline
                ? null
                : () => ref.read(syncProvider.notifier).syncNow(),
            icon: sync.isSyncing
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(s.sync),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
