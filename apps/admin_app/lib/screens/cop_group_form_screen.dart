import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';

class CopGroupFormScreen extends ConsumerStatefulWidget {
  const CopGroupFormScreen({
    super.key,
    required this.siteId,
    this.existing,
  });

  final String siteId;
  final CopGroupDetail? existing;

  @override
  ConsumerState<CopGroupFormScreen> createState() => _CopGroupFormScreenState();
}

class _CopGroupFormScreenState extends ConsumerState<CopGroupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameEn;
  late final TextEditingController _nameAr;
  late final TextEditingController _description;
  late bool _isActive;
  late Set<String> _btuMeterIds;
  late Set<String> _elecMeterIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameEn = TextEditingController(text: existing?.nameEn ?? 'Chiller Plant COP');
    _nameAr = TextEditingController(
      text: existing?.nameAr ?? 'معامل أداء محطة التبريد',
    );
    _description = TextEditingController(text: existing?.description ?? '');
    _isActive = existing?.isActive ?? true;
    _btuMeterIds = {...?existing?.btuMeterIds};
    _elecMeterIds = {...?existing?.electricityMeterIds};
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _nameAr.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save(AdminStrings s) async {
    if (!_formKey.currentState!.validate()) return;
    if (_btuMeterIds.isEmpty || _elecMeterIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.copGroupNeedsBothMeterTypes)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(copGroupRepositoryProvider).upsert(
            CopGroupUpsertInput(
              id: widget.existing?.id,
              siteId: widget.siteId,
              nameEn: _nameEn.text,
              nameAr: _nameAr.text,
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              isActive: _isActive,
              btuMeterIds: _btuMeterIds.toList(),
              electricityMeterIds: _elecMeterIds.toList(),
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(AdminStrings s) async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteCopGroup),
        content: Text(s.deleteCopGroupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(copGroupRepositoryProvider).delete(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final metersAsync = ref.watch(siteMetersProvider(widget.siteId));
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? s.editCopGroup : s.addCopGroup),
        actions: [
          if (isEdit)
            IconButton(
              onPressed: _saving ? null : () => _delete(s),
              icon: const Icon(Icons.delete_outline),
              tooltip: s.deleteCopGroup,
            ),
        ],
      ),
      body: metersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => CatalogErrorView(
          message: friendlyMeterError(error),
          onRetry: () =>
              ref.invalidate(siteMetersProvider(widget.siteId)),
        ),
        data: (meters) {
          final btuMeters = meters
              .where(
                (m) =>
                    m.categoryConfig?.supportsCopOutput == true ||
                    m.category == MeterCategory.btu,
              )
              .toList();
          final elecMeters = meters
              .where(
                (m) =>
                    m.categoryConfig?.supportsElectricInput == true ||
                    m.category == MeterCategory.electricity,
              )
              .toList();

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  s.copEerFormulaHint,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameEn,
                  decoration: InputDecoration(labelText: s.englishName),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? s.fieldRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameAr,
                  decoration: InputDecoration(labelText: s.arabicName),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? s.fieldRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: InputDecoration(labelText: s.description),
                  maxLines: 2,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.active),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 8),
                Text(
                  s.copCoolingMeters,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  s.copCoolingMetersHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (btuMeters.isEmpty)
                  Text(s.noBtuMetersForCop)
                else
                  ...btuMeters.map(
                    (meter) => CheckboxListTile(
                      value: _btuMeterIds.contains(meter.id),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _btuMeterIds.add(meter.id);
                          } else {
                            _btuMeterIds.remove(meter.id);
                          }
                        });
                      },
                      title: Text(s.isAr ? meter.nameAr : meter.nameEn),
                      subtitle: Text(
                        '${meter.meterCode} · ${meter.baseUnit}',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  s.copElectricityMeters,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  s.copElectricityMetersHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (elecMeters.isEmpty)
                  Text(s.noElectricityMetersForCop)
                else
                  ...elecMeters.map(
                    (meter) => CheckboxListTile(
                      value: _elecMeterIds.contains(meter.id),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _elecMeterIds.add(meter.id);
                          } else {
                            _elecMeterIds.remove(meter.id);
                          }
                        });
                      },
                      title: Text(s.isAr ? meter.nameAr : meter.nameEn),
                      subtitle: Text(
                        '${meter.meterCode} · ${meter.baseUnit}',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : () => _save(s),
                  child: Text(_saving ? s.saving : s.save),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
