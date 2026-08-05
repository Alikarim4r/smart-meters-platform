import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_meters_core/smart_meters_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'report_logo_crop_dialog.dart';
import 'report_logo_slots_editor.dart';

/// Single scoped logo slot (zone or site) for PDF top-left — 6×2 cm.
class ScopedReportLogoEditor extends ConsumerStatefulWidget {
  const ScopedReportLogoEditor({
    super.key,
    required this.organizationId,
    required this.storageKey,
    required this.title,
    required this.subtitle,
    required this.storagePath,
    required this.canEdit,
    required this.onPathChanged,
  });

  final String organizationId;
  /// Relative key under org folder, e.g. `sites/{id}.png` or `zones/{id}.png`.
  final String storageKey;
  final String title;
  final String subtitle;
  final String? storagePath;
  final bool canEdit;
  final ValueChanged<String?> onPathChanged;

  @override
  ConsumerState<ScopedReportLogoEditor> createState() =>
      _ScopedReportLogoEditorState();
}

class _ScopedReportLogoEditorState
    extends ConsumerState<ScopedReportLogoEditor> {
  bool _busy = false;

  // Match org slots: 6cm × 2cm
  static const slotW = 228.0;
  static const slotH = 76.0;

  Future<void> _pickAndUpload() async {
    if (!widget.canEdit || _busy) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      maxWidth: 2400,
    );
    if (file == null) return;

    final raw = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await showReportLogoCropDialog(
      context: context,
      imageBytes: Uint8List.fromList(raw),
      slotWidth: slotW,
      slotHeight: slotH,
      title: widget.title,
    );
    if (cropped == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final path = '${widget.organizationId}/${widget.storageKey}';
      final client = ref.read(supabaseClientProvider);
      await client.storage.from(kReportLogosBucket).uploadBinary(
            path,
            cropped,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
      widget.onPathChanged(path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo upload failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.storagePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(widget.subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          width: slotW,
          height: slotH,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
            ),
            borderRadius: BorderRadius.circular(6),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.35),
          ),
          clipBehavior: Clip.antiAlias,
          child: path == null || path.isEmpty
              ? const Center(child: Text('—'))
              : FutureBuilder<String>(
                  future: ref
                      .read(supabaseClientProvider)
                      .storage
                      .from(kReportLogosBucket)
                      .createSignedUrl(path, 3600),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return Image.network(
                      snap.data!,
                      fit: BoxFit.cover,
                      width: slotW,
                      height: slotH,
                      errorBuilder: (_, _, _) =>
                          const Center(child: Icon(Icons.broken_image)),
                    );
                  },
                ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton(
              onPressed: widget.canEdit && !_busy ? _pickAndUpload : null,
              child: Text(widget.canEdit ? 'Import' : 'Locked'),
            ),
            TextButton(
              onPressed: widget.canEdit &&
                      !_busy &&
                      path != null &&
                      path.isNotEmpty
                  ? () => widget.onPathChanged(null)
                  : null,
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}
