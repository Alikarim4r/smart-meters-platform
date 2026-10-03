import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/catalog_providers.dart';
import '../utils/catalog_validation.dart';
import '../widgets/catalog_widgets.dart';
import '../l10n/admin_strings.dart';

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
              padding: const EdgeInsetsDirectional.only(end: 8),
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
                    : Text(adminText(context, 'Save', 'حفظ')),
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
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text(
                      adminText(context, 'System category', 'فئة نظام'),
                    ),
                    subtitle: Text(
                      'Code and base unit are locked. You can edit labels, '
                      'icon, color, and sort order.',
                    ),
                  ),
                ),
              CatalogFormSection(
                title: adminText(
                  context,
                  'Basic information',
                  'المعلومات الأساسية',
                ),
                subtitle: adminText(
                  context,
                  'Identifiers and display names',
                  'المعرّفات وأسماء العرض',
                ),
                children: [
                  TextFormField(
                    controller: _codeController,
                    decoration: catalogFieldDecoration(
                      labelText: adminText(context, 'Code *', 'الرمز *'),
                      hintText: 'e.g. compressed_air',
                    ),
                    enabled: canManage && !_isProtected,
                    validator: validateCatalogCode,
                  ),
                  TextFormField(
                    controller: _nameEnController,
                    decoration: catalogFieldDecoration(
                      labelText: adminText(
                        context,
                        'English name *',
                        'الاسم بالإنجليزية *',
                      ),
                    ),
                    enabled: canManage,
                    validator: (v) => validateRequiredText(v, 'English name'),
                  ),
                  TextFormField(
                    controller: _nameArController,
                    decoration: catalogFieldDecoration(
                      labelText: adminText(
                        context,
                        'Arabic name',
                        'الاسم بالعربية',
                      ),
                    ),
                    enabled: canManage,
                  ),
                  TextFormField(
                    controller: _baseUnitController,
                    decoration: catalogFieldDecoration(
                      labelText: adminText(
                        context,
                        'Base unit code *',
                        'رمز الوحدة الأساسية *',
                      ),
                      hintText: 'e.g. m3, kwh',
                    ),
                    enabled: canManage && !_isProtected,
                    validator: (v) => validateRequiredText(v, 'Base unit code'),
                  ),
                  TextFormField(
                    controller: _sortOrderController,
                    decoration: catalogFieldDecoration(
                      labelText: adminText(
                        context,
                        'Sort order *',
                        'ترتيب العرض *',
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: canManage,
                    validator: validateSortOrder,
                  ),
                ],
              ),
              CatalogFormSection(
                title: adminText(context, 'Display options', 'خيارات العرض'),
                subtitle: adminText(
                  context,
                  'Icon and color shown in entry apps',
                  'الأيقونة واللون الظاهران في تطبيق الإدخال',
                ),
                children: [
                  TextFormField(
                    controller: _iconController,
                    decoration: catalogFieldDecoration(
                      labelText: adminText(context, 'Icon', 'الأيقونة'),
                      hintText: adminText(
                        context,
                        'Material icon name',
                        'اسم أيقونة Material',
                      ),
                    ),
                    enabled: canManage,
                  ),
                  TextFormField(
                    controller: _colorController,
                    decoration: catalogFieldDecoration(
                      labelText: adminText(context, 'Color', 'اللون'),
                      hintText: '#RRGGBB',
                    ),
                    enabled: canManage,
                  ),
                ],
              ),
              CatalogFormSection(
                title: adminText(
                  context,
                  'COP / consumption flags',
                  'خصائص COP / الاستهلاك',
                ),
                subtitle: adminText(
                  context,
                  'Energy performance and consumption behavior',
                  'أداء الطاقة وسلوك الاستهلاك',
                ),
                children: [
                  CatalogSwitchTile(
                    title: adminText(
                      context,
                      'Supports COP output',
                      'يدعم مخرج COP',
                    ),
                    subtitle: adminText(
                      context,
                      'Category can report coefficient of performance',
                      'يمكن للفئة عرض معامل الأداء',
                    ),
                    value: _supportsCopOutput,
                    onChanged: canManage
                        ? (value) => setState(() => _supportsCopOutput = value)
                        : null,
                  ),
                  CatalogSwitchTile(
                    title: adminText(
                      context,
                      'Supports electric input (COP)',
                      'يدعم مدخل الكهرباء (COP)',
                    ),
                    subtitle: adminText(
                      context,
                      'Category accepts electric input for COP calc',
                      'تقبل الفئة مدخل الكهرباء لحساب COP',
                    ),
                    value: _supportsElectricInput,
                    onChanged: canManage
                        ? (value) =>
                              setState(() => _supportsElectricInput = value)
                        : null,
                  ),
                  CatalogSwitchTile(
                    title: adminText(
                      context,
                      'Consumption category',
                      'فئة استهلاك',
                    ),
                    subtitle: adminText(
                      context,
                      'Readings count as consumption',
                      'تُحتسب القراءات كاستهلاك',
                    ),
                    value: _isConsumptionCategory,
                    onChanged: canManage
                        ? (value) =>
                              setState(() => _isConsumptionCategory = value)
                        : null,
                  ),
                ],
              ),
              CatalogFormSection(
                title: adminText(context, 'Status', 'الحالة'),
                children: [
                  CatalogSwitchTile(
                    title: adminText(context, 'Active', 'مفعّل'),
                    subtitle: adminText(
                      context,
                      'Inactive categories are hidden from entry apps',
                      'الفئات غير المفعّلة مخفية من تطبيق الإدخال',
                    ),
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
