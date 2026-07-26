import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';
import '../models/meter_entry_status.dart';
import '../providers/entry_providers.dart';
import '../providers/preferences_providers.dart';
import '../theme/entry_chrome.dart';
import '../widgets/connectivity_status_bar.dart';
import '../widgets/entry_settings_drawer.dart';
import '../widgets/entry_surface_background.dart';
import 'category_readings_screen.dart';
import 'category_selection_screen.dart';
import 'site_selection_screen.dart';

class EntryShellScreen extends ConsumerStatefulWidget {
  const EntryShellScreen({super.key});

  @override
  ConsumerState<EntryShellScreen> createState() => _EntryShellScreenState();
}

class _EntryShellScreenState extends ConsumerState<EntryShellScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;
    final today = qatarBusinessDate();
    final current = ref.read(businessDateProvider);
    final isPastSelected = current.year != today.year ||
        current.month != today.month ||
        current.day != today.day;
    // Refresh overnight drift; keep intentional backdated day when allowed.
    if (!isPastSelected || !profile.allowBackdatedReadings) {
      ref.read(businessDateProvider.notifier).state = today;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile!;
    final businessDate = ref.watch(businessDateProvider);
    final today = qatarBusinessDate();
    final isPastSelected =
        businessDate.year != today.year ||
        businessDate.month != today.month ||
        businessDate.day != today.day;
    if (isPastSelected && !profile.allowBackdatedReadings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(businessDateProvider.notifier).state = today;
      });
    }
    final selectedSite = ref.watch(selectedSiteProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final s = EntryStrings(ref.watch(entryLocaleProvider));

    final String title;
    final VoidCallback? onBack;
    if (selectedCategory != null) {
      title = s.categoryName(selectedCategory);
      onBack = () =>
          ref.read(selectedCategoryProvider.notifier).state = null;
    } else if (selectedSite != null) {
      title = s.siteName(selectedSite);
      onBack = () => ref.read(selectedSiteProvider.notifier).state = null;
    } else {
      title = s.entryHeaderTitle;
      onBack = null;
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const EntrySettingsDrawer(),
      body: EntrySurfaceBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EntryHeader(
                title: title,
                profile: profile,
                businessDate: businessDate,
                strings: s,
                onBack: onBack,
                onOpenSettings: () =>
                    _scaffoldKey.currentState?.openDrawer(),
                onPickDate: profile.allowBackdatedReadings
                    ? () async {
                        final today = qatarBusinessDate();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: businessDate,
                          firstDate:
                              today.subtract(const Duration(days: 365)),
                          lastDate: today,
                          helpText: s.pickEntryDate,
                        );
                        if (picked == null) return;
                        ref.read(businessDateProvider.notifier).state =
                            DateTime(picked.year, picked.month, picked.day);
                      }
                    : null,
              ),
              const ConnectivityStatusBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: selectedSite == null
                      ? SiteSelectionScreen(
                          key: const ValueKey('site'),
                          onSiteSelected: (site) {
                            ref.read(selectedSiteProvider.notifier).state =
                                site;
                            ref
                                .read(selectedCategoryProvider.notifier)
                                .state = null;
                            ref.read(meterListSearchProvider.notifier).state =
                                '';
                            ref.read(meterListFilterProvider.notifier).state =
                                MeterListFilter.all;
                          },
                        )
                      : selectedCategory == null
                          ? CategorySelectionScreen(
                              key: const ValueKey('category'),
                              site: selectedSite,
                              onBack: () {
                                ref
                                    .read(selectedSiteProvider.notifier)
                                    .state = null;
                              },
                              onCategorySelected: (category) {
                                ref
                                    .read(selectedCategoryProvider.notifier)
                                    .state = category;
                                ref
                                    .read(meterListSearchProvider.notifier)
                                    .state = '';
                                ref
                                    .read(meterListFilterProvider.notifier)
                                    .state = MeterListFilter.all;
                              },
                            )
                          : CategoryReadingsScreen(
                              key: ValueKey(
                                '${selectedSite.id}-${selectedCategory.id}-$businessDate',
                              ),
                              site: selectedSite,
                              category: selectedCategory,
                              businessDate: businessDate,
                              // Back handled by shell header.
                              onBack: () {
                                ref
                                    .read(selectedCategoryProvider.notifier)
                                    .state = null;
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact header matching site/category card language (cream + gold).
class EntryHeader extends StatelessWidget {
  const EntryHeader({
    super.key,
    required this.title,
    required this.profile,
    required this.businessDate,
    required this.strings,
    required this.onOpenSettings,
    this.onBack,
    this.onPickDate,
  });

  final String title;
  final Profile profile;
  final DateTime businessDate;
  final EntryStrings strings;
  final VoidCallback onOpenSettings;
  final VoidCallback? onBack;
  final VoidCallback? onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isBackdated = formatBusinessDate(businessDate) !=
        formatBusinessDate(qatarBusinessDate());
    final border =
        EntryChrome.border(isDark: isDark, scheme: theme.colorScheme);
    final muted =
        EntryChrome.mutedColor(isDark: isDark, scheme: theme.colorScheme);
    final titleColor =
        EntryChrome.titleColor(isDark: isDark, scheme: theme.colorScheme);

    return Container(
      constraints: const BoxConstraints(minHeight: 80, maxHeight: 96),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        gradient: EntryChrome.cardWash(isDark: isDark),
        boxShadow: [
          BoxShadow(
            color: EntryChrome.accent.withValues(alpha: isDark ? 0.14 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 2, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (onBack != null)
              IconButton(
                onPressed: onBack,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: titleColor,
                  size: 16,
                ),
              )
            else
              const SizedBox(width: 6),
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: EntryChrome.iconWellGradient,
                border: Border.all(
                  color: EntryChrome.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                Icons.speed_rounded,
                color: isDark ? EntryChrome.onAccent : EntryChrome.iconGlyph,
                size: 20,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  InkWell(
                    onTap: onPickDate,
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            formatBusinessDateDisplay(businessDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontSize: 12,
                              fontWeight: isBackdated
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (onPickDate != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_calendar_outlined,
                            size: 13,
                            color: muted,
                          ),
                        ],
                        if (isBackdated) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: EntryChrome.accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              strings.backdated,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? AppColors.goldSoft
                                    : EntryChrome.iconGlyph,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    profile.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: strings.settings,
              onPressed: onOpenSettings,
              icon: Icon(
                Icons.settings_outlined,
                color: EntryChrome.iconGlyph.withValues(
                  alpha: isDark ? 0.9 : 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
