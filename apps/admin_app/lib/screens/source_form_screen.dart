import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/catalog_providers.dart';
import '../utils/catalog_validation.dart';
import '../widgets/catalog_widgets.dart';
import '../l10n/admin_strings.dart';

class SourceFormScreen extends ConsumerStatefulWidget {
  const SourceFormScreen({super.key, required this.categoryId, this.source});

  final String categoryId;
  final MeterSourceConfig? source;

  bool get isEditing => source != null;

  @override
  ConsumerState<SourceFormScreen> createState() => _SourceFormScreenState();
}

class _SourceFormScreenState extends ConsumerState<SourceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  late final TextEditingController _sortOrderController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _codeController = TextEditingController(text: source?.code ?? '');
    _nameEnController = TextEditingController(text: source?.nameEn ?? '');
    _nameArController = TextEditingController(text: source?.nameAr ?? '');
    _sortOrderController = TextEditingController(
      text: '${source?.sortOrder ?? 0}',
    );
    _isActive = source?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
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

    try {
      if (widget.isEditing) {
        await repo.updateSource(
          widget.source!.id,
          code: _codeController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? '' : nameAr,
          isActive: _isActive,
          sortOrder: sortOrder,
        );
      } else {
        await repo.createSource(
          categoryId: widget.categoryId,
          code: _codeController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? null : nameAr,
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
        title: Text(widget.isEditing ? 'Edit source' : 'Add source'),
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
              CatalogFormSection(
                title: adminText(
                  context,
                  'Basic information',
                  'المعلومات الأساسية',
                ),
                children: [
                  TextFormField(
                    controller: _codeController,
                    decoration: catalogFieldDecoration(
                      labelText: adminText(context, 'Code *', 'الرمز *'),
                      hintText: 'e.g. compressor, grid',
                    ),
                    enabled: canManage,
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
                title: adminText(context, 'Status', 'الحالة'),
                children: [
                  CatalogSwitchTile(
                    title: adminText(context, 'Active', 'مفعّل'),
                    subtitle: adminText(
                      context,
                      'Inactive sources are hidden from entry apps',
                      'المصادر غير المفعّلة مخفية من تطبيق الإدخال',
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
