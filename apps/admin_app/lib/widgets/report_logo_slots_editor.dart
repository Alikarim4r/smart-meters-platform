import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_meters_core/smart_meters_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/admin_strings.dart';
import '../providers/preferences_providers.dart';
import 'report_logo_crop_dialog.dart';

const kReportLogosBucket = 'report-logos';

/// 6cm × 2cm report logo slots (primary = owner top-right, secondary = admin top-left).
class ReportLogoSlotsEditor extends ConsumerStatefulWidget {
  const ReportLogoSlotsEditor({
    super.key,
    required this.organizationId,
    required this.draft,
    required this.enabled,
    required this.canEditPrimary,
    required this.canEditSecondary,
    required this.onChanged,
    this.showPrimary = true,
    this.showSecondary = true,
  });

  final String organizationId;
  final PolicySettings draft;
  final bool enabled;
  final bool canEditPrimary;
  final bool canEditSecondary;
  final ValueChanged<PolicySettings> onChanged;
  final bool showPrimary;
  final bool showSecondary;

  @override
  ConsumerState<ReportLogoSlotsEditor> createState() =>
      _ReportLogoSlotsEditorState();
}

class _ReportLogoSlotsEditorState extends ConsumerState<ReportLogoSlotsEditor> {
  bool _busy = false;

  // 6cm × 2cm (width × height) at ~38 logical px/cm
  static const slotW = 228.0;
  static const slotH = 76.0;

  Future<void> _pickAndUpload({required bool primary}) async {
    final canEdit = primary ? widget.canEditPrimary : widget.canEditSecondary;
    if (!widget.enabled || !canEdit || _busy) return;

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
      title: primary ? 'Org logo (top-right)' : 'Site/zone logo (top-left)',
    );
    if (cropped == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final path =
          '${widget.organizationId}/${primary ? 'primary' : 'secondary'}.png';
      final client = ref.read(supabaseClientProvider);
      await client.storage.from(kReportLogosBucket).uploadBinary(
            path,
            cropped,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
      widget.onChanged(
        primary
            ? widget.draft.copyWith(reportLogoPrimaryPath: path)
            : widget.draft.copyWith(reportLogoSecondaryPath: path),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo upload failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear({required bool primary}) async {
    final canEdit = primary ? widget.canEditPrimary : widget.canEditSecondary;
    if (!widget.enabled || !canEdit) return;
    widget.onChanged(
      primary
          ? widget.draft.copyWith(clearReportLogoPrimaryPath: true)
          : widget.draft.copyWith(clearReportLogoSecondaryPath: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.reportLogosTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          s.reportLogosHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            if (widget.showPrimary)
              _LogoSlot(
                title: s.reportLogoPrimary,
                subtitle: s.reportLogoPrimaryHint,
                width: slotW,
                height: slotH,
                storagePath: widget.draft.reportLogoPrimaryPath,
                canEdit: widget.enabled && widget.canEditPrimary,
                busy: _busy,
                onPick: () => _pickAndUpload(primary: true),
                onClear: () => _clear(primary: true),
              ),
            if (widget.showSecondary)
              _LogoSlot(
                title: s.reportLogoSecondary,
                subtitle: s.reportLogoSecondaryHint,
                width: slotW,
                height: slotH,
                storagePath: widget.draft.reportLogoSecondaryPath,
                canEdit: widget.enabled && widget.canEditSecondary,
                busy: _busy,
                onPick: () => _pickAndUpload(primary: false),
                onClear: () => _clear(primary: false),
              ),
          ],
        ),
      ],
    );
  }
}

class _LogoSlot extends ConsumerWidget {
  const _LogoSlot({
    required this.title,
    required this.subtitle,
    required this.width,
    required this.height,
    required this.storagePath,
    required this.canEdit,
    required this.busy,
    required this.onPick,
    required this.onClear,
  });

  final String title;
  final String subtitle;
  final double width;
  final double height;
  final String? storagePath;
  final bool canEdit;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Container(
          width: width,
          height: height,
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
          child: storagePath == null || storagePath!.isEmpty
              ? Center(
                  child: Text(
                    '—',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                )
              : FutureBuilder<String>(
                  future: ref
                      .read(supabaseClientProvider)
                      .storage
                      .from(kReportLogosBucket)
                      .createSignedUrl(storagePath!, 3600),
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
                      width: width,
                      height: height,
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
              onPressed: canEdit && !busy ? onPick : null,
              child: Text(canEdit ? 'Import' : 'Locked'),
            ),
            TextButton(
              onPressed: canEdit &&
                      !busy &&
                      storagePath != null &&
                      storagePath!.isNotEmpty
                  ? onClear
                  : null,
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}
