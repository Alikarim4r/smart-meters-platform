import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/catalog_providers.dart';
import '../providers/preferences_providers.dart';
import '../utils/admin_validation.dart';
import '../widgets/catalog_widgets.dart';

class MeterFormScreen extends ConsumerStatefulWidget {
  const MeterFormScreen({
    super.key,
    required this.siteId,
    this.meter,
    this.initialCategoryId,
  });

  final String siteId;
  final Meter? meter;

  /// Prefill category when creating (e.g. water network editor).
  final String? initialCategoryId;

  bool get isEditing => meter != null;

  @override
  ConsumerState<MeterFormScreen> createState() => _MeterFormScreenState();
}

class _MeterFormScreenState extends ConsumerState<MeterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  late final TextEditingController _multiplierController;
  late final TextEditingController _sortOrderController;
  late bool _isActive;
  late bool _includeInDashboard;
  String? _categoryId;
  String? _sourceId;
  String? _unitId;
  String? _meterTypeId;
  String? _measurementTypeId;
  String? _globalUnitId;
  bool _isSaving = false;
  bool? _hasReadings;

  bool get _catalogLocked => _hasReadings == true;

  @override
  void initState() {
    super.initState();
    final meter = widget.meter;
    _codeController = TextEditingController(text: meter?.meterCode ?? '');
    _nameEnController = TextEditingController(text: meter?.nameEn ?? '');
    _nameArController = TextEditingController(text: meter?.nameAr ?? '');
    _multiplierController = TextEditingController(
      text: '${meter?.meterMultiplier ?? 1}',
    );
    _sortOrderController = TextEditingController(
      text: '${meter?.sortOrder ?? 0}',
    );
    _isActive = meter?.isActive ?? true;
    _includeInDashboard = meter?.includeInDashboard ?? true;
    _categoryId = meter?.categoryId ?? widget.initialCategoryId;
    _sourceId = meter?.sourceId;
    _unitId = meter?.unitId;

    if (widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadReadingsFlag());
    } else if (widget.initialCategoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onCategoryChanged(widget.initialCategoryId);
      });
    }
  }

  Future<void> _loadReadingsFlag() async {
    final hasReadings = await ref
        .read(meterRepositoryProvider)
        .meterHasReadings(widget.meter!.id);
    if (mounted) {
      setState(() => _hasReadings = hasReadings);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
    _multiplierController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _onCategoryChanged(String? categoryId) async {
    setState(() {
      _categoryId = categoryId;
      _sourceId = null;
      _unitId = null;
      _meterTypeId = null;
      _measurementTypeId = null;
      _globalUnitId = null;
    });
    if (categoryId == null) return;
    final catalog = ref.read(meterCatalogRepositoryProvider);
    final meterTypeId = await catalog.resolveMeterTypeIdForCategory(categoryId);
    if (!mounted || meterTypeId == null) return;
    final measurements = await catalog.getMeasurementsForMeterType(meterTypeId);
    if (!mounted) return;
    final primary = measurements.isEmpty ? null : measurements.first;
    setState(() {
      _meterTypeId = meterTypeId;
      _measurementTypeId = primary?.id;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!ref.read(canManageMetersProvider)) {
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(meterRepositoryProvider);
    final nameAr = _nameArController.text.trim();
    final sortOrder = int.parse(_sortOrderController.text.trim());
    final multiplier = double.parse(_multiplierController.text.trim());

    try {
      if (widget.isEditing) {
        // Hierarchy/tank fields stay at existing DB values — owned by utility network v2.
        final updated = await repo.updateMeter(
          widget.meter!.id,
          meterCode: _codeController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? _nameEnController.text.trim() : nameAr,
          categoryId: _catalogLocked ? null : _categoryId,
          sourceId: _catalogLocked ? null : _sourceId,
          unitId: _catalogLocked ? null : _unitId,
          level: widget.meter!.level,
          meterMultiplier: _catalogLocked ? null : multiplier,
          sortOrder: sortOrder,
          isActive: _isActive,
          includeInDashboard: _includeInDashboard,
        );
        if (!mounted) return;
        Navigator.pop(context, updated);
      } else {
        // Prefer measurement→global unit path when available.
        var legacyUnitId = _unitId;
        if (_measurementTypeId != null &&
            _globalUnitId != null &&
            _categoryId != null) {
          final catalog = ref.read(meterCatalogRepositoryProvider);
          final units = await catalog.getUnitsForMeasurement(
            _measurementTypeId!,
          );
          final global = units.where((u) => u.id == _globalUnitId).toList();
          if (global.isNotEmpty) {
            legacyUnitId =
                await catalog.resolveLegacyUnitId(
                  categoryId: _categoryId!,
                  globalUnitCode: global.first.code,
                ) ??
                _unitId;
          }
        }
        // Schema-safe defaults only; meter hierarchy is owned by utility network v2.
        final created = await repo.createMeter(
          siteId: widget.siteId,
          meterCode: _codeController.text.trim(),
          nameEn: _nameEnController.text.trim(),
          nameAr: nameAr.isEmpty ? _nameEnController.text.trim() : nameAr,
          categoryId: _categoryId!,
          sourceId: _sourceId!,
          unitId: legacyUnitId!,
          meterTypeId: _meterTypeId,
          measurementTypeId: _measurementTypeId,
          globalUnitId: _globalUnitId,
          level: MeterLevel.main,
          parentMeterId: null,
          poursIntoTank: false,
          destinationTankId: null,
          meterMultiplier: multiplier,
          sortOrder: sortOrder,
          isActive: _isActive,
          includeInDashboard: _includeInDashboard,
        );
        if (!mounted) return;
        Navigator.pop(context, created);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyMeterError(error))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final canManage = ref.watch(canManageMetersProvider);
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final unitsAsync = _categoryId == null
        ? const AsyncValue<List<MeterUnitConfig>>.data([])
        : ref.watch(catalogUnitsProvider(_categoryId!));
    final sourcesAsync = _categoryId == null
        ? const AsyncValue<List<MeterSourceConfig>>.data([])
        : ref.watch(catalogSourcesProvider(_categoryId!));
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? s.editMeter : s.addMeter),
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
                    : Text(s.save),
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
              if (_catalogLocked)
                Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  color: Colors.amber.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(s.meterHasReadings),
                    subtitle: Text(s.meterHasReadingsHint),
                  ),
                ),
              CatalogFormSection(
                title: s.basicInformation,
                children: [
                  TextFormField(
                    controller: _codeController,
                    decoration: catalogFieldDecoration(
                      labelText: '${s.meterCode} *',
                      hintText: 'e.g. WM-001',
                    ),
                    enabled: canManage,
                    validator: validateMeterCode,
                  ),
                  TextFormField(
                    controller: _nameEnController,
                    decoration: catalogFieldDecoration(
                      labelText: '${s.englishName} *',
                    ),
                    enabled: canManage,
                    validator: validateSiteNameEn,
                  ),
                  TextFormField(
                    controller: _nameArController,
                    decoration: catalogFieldDecoration(
                      labelText: s.arabicName,
                    ),
                    enabled: canManage,
                  ),
                  TextFormField(
                    controller: _sortOrderController,
                    decoration: catalogFieldDecoration(
                      labelText: '${s.sortOrder} *',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: canManage,
                    validator: validateSortOrder,
                  ),
                ],
              ),
              CatalogFormSection(
                title: s.categoryAndMeasurement,
                subtitle: s.isAr
                    ? 'خيارات الوحدة والمصدر تعتمد على الفئة المختارة'
                    : 'Unit and source options depend on the selected category',
                children: [
                  categoriesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Text(friendlyMeterError(error)),
                    data: (categories) {
                      // Primary utilities only: water, electricity, energy (BTU).
                      // Keep the meter's current category visible when editing.
                      const primaryCodes = {'water', 'electricity', 'btu'};
                      final activeCategories = categories
                          .where(
                            (c) =>
                                (c.isActive && primaryCodes.contains(c.code)) ||
                                c.id == _categoryId,
                          )
                          .toList();
                      _categoryId ??= activeCategories.isNotEmpty
                          ? activeCategories.first.id
                          : null;
                      return DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        isExpanded: true,
                        decoration: catalogFieldDecoration(
                          labelText: '${s.category} *',
                        ),
                        items: [
                          for (final category in activeCategories)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(
                                category.nameEn,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: canManage && !_catalogLocked
                            ? _onCategoryChanged
                            : null,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Category is required'
                            : null,
                      );
                    },
                  ),
                  if (_meterTypeId != null)
                    FutureBuilder<List<MeasurementTypeConfig>>(
                      future: ref
                          .read(meterCatalogRepositoryProvider)
                          .getMeasurementsForMeterType(_meterTypeId!),
                      builder: (context, snap) {
                        final measurements = snap.data ?? const [];
                        if (measurements.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        _measurementTypeId ??= measurements.first.id;
                        return DropdownButtonFormField<String>(
                          key: ValueKey(
                            'meas_$_meterTypeId$_measurementTypeId',
                          ),
                          initialValue: _measurementTypeId,
                          isExpanded: true,
                          decoration: catalogFieldDecoration(
                            labelText: 'Measurement type *',
                            helperText:
                                'Units are filtered by this measurement',
                          ),
                          items: [
                            for (final m in measurements)
                              DropdownMenuItem(
                                value: m.id,
                                child: Text(
                                  '${m.nameEn} — ${m.nameAr}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: canManage && !_catalogLocked
                              ? (value) => setState(() {
                                  _measurementTypeId = value;
                                  _globalUnitId = null;
                                  _unitId = null;
                                })
                              : null,
                        );
                      },
                    ),
                  if (_measurementTypeId != null)
                    FutureBuilder<List<GlobalUnitConfig>>(
                      future: ref
                          .read(meterCatalogRepositoryProvider)
                          .getUnitsForMeasurement(_measurementTypeId!),
                      builder: (context, snap) {
                        final units = snap.data ?? const [];
                        if (units.isEmpty) {
                          return unitsAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (error, _) =>
                                Text(friendlyMeterError(error)),
                            data: (legacyUnits) {
                              // Fall back to legacy category units.
                              final active = legacyUnits
                                  .where((u) => u.isActive)
                                  .toList();
                              return DropdownButtonFormField<String>(
                                initialValue: _unitId,
                                isExpanded: true,
                                decoration: catalogFieldDecoration(
                                  labelText: '${s.unit} *',
                                ),
                                items: [
                                  for (final u in active)
                                    DropdownMenuItem(
                                      value: u.id,
                                      child: Text('${u.nameEn} (${u.code})'),
                                    ),
                                ],
                                onChanged: canManage && !_catalogLocked
                                    ? (v) => setState(() => _unitId = v)
                                    : null,
                                validator: (v) =>
                                    v == null ? 'Unit is required' : null,
                              );
                            },
                          );
                        }
                        _globalUnitId ??= units.first.id;
                        return DropdownButtonFormField<String>(
                          key: ValueKey(
                            'gunit_$_measurementTypeId$_globalUnitId',
                          ),
                          initialValue: _globalUnitId,
                          isExpanded: true,
                          decoration: catalogFieldDecoration(
                            labelText: '${s.unit} *',
                            helperText:
                                'Only units allowed for this measurement',
                          ),
                          items: [
                            for (final u in units)
                              DropdownMenuItem(
                                value: u.id,
                                child: Text(
                                  '${u.nameEn} (${u.code})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: canManage && !_catalogLocked
                              ? (value) => setState(() => _globalUnitId = value)
                              : null,
                          validator: (value) =>
                              value == null ? 'Unit is required' : null,
                        );
                      },
                    )
                  else
                    unitsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text(friendlyMeterError(error)),
                      data: (units) {
                        if (_categoryId == null) {
                          return DropdownButtonFormField<String>(
                            initialValue: null,
                            isExpanded: true,
                            decoration: catalogFieldDecoration(
                              labelText: '${s.unit} *',
                              helperText: 'Select a category first',
                            ),
                            items: const [],
                            onChanged: null,
                            validator: (_) => 'Select a category first',
                          );
                        }
                        final activeUnits = units
                            .where((u) => u.isActive)
                            .toList();
                        if (activeUnits.isEmpty) {
                          return InputDecorator(
                            decoration: catalogFieldDecoration(
                              labelText: '${s.unit} *',
                              helperText:
                                  'No units for this category — add them under Units',
                            ),
                            child: Text(
                              'No units available',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          );
                        }
                        String? unitValue = _unitId;
                        if (unitValue != null &&
                            !activeUnits.any((u) => u.id == unitValue)) {
                          unitValue = null;
                        }
                        if (unitValue == null) {
                          final base = activeUnits.where((u) => u.isBase);
                          unitValue = base.isNotEmpty
                              ? base.first.id
                              : activeUnits.first.id;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _unitId != unitValue) {
                              setState(() => _unitId = unitValue);
                            }
                          });
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: unitValue,
                          isExpanded: true,
                          decoration: catalogFieldDecoration(
                            labelText: '${s.unit} *',
                            helperText:
                                'Choose from catalog units for this category',
                          ),
                          items: [
                            for (final unit in activeUnits)
                              DropdownMenuItem(
                                value: unit.id,
                                child: Text(
                                  '${unit.nameEn} (${unit.code})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: canManage && !_catalogLocked
                              ? (value) => setState(() => _unitId = value)
                              : null,
                          validator: (value) =>
                              value == null ? 'Unit is required' : null,
                        );
                      },
                    ),
                  sourcesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text(friendlyMeterError(error)),
                    data: (sources) {
                      final activeSources = sources
                          .where((s) => s.isActive)
                          .toList();
                      _sourceId ??= activeSources.isNotEmpty
                          ? activeSources.first.id
                          : null;
                      return DropdownButtonFormField<String>(
                        initialValue: _sourceId,
                        isExpanded: true,
                        decoration: catalogFieldDecoration(
                          labelText: '${s.source} *',
                        ),
                        items: [
                          for (final source in activeSources)
                            DropdownMenuItem(
                              value: source.id,
                              child: Text(
                                source.nameEn,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: canManage && !_catalogLocked
                            ? (value) => setState(() => _sourceId = value)
                            : null,
                        validator: (value) =>
                            value == null ? 'Source is required' : null,
                      );
                    },
                  ),
                  TextFormField(
                    controller: _multiplierController,
                    decoration: catalogFieldDecoration(
                      labelText: 'Meter multiplier *',
                      helperText: 'Applied to raw readings',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    enabled: canManage && !_catalogLocked,
                    validator: _catalogLocked ? null : validateMeterMultiplier,
                  ),
                ],
              ),
              CatalogFormSection(
                title: 'Status',
                children: [
                  CatalogSwitchTile(
                    title: 'Active',
                    subtitle: 'Inactive meters are hidden from entry apps',
                    value: _isActive,
                    onChanged: canManage
                        ? (value) => setState(() => _isActive = value)
                        : null,
                  ),
                  CatalogSwitchTile(
                    title: 'Include in dashboard',
                    subtitle: 'Show this meter on future dashboard views',
                    value: _includeInDashboard,
                    onChanged: canManage
                        ? (value) => setState(() => _includeInDashboard = value)
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
