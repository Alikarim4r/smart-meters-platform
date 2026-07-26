import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';
import '../models/meter_entry_status.dart';
import '../providers/entry_providers.dart';
import '../providers/preferences_providers.dart';
import '../theme/entry_chrome.dart';
import '../utils/reading_validation.dart';
import '../widgets/entry_state_views.dart';
import '../widgets/meter_reading_entry_card.dart';

enum _ReadingChip { all, pending, done }

/// Dense institutional readings workspace for one category at a site.
class CategoryReadingsScreen extends ConsumerStatefulWidget {
  const CategoryReadingsScreen({
    super.key,
    required this.site,
    required this.category,
    required this.businessDate,
    required this.onBack,
  });

  final Site site;
  final MeterCategoryConfig category;
  final DateTime businessDate;
  final VoidCallback onBack;

  @override
  ConsumerState<CategoryReadingsScreen> createState() =>
      _CategoryReadingsScreenState();
}

class _CategoryReadingsScreenState
    extends ConsumerState<CategoryReadingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _searchController = TextEditingController();
  bool _saving = false;
  String? _batchError;
  _ReadingChip _chip = _ReadingChip.all;

  EntryMeterQuery get _query => EntryMeterQuery(
        siteId: widget.site.id,
        category: widget.category,
        businessDate: widget.businessDate,
        siteLocation: widget.site.location,
      );

  TextEditingController _controllerFor(String meterId) {
    return _controllers.putIfAbsent(meterId, TextEditingController.new);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  ReadingEntryQuery _entryQuery(MeterEntryStatus status) => ReadingEntryQuery(
        siteId: widget.site.id,
        organizationId: widget.site.organizationId,
        meterId: status.meter.id,
        category: widget.category,
        businessDate: widget.businessDate,
        initialTodayReading: status.todayReading,
        initialLastReading: status.lastReading,
        initialLocalDraft: status.localDraft,
      );

  bool _isDone(MeterEntryStatus status) {
    return status.workStatus == MeterWorkStatus.submitted ||
        status.workStatus == MeterWorkStatus.savedLocally ||
        status.workStatus == MeterWorkStatus.syncing;
  }

  bool _isPending(MeterEntryStatus status) => !_isDone(status);

  List<MeterEntryStatus> _filtered(List<MeterEntryStatus> meters) {
    final q = _searchController.text.trim();
    return meters.where((status) {
      if (!matchesMeterSearch(status, q)) return false;
      return switch (_chip) {
        _ReadingChip.all => true,
        _ReadingChip.pending => _isPending(status),
        _ReadingChip.done => _isDone(status),
      };
    }).toList();
  }

  Future<bool> _confirmHighIfNeeded(
    EntryStrings s,
    double rawValue,
    double? lastRaw,
  ) async {
    if (!shouldWarnHighReading(newReading: rawValue, lastRawValue: lastRaw)) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.highReading),
        content: const Text(highReadingWarningMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.review),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _saveAll(EntryStrings s, List<MeterEntryStatus> meters) async {
    setState(() {
      _batchError = null;
      _saving = true;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() {
        _saving = false;
        _batchError = s.formInvalid;
      });
      return;
    }

    final editable = meters.where((m) => m.canEnterReading).toList();
    final toSave = <MeterEntryStatus>[];
    for (final status in editable) {
      final text = _controllerFor(status.meter.id).text.trim();
      if (text.isEmpty) continue;
      toSave.add(status);
    }

    if (toSave.isEmpty) {
      setState(() {
        _saving = false;
        _batchError = s.enterAtLeastOne;
      });
      return;
    }

    var saved = 0;
    var failed = 0;
    String? lastError;

    for (final status in toSave) {
      final text = _controllerFor(status.meter.id).text.trim();
      final rawValue = double.parse(text);
      final entryState = ref.read(readingEntryProvider(_entryQuery(status)));
      final lastRaw = entryState.lastReading?.rawValue;

      if (!await _confirmHighIfNeeded(s, rawValue, lastRaw)) {
        failed++;
        lastError = status.meter.nameEn;
        continue;
      }
      if (!mounted) return;

      final ok = await ref
          .read(readingEntryProvider(_entryQuery(status)).notifier)
          .saveReading(rawValue: rawValue);
      if (ok) {
        saved++;
      } else {
        failed++;
        lastError = ref
                .read(readingEntryProvider(_entryQuery(status)))
                .errorMessage ??
            status.meter.nameEn;
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ref.invalidate(metersWithStatusProvider(_query));

    final messenger = ScaffoldMessenger.of(context);
    if (failed == 0) {
      messenger.showSnackBar(SnackBar(content: Text(s.savedCount(saved))));
    } else {
      setState(() => _batchError = lastError);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved $saved, failed $failed. $lastError'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = EntryStrings(ref.watch(entryLocaleProvider));
    final metersAsync = ref.watch(metersWithStatusProvider(_query));
    final policyAsync = ref.watch(sitePolicyProvider(widget.site.id));
    final photoRequired = policyAsync.maybeWhen(
      data: (policy) => policy.photoRequired,
      orElse: () => false,
    );

    return metersAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(20),
        child: EntryLoadingCard(message: s.loadingMeters),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: EntryErrorCard(
          message: s.couldNotLoadMeters,
          onRetry: () => ref.invalidate(metersWithStatusProvider(_query)),
        ),
      ),
      data: (meters) {
        final summary = MeterWorkSummary.fromStatuses(meters);
        final pendingCount = meters.where(_isPending).length;
        final doneCount = meters.where(_isDone).length;
        final visible = _filtered(meters);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                  children: [
                    _FilterChips(
                      allCount: meters.length,
                      pendingCount: pendingCount,
                      doneCount: doneCount,
                      selected: _chip,
                      strings: s,
                      onSelected: (chip) => setState(() => _chip = chip),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: s.searchMeters,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                    if (_batchError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _batchError!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (meters.isEmpty)
                      EntryEmptyCard(message: s.noMetersOfType)
                    else if (visible.isEmpty)
                      EntryEmptyCard(message: s.noMetersOfType)
                    else
                      for (final status in visible)
                        MeterReadingEntryCard(
                          site: widget.site,
                          category: widget.category,
                          status: status,
                          businessDate: widget.businessDate,
                          controller: _controllerFor(status.meter.id),
                          photoRequired: photoRequired,
                          index: meters.indexOf(status) + 1,
                          onChanged: () => setState(() {}),
                        ),
                  ],
                ),
              ),
            ),
            _StickySaveBar(
              summaryText: s.metersFooter(summary.total, summary.completed),
              saving: _saving,
              enabled: !_saving && meters.isNotEmpty,
              label: _saving ? s.saving : s.saveAndSubmit,
              onSave: () => _saveAll(s, meters),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.allCount,
    required this.pendingCount,
    required this.doneCount,
    required this.selected,
    required this.strings,
    required this.onSelected,
  });

  final int allCount;
  final int pendingCount;
  final int doneCount;
  final _ReadingChip selected;
  final EntryStrings strings;
  final ValueChanged<_ReadingChip> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            context,
            chip: _ReadingChip.all,
            label: '${strings.filterAll} $allCount',
          ),
          const SizedBox(width: 8),
          _chip(
            context,
            chip: _ReadingChip.pending,
            label: '${strings.filterPending} $pendingCount',
          ),
          const SizedBox(width: 8),
          _chip(
            context,
            chip: _ReadingChip.done,
            label: '${strings.filterDone} $doneCount',
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required _ReadingChip chip,
    required String label,
  }) {
    final theme = Theme.of(context);
    final active = selected == chip;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onSelected(chip),
      selectedColor: EntryChrome.accent,
      labelStyle: TextStyle(
        color: active ? EntryChrome.onAccent : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: BorderSide(
        color: active
            ? EntryChrome.accentDeep
            : theme.colorScheme.outline.withValues(alpha: 0.35),
      ),
      backgroundColor: theme.colorScheme.surface,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StickySaveBar extends StatelessWidget {
  const _StickySaveBar({
    required this.summaryText,
    required this.saving,
    required this.enabled,
    required this.label,
    required this.onSave,
  });

  final String summaryText;
  final bool saving;
  final bool enabled;
  final String label;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summaryText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: enabled ? onSave : null,
                style: FilledButton.styleFrom(
                  backgroundColor: EntryChrome.accent,
                  foregroundColor: EntryChrome.onAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: EntryChrome.onAccent,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
