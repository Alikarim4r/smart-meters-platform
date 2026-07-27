import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';
import '../models/meter_entry_status.dart';
import '../offline/local_reading_draft.dart';
import '../photos/reading_photo_models.dart';
import '../providers/entry_providers.dart';
import '../providers/preferences_providers.dart';
import '../utils/reading_validation.dart';
import '../widgets/cumulative_reading_input.dart';
import '../widgets/optional_note_field.dart';
import '../widgets/reading_photo_section.dart';
import '../widgets/submitted_reading_view.dart';

class ReadingEntryScreen extends ConsumerStatefulWidget {
  const ReadingEntryScreen({
    super.key,
    required this.site,
    required this.category,
    required this.meter,
    required this.businessDate,
    this.initialStatus,
  });

  final Site site;
  final MeterCategoryConfig category;
  final Meter meter;
  final DateTime businessDate;
  final MeterEntryStatus? initialStatus;

  @override
  ConsumerState<ReadingEntryScreen> createState() => _ReadingEntryScreenState();
}

class _ReadingEntryScreenState extends ConsumerState<ReadingEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rawValueController = TextEditingController();
  final _noteController = TextEditingController();
  final _readingFocusNode = FocusNode();
  bool _didRequestFocus = false;
  bool _didPopulateDraft = false;

  @override
  void dispose() {
    _rawValueController.dispose();
    _noteController.dispose();
    _readingFocusNode.dispose();
    super.dispose();
  }

  ReadingEntryQuery get _query => ReadingEntryQuery(
        siteId: widget.site.id,
        organizationId: widget.site.organizationId,
        meterId: widget.meter.id,
        category: widget.category,
        businessDate: widget.businessDate,
        initialTodayReading: widget.initialStatus?.todayReading,
        initialLastReading: widget.initialStatus?.lastReading,
        initialLocalDraft: widget.initialStatus?.localDraft,
      );

  double? get _lastRawValue {
    final last = ref.read(readingEntryProvider(_query)).lastReading;
    return last?.rawValue;
  }

  void _populateDraftFields(ReadingEntryState entryState) {
    if (_didPopulateDraft || entryState.isLoading) {
      return;
    }
    final draft = entryState.localDraft;
    if (draft != null && draft.isEditable && !entryState.isSubmitted) {
      _rawValueController.text = _formatValue(draft.rawValue);
      _noteController.text = draft.note ?? '';
      _didPopulateDraft = true;
    }
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  Future<bool> _confirmHighReadingIfNeeded(double rawValue, double? lastRaw) async {
    if (!shouldWarnHighReading(newReading: rawValue, lastRawValue: lastRaw)) {
      return true;
    }

    final s = EntryStrings(ref.read(entryLocaleProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.highReading),
        content: Text(
          s.isAr
              ? 'هذه القراءة أعلى بكثير من السابقة. راجع القيمة قبل التأكيد.'
              : highReadingWarningMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.review),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final s = EntryStrings(ref.read(entryLocaleProvider));
    final rawValue = double.parse(_rawValueController.text.trim());
    final lastRaw = _lastRawValue;
    if (lastRaw != null && rawValue < lastRaw) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isAr
                ? 'هذه القراءة أقل من القراءة السابقة.'
                : 'This reading is lower than the previous reading.',
          ),
        ),
      );
      return;
    }

    if (!await _confirmHighReadingIfNeeded(rawValue, lastRaw)) {
      return;
    }

    final success =
        await ref.read(readingEntryProvider(_query).notifier).saveReading(
              rawValue: rawValue,
              note: _noteController.text,
            );

    if (!mounted || !success) {
      return;
    }

    final entryState = ref.read(readingEntryProvider(_query));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entryState.savedLocally
              ? (s.isAr
                  ? 'حُفظت القراءة محلياً. ستُزامن عند الاتصال.'
                  : 'Reading saved locally. It will sync when online.')
              : (s.isAr ? 'تم حفظ القراءة بنجاح' : 'Reading saved successfully'),
        ),
      ),
    );
  }

  Future<void> _goToNextPending() async {
    final listQuery = EntryMeterQuery(
      siteId: widget.site.id,
      category: widget.category,
      businessDate: widget.businessDate,
      siteLocation: widget.site.location,
    );

    final statuses =
        await ref.read(metersWithStatusProvider(listQuery).future);
    final pending = statuses.where((s) => s.canEnterReading).toList();

    if (!mounted) {
      return;
    }

    if (pending.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final next = pending.firstWhere(
      (s) => s.meter.id != widget.meter.id,
      orElse: () => pending.first,
    );

    if (next.meter.id == widget.meter.id) {
      Navigator.of(context).pop();
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => ReadingEntryScreen(
          site: widget.site,
          category: widget.category,
          meter: next.meter,
          businessDate: widget.businessDate,
          initialStatus: next,
        ),
      ),
    );
  }

  Future<bool> _hasOtherPendingMeters() async {
    final listQuery = EntryMeterQuery(
      siteId: widget.site.id,
      category: widget.category,
      businessDate: widget.businessDate,
      siteLocation: widget.site.location,
    );
    final statuses =
        await ref.read(metersWithStatusProvider(listQuery).future);
    return statuses.any(
      (s) => s.canEnterReading && s.meter.id != widget.meter.id,
    );
  }

  void _requestReadingFocusIfNeeded(bool isReadOnly, bool isLoading) {
    if (isReadOnly || isLoading || _didRequestFocus) {
      return;
    }
    _didRequestFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _readingFocusNode.canRequestFocus) {
        _readingFocusNode.requestFocus();
      }
    });
  }

  MeterReading? _displayReading(ReadingEntryState entryState) {
    if (entryState.todayReading != null) {
      return entryState.todayReading;
    }
    final draft = entryState.localDraft;
    if (draft == null) {
      return null;
    }
    if (draft.status == LocalReadingStatus.synced ||
        draft.status == LocalReadingStatus.conflict) {
      return MeterReading(
        id: draft.localId,
        siteId: draft.siteId,
        meterId: draft.meterId,
        readingDate: DateTime.parse(draft.readingDate),
        rawValue: draft.rawValue,
        normalizedValue: draft.rawValue,
        note: draft.note,
        imageStoragePath: draft.remotePhotoPath,
        enteredAt: draft.updatedAt,
      );
    }
    return null;
  }

  Future<void> _attachPhoto(ReadingPhotoSource source) async {
    final success = await ref
        .read(readingEntryProvider(_query).notifier)
        .attachPhoto(
          site: widget.site,
          meter: widget.meter,
          source: source,
        );
    if (!mounted || success) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          EntryStrings(ref.read(entryLocaleProvider)).isAr
              ? 'لم تتم إضافة الصورة.'
              : 'Photo was not added.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = EntryStrings(ref.watch(entryLocaleProvider));
    final entryState = ref.watch(readingEntryProvider(_query));
    final policyAsync = ref.watch(sitePolicyProvider(widget.site.id));
    final photoRequired = policyAsync.valueOrNull?.photoRequired ?? false;
    final theme = Theme.of(context);
    final isReadOnly = entryState.isReadOnly;
    final displayReading = _displayReading(entryState);

    _populateDraftFields(entryState);
    _requestReadingFocusIfNeeded(isReadOnly, entryState.isLoading);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isReadOnly
              ? (s.isAr ? 'تم إرسال القراءة' : 'Reading submitted')
              : (s.isAr ? 'إدخال قراءة' : 'Enter reading'),
        ),
      ),
      body: entryState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoCard(
                      meter: widget.meter,
                      businessDate: widget.businessDate,
                      lastReading: entryState.lastReading,
                      location: widget.site.location,
                    ),
                    const SizedBox(height: 12),
                    if (isReadOnly && displayReading != null)
                      FutureBuilder<bool>(
                        future: _hasOtherPendingMeters(),
                        builder: (context, snapshot) {
                          final draft = entryState.localDraft;
                          final storagePath = displayReading.imageStoragePath ??
                              draft?.remotePhotoPath;
                          return SubmittedReadingView(
                            reading: displayReading,
                            unit: widget.meter.unit,
                            localPhotoPath: draft?.watermarkedPhotoPath,
                            imageStoragePath: storagePath,
                            onBackToMeters: () => Navigator.of(context).pop(),
                            onNextPending: _goToNextPending,
                            showNextPending: snapshot.data ?? false,
                          );
                        },
                      )
                    else ...[
                      if (entryState.localDraft?.status ==
                          LocalReadingStatus.savedLocally)
                        _LocalDraftBanner(),
                      CumulativeReadingInput(
                        controller: _rawValueController,
                        focusNode: _readingFocusNode,
                        unit: widget.meter.unit,
                        lastRawValue: entryState.lastReading?.rawValue,
                        onFieldSubmitted: _save,
                      ),
                      const SizedBox(height: 10),
                      OptionalNoteField(controller: _noteController),
                      const SizedBox(height: 12),
                      ReadingPhotoSection(
                        draft: entryState.localDraft,
                        isReadOnly: false,
                        isBusy:
                            entryState.isSaving || entryState.isAttachingPhoto,
                        onCameraTap: () => _attachPhoto(ReadingPhotoSource.camera),
                        onGalleryTap: () => _attachPhoto(ReadingPhotoSource.gallery),
                        onRemovePhoto: () => ref
                            .read(readingEntryProvider(_query).notifier)
                            .removePhoto(),
                        meterName: widget.meter.nameEn,
                        meterCode: widget.meter.meterCode,
                        photoRequired: photoRequired,
                      ),
                      if (entryState.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          entryState.errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: entryState.isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: entryState.isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(s.isAr ? 'حفظ القراءة' : 'Save reading'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _LocalDraftBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Text(
        'You are editing a locally saved reading. Changes sync when online.',
        style: TextStyle(color: Colors.indigo.shade900, fontSize: 13),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.meter,
    required this.businessDate,
    this.lastReading,
    this.location,
  });

  final Meter meter;
  final DateTime businessDate;
  final MeterReading? lastReading;
  final String? location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meter.nameEn,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            _InfoRow(label: 'Code', value: meter.meterCode),
            if (location != null && location!.trim().isNotEmpty)
              _InfoRow(label: 'Location', value: location!),
            _InfoRow(label: 'Unit', value: meter.unitDisplayLabel),
            _InfoRow(
              label: 'Today',
              value: formatBusinessDateDisplay(businessDate),
            ),
            _InfoRow(
              label: 'Last reading',
              value: lastReading == null
                  ? 'No previous reading'
                  : '${lastReading!.rawValue} ${meter.unitDisplayLabel} '
                      '(${formatBusinessDate(lastReading!.readingDate)})',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
