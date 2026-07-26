import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';
import '../models/meter_entry_status.dart';
import '../offline/local_reading_draft.dart';
import '../photos/reading_photo_models.dart';
import '../providers/entry_providers.dart';
import '../providers/preferences_providers.dart';
import '../screens/photo_preview_screen.dart';
import '../theme/entry_chrome.dart';
import '../utils/reading_validation.dart';
import 'meter_card_chrome.dart';

/// Quiet, dense institutional meter reading card.
class MeterReadingEntryCard extends ConsumerStatefulWidget {
  const MeterReadingEntryCard({
    super.key,
    required this.site,
    required this.category,
    required this.status,
    required this.businessDate,
    required this.controller,
    required this.photoRequired,
    this.index,
    this.onChanged,
  });

  final Site site;
  final MeterCategoryConfig category;
  final MeterEntryStatus status;
  final DateTime businessDate;
  final TextEditingController controller;
  final bool photoRequired;
  final int? index;
  final VoidCallback? onChanged;

  @override
  ConsumerState<MeterReadingEntryCard> createState() =>
      _MeterReadingEntryCardState();
}

class _MeterReadingEntryCardState extends ConsumerState<MeterReadingEntryCard> {
  bool _didPopulate = false;

  ReadingEntryQuery get _query => ReadingEntryQuery(
        siteId: widget.site.id,
        organizationId: widget.site.organizationId,
        meterId: widget.status.meter.id,
        category: widget.category,
        businessDate: widget.businessDate,
        initialTodayReading: widget.status.todayReading,
        initialLastReading: widget.status.lastReading,
        initialLocalDraft: widget.status.localDraft,
      );

