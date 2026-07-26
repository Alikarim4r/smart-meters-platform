import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../photos/reading_photo_models.dart';

class PhotoPreviewScreen extends StatelessWidget {
  const PhotoPreviewScreen({
    super.key,
    this.localPath,
    this.remoteUrl,
    this.storagePath,
    this.meterName,
    this.meterCode,
    this.photoSource,
    this.capturedAt,
  });

  final String? localPath;
  final String? remoteUrl;
  final String? storagePath;
  final String? meterName;
  final String? meterCode;
  final ReadingPhotoSource? photoSource;
  final DateTime? capturedAt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meter photo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: _buildImage(),
              ),
            ),
            const SizedBox(height: 16),
            if (meterName != null)
              _MetaRow(label: 'Meter', value: '$meterName${meterCode != null ? ' ($meterCode)' : ''}'),
            if (photoSource != null)
              _MetaRow(label: 'Source', value: photoSource!.label),
            if (capturedAt != null)
              _MetaRow(
                label: 'Captured',
                value: formatQatarCaptureTimestamp(capturedAt!),
              ),
            if (storagePath != null)
              _MetaRow(label: 'Storage path', value: storagePath!),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (localPath != null && File(localPath!).existsSync()) {
      return Image.file(File(localPath!), fit: BoxFit.contain);
    }
    if (remoteUrl != null) {
      return Image.network(remoteUrl!, fit: BoxFit.contain);
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
