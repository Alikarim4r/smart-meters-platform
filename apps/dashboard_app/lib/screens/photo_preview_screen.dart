import 'package:flutter/material.dart';

class PhotoPreviewScreen extends StatelessWidget {
  const PhotoPreviewScreen({
    super.key,
    required this.imageUrl,
    this.storagePath,
    this.meterName,
    this.meterCode,
    this.readingDate,
    this.value,
    this.siteName,
  });

  final String imageUrl;
  final String? storagePath;
  final String? meterName;
  final String? meterCode;
  final String? readingDate;
  final String? value;
  final String? siteName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reading photo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 240,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Text('Could not load image. Pull to refresh.'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (meterName != null)
              _MetaRow(
                label: 'Meter',
                value: '$meterName${meterCode != null ? ' ($meterCode)' : ''}',
              ),
            if (readingDate != null)
              _MetaRow(label: 'Reading date', value: readingDate!),
            if (value != null) _MetaRow(label: 'Value', value: value!),
            if (storagePath != null)
              _MetaRow(label: 'Storage path', value: storagePath!),
          ],
        ),
      ),
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
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
