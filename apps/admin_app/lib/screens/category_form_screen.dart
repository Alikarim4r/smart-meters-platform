import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/catalog_providers.dart';
import '../utils/catalog_validation.dart';
import '../widgets/catalog_widgets.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.category});

  final MeterCategoryConfig? category;

  bool get isEditing => category != null;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  late final TextEditingController _baseUnitController;
  late final TextEditingController _iconController;
  late final TextEditingController _colorController;
  late final TextEditingController _sortOrderController;
  late bool _isActive;
  late bool _supportsCopOutput;
  late bool _supportsElectricInput;
  late bool _isConsumptionCategory;
  bool _isSaving = false;

  bool get _isProtected =>
      widget.category != null && isProtectedSystemCategory(widget.category!);

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _codeController = TextEditingController(text: category?.code ?? '');
    _nameEnController = TextEditingController(text: category?.nameEn ?? '');
    _nameArController = TextEditingController(text: category?.nameAr ?? '');
    _baseUnitController = TextEditingController(
      text: category?.baseUnitCode ?? '',
    );
    _iconController = TextEditingController(text: category?.icon ?? '');
    _colorController = TextEditingController(text: category?.color ?? '');
    _sortOrderController = TextEditingController(
      text: '${category?.sortOrder ?? 0}',
    );
    _isActive = category?.isActive ?? true;
    _supportsCopOutput = category?.supportsCopOutput ?? false;
    _supportsElectricInput = category?.supportsElectricInput ?? false;
    _isConsumptionCategory = category?.isConsumptionCategory ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
    _baseUnitController.dispose();
    _iconController.dispose();
    _colorController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!ref.read(canManageCatalogProvider)) {
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(meterCatalogRepositoryProvider);
    final sortOrder = int.parse(_sortOrderController.text.trim());
    final nameAr = _nameArController.text.trim();
    final icon = _iconController.text.trim();
    final color = _colorController.text.trim();

    try {
      if (widget.isEditing) {
        await repo.updateCategory(
          widget.category!.id,
          code: _isProtected ? null : _codeController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? '' : nameAr,
          baseUnitCode: _isProtected ? null : _baseUnitController.text.trim(),
          icon: icon.isEmpty ? '' : icon,
          color: color.isEmpty ? '' : color,
          isActive: _isActive,
          sortOrder: sortOrder,
          supportsCopOutput: _supportsCopOutput,
          supportsElectricInput: _supportsElectricInput,
          isConsumptionCategory: _isConsumptionCategory,
        );
      } else {
        await repo.createCategory(
          code: _codeController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? null : nameAr,
          baseUnitCode: _baseUnitController.text.trim(),
          icon: icon.isEmpty ? null : icon,
          color: color.isEmpty ? null : color,
          isActive: _isActive,
          sortOrder: sortOrder,
          supportsCopOutput: _supportsCopOutput,
          supportsElectricInput: _supportsElectricInput,
          isConsumptionCategory: _isConsumptionCategory,
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
        title: Text(widget.isEditing ? 'Edit category' : 'Add category'),
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
              if (_isProtected)
                Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  color: Colors.blue.shade50,
                  child: const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('System category'),
                    subtitle: Text(
                      'Code and base unit are locked. You can edit labels, '
                      'icon, color, and sort order.',
                    ),
                  ),
                ),
              CatalogFormSection(
                title: 'Basic information',
                subtitle: 'Identifiers and display names',
                children: [
                  TextFormField(
                    controller: _codeController,
                    decoration: catalogFieldDecoration(
                      labelText: 'Code *',
                      hintText: 'e.g. compressed_air',
                    ),
                    enabled: canManage && !_isProtected,
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
                    controller: _baseUnitController,
                    decoration: catalogFieldDecoration(
                      labelText: 'Base unit code *',
                      hintText: 'e.g. m3, kwh',
                    ),
                    enabled: canManage && !_isProtected,
                    validator: (v) => validateRequiredText(v, 'Base unit code'),
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
                title: 'Display options',
                subtitle: 'Icon and color shown in entry apps',
                children: [
                  TextFormField(
                    controller: _iconController,
                    decoration: catalogFieldDecoration(
                      labelText: 'Icon',
                      hintText: 'Material icon name',
                    ),
                    enabled: canManage,
                  ),
                  TextFormField(
                    controller: _colorController,
                    decoration: catalogFieldDecoration(
                      labelText: 'Color',
                      hintText: '#RRGGBB',
                    ),
                    enabled: canManage,
                  ),
                ],
              ),
              CatalogFormSection(
                title: 'COP / consumption flags',
                subtitle: 'Energy performance and consumption behavior',
                children: [
                  CatalogSwitchTile(
                    title: 'Supports COP output',
                    subtitle: 'Category can report coefficient of performance',
                    value: _supportsCopOutput,
                    onChanged: canManage
                        ? (value) => setState(() => _supportsCopOutput = value)
                        : null,
                  ),
                  CatalogSwitchTile(
                    title: 'Supports electric input (COP)',
                    subtitle: 'Category accepts electric input for COP calc',
                    value: _supportsElectricInput,
                    onChanged: canManage
                        ? (value) =>
                              setState(() => _supportsElectricInput = value)
                        : null,
                  ),
                  CatalogSwitchTile(
                    title: 'Consumption category',
                    subtitle: 'Readings count as consumption',
                    value: _isConsumptionCategory,
                    onChanged: canManage
                        ? (value) =>
                              setState(() => _isConsumptionCategory = value)
                        : null,
                  ),
                ],
              ),
              CatalogFormSection(
                title: 'Status',
                children: [
                  CatalogSwitchTile(
                    title: 'Active',
                    subtitle: 'Inactive categories are hidden from entry apps',
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
