import 'dart:io';

import 'package:flutter/material.dart';

import '../offline/local_reading_draft.dart';
import '../photos/reading_photo_models.dart';
import '../screens/photo_preview_screen.dart';

class ReadingPhotoSection extends StatelessWidget {
  const ReadingPhotoSection({
    super.key,
    required this.draft,
    required this.isReadOnly,
    required this.isBusy,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onRemovePhoto,
    this.remoteImageUrl,
    this.remoteStoragePath,
    this.meterName,
    this.meterCode,
    this.photoRequired = false,
  });

  final LocalReadingDraft? draft;
  final bool isReadOnly;
  final bool isBusy;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onRemovePhoto;
  final String? remoteImageUrl;
  final String? remoteStoragePath;
  final String? meterName;
  final String? meterCode;
  final bool photoRequired;

  String? get _previewPath => draft?.watermarkedPhotoPath;

  PhotoUploadStatus get _status {
    if (draft == null) {
      return PhotoUploadStatus.none;
    }
    return draft!.photoUploadStatus;
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview = _previewPath != null || remoteImageUrl != null;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera_outlined, color: Colors.blueGrey.shade700),
              const SizedBox(width: 8),
              Text(
                'Meter photo',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              _PhotoStatusChip(status: _status),
            ],
          ),
          const SizedBox(height: 10),
          if (hasPreview)
            _PhotoPreviewTile(
              localPath: _previewPath,
              remoteUrl: remoteImageUrl,
              isReadOnly: isReadOnly,
              onTap: () => _openPreview(context),
            )
          else
            Text(
              photoRequired
                  ? 'A meter photo is required by policy.'
                  : 'Optional photo with visible watermark for audit trail.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: photoRequired
                        ? theme.colorScheme.error
                        : Colors.grey.shade700,
                  ),
            ),
          if (draft?.photoErrorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              draft!.photoErrorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ],
          if (!isReadOnly) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onCameraTap,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onGalleryTap,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            if (hasPreview) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: isBusy ? null : onRemovePhoto,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove photo'),
                ),
              ),
            ],
          ] else if (hasPreview) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Photo is read-only after submission.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoPreviewScreen(
          localPath: _previewPath,
          remoteUrl: remoteImageUrl,
          storagePath: remoteStoragePath ?? draft?.remotePhotoPath,
          meterName: meterName,
          meterCode: meterCode,
          photoSource: draft?.photoSource,
          capturedAt: draft?.photoCapturedAt,
        ),
      ),
    );
  }
}

class _PhotoStatusChip extends StatelessWidget {
  const _PhotoStatusChip({required this.status});

  final PhotoUploadStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PhotoUploadStatus.none => ('No photo', Colors.grey.shade700),
      PhotoUploadStatus.attachedLocally => ('Local photo', Colors.indigo.shade800),
      PhotoUploadStatus.uploading => ('Uploading', Colors.blue.shade800),
      PhotoUploadStatus.uploaded => ('Uploaded', Colors.green.shade800),
      PhotoUploadStatus.failed => ('Upload failed', Colors.red.shade800),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _PhotoPreviewTile extends StatelessWidget {
  const _PhotoPreviewTile({
    required this.localPath,
    required this.remoteUrl,
    required this.isReadOnly,
    required this.onTap,
  });

  final String? localPath;
  final String? remoteUrl;
  final bool isReadOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildImage(),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (localPath != null && File(localPath!).existsSync()) {
      return Image.file(File(localPath!), fit: BoxFit.cover);
    }
    if (remoteUrl != null) {
      return Image.network(remoteUrl!, fit: BoxFit.cover);
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

class ReadingPhotoThumbnail extends StatelessWidget {
  const ReadingPhotoThumbnail({
    super.key,
    this.localPath,
    this.remoteUrl,
    this.onTap,
  });

  final String? localPath;
  final String? remoteUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if ((localPath == null || !File(localPath!).existsSync()) &&
        remoteUrl == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: localPath != null && File(localPath!).existsSync()
              ? Image.file(File(localPath!), fit: BoxFit.cover)
              : Image.network(remoteUrl!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