  @override
  void didUpdateWidget(covariant MeterReadingEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.meter.id != widget.status.meter.id) {
      _didPopulate = false;
    }
  }

  void _populateFromState(ReadingEntryState entryState) {
    if (_didPopulate || entryState.isLoading) return;
    final draft = entryState.localDraft;
    if (draft != null && draft.isEditable && !entryState.isSubmitted) {
      if (widget.controller.text.isEmpty && draft.rawValue != 0) {
        widget.controller.text = _formatRaw(draft.rawValue);
      }
    } else if (entryState.todayReading != null &&
        widget.controller.text.isEmpty) {
      widget.controller.text = _formatRaw(entryState.todayReading!.rawValue);
    }
    _didPopulate = true;
  }

  String _formatRaw(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  String _formatDisplay(double value) {
    final raw = _formatRaw(value);
    final parts = raw.split('.');
    final negative = parts[0].startsWith('-');
    var intPart = negative ? parts[0].substring(1) : parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final fromEnd = intPart.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    final formatted = parts.length > 1 ? '${buf.toString()}.${parts[1]}' : buf.toString();
    return negative ? '-$formatted' : formatted;
  }

  Future<void> _pickPhoto(ReadingPhotoSource source) async {
    final ok = await ref.read(readingEntryProvider(_query).notifier).attachPhoto(
          site: widget.site,
          meter: widget.status.meter,
          source: source,
        );
    if (ok) {
      setState(() {});
      widget.onChanged?.call();
    }
  }

  Future<void> _showPhotoSourceSheet(EntryStrings s) async {
    final entryState = ref.read(readingEntryProvider(_query));
    if (entryState.isReadOnly || entryState.isAttachingPhoto) return;

    final source = await showModalBottomSheet<ReadingPhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(s.camera),
              onTap: () => Navigator.pop(context, ReadingPhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.gallery),
              onTap: () => Navigator.pop(context, ReadingPhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickPhoto(source);
  }

  Future<void> _clearEntry(EntryStrings s) async {
    final meterLabel = s.meterName(widget.status.meter);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.clearReading),
        content: Text(s.clearReadingBody(meterLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.clear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(readingEntryProvider(_query).notifier).clearEntry();
    widget.controller.clear();
    _didPopulate = true;
    setState(() {});
    widget.onChanged?.call();
  }

  Color _statusBorder({
    required bool hasValue,
    required bool hasPhoto,
    required bool isSaved,
  }) {
    final work = widget.status.workStatus;
    return MeterCardChrome.borderFor(
      hasValue: hasValue,
      hasPhoto: hasPhoto,
      isSaved: isSaved || work == MeterWorkStatus.submitted,
      needsReview: work == MeterWorkStatus.failedSync ||
          work == MeterWorkStatus.conflict,
      savedLocally: work == MeterWorkStatus.savedLocally ||
          work == MeterWorkStatus.syncing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final s = EntryStrings(ref.watch(entryLocaleProvider));
    final meter = widget.status.meter;
    final entryState = ref.watch(readingEntryProvider(_query));
    _populateFromState(entryState);

    final draft = entryState.localDraft;
    final isReadOnly = entryState.isReadOnly;
    final lastRaw = entryState.lastReading?.rawValue;
    final unit = meter.unit;
    final previewPath = draft?.watermarkedPhotoPath;
    final remotePath =
        draft?.remotePhotoPath ?? entryState.todayReading?.imageStoragePath;
    final remoteUrlAsync = remotePath == null
        ? const AsyncValue<String?>.data(null)
        : ref.watch(meterReadingPhotoUrlProvider(remotePath));
    final remoteUrl = remoteUrlAsync.valueOrNull;
    final hasPhoto = (previewPath != null && previewPath.isNotEmpty) ||
        (remoteUrl != null && remoteUrl.isNotEmpty) ||
        (entryState.todayReading?.hasPhoto ?? false);

    final typed = double.tryParse(widget.controller.text.trim());
    final consumption =
        (typed != null && lastRaw != null) ? typed - lastRaw : null;

    final hasValue = widget.controller.text.trim().isNotEmpty;
    final isSaved = entryState.isSubmitted ||
        entryState.savedLocally ||
        draft?.status == LocalReadingStatus.savedLocally ||
        draft?.status == LocalReadingStatus.synced ||
        widget.status.workStatus == MeterWorkStatus.savedLocally ||
        widget.status.workStatus == MeterWorkStatus.submitted;

    final statusBorder = _statusBorder(
      hasValue: hasValue,
      hasPhoto: hasPhoto,
      isSaved: isSaved && (hasValue || entryState.isSubmitted),
    );
    final titleColor =
        EntryChrome.titleColor(isDark: isDark, scheme: theme.colorScheme);
    final muted =
        EntryChrome.mutedColor(isDark: isDark, scheme: theme.colorScheme);
    final subtitleParts = <String>[
      meter.meterCode,
      s.categoryName(widget.category),
    ];

    Future<void> onPhotoTap() async {
      if (isReadOnly) {
        if (hasPhoto) {
          _openPreview(
            previewPath: previewPath,
            remoteUrl: remoteUrl,
            storagePath: remotePath,
          );
        }
        return;
      }
      if (hasPhoto) {
        final action = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(s.viewPhoto),
                  onTap: () => Navigator.pop(context, 'view'),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(s.replaceCamera),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(s.replaceGallery),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  title: Text(
                    s.removePhoto,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
              ],
            ),
          ),
        );
        if (!mounted || action == null) return;
        switch (action) {
          case 'view':
            _openPreview(
              previewPath: previewPath,
              remoteUrl: remoteUrl,
              storagePath: remotePath,
            );
          case 'camera':
            await _pickPhoto(ReadingPhotoSource.camera);
          case 'gallery':
            await _pickPhoto(ReadingPhotoSource.gallery);
          case 'remove':
            ref.read(readingEntryProvider(_query).notifier).removePhoto();
            setState(() {});
            widget.onChanged?.call();
        }
      } else {
        await _showPhotoSourceSheet(s);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // Enables splash/highlight like category cards.
          onTap: () {},
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusBorder, width: 0.9),
              gradient: EntryChrome.cardWash(isDark: isDark),
              boxShadow: [
                BoxShadow(
                  color: EntryChrome.accent
                      .withValues(alpha: isDark ? 0.12 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: EntryChrome.iconWellGradient,
                          border: Border.all(
                            color: EntryChrome.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          MeterCategoryIcons.iconForCode(widget.category.code),
                          color: isDark
                              ? EntryChrome.onAccent
                              : EntryChrome.iconGlyph,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.meterName(meter),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            if (subtitleParts.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitleParts.join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _StatusBadge(
                        status: widget.status.workStatus,
                        strings: s,
                      ),
                      if (!isReadOnly && hasPhoto)
                        IconButton(
                          tooltip: s.clear,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: entryState.isSaving ||
                                  entryState.isAttachingPhoto
                              ? null
                              : () => _clearEntry(s),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.red.shade600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.previousReading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastRaw == null
                        ? '—'
                        : '${_formatDisplay(lastRaw)} ${unit.label}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (widget.status.lastReading != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      formatBusinessDateDisplay(
                        widget.status.lastReading!.readingDate,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    s.newReading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: widget.controller,
                          enabled: !isReadOnly && !entryState.isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: '0.00',
                            suffixText: unit.label,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: statusBorder.withValues(alpha: 0.55),
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.55),
                          ),
                          onChanged: (_) {
                            setState(() {});
                            widget.onChanged?.call();
                          },
                          validator: isReadOnly
                              ? null
                              : (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  return validateCumulativeReading(
                                    value,
                                    lastRawValue: lastRaw,
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      _PhotoThumb(
                        previewPath: previewPath,
                        remoteUrl: remoteUrl,
                        isBusy: entryState.isAttachingPhoto,
                        hasPhoto: hasPhoto,
                        photoRequired: widget.photoRequired,
                        isReadOnly: isReadOnly,
                        strings: s,
                        onTap: onPhotoTap,
                      ),
                    ],
                  ),
                  if (consumption != null && consumption >= 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: MeterCardChrome.savedBorder
                            .withValues(alpha: isDark ? 0.22 : 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 16,
                            color: isDark
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFF3F7A4E),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${s.consumption}  ${_formatDisplay(consumption)} ${unit.label}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: isDark
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFF3F7A4E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (entryState.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      entryState.errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPreview({
    String? previewPath,
    String? remoteUrl,
    String? storagePath,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoPreviewScreen(
          localPath: previewPath,
          remoteUrl: remoteUrl,
          storagePath: storagePath,
          meterName: widget.status.meter.nameEn,
          meterCode: widget.status.meter.meterCode,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.strings,
  });

  final MeterWorkStatus status;
  final EntryStrings strings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, color, icon) = switch (status) {
      MeterWorkStatus.submitted => (
          strings.statusDone,
          MeterCardChrome.savedBorder,
          Icons.check_circle_outline,
        ),
      MeterWorkStatus.savedLocally || MeterWorkStatus.syncing => (
          strings.statusLocal,
          MeterCardChrome.localBorder,
          Icons.check_circle_outline,
        ),
      MeterWorkStatus.failedSync || MeterWorkStatus.conflict => (
          strings.statusReview,
          MeterCardChrome.reviewBorder,
          Icons.error_outline,
        ),
      MeterWorkStatus.pending => (
          strings.statusPending,
          MeterCardChrome.emptyBorder,
          Icons.schedule,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.previewPath,
    required this.remoteUrl,
    required this.isBusy,
    required this.hasPhoto,
    required this.photoRequired,
    required this.isReadOnly,
    required this.strings,
    required this.onTap,
  });

  final String? previewPath;
  final String? remoteUrl;
  final bool isBusy;
  final bool hasPhoto;
  final bool photoRequired;
  final bool isReadOnly;
  final EntryStrings strings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = photoRequired && !hasPhoto && !isReadOnly
        ? theme.colorScheme.error.withValues(alpha: 0.55)
        : theme.colorScheme.outline.withValues(alpha: 0.35);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isBusy ? null : onTap,
        child: Ink(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              style: hasPhoto ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: isBusy
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : hasPhoto
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          if (previewPath != null &&
                              File(previewPath!).existsSync())
                            Image.file(File(previewPath!), fit: BoxFit.cover)
                          else if (remoteUrl != null)
                            Image.network(remoteUrl!, fit: BoxFit.cover)
                          else
                            ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                strings.photo,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 20,
                            color: photoRequired
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings.photo,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: photoRequired
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}
