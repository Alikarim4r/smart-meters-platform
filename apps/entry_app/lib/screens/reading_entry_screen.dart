import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_meters_core/smart_meters_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/entry_strings.dart';
import '../models/meter_entry_status.dart';
import '../offline/local_reading_draft.dart';
import '../photos/reading_photo_models.dart';
import '../providers/entry_providers.dart';
import '../providers/preferences_providers.dart';
import '../utils/platform_image_picker.dart';
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

  Future<bool> _confirmHighReadingIfNeeded(
    double rawValue,
    double? lastRaw,
  ) async {
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

    final success = await ref
        .read(readingEntryProvider(_query).notifier)
        .saveReading(rawValue: rawValue, note: _noteController.text);

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
              : (s.isAr
                    ? 'تم حفظ القراءة بنجاح'
                    : 'Reading saved successfully'),
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

    final statuses = await ref.read(metersWithStatusProvider(listQuery).future);
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
    final statuses = await ref.read(metersWithStatusProvider(listQuery).future);
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
    final s = EntryStrings(ref.read(entryLocaleProvider));
    try {
      // Pick before notifier state updates so the browser keeps the tap gesture.
      final picked = await pickPlatformImage(
        source: source == ReadingPhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      if (picked == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.photoPickCancelled)));
        return;
      }

      final success = await ref
          .read(readingEntryProvider(_query).notifier)
          .attachPhoto(
            site: widget.site,
            meter: widget.meter,
            source: source,
            prePicked: picked,
          );
      if (!mounted || success) {
        return;
      }
      final err = ref.read(readingEntryProvider(_query)).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (err != null && err.isNotEmpty)
                ? err
                : (s.isAr ? 'لم تتم إضافة الصورة.' : 'Photo was not added.'),
          ),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      final denied =
          error.code.contains('permission') ||
          error.code.contains('access_denied');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            denied
                ? (s.isAr
                      ? 'فعّل صلاحية الكاميرا/الصور من إعدادات التطبيق ثم أعد المحاولة.'
                      : 'Enable camera or photo access in app settings, then try again.')
                : s.photoPickFailed,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            EntryStrings(Localizations.localeOf(context)).photoPickFailed,
          ),
        ),
      );
    }
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
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [BrandSkeletonLedger(rows: 5)],
            )
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
                    FutureBuilder<bool>(
                      future:
                          PlatformFeatureFlagRepository(
                            Supabase.instance.client,
                          ).isEnabled(
                            organizationId: widget.site.organizationId,
                            flagKey: PlatformFeatureFlags.unifiedIngestion,
                            siteId: widget.site.id,
                          ),
                      builder: (context, snap) {
                        if (snap.data != true) {
                          return const SizedBox.shrink();
                        }
                        final source =
                            entryState.todayReading?.effectiveReadingSource ??
                            'manual';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(s.readingSourceLabel(source)),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (isReadOnly && displayReading != null)
                      FutureBuilder<bool>(
                        future: _hasOtherPendingMeters(),
                        builder: (context, snapshot) {
                          final draft = entryState.localDraft;
                          final storagePath =
                              displayReading.imageStoragePath ??
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
                        onCameraTap: () =>
                            _attachPhoto(ReadingPhotoSource.camera),
                        onGalleryTap: () =>
                            _attachPhoto(ReadingPhotoSource.gallery),
                        onRemovePhoto: () => ref
                            .read(readingEntryProvider(_query).notifier)
                            .removePhoto(),
                        meterName: widget.meter.nameEn,
                        meterCode: widget.meter.meterCode,
                        photoRequired: photoRequired,
                      ),
                      if (entryState.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Semantics(
                          liveRegion: true,
                          child: BrandStatusMark(
                            label: s.isAr
                                ? 'تعذّر حفظ القراءة. راجع القيمة والصورة ثم أعد المحاولة.'
                                : 'Could not save the reading. Review the value and photo, then try again.',
                            tone: BrandStatusTone.danger,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
      bottomNavigationBar: entryState.isLoading || isReadOnly
          ? null
          : SafeArea(
              top: false,
              child: Material(
                color: theme.colorScheme.surface,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  child: FilledButton.icon(
                    onPressed: entryState.isSaving ? null : _save,
                    icon: entryState.isSaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(s.isAr ? 'حفظ القراءة' : 'Save reading'),
                  ),
                ),
              ),
            ),
    );
  }
}

class _LocalDraftBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(BrandRadius.control),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BrandRadius.control),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entryText(
                context,
                'You are editing a locally saved reading. Changes sync when online.',
                'أنت تعدّل قراءة محفوظة محليًا. ستتم مزامنة التغييرات عند الاتصال.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final meterName = isAr && meter.nameAr.trim().isNotEmpty
        ? meter.nameAr
        : meter.nameEn;
    return BrandContextStrip(
      fields: [
        BrandContextField(
          label: entryText(context, 'Meter', 'العداد'),
          value: meterName,
          flex: 2,
          maxLines: 2,
        ),
        BrandContextField(
          label: entryText(context, 'Code', 'الرمز'),
          value: meter.meterCode,
          tabular: true,
        ),
        if (location != null && location!.trim().isNotEmpty)
          BrandContextField(
            label: entryText(context, 'Location', 'الموقع'),
            value: location!,
            maxLines: 2,
          ),
        BrandContextField(
          label: entryText(context, 'Unit', 'الوحدة'),
          value: meter.unitDisplayLabel,
        ),
        BrandContextField(
          label: entryText(context, 'Today', 'اليوم'),
          value: EntryStrings(
            Localizations.localeOf(context),
          ).dateDisplay(businessDate),
          tabular: true,
        ),
        BrandContextField(
          label: entryText(context, 'Last reading', 'آخر قراءة'),
          value: lastReading == null
              ? (isAr ? 'لا توجد قراءة سابقة' : 'No previous reading')
              : '${lastReading!.rawValue} ${meter.unitDisplayLabel} '
                    '(${formatBusinessDate(lastReading!.readingDate)})',
          maxLines: 2,
          tabular: true,
        ),
      ],
    );
  }
}
