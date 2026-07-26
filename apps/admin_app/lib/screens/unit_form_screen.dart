import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/catalog_providers.dart';
import '../utils/catalog_validation.dart';
import '../widgets/catalog_widgets.dart';

class UnitFormScreen extends ConsumerStatefulWidget {
  const UnitFormScreen({
    super.key,
    required this.categoryId,
    this.unit,
    this.existingUnits = const [],
  });

  final String categoryId;
  final MeterUnitConfig? unit;
  final List<MeterUnitConfig> existingUnits;

  bool get isEditing => unit != null;

  @override
  ConsumerState<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends ConsumerState<UnitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  late final TextEditingController _factorController;
  late final TextEditingController _sortOrderController;
  late bool _isBase;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final unit = widget.unit;
    _codeController = TextEditingController(text: unit?.code ?? '');
    _nameEnController = TextEditingController(text: unit?.nameEn ?? '');
    _nameArController = TextEditingController(text: unit?.nameAr ?? '');
    _factorController = TextEditingController(
      text: unit?.unitToBaseFactor.toString() ?? '1',
    );
    _sortOrderController = TextEditingController(
      text: '${unit?.sortOrder ?? 0}',
    );
    _isBase = unit?.isBase ?? false;
    _isActive = unit?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
    _factorController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final baseError = validateSingleBaseUnit(
      isBase: _isBase,
      editingUnitId: widget.unit?.id,
      existingUnits: widget.existingUnits,
    );
    if (baseError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(baseError)));
      return;
    }

    if (!ref.read(canManageCatalogProvider)) {
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(meterCatalogRepositoryProvider);
    final sortOrder = int.parse(_sortOrderController.text.trim());
    final factor = double.parse(_factorController.text.trim());
    final nameAr = _nameArController.text.trim();

    try {
      if (widget.isEditing) {
        await repo.updateUnit(
          widget.unit!.id,
          code: _codeController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? '' : nameAr,
          unitToBaseFactor: factor,
          isBase: _isBase,
          isActive: _isActive,
          sortOrder: sortOrder,
        );
      } else {
        await repo.createUnit(
          categoryId: widget.categoryId,
          code: _codeController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? null : nameAr,
          unitToBaseFactor: factor,
          isBase: _isBase,
          isActive: _isActive,
          sortOrder: sortOrder,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyCatalogError(error))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageCatalogProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit unit' : 'Add unit'),
        actions: [
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
            children: [
              CatalogFormSection(
                title: 'Basic information',
                children: [
                  TextFormField(
                    controller: _codeController,
                    decoration: catalogFieldDecoration(
                      labelText: 'Code *',
                      hintText: 'e.g. m3, gal',
                    ),
                    enabled: canManage,
                    validator: validateCatalogCode,
                  ),
                  TextFormField(
                    controller: _nameEnController,
                    decoration: catalogFieldDecoration(
                      labelText: 'English name *',
                    ),
                    enabled: canManage,
                    validator: (v) => validateRequiredText(v, 'English name'),
                  ),
                  TextFormField(
                    controller: _nameArController,
                    decoration: catalogFieldDecoration(
                      labelText: 'Arabic name',
                    ),
                    enabled: canManage,
                  ),
                  TextFormField(
                    controller: _factorController,
                    decoration: catalogFieldDecoration(
                      labelText: 'Unit to base factor *',
                      helperText: 'Multiply reading by this to get base units',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    enabled: canManage,
                    validator: validateUnitFactor,
                  ),
                  TextFormField(
                    controller: _sortOrderController,
                    decoration: catalogFieldDecoration(
                      labelText: 'Sort order *',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: canManage,
                    validator: validateSortOrder,
                  ),
                ],
              ),
              CatalogFormSection(
                title: 'Status',
                children: [
                  CatalogSwitchTile(
                    title: 'Base unit for category',
                    subtitle: 'Only one base unit per category',
                    value: _isBase,
                    onChanged: canManage
                        ? (value) => setState(() => _isBase = value)
                        : null,
                  ),
                  CatalogSwitchTile(
                    title: 'Active',
                    subtitle: 'Inactive units are hidden from entry apps',
                    value: _isActive,
                    onChanged: canManage
                        ? (value) => setState(() => _isActive = value)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
