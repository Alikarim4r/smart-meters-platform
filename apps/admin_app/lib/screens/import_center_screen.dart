import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/admin_providers.dart';

/// CSV import preview/validate workflow (no silent write).
class ImportCenterScreen extends ConsumerStatefulWidget {
  const ImportCenterScreen({
    super.key,
    required this.organizationId,
    this.siteId,
  });

  final String organizationId;
  final String? siteId;

  @override
  ConsumerState<ImportCenterScreen> createState() => _ImportCenterScreenState();
}

class _ImportCenterScreenState extends ConsumerState<ImportCenterScreen> {
  final _controller = TextEditingController();
  ImportPreviewResult? _preview;
  String? _error;
  String? _fingerprint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runPreview() async {
    setState(() {
      _error = null;
      _preview = null;
    });
    try {
      const svc = ImportValidationService();
      final content = _controller.text;
      _fingerprint = computeImportContentFingerprint(content);
      final client = ref.read(supabaseClientProvider);
      final repo = ImportBatchRepository(client);
      final dup = await repo.hasCommittedFingerprint(
        organizationId: widget.organizationId,
        fileFingerprint: _fingerprint!,
      );
      if (dup) {
        setState(() {
          _error =
              'Duplicate file fingerprint — already committed. Re-upload blocked (idempotent).';
        });
        return;
      }

      final rows = svc.parseCsv(content);
      final meters = await _loadMetersByCode();
      final preview = svc.validate(
        headers: content.trim().isEmpty
            ? const <String>[]
            : content.trim().split('\n').first.split(',').map((e) => e.trim()).toList(),
        rows: rows,
        mapping: const ImportColumnMapping(
          meterCodeColumn: 'meter_code',
          readingDateColumn: 'reading_date',
          rawValueColumn: 'raw_value',
          unitColumn: 'unit',
          externalIdColumn: 'external_reading_id',
        ),
        metersByCode: meters,
        expectedSiteId: widget.siteId,
      );
      setState(() => _preview = preview);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<Map<String, ImportMeterRef>> _loadMetersByCode() async {
    final client = ref.read(supabaseClientProvider);
    final sites = await ref.read(adminSitesProvider.future);
    final siteIds = sites
        .where((s) => s.organizationId == widget.organizationId)
        .where((s) => widget.siteId == null || s.id == widget.siteId)
        .map((s) => s.id)
        .toList();
    if (siteIds.isEmpty) return {};
    final rows = await client
        .from('meters')
        .select('id, meter_code, site_id, unit:meter_units(code)')
        .inFilter('site_id', siteIds)
        .eq('meter_kind', 'physical');
    final map = <String, ImportMeterRef>{};
    for (final row in rows as List) {
      final m = Map<String, dynamic>.from(row as Map);
      final code = (m['meter_code'] as String?)?.trim() ?? '';
      if (code.isEmpty) continue;
      final unitObj = m['unit'];
      String unitCode = '';
      if (unitObj is Map) {
        unitCode = (unitObj['code'] as String?) ?? '';
      }
      map[code] = ImportMeterRef(
        id: m['id'] as String,
        code: code,
        siteId: m['site_id'] as String,
        unitCode: unitCode,
        organizationId: widget.organizationId,
      );
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Import Center',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: ImportValidationService.templateCsv()),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template CSV copied')),
                );
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('Template'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Paste CSV → Preview → Validate. Commit is admin-confirmed only. '
          'Corrections use the existing Corrections path — no silent overwrite.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLines: 12,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Paste CSV contents…',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _runPreview,
          child: const Text('Preview & Validate'),
        ),
        if (_fingerprint != null) ...[
          const SizedBox(height: 8),
          Text('Fingerprint: $_fingerprint',
              style: Theme.of(context).textTheme.bodySmall),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_preview != null) ...[
          const SizedBox(height: 16),
          Text(
            'Accepted ${_preview!.acceptedCount} · '
            'Rejected ${_preview!.rejectedCount} · '
            'Duplicated ${_preview!.duplicatedCount}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!_preview!.headersValid)
            Text('Header errors: ${_preview!.headerErrors.join(", ")}'),
          const SizedBox(height: 8),
          ..._preview!.rows.take(50).map(
                (r) => ListTile(
                  dense: true,
                  title: Text('Row ${r.rowNumber}: ${r.status.name}'),
                  subtitle: Text(r.errorMessage ?? r.raw.toString()),
                ),
              ),
          if (_preview!.canCommitPartial)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Partial acceptance allowed for ${_preview!.acceptedCount} rows. '
                'Commit writes via authenticated batch after explicit admin action '
                '(not auto-run from this preview).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}
