import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/correction_providers.dart';
import 'reading_audit_history_screen.dart';

class ReadingCorrectionFormScreen extends ConsumerStatefulWidget {
  const ReadingCorrectionFormScreen({super.key, required this.readingId});

  final String readingId;

  @override
  ConsumerState<ReadingCorrectionFormScreen> createState() =>
      _ReadingCorrectionFormScreenState();
}

class _ReadingCorrectionFormScreenState
    extends ConsumerState<ReadingCorrectionFormScreen> {
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();
  final _internalCommentController = TextEditingController();
  CorrectionReason? _reason;
  bool _lowerConfirmed = false;
  bool _greaterAcknowledged = false;
  bool _saving = false;
  bool _fieldsInitialized = false;

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    _internalCommentController.dispose();
    super.dispose();
  }

  void _initializeFields(ReadingCorrectionDetails details) {
    if (_fieldsInitialized) return;
    _fieldsInitialized = true;
    _valueController.text = details.reading.rawValue.toString();
    final stripped = stripCorrectionMarkers(details.reading.note);
    if (stripped != null) {
      _noteController.text = stripped;
    }
  }

  Future<void> _replacePhoto(ReadingCorrectionDetails details) async {
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (file == null) return;

    // Resolve organization from site via accessible sites list if needed.
    String? organizationId;
    try {
      final sites = await ref.read(siteRepositoryProvider).getAccessibleSites(profile);
      for (final site in sites) {
        if (site.id == details.reading.siteId) {
          organizationId = site.organizationId;
          break;
        }
      }
    } catch (_) {}
    organizationId ??= profile.id; // fallback folder key — better than failing

    setState(() => _saving = true);
    try {
      final bytes = await file.readAsBytes();
      final oldPath = details.reading.imageStoragePath;
      await ref.read(readingCorrectionRepositoryProvider).replaceReadingPhoto(
            readingId: widget.readingId,
            bytes: bytes,
            organizationId: organizationId!,
          );
      if (oldPath != null) {
        ref.invalidate(correctionPhotoUrlProvider(oldPath));
      }
      ref.invalidate(readingCorrectionDetailsProvider(widget.readingId));
      ref.invalidate(adminCorrectionsProvider);
      _showMessage('Photo updated.');
    } catch (error) {
      _showMessage('Could not update photo: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePhoto(ReadingCorrectionDetails details) async {
    final path = details.reading.imageStoragePath;
    if (path == null || path.trim().isEmpty) return;

    final confirmed = await _confirmDialog(
      title: 'Delete photo?',
      message:
          'This removes the reading photo permanently. The numeric reading stays unchanged.',
      confirmLabel: 'Delete photo',
      isCritical: true,
    );
    if (!confirmed) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(readingCorrectionRepositoryProvider)
          .deleteReadingPhoto(readingId: widget.readingId);
      final storagePath = details.reading.imageStoragePath;
      if (storagePath != null) {
        ref.invalidate(correctionPhotoUrlProvider(storagePath));
      }
      ref.invalidate(readingCorrectionDetailsProvider(widget.readingId));
      ref.invalidate(adminCorrectionsProvider);
      _showMessage('Photo deleted.');
    } catch (error) {
      _showMessage('Could not delete photo: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save(ReadingCorrectionDetails details) async {
    final parsed = double.tryParse(_valueController.text.trim());
    if (parsed == null) {
      _showMessage('Enter a valid numeric value.');
      return;
    }

    final validation = validateReadingCorrection(
      currentValue: details.reading.rawValue,
      newValue: parsed,
      reason: _reason,
      newNote: _noteController.text,
      previousValue: details.previousValue,
      nextValue: details.nextValue,
      lowerThanPreviousConfirmed: _lowerConfirmed,
      greaterThanNextAcknowledged: _greaterAcknowledged,
    );

    if (validation.requiresLowerThanPreviousConfirm) {
      final confirmed = await _confirmDialog(
        title: 'Lower than previous reading',
        message:
            'The corrected value ($parsed) is lower than the previous reading (${details.previousValue}). '
            'This is unusual. Confirm you want to proceed.',
        confirmLabel: 'Confirm correction',
        isCritical: true,
      );
      if (!confirmed) return;
      setState(() => _lowerConfirmed = true);
      return _save(details);
    }

    if (validation.requiresGreaterThanNextWarning) {
      final acknowledged = await _confirmDialog(
        title: 'Greater than next reading',
        message:
            'The corrected value ($parsed) is greater than the next reading (${details.nextValue}). '
            'This may indicate an ordering issue. Proceed anyway?',
        confirmLabel: 'Proceed',
        isCritical: false,
      );
      if (!acknowledged) return;
      setState(() => _greaterAcknowledged = true);
      return _save(details);
    }

    if (!validation.isValid) {
      _showMessage(validation.blockingMessage ?? 'Validation failed.');
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = ref.read(authProvider).profile!;
      await ref
          .read(readingCorrectionRepositoryProvider)
          .correctReading(
            readingId: widget.readingId,
            newValue: parsed,
            newNote: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            reason: _reason!,
            internalComment: _internalCommentController.text.trim().isEmpty
                ? null
                : _internalCommentController.text.trim(),
            correctedByUserId: profile.id,
            lowerThanPreviousConfirmed: _lowerConfirmed,
            greaterThanNextAcknowledged: _greaterAcknowledged,
          );
      ref.invalidate(readingCorrectionDetailsProvider(widget.readingId));
      ref.invalidate(readingAuditHistoryProvider(widget.readingId));
      ref.invalidate(adminCorrectionsProvider);
      if (!mounted) return;
      _showMessage('Reading corrected successfully.');
      Navigator.of(context).pop();
    } on CorrectionValidationException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Failed to save correction: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required bool isCritical,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isCritical ? Icons.warning_amber : Icons.info_outline,
          color: isCritical ? Theme.of(context).colorScheme.error : null,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(
      readingCorrectionDetailsProvider(widget.readingId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Correct reading'),
        actions: [
          IconButton(
            tooltip: 'Audit history',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ReadingAuditHistoryScreen(readingId: widget.readingId),
                ),
              );
            },
          ),
        ],
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (details) {
          _initializeFields(details);
          final reading = details.reading;
          final photoAsync = reading.hasPhoto
              ? ref.watch(correctionPhotoUrlProvider(reading.imageStoragePath!))
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoTile(label: 'Site', value: reading.siteName),
              _InfoTile(label: 'Zone', value: reading.zoneName),
              _InfoTile(
                label: 'Meter',
                value: '${reading.meterName} (${reading.meterCode})',
              ),
              _InfoTile(label: 'Category', value: reading.categoryName),
              _InfoTile(label: 'Unit', value: reading.unitLabel),
              _InfoTile(
                label: 'Reading date',
                value: formatBusinessDateDisplay(reading.readingDate),
              ),
              _InfoTile(
                label: 'Current value',
                value: '${reading.rawValue} ${reading.unitLabel}',
              ),
              if (details.previousValue != null)
                _InfoTile(
                  label: 'Previous reading',
                  value: '${details.previousValue} ${reading.unitLabel}',
                ),
              if (details.nextValue != null)
                _InfoTile(
                  label: 'Next reading',
                  value: '${details.nextValue} ${reading.unitLabel}',
                ),
              if (reading.enteredByName != null ||
                  reading.enteredByEmail != null)
                _InfoTile(
                  label: 'Submitted by',
                  value: reading.enteredByName ?? reading.enteredByEmail!,
                ),
              if (reading.note != null && reading.note!.trim().isNotEmpty)
                _InfoTile(
                  label: 'Current note',
                  value: stripCorrectionMarkers(reading.note) ?? reading.note!,
                ),
              if (reading.hasPhoto) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Photo',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _saving ? null : () => _replacePhoto(details),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Replace photo'),
                    ),
                    TextButton.icon(
                      onPressed: _saving ? null : () => _deletePhoto(details),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      label: Text(
                        'Delete photo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: photoAsync == null
                        ? const Center(child: CircularProgressIndicator())
                        : photoAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, _) => const Center(
                              child: Icon(Icons.broken_image, size: 48),
                            ),
                            data: (url) => Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _replacePhoto(details),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add photo'),
                ),
              ],
              if (details.relatedAlerts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Related alerts',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: details.relatedAlerts
                      .map(
                        (type) => Chip(
                          label: Text(type.label),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Related alerts may disappear after correction if resolved.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const Divider(height: 32),
              Text(
                'Correction',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: 'Corrected value *',
                  suffixText: reading.unitLabel,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Corrected note',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CorrectionReason?>(
                initialValue: _reason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Correction reason *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<CorrectionReason?>(
                    value: null,
                    child: Text(
                      'Select reason',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...CorrectionReason.values.map(
                    (reason) => DropdownMenuItem(
                      value: reason,
                      child: Text(
                        reason.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _reason = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _internalCommentController,
                decoration: const InputDecoration(
                  labelText: 'Internal comment (admin only)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(details),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save correction'),
              ),
              if (details.auditHistory.isNotEmpty) ...[
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent audit (${details.auditHistory.length})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReadingAuditHistoryScreen(
                              readingId: widget.readingId,
                            ),
                          ),
                        );
                      },
                      child: const Text('View all'),
                    ),
                  ],
                ),
                ...details.auditHistory.take(3).map(_AuditPreview.new),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _AuditPreview extends StatelessWidget {
  const _AuditPreview(this.entry);

  final ReadingAuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final who = entry.changedByName ?? entry.changedByEmail ?? 'Unknown';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history),
      title: Text(entry.action.label),
      subtitle: Text(
        [
          if (entry.oldValue != null && entry.newValue != null)
            '${entry.oldValue} → ${entry.newValue}',
          if (entry.reason != null) entry.reason!.label,
          who,
        ].join(' · '),
      ),
      trailing: Text(
        _formatTime(entry.changedAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
