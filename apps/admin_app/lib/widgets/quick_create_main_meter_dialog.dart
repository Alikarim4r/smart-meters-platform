import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/admin_validation.dart';
import '../widgets/catalog_widgets.dart';

/// Quick-create a meter with schema-neutral hierarchy defaults (v2 owns links).
Future<Meter?> showQuickCreateMainMeterDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String siteId,
  required String categoryId,
  required String sourceId,
  required String unitId,
}) {
  return showDialog<Meter>(
    context: context,
    builder: (ctx) => _QuickCreateMainMeterDialog(
      siteId: siteId,
      categoryId: categoryId,
      sourceId: sourceId,
      unitId: unitId,
    ),
  );
}

class _QuickCreateMainMeterDialog extends ConsumerStatefulWidget {
  const _QuickCreateMainMeterDialog({
    required this.siteId,
    required this.categoryId,
    required this.sourceId,
    required this.unitId,
  });

  final String siteId;
  final String categoryId;
  final String sourceId;
  final String unitId;

  @override
  ConsumerState<_QuickCreateMainMeterDialog> createState() =>
      _QuickCreateMainMeterDialogState();
}

class _QuickCreateMainMeterDialogState
    extends ConsumerState<_QuickCreateMainMeterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _nameEn = TextEditingController();
  final _nameAr = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _nameEn.dispose();
    _nameAr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final meter = await ref
          .read(meterRepositoryProvider)
          .createMeter(
            siteId: widget.siteId,
            meterCode: _code.text.trim(),
            nameEn: _nameEn.text.trim(),
            nameAr: _nameAr.text.trim().isEmpty
                ? _nameEn.text.trim()
                : _nameAr.text.trim(),
            categoryId: widget.categoryId,
            sourceId: widget.sourceId,
            unitId: widget.unitId,
            level: MeterLevel.main,
            parentMeterId: null,
            poursIntoTank: false,
            destinationTankId: null,
          );
      if (!mounted) return;
      Navigator.pop(context, meter);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyMeterError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create meter'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _code,
                  decoration: catalogFieldDecoration(labelText: 'Meter code *'),
                  validator: validateMeterCode,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameEn,
                  decoration: catalogFieldDecoration(
                    labelText: 'English name *',
                  ),
                  validator: validateSiteNameEn,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameAr,
                  decoration: catalogFieldDecoration(labelText: 'Arabic name'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
