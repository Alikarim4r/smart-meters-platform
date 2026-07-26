import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/catalog_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/overflow_safe.dart';
import 'meter_form_screen.dart';

bool networkEditorIsCompact(BuildContext context) {
  // Phones/tablets in portrait must never use the desktop side-panel layout.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return true;
  }
  final size = MediaQuery.sizeOf(context);
  return size.width < 900 || size.shortestSide < 700;
}

/// Lock phone to portrait while the admin Network tab is active.
Future<void> applyAdminNetworkOrientation({
  required bool networkTabActive,
}) async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  if (networkTabActive) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
}

enum NetworkV2ScreenState {
  loading,
  noSiteSelected,
  noNetwork,
  networkWithoutDraft,
  emptyDraft,
  importAvailable,
  importPreview,
  importing,
  loaded,
  versionConflict,
  permissionDenied,
  error,
}

enum NetworkEditorMode { view, edit }

NetworkEditorMode networkEditorModeFor({required bool editDraft}) =>
    editDraft ? NetworkEditorMode.edit : NetworkEditorMode.view;

NetworkV2ScreenState networkV2StateFor({
  required bool hasSite,
  required bool loading,
  required bool hasNetwork,
  UtilityNetworkSnapshot? snapshot,
  Object? error,
  bool importing = false,
  bool previewing = false,
  bool hasLegacyGraph = false,
}) {
  if (!hasSite) return NetworkV2ScreenState.noSiteSelected;
  if (loading) return NetworkV2ScreenState.loading;
  if (importing) return NetworkV2ScreenState.importing;
  if (previewing) return NetworkV2ScreenState.importPreview;
  if (error is NetworkVersionConflict) {
    return NetworkV2ScreenState.versionConflict;
  }
  if (error is NetworkPermissionError) {
    return NetworkV2ScreenState.permissionDenied;
  }
  if (error is NetworkNoDraftError) {
    return NetworkV2ScreenState.networkWithoutDraft;
  }
  if (error != null) return NetworkV2ScreenState.error;
  if (!hasNetwork) return NetworkV2ScreenState.noNetwork;
  if (snapshot == null) return NetworkV2ScreenState.loading;
  if (snapshot.nodes.isEmpty) {
    return hasLegacyGraph
        ? NetworkV2ScreenState.importAvailable
        : NetworkV2ScreenState.emptyDraft;
  }
  return NetworkV2ScreenState.loaded;
}

/// Contract helper for tests: editor must not call legacy 031 write APIs.
bool networkEditorAvoidsLegacyWrites(String source) {
  final forbidden = <String>[
    'importFrom'
        'Meters',
    'upsert'
        'Node',
    'updateNode'
        'Position',
    'delete'
        'Node',
    'create'
        'Edge',
    'delete'
        'Edge',
    'upsert'
        'Edge',
    "from('site_network_"
        "nodes')",
    "from('site_network_"
        "edges')",
  ];
  return !forbidden.any(source.contains);
}

/// Single source for the water types offered when creating or editing a
/// connection (the two dropdowns must always match).
const List<String> kNetworkWaterTypes = [
  'potable',
  'raw',
  'treated',
  'tse',
  'product',
  'reject',
  'ro_reject',
  'rainwater',
  'rainwater_filtered',
  'irrigation',
  'drainage',
  'discharge',
  'firefighting',
];

/// Connection kinds / transport / operating modes — must match DB checks.
final List<String> kNetworkConnectionKinds = [
  for (final v in UtilityConnectionKind.values) v.dbValue,
];
final List<String> kNetworkTransportModes = [
  for (final v in UtilityTransportMode.values) v.dbValue,
];
final List<String> kNetworkOperatingModes = [
  for (final v in UtilityOperatingMode.values) v.dbValue,
];

/// Ensures [current] is selectable so DropdownButton never asserts.
List<String> networkDropdownOptions(List<String> canonical, {String? current}) {
  final options = [...canonical];
  if (current != null && current.isNotEmpty && !options.contains(current)) {
    options.add(current);
  }
  return options;
}

String networkWaterTypeLabel(String value, {required bool isArabic}) =>
    switch (value) {
      'potable' => isArabic ? 'مياه الشرب' : 'Potable',
      'raw' => isArabic ? 'مياه خام' : 'Raw',
      'treated' => isArabic ? 'مياه معالجة' : 'Treated',
      'tse' => isArabic ? 'مياه معالجة ثلاثيًا (TSE)' : 'TSE',
      'product' => isArabic ? 'منتجة (RO)' : 'Product (RO)',
      'reject' => isArabic ? 'مرفوضة' : 'Reject',
      'ro_reject' => isArabic ? 'مرفوض تحلية (RO)' : 'RO Reject',
      'rainwater' => isArabic ? 'مياه أمطار' : 'Rainwater',
      'rainwater_filtered' =>
          isArabic ? 'مياه أمطار مفلترة' : 'Rainwater (filtered)',
      'irrigation' => isArabic ? 'ري' : 'Irrigation',
      'drainage' => isArabic ? 'صرف' : 'Drainage',
      'discharge' => isArabic ? 'تصريف' : 'Discharge',
      'firefighting' => isArabic ? 'مكافحة حريق' : 'Firefighting',
      _ => value,
    };

/// Maps a meter source code to utility asset service_type for canvas colors.
String? networkServiceTypeFromMeterSource(String? sourceCode) {
  final key = sourceCode?.trim().toLowerCase();
  if (key == null || key.isEmpty) return null;
  return switch (key) {
    'kahramaa' || 'potable' || 'drinking' => 'potable',
    'tse' || 'treated_sewage' => 'tse',
    'ro' || 'ro_product' || 'product' => 'product',
    'tanker' => 'raw',
    _ => key,
  };
}

String networkConnectionKindLabel(String value, {required bool isArabic}) =>
    switch (value) {
      'supply' => isArabic ? 'تزويد' : 'Supply',
      'transfer' => isArabic ? 'نقل' : 'Transfer',
      'overflow' => isArabic ? 'فيض' : 'Overflow',
      'washout' => isArabic ? 'غسيل' : 'Washout',
      'drain' => isArabic ? 'صرف' : 'Drain',
      'discharge' => isArabic ? 'تصريف' : 'Discharge',
      'tanker_transport' => isArabic ? 'نقل صهريج' : 'Tanker transport',
      'bypass' => isArabic ? 'تجاوز' : 'Bypass',
      'recirculation' => isArabic ? 'إعادة تدوير' : 'Recirculation',
      _ => value,
    };

String networkTransportModeLabel(String value, {required bool isArabic}) =>
    switch (value) {
      'pipe' => isArabic ? 'أنبوب' : 'Pipe',
      'tanker' => isArabic ? 'صهريج' : 'Tanker',
      'open_drain' => isArabic ? 'صرف مفتوح' : 'Open drain',
      'other' => isArabic ? 'أخرى' : 'Other',
      // Legacy UI value — keep label if an old draft still has it.
      'channel' => isArabic ? 'قناة' : 'Channel',
      _ => value,
    };

String networkOperatingModeLabel(String value, {required bool isArabic}) =>
    switch (value) {
      'normal' => isArabic ? 'عادي' : 'Normal',
      'standby' => isArabic ? 'احتياطي' : 'Standby',
      'emergency' => isArabic ? 'طوارئ' : 'Emergency',
      'seasonal' => isArabic ? 'موسمي' : 'Seasonal',
      'maintenance' => isArabic ? 'صيانة' : 'Maintenance',
      _ => value,
    };

sealed class NetworkUndoEntry {
  const NetworkUndoEntry();
}

class NetworkUndoMove extends NetworkUndoEntry {
  const NetworkUndoMove({required this.viewId, required this.previous});
  final String viewId;
  final List<UtilityViewNode> previous;
}

class NetworkUndoConnect extends NetworkUndoEntry {
  const NetworkUndoConnect({required this.connectionId});
  final String connectionId;
}

class NetworkUndoDisconnect extends NetworkUndoEntry {
  const NetworkUndoDisconnect({
    required this.fromNodeId,
    required this.fromPortId,
    required this.toNodeId,
    required this.toPortId,
    required this.connectionKind,
    this.waterType,
    this.transportMode = 'pipe',
    this.operatingMode = 'normal',
  });
  final String fromNodeId;
  final String fromPortId;
  final String toNodeId;
  final String toPortId;
  final String connectionKind;
  final String? waterType;
  final String transportMode;
  final String operatingMode;
}

class NetworkUndoRemoveFromView extends NetworkUndoEntry {
  const NetworkUndoRemoveFromView({
    required this.viewId,
    required this.placement,
  });
  final String viewId;
  final UtilityViewNode placement;
}

class NetworkTab extends ConsumerStatefulWidget {
  const NetworkTab({super.key});

  @override
  ConsumerState<NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends ConsumerState<NetworkTab> {
  String? _siteId;
  String? _categoryId;
  String? _networkId;
  String? _selectedViewId;
  String? _selectedNodeId;
  String? _selectedConnectionId;
  UtilityNetworkSnapshot? _snapshot;
  Object? _loadError;
  bool _loading = false;
  bool _resolving = false;
  bool _importing = false;
  bool _previewing = false;
  bool _editMode = false;
  bool _mutating = false;
  bool _autoSaved = false;
  bool _hasLegacyImport = false;
  List<NetworkValidationIssue> _sideErrors = const [];
  List<NetworkValidationIssue> _sideWarnings = const [];
  final List<NetworkUndoEntry> _undoStack = [];
  final GlobalKey<UtilityNetworkCanvasState> _canvasKey = GlobalKey();
  Timer? _moveDebounce;
  Timer? _autoSavedHide;
  final Map<String, UtilityViewNode> _pendingMoves = {};
  Map<String, UtilityViewNode>? _moveBaseline;
  Offset? _pendingDropPos;
  bool _didSyncMetersForDraft = false;
  String? _syncedDraftKey;
  bool _paletteDragging = false;
  bool _flushingMoves = false;
  bool _ensuringMeters = false;
  static const _addOffsetStep = 40.0;

  UtilityNetworkRepository get _repo =>
      ref.read(utilityNetworkRepositoryProvider);

  void _logNetworkError(String where, Object e, [StackTrace? st]) {
    final trace = st ?? (e is Error ? e.stackTrace : null);
    assert(() {
      // ignore: avoid_print
      print('[network_tab] $where: $e');
      if (trace != null) {
        // ignore: avoid_print
        print(trace);
      }
      return true;
    }());
    // Staging/debug: keep technical detail in Flutter error pipeline.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: e,
        stack: trace,
        library: 'network_tab',
        context: ErrorDescription(where),
      ),
    );
  }

  int get _lock => _snapshot?.revision.lockVersion ?? 0;
  String? get _revisionId => _snapshot?.revision.id;

  String? _waterCategoryId(List<MeterCategoryConfig> categories) {
    for (final c in categories) {
      if (c.code == MeterCategory.water.dbValue && c.isActive) return c.id;
    }
    for (final c in categories) {
      if (c.code == MeterCategory.water.dbValue) return c.id;
    }
    return null;
  }

  Offset _nextAddPos() {
    final n = _undoStack.length + (_snapshot?.placements.length ?? 0);
    return Offset(80 + n * _addOffsetStep, 80 + n * _addOffsetStep * 0.6);
  }

  Offset _gridPos(int index, {int columns = 4}) {
    const dx = 200.0;
    const dy = 120.0;
    final col = index % columns;
    final row = index ~/ columns;
    return Offset(80 + col * dx, 80 + row * dy);
  }

  Offset _addPos() => _pendingDropPos ?? _nextAddPos();

  void _applyLockVersion(int lockVersion) {
    final snap = _snapshot;
    if (snap == null || snap.revision.lockVersion == lockVersion) return;
    _snapshot = snap.copyWith(
      revision: snap.revision.copyWith(lockVersion: lockVersion),
    );
  }

  bool get _movesBusy =>
      _flushingMoves || _pendingMoves.isNotEmpty || (_moveDebounce?.isActive ?? false);

  /// Places every active site meter missing from the current view onto the canvas.
  Future<void> _ensureAllMetersOnView({bool force = false}) async {
    final siteId = _siteId;
    final networkId = _networkId;
    final viewId = _selectedViewId;
    final revisionId = _revisionId;
    final snapshot = _snapshot;
    if (siteId == null ||
        networkId == null ||
        viewId == null ||
        revisionId == null ||
        snapshot == null) {
      return;
    }
    if (!ref.read(canManageMetersProvider)) return;
    // Never fight an in-flight canvas drag/save — that snaps cards back.
    if (_movesBusy || _ensuringMeters) return;

    final draftKey = '$revisionId|$viewId';
    if (!force && _didSyncMetersForDraft && _syncedDraftKey == draftKey) {
      return;
    }

    try {
      _ensuringMeters = true;
      final available = await _repo.listAvailableMeters(
        networkId: networkId,
        revisionId: revisionId,
        viewId: viewId,
        siteId: siteId,
        limit: 500,
      );
      if (!mounted || _movesBusy) return;
      final missing = [
        for (final m in available)
          if (m.state.dbValue != AvailableMeterState.inCurrentView.dbValue) m,
      ];
      if (missing.isEmpty) {
        _didSyncMetersForDraft = true;
        _syncedDraftKey = draftKey;
        return;
      }

      if (_mutating) return;
      setState(() => _mutating = true);
      var lock = _lock;
      final existingCount = snapshot.placements
          .where((p) => p.viewId == viewId)
          .length;
      String? lastNodeId;
      for (var i = 0; i < missing.length; i++) {
        if (!mounted || _movesBusy) break;
        final m = missing[i];
        final pos = _gridPos(existingCount + i);
        final result = await _repo.attachExistingMeter(
          revisionId: revisionId,
          expectedLockVersion: lock,
          meterId: m.meterId,
          viewId: viewId,
          posX: pos.dx,
          posY: pos.dy,
          replaceExistingParent: false,
        );
        lock = result.lockVersion;
        lastNodeId = result.nodeId ?? lastNodeId;
      }
      _didSyncMetersForDraft = true;
      _syncedDraftKey = draftKey;
      if (!mounted) return;
      if (!_movesBusy) {
        await _refreshKeepSelection(focusNodeId: lastNodeId);
      } else {
        _applyLockVersion(lock);
      }
      if (!mounted || missing.isEmpty) return;
      final s = AdminStrings(ref.read(adminLocaleProvider));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.isAr
                ? 'تم وضع ${missing.length} عداد على الشبكة'
                : 'Placed ${missing.length} meter(s) on the network',
          ),
        ),
      );
    } catch (e) {
      final s = AdminStrings(ref.read(adminLocaleProvider));
      _showMutationError(e, s);
    } finally {
      _ensuringMeters = false;
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _addPaletteItem(String kind, {Offset? dropAt}) async {
    final siteId = _siteId;
    final categoryId = _categoryId;
    if (siteId == null || categoryId == null) return;
    _pendingDropPos = dropAt;
    try {
      switch (kind) {
        case 'existing_meter':
          await _pickExistingMeter(siteId);
          return;
        case 'new_meter':
          await _createNewMeter(siteId, categoryId);
          return;
        case 'existing_tank':
          await _pickExistingTank(siteId);
          return;
        case 'new_tank':
          await _createNewTank(siteId);
          return;
        default:
          await _createGeneric(siteId, kind);
      }
    } finally {
      _pendingDropPos = null;
    }
  }

  String _errorDetail(Object e) {
    if (e is TypeError || e is Error) return e.toString();
    return e.toString();
  }

  String _arabicError(Object e, AdminStrings s) {
    if (e is NetworkVersionConflict) return s.networkVersionConflict;
    if (e is NetworkPermissionError) return s.networkPermissionDenied;
    if (e is NetworkNoDraftError) return s.networkNoDraft;
    return s.networkLoadFailed;
  }

  void _showMutationError(Object e, AdminStrings s) {
    if (!mounted) return;
    final msg = '${_arabicError(e, s)}\n${_errorDetail(e)}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _markAutoSaved() {
    _autoSavedHide?.cancel();
    setState(() => _autoSaved = true);
    _autoSavedHide = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _autoSaved = false);
    });
    final s = AdminStrings(ref.read(adminLocaleProvider));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.networkAutoSaved),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _resolveAndLoad(String siteId, String categoryId) async {
    if (_resolving) return;
    setState(() {
      _resolving = true;
      _loading = true;
      _loadError = null;
      _siteId = siteId;
      _categoryId = categoryId;
      _sideErrors = const [];
      _sideWarnings = const [];
    });
    try {
      final primary = await _repo.resolvePrimaryNetworkForSite(
        siteId: siteId,
        categoryId: categoryId,
      );
      if (!mounted) return;
      if (primary == null) {
        setState(() {
          _networkId = null;
          _snapshot = null;
          _loading = false;
          _resolving = false;
        });
        return;
      }
      final id = primary.id.toString();
      setState(() => _networkId = id);
      await _loadDraft(id);
    } catch (e, st) {
      _logNetworkError('_resolveAndLoad', e, st);
      if (mounted) {
        setState(() {
          _loadError = e;
          _snapshot = null;
          _loading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _loadDraft(String networkId) async {
    setState(() {
      _loading = true;
      _loadError = null;
      _selectedNodeId = null;
      _selectedConnectionId = null;
      _undoStack.clear();
      _pendingMoves.clear();
      _moveBaseline = null;
    });
    try {
      final snapshot = await _repo.getDraftSnapshot(networkId);
      if (!mounted) return;
      var hasLegacy = false;
      final siteId = _siteId;
      final categoryId = _categoryId;
      if (snapshot.nodes.isEmpty && siteId != null && categoryId != null) {
        try {
          final plan = await _repo.importLegacyDryRun(
            siteId: siteId,
            categoryId: categoryId,
            networkId: networkId,
          );
          final summary = LegacyImportPlanSummary.fromPlan(plan);
          hasLegacy = summary.totalAdds > 0 || summary.legacyNodes > 0;
        } catch (_) {
          hasLegacy = false;
        }
      }
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _hasLegacyImport = hasLegacy;
        _selectedViewId =
            snapshot.views.where((v) => v.isDefault).firstOrNull?.id ??
            snapshot.views.firstOrNull?.id;
        _loading = false;
        _didSyncMetersForDraft = false;
        _syncedDraftKey = null;
      });
      // Dump all registered site meters onto the canvas, then user links them.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureAllMetersOnView();
      });
    } catch (e, st) {
      _logNetworkError('_loadDraft', e, st);
      if (mounted) {
        final hadSnapshot = _snapshot != null;
        setState(() {
          // Only blank the canvas on initial load failure.
          if (!hadSnapshot) {
            _loadError = e;
          }
          _loading = false;
        });
        if (hadSnapshot) {
          final s = AdminStrings(ref.read(adminLocaleProvider));
          _showMutationError(e, s);
        }
      }
    }
  }

  Future<void> _refreshKeepSelection({
    NetworkUndoEntry? undo,
    String? focusNodeId,
  }) async {
    final id = _networkId;
    if (id == null) return;
    if (_movesBusy) return;
    if (undo != null) {
      _undoStack.add(undo);
      if (_undoStack.length > 40) _undoStack.removeAt(0);
    }
    final keepNode = focusNodeId ?? _selectedNodeId;
    final keepConn = _selectedConnectionId;
    try {
      final snapshot = await _repo.getDraftSnapshot(id);
      if (!mounted || _movesBusy) return;
      setState(() {
        _snapshot = snapshot;
        _selectedViewId =
            _selectedViewId ??
            snapshot.views.where((v) => v.isDefault).firstOrNull?.id ??
            snapshot.views.firstOrNull?.id;
        _selectedNodeId = keepNode;
        _selectedConnectionId = keepConn;
      });
      if (keepNode != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _canvasKey.currentState?.focusNode(keepNode);
        });
      }
    } catch (e) {
      final s = AdminStrings(ref.read(adminLocaleProvider));
      _showMutationError(e, s);
    }
  }

  Future<T?> _runMutation<T>(
    Future<T> Function() action, {
    NetworkUndoEntry? undo,
    String? focusNodeId,
  }) async {
    if (_mutating) return null;
    final s = AdminStrings(ref.read(adminLocaleProvider));
    setState(() => _mutating = true);
    try {
      final result = await action();
      if (!mounted) return result;
      _markAutoSaved();
      await _refreshKeepSelection(undo: undo, focusNodeId: focusNodeId);
      return result;
    } catch (e) {
      _showMutationError(e, s);
      return null;
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _createWaterNetwork(String siteId, String categoryId) async {
    final s = AdminStrings(ref.read(adminLocaleProvider));
    setState(() => _mutating = true);
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final result = await _repo.createUtilityNetwork(
        categoryId: categoryId,
        code: 'water-$stamp',
        nameEn: 'Water network',
        nameAr: 'شبكة المياه',
        memberSiteIds: [siteId],
      );
      final id = result['network_id']?.toString();
      if (id != null) {
        setState(() => _networkId = id);
        await _loadDraft(id);
      }
    } catch (e) {
      _showMutationError(e, s);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _importLegacy(String siteId, String categoryId) async {
    final networkId = _networkId;
    final snapshot = _snapshot;
    if (networkId == null || snapshot == null) return;
    final s = AdminStrings(ref.read(adminLocaleProvider));
    setState(() => _previewing = true);
    try {
      final plan = await _repo.importLegacyDryRun(
        siteId: siteId,
        categoryId: categoryId,
        networkId: networkId,
      );
      if (!mounted) return;
      final summary = LegacyImportPlanSummary.fromPlan(plan);
      final apply = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.networkImportPreview),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${s.networkImportMeters}: ${summary.metersToAdd}'),
              Text('${s.networkImportTanks}: ${summary.tanksToAdd}'),
              Text(
                '${s.networkImportConnections}: ${summary.connectionsToAdd}',
              ),
              Text('${s.networkImportSkipped}: ${summary.skipped}'),
              Text('${s.networkImportConflicts}: ${summary.conflicts}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.networkImportApply),
            ),
          ],
        ),
      );
      if (apply != true || !mounted) return;
      setState(() => _importing = true);
      await _repo.importLegacyApply(
        revisionId: snapshot.revision.id,
        expectedLockVersion: snapshot.revision.lockVersion,
        siteId: siteId,
      );
      if (!mounted) return;
      _markAutoSaved();
      await _loadDraft(networkId);
    } catch (e) {
      _showMutationError(e, s);
    } finally {
      if (mounted) {
        setState(() {
          _previewing = false;
          _importing = false;
        });
      }
    }
  }

  void _onNodeMoved(UtilityRevisionNode node, UtilityViewNode placement) {
    final snapshot = _snapshot;
    final viewId = _selectedViewId;
    if (snapshot == null || viewId == null || !_editMode) return;
    _moveBaseline ??= {
      for (final p in snapshot.placements.where((p) => p.viewId == viewId))
        p.nodeId: p,
    };
    final existing = snapshot.placements
        .where((p) => p.viewId == viewId && p.nodeId == node.id)
        .firstOrNull;
    if (existing == null) return;
    final updated = placement;
    _pendingMoves[node.id] = updated;
    setState(() {
      _snapshot = snapshot.copyWith(
        placements: [
          for (final p in snapshot.placements)
            if (p.viewId == viewId && p.nodeId == node.id) updated else p,
        ],
      );
    });
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 450), _flushMoves);
  }

  Future<void> _flushMoves() async {
    final snapshot = _snapshot;
    final viewId = _selectedViewId;
    final revisionId = _revisionId;
    final s = AdminStrings(ref.read(adminLocaleProvider));
    if (snapshot == null ||
        viewId == null ||
        revisionId == null ||
        _pendingMoves.isEmpty ||
        _flushingMoves) {
      return;
    }
    final positions = _pendingMoves.values.toList();
    final baseline = _moveBaseline;
    final optimisticPlacements = [
      for (final p in snapshot.placements)
        if (p.viewId == viewId && _pendingMoves.containsKey(p.nodeId))
          _pendingMoves[p.nodeId]!
        else
          p,
    ];
    _pendingMoves.clear();
    _flushingMoves = true;
    try {
      Future<NetworkMutationResult> save(int lock) => _repo.batchMoveViewNodes(
        revisionId: revisionId,
        expectedLockVersion: lock,
        viewId: viewId,
        positions: positions,
      );

      NetworkMutationResult result;
      try {
        result = await save(_lock);
      } on NetworkVersionConflict {
        // Another mutation bumped the lock — refresh lock only, keep new positions.
        final fresh = await _repo.getDraftSnapshot(_networkId!);
        if (!mounted) return;
        final merged = [
          for (final p in fresh.placements)
            if (p.viewId == viewId)
              positions.where((m) => m.nodeId == p.nodeId).firstOrNull ?? p
            else
              p,
        ];
        // Include any brand-new placements from optimistic list.
        final byId = {for (final p in merged) p.nodeId: p};
        for (final p in positions) {
          byId[p.nodeId] = p;
        }
        setState(() {
          _snapshot = fresh.copyWith(placements: byId.values.toList());
        });
        result = await save(_lock);
      }

      if (!mounted) return;
      if (baseline != null) {
        _undoStack.add(
          NetworkUndoMove(viewId: viewId, previous: baseline.values.toList()),
        );
      }
      _moveBaseline = null;
      setState(() {
        _applyLockVersion(result.lockVersion);
        // Keep the positions the user just placed — do not reload (snap-back).
        _snapshot = (_snapshot ?? snapshot).copyWith(
          placements: optimisticPlacements,
          revision: (_snapshot ?? snapshot).revision.copyWith(
            lockVersion: result.lockVersion,
          ),
        );
      });
      _markAutoSaved();
    } catch (e) {
      if (!mounted) return;
      if (baseline != null) {
        setState(() {
          _snapshot = snapshot.copyWith(
            placements: [
              for (final p in snapshot.placements)
                if (p.viewId == viewId && baseline.containsKey(p.nodeId))
                  baseline[p.nodeId]!
                else
                  p,
            ],
          );
        });
      }
      _moveBaseline = null;
      _showMutationError(e, s);
    } finally {
      _flushingMoves = false;
    }
  }

  Future<void> _onConnectPorts(
    UtilityRevisionNode fromNode,
    UtilityAssetPort fromPort,
    UtilityRevisionNode toNode,
    UtilityAssetPort toPort,
  ) async {
    final snapshot = _snapshot;
    final revisionId = _revisionId;
    if (snapshot == null || revisionId == null || !_editMode) return;
    final s = AdminStrings(ref.read(adminLocaleProvider));

    // Ensure outflow → inflow (swap or pick alternate ports if needed).
    var fromN = fromNode;
    var fromP = fromPort;
    var toN = toNode;
    var toP = toPort;
    final fromDir = fromP.direction.dbValue;
    final toDir = toP.direction.dbValue;
    if (fromDir == 'in' && toDir == 'out') {
      fromN = toNode;
      fromP = toPort;
      toN = fromNode;
      toP = fromPort;
    } else if (fromDir == 'in') {
      final out = fromN.asset?.ports
          .where((p) => p.direction.dbValue == 'out')
          .firstOrNull;
      if (out != null) fromP = out;
    }
    if (toP.direction.dbValue == 'out') {
      final inn = toN.asset?.ports
          .where((p) => p.direction.dbValue != 'out')
          .firstOrNull;
      if (inn != null) toP = inn;
    }

    final bothMeters =
        fromN.asset?.assetType.dbValue == 'meter' &&
        toN.asset?.assetType.dbValue == 'meter';

    final form = await showDialog<_ConnectForm>(
      context: context,
      builder: (context) => _ConnectPortsDialog(
        strings: s,
        initialKind: bothMeters ? 'transfer' : 'supply',
      ),
    );
    if (form == null || !mounted) return;
    setState(() => _mutating = true);
    try {
      final result = await _repo.connectPorts(
        revisionId: revisionId,
        expectedLockVersion: _lock,
        fromNodeId: fromN.id,
        fromPortId: fromP.id,
        toNodeId: toN.id,
        toPortId: toP.id,
        connectionKind: form.kind,
        waterType: form.waterType,
        // Meter↔meter must stay graph-only so parent_meter hierarchy rules
        // (main/sub constraints) never block the canvas connection.
        legacySyncStatus: bothMeters ? 'graph_only' : null,
        replaceExistingParent: bothMeters && form.kind == 'supply',
      );
      if (!mounted) return;
      _markAutoSaved();
      await _refreshKeepSelection();
      final connectionId = result.connectionId?.toString() ?? '';
      if (connectionId.isNotEmpty) {
        _undoStack.add(NetworkUndoConnect(connectionId: connectionId));
      } else {
        final created = _snapshot?.connections
            .where(
              (c) =>
                  c.fromNodeId == fromN.id &&
                  c.fromPortId == fromP.id &&
                  c.toNodeId == toN.id &&
                  c.toPortId == toP.id,
            )
            .lastOrNull;
        if (created != null) {
          _undoStack.add(NetworkUndoConnect(connectionId: created.id));
        }
      }
    } catch (e) {
      _showMutationError(e, s);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _syncMeterServiceType({
    required String? assetId,
    required String? nodeId,
    required String? sourceCode,
  }) async {
    if (assetId == null || _revisionId == null) return;
    final serviceType = networkServiceTypeFromMeterSource(sourceCode);
    if (serviceType == null) return;
    await _runMutation(
      () => _repo.updateAsset(
        revisionId: _revisionId!,
        expectedLockVersion: _lock,
        assetId: assetId,
        serviceType: serviceType,
      ),
      focusNodeId: nodeId,
    );
  }

  Future<void> _addAssetPort(
    UtilityRevisionNode node, {
    required String direction,
  }) async {
    final revisionId = _revisionId;
    final asset = node.asset;
    if (revisionId == null || asset == null || !_editMode) return;
    final existingCodes = {for (final p in asset.ports) p.code};
    final prefix = direction == 'out' ? 'out' : 'in';
    final isOut = direction == 'out';
    String code;
    if (isOut && !existingCodes.contains('outlet')) {
      code = 'outlet';
    } else if (!isOut && !existingCodes.contains('inlet')) {
      code = 'inlet';
    } else {
      var n = 1;
      code = '${prefix}_$n';
      while (existingCodes.contains(code)) {
        n++;
        code = '${prefix}_$n';
      }
    }
    final nLabel =
        asset.ports.where((p) => p.direction.dbValue == direction).length + 1;
    await _runMutation(
      () => _repo.addAssetPort(
        revisionId: revisionId,
        expectedLockVersion: _lock,
        assetId: asset.id,
        code: code,
        nameEn: isOut ? 'Outlet $nLabel' : 'Inlet $nLabel',
        nameAr: isOut ? 'مخرج $nLabel' : 'مدخل $nLabel',
        direction: direction,
        portRole: isOut ? 'outlet' : 'inlet',
      ),
      focusNodeId: node.id,
    );
  }

  Future<void> _removeAssetPort(
    UtilityRevisionNode node,
    UtilityAssetPort port,
  ) async {
    final revisionId = _revisionId;
    if (revisionId == null || !_editMode) return;
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.networkRemovePort),
        content: Text('${port.code} (${port.direction.dbValue})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.networkRemovePort),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _runMutation(
      () => _repo.removeAssetPort(
        revisionId: revisionId,
        expectedLockVersion: _lock,
        portId: port.id,
      ),
      focusNodeId: node.id,
    );
  }

  Future<void> _saveAssetServiceType(
    UtilityRevisionNode node,
    String? serviceType,
  ) async {
    final revisionId = _revisionId;
    final asset = node.asset;
    if (revisionId == null || asset == null || !_editMode) return;
    await _runMutation(
      () => _repo.updateAsset(
        revisionId: revisionId,
        expectedLockVersion: _lock,
        assetId: asset.id,
        serviceType: serviceType ?? '',
      ),
      focusNodeId: node.id,
    );
  }

  Future<void> _removeNodeFromView(
    UtilityRevisionNode node,
    String viewId,
  ) async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final placement = snapshot.placements
        .where((p) => p.viewId == viewId && p.nodeId == node.id)
        .firstOrNull;
    await _runMutation(
      () => _repo.removeAssetFromView(
        revisionId: snapshot.revision.id,
        expectedLockVersion: _lock,
        viewId: viewId,
        nodeId: node.id,
      ),
      undo: placement == null
          ? null
          : NetworkUndoRemoveFromView(viewId: viewId, placement: placement),
    );
    if (mounted) setState(() => _selectedNodeId = null);
  }

  Future<void> _removeNodeFromRevision(UtilityRevisionNode node) async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.networkDeleteNode),
        content: Text(s.networkDeleteNodeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.networkDeleteNode),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _runMutation(
      () => _repo.removeAssetFromRevision(
        revisionId: snapshot.revision.id,
        expectedLockVersion: _lock,
        nodeId: node.id,
      ),
    );
    if (mounted) setState(() => _selectedNodeId = null);
  }

  Future<ImageSource?> _chooseImageSource(AdminStrings s) async {
    final isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    if (isDesktop) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.networkPickFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(s.networkPickFromCamera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<XFile?> _pickImageFile(ImageSource source) async {
    final isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
    if (isDesktop) {
      const typeGroup = XTypeGroup(
        label: 'images',
        extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return null;
      return XFile(file.path, mimeType: file.mimeType);
    }
    return ImagePicker().pickImage(
      source: source,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 72,
      requestFullMetadata: false,
    );
  }

  Future<void> _pickAndSaveNodeImage(UtilityRevisionNode node) async {
    final snapshot = _snapshot;
    final asset = node.asset;
    if (snapshot == null || asset == null) return;
    final s = AdminStrings(ref.read(adminLocaleProvider));
    try {
      final source = await _chooseImageSource(s);
      if (source == null || !mounted) return;
      final picked = await _pickImageFile(source);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;
      final mime = (picked.mimeType ?? 'image/jpeg').split(';').first;
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      final props = Map<String, dynamic>.from(asset.properties)
        ..['image_url'] = dataUrl;
      await _runMutation(
        () => _repo.updateAsset(
          revisionId: snapshot.revision.id,
          expectedLockVersion: _lock,
          assetId: asset.id,
          properties: props,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.networkPickImageFailed}\n$e')),
      );
    }
  }

  Future<void> _clearNodeImage(UtilityRevisionNode node) async {
    final snapshot = _snapshot;
    final asset = node.asset;
    if (snapshot == null || asset == null) return;
    final props = Map<String, dynamic>.from(asset.properties)
      ..remove('image_url');
    await _runMutation(
      () => _repo.updateAsset(
        revisionId: snapshot.revision.id,
        expectedLockVersion: _lock,
        assetId: asset.id,
        properties: props,
      ),
    );
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty || _revisionId == null) return;
    final entry = _undoStack.removeLast();
    final revisionId = _revisionId!;
    final lock = _lock;
    final s = AdminStrings(ref.read(adminLocaleProvider));
    setState(() => _mutating = true);
    try {
      switch (entry) {
        case NetworkUndoMove(:final viewId, :final previous):
          await _repo.batchMoveViewNodes(
            revisionId: revisionId,
            expectedLockVersion: lock,
            viewId: viewId,
            positions: previous,
          );
        case NetworkUndoConnect(:final connectionId):
          if (connectionId.isNotEmpty) {
            await _repo.disconnectConnection(
              revisionId: revisionId,
              expectedLockVersion: lock,
              connectionId: connectionId,
            );
          }
        case NetworkUndoDisconnect(
          :final fromNodeId,
          :final fromPortId,
          :final toNodeId,
          :final toPortId,
          :final connectionKind,
          :final waterType,
          :final transportMode,
          :final operatingMode,
        ):
          await _repo.connectPorts(
            revisionId: revisionId,
            expectedLockVersion: lock,
            fromNodeId: fromNodeId,
            fromPortId: fromPortId,
            toNodeId: toNodeId,
            toPortId: toPortId,
            connectionKind: connectionKind,
            waterType: waterType,
            transportMode: transportMode,
            operatingMode: operatingMode,
          );
        case NetworkUndoRemoveFromView(:final viewId, :final placement):
          await _repo.batchMoveViewNodes(
            revisionId: revisionId,
            expectedLockVersion: lock,
            viewId: viewId,
            positions: [placement],
          );
      }
      _markAutoSaved();
      await _refreshKeepSelection();
    } catch (e) {
      _undoStack.add(entry);
      _showMutationError(e, s);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _approveChanges() async {
    final revisionId = _revisionId;
    if (revisionId == null) return;
    final s = AdminStrings(ref.read(adminLocaleProvider));
    setState(() => _mutating = true);
    try {
      final result = await _repo.validateDraft(revisionId);
      if (!mounted) return;
      setState(() {
        _sideErrors = List<NetworkValidationIssue>.from(result.errors);
        _sideWarnings = List<NetworkValidationIssue>.from(result.warnings);
      });
      if (!result.ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.networkValidationErrors)));
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.networkApproveChanges),
          content: Text(s.networkPublishConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.networkApproveChanges),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await _repo.publishDraft(
        revisionId: revisionId,
        expectedLockVersion: _lock,
        allowWarnings: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.networkPublishDone)));
      _undoStack.clear();
      final id = _networkId;
      if (id != null) await _loadDraft(id);
    } catch (e) {
      setState(() {
        _sideErrors = [
          NetworkValidationIssue(
            code: 'publish_error',
            message: '${_arabicError(e, s)} · ${_errorDetail(e)}',
            severity: UtilityValidationSeverity.error,
          ),
        ];
      });
      _showMutationError(e, s);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _pickExistingMeter(String siteId) async {
    final snapshot = _snapshot;
    final networkId = _networkId;
    final viewId = _selectedViewId;
    final revisionId = _revisionId;
    if (snapshot == null ||
        networkId == null ||
        viewId == null ||
        revisionId == null) {
      return;
    }
    // Position is already captured in _pendingDropPos (or cascade).
    final pos = _addPos();
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final pickedRow = await showDialog<_PickerRow>(
      context: context,
      builder: (context) => _SearchPickerDialog(
        strings: s,
        title: s.networkMeterPicker,
        load: (search) async {
          final list = await _repo.listAvailableMeters(
            networkId: networkId,
            revisionId: revisionId,
            viewId: viewId,
            siteId: siteId,
            search: search,
          );
          return [
            for (final m in list)
              _PickerRow(
                id: m.meterId,
                title: '${m.code} · ${s.isAr ? m.nameAr : m.nameEn}',
                state: m.state,
                revisionNodeId: m.revisionNodeId,
                raw: m,
              ),
          ];
        },
      ),
    );
    if (pickedRow == null || !mounted) return;
    final picked = pickedRow.raw as AvailableNetworkMeter;
    if (picked.state.dbValue == AvailableMeterState.inCurrentView.dbValue) {
      final nodeId = picked.revisionNodeId;
      if (nodeId != null) {
        setState(() => _selectedNodeId = nodeId);
        _canvasKey.currentState?.focusNode(nodeId);
      }
      return;
    }
    final result = await _runMutation(
      () => _repo.attachExistingMeter(
        revisionId: revisionId,
        expectedLockVersion: _lock,
        meterId: picked.meterId,
        viewId: viewId,
        posX: pos.dx,
        posY: pos.dy,
        replaceExistingParent: false,
      ),
      focusNodeId: null,
    );
    final nodeId = result?.nodeId;
    if (nodeId != null && mounted) {
      setState(() => _selectedNodeId = nodeId);
      _canvasKey.currentState?.focusNode(nodeId);
    }
  }

  Future<void> _createNewMeter(String siteId, String categoryId) async {
    final viewId = _selectedViewId;
    final revisionId = _revisionId;
    if (viewId == null || revisionId == null) return;
    final pos = _addPos();
    // Same full form as Meters tab — created meter syncs both ways.
    final created = await Navigator.of(context).push<Meter>(
      MaterialPageRoute(
        builder: (_) =>
            MeterFormScreen(siteId: siteId, initialCategoryId: categoryId),
      ),
    );
    if (created == null || !mounted) return;
    ref.invalidate(adminMetersProvider);
    final result = await _runMutation(
      () => _repo.attachExistingMeter(
        revisionId: revisionId,
        expectedLockVersion: _lock,
        meterId: created.id,
        viewId: viewId,
        posX: pos.dx,
        posY: pos.dy,
        replaceExistingParent: false,
      ),
      focusNodeId: null,
    );
    final nodeId = result?.nodeId;
    await _syncMeterServiceType(
      assetId: result?.assetId,
      nodeId: nodeId,
      sourceCode: created.sourceConfig?.code ?? created.source.dbValue,
    );
    if (nodeId != null && mounted) {
      setState(() => _selectedNodeId = nodeId);
      _canvasKey.currentState?.focusNode(nodeId);
    }
    // Allow a later sync pass to pick up any other meters created elsewhere.
    _didSyncMetersForDraft = false;
  }

  Future<void> _pickExistingTank(String siteId) async {
    final networkId = _networkId;
    final viewId = _selectedViewId;
    final revisionId = _revisionId;
    if (networkId == null || viewId == null || revisionId == null) return;
    final pos = _addPos();
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final pickedRow = await showDialog<_PickerRow>(
      context: context,
      builder: (context) => _SearchPickerDialog(
        strings: s,
        title: s.networkTankPicker,
        load: (search) async {
          final list = await _repo.listAvailableTanks(
            networkId: networkId,
            revisionId: revisionId,
            viewId: viewId,
            siteId: siteId,
            search: search,
          );
          return [
            for (final t in list)
              _PickerRow(
                id: t.tankId,
                title: s.isAr ? t.nameAr : t.nameEn,
                state: t.state,
                revisionNodeId: t.revisionNodeId,
                raw: t,
              ),
          ];
        },
      ),
    );
    if (pickedRow == null || !mounted) return;
    final picked = pickedRow.raw as AvailableNetworkTank;
    if (picked.state.dbValue == AvailableMeterState.inCurrentView.dbValue) {
      final nodeId = picked.revisionNodeId;
      if (nodeId != null) {
        setState(() => _selectedNodeId = nodeId);
        _canvasKey.currentState?.focusNode(nodeId);
      }
      return;
    }
    final result = await _runMutation(
      () => _repo.attachExistingTank(
        revisionId: revisionId,
        expectedLockVersion: _lock,
        tankId: picked.tankId,
        viewId: viewId,
        posX: pos.dx,
        posY: pos.dy,
      ),
    );
    final nodeId = result?.nodeId;
    if (nodeId != null && mounted) {
      setState(() => _selectedNodeId = nodeId);
      _canvasKey.currentState?.focusNode(nodeId);
    }
  }

  Future<void> _createNewTank(String siteId) async {
    final revisionId = _revisionId;
    final viewId = _selectedViewId;
    if (revisionId == null || viewId == null) return;
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final pos = _addPos();
    final draftNameEn = 'New tank $stamp';
    final draftNameAr = 'خزان جديد $stamp';
    final draftCode = 'TANK-DRAFT-$stamp';
    final result = await _runMutation(
      () => _repo.createTankInDraft(
        revisionId: revisionId,
        expectedLockVersion: _lock,
        siteId: siteId,
        nameEn: draftNameEn,
        nameAr: draftNameAr,
        code: draftCode,
        viewId: viewId,
        posX: pos.dx,
        posY: pos.dy,
      ),
    );
    if (result == null || !mounted) return;
    final assetId = result.assetId;
    final nodeId = result.nodeId;
    if (assetId != null) {
      try {
        await _repo.updateAsset(
          revisionId: revisionId,
          expectedLockVersion: _lock,
          assetId: assetId,
          properties: const {'draft': true},
        );
        await _refreshKeepSelection(focusNodeId: nodeId);
      } catch (_) {}
    }
    if (nodeId != null && mounted) {
      setState(() => _selectedNodeId = nodeId);
      _canvasKey.currentState?.focusNode(nodeId);
    }
    if (!mounted) return;
    final form = await showDialog<_NamedAssetForm>(
      context: context,
      builder: (context) => _NamedAssetDialog(
        strings: s,
        title: s.networkAddNewTank,
        requireCode: false,
        initialCode: draftCode,
        initialNameEn: draftNameEn,
        initialNameAr: draftNameAr,
      ),
    );
    if (form == null || !mounted || assetId == null) return;
    await _runMutation(
      () => _repo.updateAsset(
        revisionId: _revisionId!,
        expectedLockVersion: _lock,
        assetId: assetId,
        code: form.code,
        nameEn: form.nameEn,
        nameAr: form.nameAr,
        properties: const {'draft': false},
      ),
      focusNodeId: nodeId,
    );
  }

  Future<void> _createGeneric(String siteId, String assetType) async {
    final revisionId = _revisionId;
    final viewId = _selectedViewId;
    if (revisionId == null || viewId == null) return;
    final s = AdminStrings(ref.read(adminLocaleProvider));
    final title = switch (assetType) {
      'external_source' => s.networkAddWaterSource,
      'pump' => s.networkAddPump,
      'filter' => s.networkAddFilter,
      'treatment_unit' => s.networkAddRo,
      'cooling_tower' => s.networkAddCoolingTower,
      'chiller' => s.networkAddChiller,
      'building_portal' => s.networkAddBuildingPortal,
      'junction' => s.networkAddJunction,
      'consumer' => s.networkAddConsumer,
      'discharge_point' => s.networkAddGroundDrain,
      'tanker_loading' => s.networkAddTankerLoading,
      _ => assetType,
    };
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final pos = _addPos();
    final draftCode = '$assetType-$stamp';
    final draftNameEn = 'New $assetType';
    final draftNameAr = title;
    final result = await _runMutation(
      () => _repo.createGenericAsset(
        revisionId: revisionId,
        expectedLockVersion: _lock,
        siteId: siteId,
        assetType: assetType,
        code: draftCode,
        nameEn: draftNameEn,
        nameAr: draftNameAr,
        properties: const {'draft': true},
        viewId: viewId,
        posX: pos.dx,
        posY: pos.dy,
      ),
    );
    if (result == null || !mounted) return;
    final assetId = result.assetId;
    final nodeId = result.nodeId;
    if (nodeId != null && mounted) {
      setState(() => _selectedNodeId = nodeId);
      _canvasKey.currentState?.focusNode(nodeId);
    }
    if (!mounted) return;
    final form = await showDialog<_NamedAssetForm>(
      context: context,
      builder: (context) => _NamedAssetDialog(
        strings: s,
        title: title,
        requireCode: true,
        initialCode: draftCode,
        initialNameEn: draftNameEn,
        initialNameAr: draftNameAr,
      ),
    );
    if (form == null || !mounted || assetId == null) return;
    await _runMutation(
      () => _repo.updateAsset(
        revisionId: _revisionId!,
        expectedLockVersion: _lock,
        assetId: assetId,
        code: form.code ?? draftCode,
        nameEn: form.nameEn,
        nameAr: form.nameAr,
        properties: const {'draft': false},
      ),
      focusNodeId: nodeId,
    );
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _autoSavedHide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final canManage = ref.watch(canManageMetersProvider);
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final selectedSiteId = ref.watch(selectedAdminSiteIdProvider);
    final isAr = ref.watch(adminLocaleProvider).languageCode == 'ar';

    // Meters tab create/edit → place newly added meters (not a full re-sync).
    ref.listen(adminMetersProvider, (previous, next) {
      if (_snapshot == null || !canManage || _movesBusy) return;
      next.whenData((meters) {
        final prevCount = previous?.asData?.value.length;
        // Only react when the meter list grows (new meter created elsewhere).
        if (prevCount != null && meters.length <= prevCount) return;
        _didSyncMetersForDraft = false;
        _ensureAllMetersOnView(force: true);
      });
    });

    if (selectedSiteId == null) {
      return Center(child: Text(s.networkSelectSite));
    }

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _LoadErrorPane(
        message: '${s.networkLoadFailed}\n${_errorDetail(e)}',
        retryLabel: s.networkRetry,
        onRetry: () => ref.invalidate(catalogCategoriesProvider),
      ),
      data: (categories) {
        final categoryId = _waterCategoryId(categories);
        if (categoryId == null) {
          return Center(child: Text(s.networkNoWaterCategory));
        }
        if (_siteId != selectedSiteId || _categoryId != categoryId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _resolveAndLoad(selectedSiteId, categoryId);
          });
        }
        return _buildEditor(
          siteId: selectedSiteId,
          categoryId: categoryId,
          canManage: canManage,
          isAr: isAr,
          s: s,
        );
      },
    );
  }

  Widget _buildEditor({
    required String siteId,
    required String categoryId,
    required bool canManage,
    required bool isAr,
    required AdminStrings s,
  }) {
    final state = networkV2StateFor(
      hasSite: true,
      loading: _loading || _resolving,
      hasNetwork: _networkId != null,
      snapshot: _snapshot,
      error: _loadError,
      importing: _importing,
      previewing: _previewing,
      hasLegacyGraph: _hasLegacyImport,
    );
    final mode = networkEditorModeFor(editDraft: _editMode);

    if (state == NetworkV2ScreenState.loading ||
        state == NetworkV2ScreenState.importing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state == NetworkV2ScreenState.noNetwork) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.networkEmpty),
            if (canManage) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _createWaterNetwork(siteId, categoryId),
                child: Text(s.networkCreateWater),
              ),
            ],
          ],
        ),
      );
    }
    if (state == NetworkV2ScreenState.networkWithoutDraft) {
      return Center(child: Text(s.networkNoDraft));
    }
    if (state == NetworkV2ScreenState.permissionDenied) {
      return Center(child: Text(s.networkPermissionDenied));
    }
    if (state == NetworkV2ScreenState.versionConflict ||
        state == NetworkV2ScreenState.error) {
      return _LoadErrorPane(
        message:
            '${_arabicError(_loadError ?? 'error', s)}\n'
            '${_errorDetail(_loadError ?? 'error')}',
        retryLabel: s.networkRetry,
        onRetry: () {
          final id = _networkId;
          if (id != null) {
            _loadDraft(id);
          } else {
            _resolveAndLoad(siteId, categoryId);
          }
        },
      );
    }

    final snapshot = _snapshot;
    final viewId = _selectedViewId;
    final showImport =
        state == NetworkV2ScreenState.emptyDraft ||
        state == NetworkV2ScreenState.importAvailable ||
        state == NetworkV2ScreenState.importPreview;

    final sites = ref.watch(adminSitesProvider).valueOrNull ?? const [];
    final siteName = sites
        .where((site) => site.id == siteId)
        .map((site) => isAr ? site.nameAr : site.nameEn)
        .firstOrNull;

    final compact = networkEditorIsCompact(context);
    return Padding(
      padding: EdgeInsets.all(compact ? 8 : 12),
      child: Column(
        children: [
          _HeaderBar(
            strings: s,
            siteName: siteName,
            sites: sites,
            selectedSiteId: siteId,
            onSiteChanged: (id) =>
                ref.read(selectedAdminSiteIdProvider.notifier).state = id,
            mode: mode,
            editMode: _editMode,
            canManage: canManage,
            mutating: _mutating,
            canUndo: _undoStack.isNotEmpty && !_mutating,
            autoSaved: _autoSaved,
            onModeChanged: (edit) => setState(() => _editMode = edit),
            onUndo: _undo,
            onApprove: _approveChanges,
          ),
          if (showImport && canManage)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state == NetworkV2ScreenState.importAvailable
                          ? s.networkImportAvailable
                          : s.networkDraftEmpty,
                    ),
                  ),
                  TextButton(
                    onPressed: _previewing || _importing
                        ? null
                        : () => _importLegacy(siteId, categoryId),
                    child: Text(s.networkImportPreview),
                  ),
                ],
              ),
            ),
          if (_sideErrors.isNotEmpty || _sideWarnings.isNotEmpty)
            _SideIssueList(
              strings: s,
              errors: _sideErrors,
              warnings: _sideWarnings,
            ),
          const SizedBox(height: 8),
          Expanded(
            child: snapshot == null || viewId == null
                ? Center(child: Text(s.networkDraftEmpty))
                : _buildWorkspace(
                    snapshot: snapshot,
                    viewId: viewId,
                    canManage: canManage,
                    isAr: isAr,
                    s: s,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspace({
    required UtilityNetworkSnapshot snapshot,
    required String viewId,
    required bool canManage,
    required bool isAr,
    required AdminStrings s,
  }) {
    final details = _DetailsPanel(
      snapshot: snapshot,
      selectedNodeId: _selectedNodeId,
      selectedConnectionId: _selectedConnectionId,
      isArabic: isAr,
      strings: s,
      editMode: _editMode,
      onSaveConnection: _editMode
          ? (c, kind, waterType, transport, operating) async {
              await _runMutation(
                () => _repo.updateConnection(
                  revisionId: snapshot.revision.id,
                  expectedLockVersion: _lock,
                  connectionId: c.id,
                  connectionKind: kind,
                  waterType: waterType,
                  transportMode: transport,
                  operatingMode: operating,
                  allowBreakLegacySync: true,
                ),
              );
            }
          : null,
      onDisconnect: _editMode
          ? (c) async {
              await _runMutation(
                () => _repo.disconnectConnection(
                  revisionId: snapshot.revision.id,
                  expectedLockVersion: _lock,
                  connectionId: c.id,
                ),
                undo: NetworkUndoDisconnect(
                  fromNodeId: c.fromNodeId,
                  fromPortId: c.fromPortId,
                  toNodeId: c.toNodeId,
                  toPortId: c.toPortId,
                  connectionKind: c.connectionKind.dbValue,
                  waterType: c.waterType,
                  transportMode: c.transportMode.dbValue,
                  operatingMode: c.operatingMode.dbValue,
                ),
              );
              setState(() => _selectedConnectionId = null);
            }
          : null,
      onRemoveFromView: _editMode
          ? (node) => _removeNodeFromView(node, viewId)
          : null,
      onDeleteNode: _editMode ? _removeNodeFromRevision : null,
      onPickNodeImage: _editMode ? _pickAndSaveNodeImage : null,
      onClearNodeImage: _editMode ? _clearNodeImage : null,
      onAddInlet: _editMode
          ? (node) => _addAssetPort(node, direction: 'in')
          : null,
      onAddOutlet: _editMode
          ? (node) => _addAssetPort(node, direction: 'out')
          : null,
      onRemovePort: _editMode ? _removeAssetPort : null,
      onSaveServiceType: _editMode ? _saveAssetServiceType : null,
    );
    final canvas = UtilityNetworkCanvas(
      key: _canvasKey,
      snapshot: snapshot,
      viewId: viewId,
      isArabic: isAr,
      selectedNodeId: _selectedNodeId,
      selectedConnectionId: _selectedConnectionId,
      editMode: _editMode,
      showPorts: _editMode,
      lockInteraction: _paletteDragging,
      onNodeTap: (n) => setState(() {
        _selectedNodeId = n.id;
        _selectedConnectionId = null;
      }),
      onConnectionTap: (c) => setState(() {
        _selectedConnectionId = c.id;
        _selectedNodeId = null;
      }),
      onNodeMoved: _editMode ? _onNodeMoved : null,
      onConnectPorts: _editMode ? _onConnectPorts : null,
    );
    final dropCanvas = _editMode && canManage
        ? DragTarget<String>(
            onWillAcceptWithDetails: (details) => !_mutating,
            onAcceptWithDetails: (details) {
              // Prefer pointer position; fall back to feedback top-left.
              final global = details.offset;
              final world =
                  _canvasKey.currentState?.globalToWorld(global) ??
                  _nextAddPos();
              // Center the card under the drop point.
              final dropAt = Offset(
                world.dx - kUtilityNetworkNodeWidth / 2,
                world.dy - kUtilityNetworkNodeHeight / 2,
              );
              _addPaletteItem(details.data, dropAt: dropAt);
            },
            builder: (context, candidate, rejected) {
              final highlight = candidate.isNotEmpty;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: highlight
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: canvas,
              );
            },
          )
        : canvas;
    final addRail = _editMode && canManage
        ? _AddRail(
            strings: s,
            enabled: !_mutating,
            onAdd: (kind) => _addPaletteItem(kind),
            compact: true,
            onDragActive: (active) {
              if (_paletteDragging != active) {
                setState(() => _paletteDragging = active);
              }
            },
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Prefer MediaQuery — LayoutBuilder can report a misleading width in
        // some IndexedStack/body combinations on phones.
        final compact = networkEditorIsCompact(context);
        final hasSelection =
            _selectedNodeId != null || _selectedConnectionId != null;

        if (compact) {
          // Portrait stack: canvas on top, vertical add grid, then details.
          // Shrink chrome when the viewport is short so the Column never overflows.
          final showPalette = _editMode && canManage;
          final showDetails = hasSelection;
          final available = constraints.maxHeight;
          var paletteH = showPalette ? 148.0 : 0.0;
          var detailsH = showDetails
              ? math.min(220.0, math.max(150.0, available * 0.28))
              : 0.0;
          const detailsGap = 6.0;
          final minCanvas = math.max(180.0, available * 0.38);
          var chrome = paletteH + detailsH + (showDetails ? detailsGap : 0.0);
          if (available - chrome < minCanvas) {
            var deficit = minCanvas - (available - chrome);
            if (showDetails) {
              final cut = math.min(deficit, math.max(0.0, detailsH - 112.0));
              detailsH -= cut;
              deficit -= cut;
            }
            if (deficit > 0 && showPalette) {
              final cut = math.min(deficit, math.max(0.0, paletteH - 100.0));
              paletteH -= cut;
            }
          }
          return Column(
            children: [
              Expanded(child: dropCanvas),
              if (showPalette)
                SizedBox(
                  height: paletteH,
                  width: double.infinity,
                  child: _VerticalAddRail(
                    strings: s,
                    enabled: !_mutating,
                    onAdd: (kind) => _addPaletteItem(kind),
                    onDragActive: (active) {
                      if (_paletteDragging != active) {
                        setState(() => _paletteDragging = active);
                      }
                    },
                  ),
                ),
              if (showDetails) ...[
                const SizedBox(height: detailsGap),
                SizedBox(
                  height: detailsH,
                  width: double.infinity,
                  child: details,
                ),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: dropCanvas),
            const SizedBox(width: 8),
            SizedBox(width: 260, child: details),
            if (addRail != null) ...[
              const SizedBox(width: 8),
              SizedBox(width: 100, child: addRail),
            ],
          ],
        );
      },
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.strings,
    required this.siteName,
    required this.sites,
    required this.selectedSiteId,
    required this.onSiteChanged,
    required this.mode,
    required this.editMode,
    required this.canManage,
    required this.mutating,
    required this.canUndo,
    required this.autoSaved,
    required this.onModeChanged,
    required this.onUndo,
    required this.onApprove,
  });

  final AdminStrings strings;
  final String? siteName;
  final List<Site> sites;
  final String selectedSiteId;
  final ValueChanged<String> onSiteChanged;
  final NetworkEditorMode mode;
  final bool editMode;
  final bool canManage;
  final bool mutating;
  final bool canUndo;
  final bool autoSaved;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onUndo;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final compact = networkEditorIsCompact(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.hub_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.networkWaterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (autoSaved)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Colors.green.shade600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _SiteSelector(
          strings: s,
          sites: sites,
          selectedSiteId: selectedSiteId,
          siteName: siteName,
          onSiteChanged: onSiteChanged,
        ),
        const SizedBox(height: 8),
        if (mode == NetworkEditorMode.edit)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: mutating ? null : onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      s.networkApproveChanges,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: OutlinedButton.icon(
                    onPressed: canUndo ? onUndo : null,
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(
                      s.networkUndo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: SegmentedButton<bool>(
              showSelectedIcon: !compact,
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(s.networkModeView),
                  icon: compact ? const Icon(Icons.visibility_outlined) : null,
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    compact ? s.networkModeEditShort : s.networkModeEdit,
                  ),
                  icon: compact ? const Icon(Icons.edit_outlined) : null,
                  enabled: canManage,
                ),
              ],
              selected: {editMode},
              onSelectionChanged: (v) => onModeChanged(v.first),
            ),
          ),
        ),
      ],
    );
  }
}

class _SiteSelector extends StatelessWidget {
  const _SiteSelector({
    required this.strings,
    required this.sites,
    required this.selectedSiteId,
    required this.siteName,
    required this.onSiteChanged,
  });

  final AdminStrings strings;
  final List<Site> sites;
  final String selectedSiteId;
  final String? siteName;
  final ValueChanged<String> onSiteChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = siteName ?? strings.networkSelectSite;
    return PopupMenuButton<String>(
      tooltip: strings.networkSelectSite,
      enabled: sites.isNotEmpty,
      initialValue: selectedSiteId,
      onSelected: (id) {
        if (id != selectedSiteId) onSiteChanged(id);
      },
      itemBuilder: (context) => [
        for (final site in sites)
          PopupMenuItem(
            value: site.id,
            child: Text(
              strings.isAr ? site.nameAr : site.nameEn,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.apartment, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorPane extends StatelessWidget {
  const _LoadErrorPane({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

class _SideIssueList extends StatelessWidget {
  const _SideIssueList({
    required this.strings,
    required this.errors,
    required this.warnings,
  });
  final AdminStrings strings;
  final List<NetworkValidationIssue> errors;
  final List<NetworkValidationIssue> warnings;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 120),
        child: ListView(
          shrinkWrap: true,
          children: [
            if (errors.isNotEmpty)
              Text(
                strings.networkValidationErrors,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            for (final e in errors.take(8))
              Text(
                '· ${e.message}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (warnings.isNotEmpty)
              Text(
                strings.networkValidationWarnings,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            for (final w in warnings.take(8))
              Text(
                '· ${w.message}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

bool _networkPaletteUsesImmediateDrag(BuildContext context) {
  // Desktop: immediate drag (no long-press) so zoomed canvas drops still work.
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

Widget _paletteItemDraggable({
  required BuildContext context,
  required String data,
  required bool enabled,
  required Widget feedback,
  required Widget childWhenDragging,
  required Widget child,
  ValueChanged<bool>? onDragActive,
}) {
  if (!enabled) return child;
  void setActive(bool active) => onDragActive?.call(active);
  if (_networkPaletteUsesImmediateDrag(context)) {
    return Draggable<String>(
      data: data,
      feedback: feedback,
      childWhenDragging: childWhenDragging,
      maxSimultaneousDrags: 1,
      onDragStarted: () => setActive(true),
      onDragEnd: (_) => setActive(false),
      onDraggableCanceled: (_, _) => setActive(false),
      child: child,
    );
  }
  return LongPressDraggable<String>(
    data: data,
    feedback: feedback,
    childWhenDragging: childWhenDragging,
    maxSimultaneousDrags: 1,
    onDragStarted: () => setActive(true),
    onDragEnd: (_) => setActive(false),
    onDraggableCanceled: (_, _) => setActive(false),
    child: child,
  );
}

List<(String, String, IconData)> _networkPaletteItems(AdminStrings s) => [
  ('existing_meter', s.networkAddExistingMeter, Icons.speed),
  ('new_meter', s.networkAddNewMeter, Icons.add_circle_outline),
  ('existing_tank', s.networkAddExistingTank, Icons.water_drop_outlined),
  ('new_tank', s.networkAddNewTank, Icons.water_drop),
  ('external_source', s.networkAddWaterSource, Icons.waves),
  ('pump', s.networkAddPump, Icons.settings),
  ('filter', s.networkAddFilter, Icons.filter_alt),
  ('treatment_unit', s.networkAddRo, Icons.science),
  ('cooling_tower', s.networkAddCoolingTower, Icons.cottage_outlined),
  ('chiller', s.networkAddChiller, Icons.ac_unit),
  ('building_portal', s.networkAddBuildingPortal, Icons.apartment),
  ('junction', s.networkAddJunction, Icons.hub),
  ('consumer', s.networkAddConsumer, Icons.home),
  ('discharge_point', s.networkAddGroundDrain, Icons.vertical_align_bottom),
  ('tanker_loading', s.networkAddTankerLoading, Icons.local_shipping),
];

Widget _paletteDragFeedback({
  required IconData icon,
  required String label,
  required ColorScheme scheme,
}) {
  return Material(
    elevation: 6,
    borderRadius: BorderRadius.circular(10),
    color: scheme.primaryContainer,
    child: SizedBox(
      width: 88,
      height: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: scheme.onPrimaryContainer),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: scheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AddRail extends StatelessWidget {
  const _AddRail({
    required this.strings,
    required this.enabled,
    required this.onAdd,
    this.compact = false,
    this.onDragActive,
  });
  final AdminStrings strings;
  final bool enabled;
  final ValueChanged<String> onAdd;
  final bool compact;
  final ValueChanged<bool>? onDragActive;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final items = _networkPaletteItems(s);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              s.networkAddElement,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          for (final item in items)
            _paletteItemDraggable(
              context: context,
              data: item.$1,
              enabled: enabled,
              onDragActive: onDragActive,
              feedback: _paletteDragFeedback(
                icon: item.$3,
                label: item.$2,
                scheme: scheme,
              ),
              childWhenDragging: Opacity(
                opacity: 0.35,
                child: _AddRailTile(
                  icon: item.$3,
                  label: item.$2,
                  compact: compact,
                  onTap: null,
                ),
              ),
              child: _AddRailTile(
                icon: item.$3,
                label: item.$2,
                compact: compact,
                onTap: enabled ? () => onAdd(item.$1) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddRailTile extends StatelessWidget {
  const _AddRailTile({
    required this.icon,
    required this.label,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8, horizontal: 4),
        child: Column(
          children: [
            Icon(icon, size: compact ? 20 : 22),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontSize: compact ? 9 : null),
            ),
          ],
        ),
      ),
    );
  }
}

/// Portrait-friendly add palette: wraps top-to-bottom in a vertical grid.
class _VerticalAddRail extends StatelessWidget {
  const _VerticalAddRail({
    required this.strings,
    required this.enabled,
    required this.onAdd,
    this.onDragActive,
  });
  final AdminStrings strings;
  final bool enabled;
  final ValueChanged<String> onAdd;
  final ValueChanged<bool>? onDragActive;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final items = _networkPaletteItems(s);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
            child: Text(
              '${s.networkAddElement} · ${s.isAr ? 'اسحب إلى الشبكة أو اضغط' : 'Drag onto canvas or tap'}',
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
              scrollDirection: Axis.vertical,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.05,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _paletteItemDraggable(
                  context: context,
                  data: item.$1,
                  enabled: enabled,
                  onDragActive: onDragActive,
                  feedback: _paletteDragFeedback(
                    icon: item.$3,
                    label: item.$2,
                    scheme: scheme,
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: _VerticalAddTile(
                      icon: item.$3,
                      label: item.$2,
                      onTap: null,
                    ),
                  ),
                  child: _VerticalAddTile(
                    icon: item.$3,
                    label: item.$2,
                    onTap: enabled ? () => onAdd(item.$1) : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalAddTile extends StatelessWidget {
  const _VerticalAddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontSize: 9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsPanel extends StatefulWidget {
  const _DetailsPanel({
    required this.snapshot,
    required this.selectedNodeId,
    required this.selectedConnectionId,
    required this.isArabic,
    required this.strings,
    required this.editMode,
    this.onSaveConnection,
    this.onDisconnect,
    this.onRemoveFromView,
    this.onDeleteNode,
    this.onPickNodeImage,
    this.onClearNodeImage,
    this.onAddInlet,
    this.onAddOutlet,
    this.onRemovePort,
    this.onSaveServiceType,
  });

  final UtilityNetworkSnapshot snapshot;
  final String? selectedNodeId;
  final String? selectedConnectionId;
  final bool isArabic;
  final AdminStrings strings;
  final bool editMode;
  final Future<void> Function(
    UtilityConnection connection,
    String kind,
    String? waterType,
    String transport,
    String operating,
  )?
  onSaveConnection;
  final Future<void> Function(UtilityConnection connection)? onDisconnect;
  final Future<void> Function(UtilityRevisionNode node)? onRemoveFromView;
  final Future<void> Function(UtilityRevisionNode node)? onDeleteNode;
  final Future<void> Function(UtilityRevisionNode node)? onPickNodeImage;
  final Future<void> Function(UtilityRevisionNode node)? onClearNodeImage;
  final Future<void> Function(UtilityRevisionNode node)? onAddInlet;
  final Future<void> Function(UtilityRevisionNode node)? onAddOutlet;
  final Future<void> Function(UtilityRevisionNode node, UtilityAssetPort port)?
  onRemovePort;
  final Future<void> Function(UtilityRevisionNode node, String? serviceType)?
  onSaveServiceType;

  @override
  State<_DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<_DetailsPanel> {
  String? _kind;
  String? _waterType;
  String? _transport;
  String? _operating;
  String? _boundConnectionId;
  String? _serviceType;
  String? _boundAssetId;

  void _syncFromConnection(UtilityConnection? connection) {
    if (connection == null) {
      _boundConnectionId = null;
      return;
    }
    if (_boundConnectionId == connection.id) return;
    _boundConnectionId = connection.id;
    _kind = connection.connectionKind.dbValue;
    _waterType = connection.waterType;
    _transport = connection.transportMode.dbValue;
    _operating = connection.operatingMode.dbValue;
  }

  void _syncFromAsset(UtilityAsset? asset) {
    if (asset == null) {
      _boundAssetId = null;
      return;
    }
    if (_boundAssetId == asset.id) return;
    _boundAssetId = asset.id;
    _serviceType = asset.serviceType?.dbValue;
  }

  String _nodeLabel(String nodeId) {
    final node = widget.snapshot.nodes.where((n) => n.id == nodeId).firstOrNull;
    final asset = node?.asset;
    if (asset == null) return nodeId;
    final name = widget.isArabic ? asset.nameAr : asset.nameEn;
    return '${asset.code} · $name';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final node = widget.selectedNodeId == null
        ? null
        : widget.snapshot.nodes
              .where((n) => n.id == widget.selectedNodeId)
              .firstOrNull;
    final connection = widget.selectedConnectionId == null
        ? null
        : widget.snapshot.connections
              .where((c) => c.id == widget.selectedConnectionId)
              .firstOrNull;
    _syncFromConnection(connection);

    Widget body;
    if (connection != null) {
      body = ListView(
        children: [
          Text(
            s.networkConnectionProps,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${s.networkInputs}: ${_nodeLabel(connection.fromNodeId)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${s.networkOutputs}: ${_nodeLabel(connection.toNodeId)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final kindOptions = networkDropdownOptions(
                kNetworkConnectionKinds,
                current: _kind,
              );
              return DropdownButtonFormField<String>(
                key: ValueKey('conn-kind-${connection.id}'),
                initialValue: _kind,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.networkConnectionKind),
                items: [
                  for (final k in kindOptions)
                    DropdownMenuItem(
                      value: k,
                      child: dropdownItemText(
                        networkConnectionKindLabel(
                          k,
                          isArabic: widget.isArabic,
                        ),
                      ),
                    ),
                ],
                onChanged: widget.editMode
                    ? (v) => setState(() => _kind = v)
                    : null,
              );
            },
          ),
          Builder(
            builder: (context) {
              // Keep the current value selectable even if it is not part of
              // the standard list (prevents the DropdownButton assertion).
              final options = networkDropdownOptions(
                kNetworkWaterTypes,
                current: _waterType,
              );
              return DropdownButtonFormField<String?>(
                key: ValueKey('conn-water-${connection.id}'),
                initialValue: _waterType,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.networkWaterType),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: dropdownItemText(s.networkNone),
                  ),
                  for (final w in options)
                    DropdownMenuItem(
                      value: w,
                      child: dropdownItemText(
                        networkWaterTypeLabel(w, isArabic: widget.isArabic),
                      ),
                    ),
                ],
                onChanged: widget.editMode
                    ? (v) => setState(() => _waterType = v)
                    : null,
              );
            },
          ),
          Builder(
            builder: (context) {
              final transport = _transport ?? 'pipe';
              final options = networkDropdownOptions(
                kNetworkTransportModes,
                current: transport,
              );
              return DropdownButtonFormField<String>(
                key: ValueKey('conn-transport-${connection.id}'),
                initialValue: transport,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.networkTransportMode),
                items: [
                  for (final t in options)
                    DropdownMenuItem(
                      value: t,
                      child: dropdownItemText(
                        networkTransportModeLabel(t, isArabic: widget.isArabic),
                      ),
                    ),
                ],
                onChanged: widget.editMode
                    ? (v) => setState(() => _transport = v)
                    : null,
              );
            },
          ),
          Builder(
            builder: (context) {
              final operating = _operating ?? 'normal';
              final options = networkDropdownOptions(
                kNetworkOperatingModes,
                current: operating,
              );
              return DropdownButtonFormField<String>(
                key: ValueKey('conn-operating-${connection.id}'),
                initialValue: operating,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.networkOperatingMode),
                items: [
                  for (final o in options)
                    DropdownMenuItem(
                      value: o,
                      child: dropdownItemText(
                        networkOperatingModeLabel(o, isArabic: widget.isArabic),
                      ),
                    ),
                ],
                onChanged: widget.editMode
                    ? (v) => setState(() => _operating = v)
                    : null,
              );
            },
          ),
          if (widget.editMode && widget.onSaveConnection != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => widget.onSaveConnection!(
                connection,
                _kind ?? connection.connectionKind.dbValue,
                _waterType,
                _transport ?? connection.transportMode.dbValue,
                _operating ?? connection.operatingMode.dbValue,
              ),
              child: Text(s.networkSaveConnection),
            ),
          ],
          if (widget.editMode && widget.onDisconnect != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => widget.onDisconnect!(connection),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(s.networkDeleteConnection),
            ),
          ],
        ],
      );
    } else if (node?.asset == null) {
      body = Center(child: Text(s.networkElementDetails));
    } else {
      final asset = node!.asset!;
      _syncFromAsset(asset);
      final inlets = asset.ports
          .where((p) => p.direction.dbValue != 'out')
          .toList();
      final outlets = asset.ports
          .where((p) => p.direction.dbValue == 'out')
          .toList();
      final inbound = widget.snapshot.connections
          .where((c) => c.toNodeId == node.id)
          .toList();
      final outbound = widget.snapshot.connections
          .where((c) => c.fromNodeId == node.id)
          .toList();
      body = ListView(
        children: [
          Text(
            s.networkElementDetails,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isArabic ? asset.nameAr : asset.nameEn,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${s.code}: ${asset.code}'),
          Text('${s.networkBuildingArea}: ${asset.assetType.dbValue}'),
          const SizedBox(height: 12),
          Text(
            s.networkServiceType,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final options = networkDropdownOptions(
                kNetworkWaterTypes,
                current: _serviceType,
              );
              return DropdownButtonFormField<String?>(
                key: ValueKey('asset-service-${asset.id}'),
                initialValue: _serviceType,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.networkServiceType),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: dropdownItemText(s.networkNone),
                  ),
                  for (final w in options)
                    DropdownMenuItem(
                      value: w,
                      child: dropdownItemText(
                        networkWaterTypeLabel(w, isArabic: widget.isArabic),
                      ),
                    ),
                ],
                onChanged: widget.editMode && widget.onSaveServiceType != null
                    ? (v) => setState(() => _serviceType = v)
                    : null,
              );
            },
          ),
          if (widget.editMode && widget.onSaveServiceType != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonal(
                onPressed: () =>
                    widget.onSaveServiceType!(node, _serviceType),
                child: Text(s.networkSaveServiceType),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            s.networkPorts,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            s.networkInlets,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          for (final p in inlets)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${p.code} (${p.portRole.dbValue})'),
              trailing: widget.editMode && widget.onRemovePort != null
                  ? IconButton(
                      tooltip: s.networkRemovePort,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed: () => widget.onRemovePort!(node, p),
                    )
                  : null,
            ),
          if (inlets.isEmpty) Text('· —'),
          Text(
            s.networkOutlets,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          for (final p in outlets)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${p.code} (${p.portRole.dbValue})'),
              trailing: widget.editMode && widget.onRemovePort != null
                  ? IconButton(
                      tooltip: s.networkRemovePort,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed: () => widget.onRemovePort!(node, p),
                    )
                  : null,
            ),
          if (outlets.isEmpty) Text('· —'),
          if (widget.editMode) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onAddInlet != null)
                  OutlinedButton.icon(
                    onPressed: () => widget.onAddInlet!(node),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(s.networkAddInlet),
                  ),
                if (widget.onAddOutlet != null)
                  OutlinedButton.icon(
                    onPressed: () => widget.onAddOutlet!(node),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(s.networkAddOutlet),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            s.networkInputs,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          for (final c in inbound) Text('· ${_nodeLabel(c.fromNodeId)}'),
          if (inbound.isEmpty) Text('· —'),
          const SizedBox(height: 8),
          Text(
            s.networkOutputs,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          for (final c in outbound) Text('· ${_nodeLabel(c.toNodeId)}'),
          if (outbound.isEmpty) Text('· —'),
          if (widget.editMode) ...[
            const Divider(height: 24),
            Text(
              s.networkCardImage,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (widget.onPickNodeImage != null)
              OutlinedButton.icon(
                onPressed: () => widget.onPickNodeImage!(node),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(s.networkPickCardImage),
              ),
            if ((asset.properties['image_url']?.toString().isNotEmpty ??
                    false) &&
                widget.onClearNodeImage != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => widget.onClearNodeImage!(node),
                icon: const Icon(Icons.hide_image_outlined, size: 18),
                label: Text(s.networkClearCardImage),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.onRemoveFromView != null)
              OutlinedButton.icon(
                onPressed: () => widget.onRemoveFromView!(node),
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: Text(s.networkRemoveFromBoard),
              ),
            if (widget.onDeleteNode != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => widget.onDeleteNode!(node),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(s.networkDeleteNode),
              ),
            ],
          ],
        ],
      );
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(12), child: body),
    );
  }
}

class _ConnectForm {
  const _ConnectForm({required this.kind, this.waterType});
  final String kind;
  final String? waterType;
}

class _ConnectPortsDialog extends StatefulWidget {
  const _ConnectPortsDialog({
    required this.strings,
    this.initialKind = 'supply',
  });
  final AdminStrings strings;
  final String initialKind;
  @override
  State<_ConnectPortsDialog> createState() => _ConnectPortsDialogState();
}

class _ConnectPortsDialogState extends State<_ConnectPortsDialog> {
  late String _kind = widget.initialKind;
  String? _waterType;

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      title: Text(s.networkConnectPorts),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kind,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.networkConnectionKind),
              items: [
                for (final k in kNetworkConnectionKinds)
                  DropdownMenuItem(
                    value: k,
                    child: dropdownItemText(
                      networkConnectionKindLabel(k, isArabic: s.isAr),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'supply'),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _waterType,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.networkWaterType),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: dropdownItemText(s.networkNone),
                ),
                for (final w in kNetworkWaterTypes)
                  DropdownMenuItem(
                    value: w,
                    child: dropdownItemText(
                      networkWaterTypeLabel(w, isArabic: s.isAr),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _waterType = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ConnectForm(kind: _kind, waterType: _waterType),
          ),
          child: Text(s.save),
        ),
      ],
    );
  }
}

class _NewMeterForm {
  const _NewMeterForm({
    required this.code,
    required this.nameEn,
    required this.nameAr,
  });
  final String code;
  final String nameEn;
  final String nameAr;
}

class _NamedAssetForm {
  const _NamedAssetForm({
    required this.nameEn,
    required this.nameAr,
    this.code,
  });
  final String nameEn;
  final String nameAr;
  final String? code;
}

class _NewMeterDialog extends StatefulWidget {
  const _NewMeterDialog({
    required this.strings,
    this.initialCode,
    this.initialNameEn,
    this.initialNameAr,
  });
  final AdminStrings strings;
  final String? initialCode;
  final String? initialNameEn;
  final String? initialNameAr;
  @override
  State<_NewMeterDialog> createState() => _NewMeterDialogState();
}

class _NewMeterDialogState extends State<_NewMeterDialog> {
  late final TextEditingController _code;
  late final TextEditingController _nameEn;
  late final TextEditingController _nameAr;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode ?? '');
    _nameEn = TextEditingController(text: widget.initialNameEn ?? '');
    _nameAr = TextEditingController(text: widget.initialNameAr ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    _nameEn.dispose();
    _nameAr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      title: Text(s.networkAddNewMeter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _code,
            decoration: InputDecoration(labelText: s.networkMeterCode),
          ),
          TextField(
            controller: _nameEn,
            decoration: InputDecoration(labelText: s.networkNameEn),
          ),
          TextField(
            controller: _nameAr,
            decoration: InputDecoration(labelText: s.networkNameAr),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_code.text.trim().isEmpty || _nameEn.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _NewMeterForm(
                code: _code.text.trim(),
                nameEn: _nameEn.text.trim(),
                nameAr: _nameAr.text.trim().isEmpty
                    ? _nameEn.text.trim()
                    : _nameAr.text.trim(),
              ),
            );
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}

class _NamedAssetDialog extends StatefulWidget {
  const _NamedAssetDialog({
    required this.strings,
    required this.title,
    required this.requireCode,
    this.initialCode,
    this.initialNameEn,
    this.initialNameAr,
  });
  final AdminStrings strings;
  final String title;
  final bool requireCode;
  final String? initialCode;
  final String? initialNameEn;
  final String? initialNameAr;
  @override
  State<_NamedAssetDialog> createState() => _NamedAssetDialogState();
}

class _NamedAssetDialogState extends State<_NamedAssetDialog> {
  late final TextEditingController _code;
  late final TextEditingController _nameEn;
  late final TextEditingController _nameAr;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode ?? '');
    _nameEn = TextEditingController(text: widget.initialNameEn ?? '');
    _nameAr = TextEditingController(text: widget.initialNameAr ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    _nameEn.dispose();
    _nameAr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.requireCode)
            TextField(
              controller: _code,
              decoration: InputDecoration(labelText: s.code),
            ),
          TextField(
            controller: _nameEn,
            decoration: InputDecoration(labelText: s.networkNameEn),
          ),
          TextField(
            controller: _nameAr,
            decoration: InputDecoration(labelText: s.networkNameAr),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_nameEn.text.trim().isEmpty) return;
            if (widget.requireCode && _code.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _NamedAssetForm(
                nameEn: _nameEn.text.trim(),
                nameAr: _nameAr.text.trim().isEmpty
                    ? _nameEn.text.trim()
                    : _nameAr.text.trim(),
                code: _code.text.trim().isEmpty ? null : _code.text.trim(),
              ),
            );
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}

class _LinkChoice {
  const _LinkChoice({this.upstream, this.downstream, this.connect = true});
  final String? upstream;
  final String? downstream;
  final bool connect;
}

class _LinkChoiceDialog extends StatefulWidget {
  const _LinkChoiceDialog({required this.strings, required this.snapshot});
  final AdminStrings strings;
  final UtilityNetworkSnapshot snapshot;
  @override
  State<_LinkChoiceDialog> createState() => _LinkChoiceDialogState();
}

class _LinkChoiceDialogState extends State<_LinkChoiceDialog> {
  String? _upstream;
  String? _downstream;
  bool _connect = true;

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final nodes = widget.snapshot.nodes.where((n) => n.asset != null).toList();
    DropdownMenuItem<String?> none() =>
        DropdownMenuItem(value: null, child: dropdownItemText(s.networkNone));
    List<DropdownMenuItem<String?>> nodeItems() => [
      none(),
      for (final n in nodes)
        DropdownMenuItem(
          value: n.id,
          child: dropdownItemText('${n.asset!.code} · ${n.asset!.nameAr}'),
        ),
    ];
    return AlertDialog(
      title: Text(s.networkAddExistingMeter),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _upstream,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.networkUpstreamOptional),
              items: nodeItems(),
              onChanged: (v) => setState(() => _upstream = v),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _downstream,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: s.networkDownstreamOptional,
              ),
              items: nodeItems(),
              onChanged: (v) => setState(() => _downstream = v),
            ),
            const SizedBox(height: 8),
            RadioGroup<bool>(
              groupValue: _connect,
              onChanged: (v) => setState(() => _connect = v ?? true),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    title: Text(s.networkAddAndConnect),
                    dense: true,
                  ),
                  RadioListTile<bool>(
                    value: false,
                    title: Text(s.networkAddWithoutLink),
                    dense: true,
                  ),
                ],
              ),
            ),
            Text(
              s.networkNoCopyHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _LinkChoice(
              upstream: _connect ? _upstream : null,
              downstream: _connect ? _downstream : null,
              connect: _connect,
            ),
          ),
          child: Text(
            _connect ? s.networkAddAndConnect : s.networkAddWithoutLink,
          ),
        ),
      ],
    );
  }
}

class _PickerRow {
  const _PickerRow({
    required this.id,
    required this.title,
    required this.state,
    required this.revisionNodeId,
    required this.raw,
  });
  final String id;
  final String title;
  final UtilityLookup state;
  final String? revisionNodeId;
  final Object raw;
}

class _SearchPickerDialog extends StatefulWidget {
  const _SearchPickerDialog({
    required this.strings,
    required this.title,
    required this.load,
  });
  final AdminStrings strings;
  final String title;
  final Future<List<_PickerRow>> Function(String? search) load;
  @override
  State<_SearchPickerDialog> createState() => _SearchPickerDialogState();
}

class _SearchPickerDialogState extends State<_SearchPickerDialog> {
  final _search = TextEditingController();
  List<_PickerRow> _all = const [];
  List<_PickerRow> _items = const [];
  bool _loading = true;
  String? _building;
  String? _status;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final items = await widget.load(_search.text.trim());
    if (!mounted) return;
    setState(() {
      _all = items;
      _loading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _items = _all.where((m) {
      if (_status != null && m.state.dbValue != _status) return false;
      if (_building != null) {
        final raw = m.raw;
        if (raw is AvailableNetworkMeter) {
          final area = raw.facilityArea?.nameAr ?? raw.facilityArea?.nameEn;
          if (area != _building) return false;
        }
      }
      return true;
    }).toList();
  }

  String _stateLabel(UtilityLookup state) {
    final s = widget.strings;
    if (state.dbValue == AvailableMeterState.notInNetwork.dbValue) {
      return s.networkStateNotInNetwork;
    }
    if (state.dbValue ==
        AvailableMeterState.inNetworkNotInCurrentView.dbValue) {
      return s.networkStateInNetworkOtherView;
    }
    return s.networkStateInCurrentView;
  }

  Color _stateColor(UtilityLookup state) {
    if (state.dbValue == AvailableMeterState.notInNetwork.dbValue) {
      return Colors.orange.shade100;
    }
    if (state.dbValue ==
        AvailableMeterState.inNetworkNotInCurrentView.dbValue) {
      return Colors.blue.shade100;
    }
    return Colors.green.shade100;
  }

  String? _areaLabel(_PickerRow row) {
    final raw = row.raw;
    if (raw is AvailableNetworkMeter) {
      return raw.facilityArea?.nameAr ??
          raw.facilityArea?.nameEn ??
          widget.strings.networkNone;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final buildings = <String>{
      for (final m in _all)
        if (m.raw is AvailableNetworkMeter)
          ...(m.raw as AvailableNetworkMeter).facilityArea == null
              ? const <String>[]
              : [
                  (m.raw as AvailableNetworkMeter)
                          .facilityArea!
                          .nameAr
                          .isNotEmpty
                      ? (m.raw as AvailableNetworkMeter).facilityArea!.nameAr
                      : (m.raw as AvailableNetworkMeter).facilityArea!.nameEn,
                ],
    }.toList()..sort();
    final dialogSize = dialogContentSize(context);
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final buildingDropdown = DropdownButtonFormField<String?>(
      initialValue: _building,
      isExpanded: true,
      decoration: InputDecoration(labelText: s.networkFilterBuilding),
      items: [
        DropdownMenuItem(value: null, child: dropdownItemText(s.networkAll)),
        for (final b in buildings)
          DropdownMenuItem(value: b, child: dropdownItemText(b)),
      ],
      onChanged: (v) => setState(() {
        _building = v;
        _applyFilters();
      }),
    );
    final statusDropdown = DropdownButtonFormField<String?>(
      initialValue: _status,
      isExpanded: true,
      decoration: InputDecoration(labelText: s.networkFilterStatus),
      items: [
        DropdownMenuItem(value: null, child: dropdownItemText(s.networkAll)),
        DropdownMenuItem(
          value: AvailableMeterState.inCurrentView.dbValue,
          child: dropdownItemText(s.networkStateInCurrentView),
        ),
        DropdownMenuItem(
          value: AvailableMeterState.notInNetwork.dbValue,
          child: dropdownItemText(s.networkStateNotInNetwork),
        ),
        DropdownMenuItem(
          value: AvailableMeterState.inNetworkNotInCurrentView.dbValue,
          child: dropdownItemText(s.networkStateInNetworkOtherView),
        ),
      ],
      onChanged: (v) => setState(() {
        _status = v;
        _applyFilters();
      }),
    );
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: dialogSize.width,
        height: dialogSize.height,
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: s.networkSearch,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _reload,
                ),
              ),
              onSubmitted: (_) => _reload(),
            ),
            const SizedBox(height: 8),
            if (narrow)
              Column(
                children: [
                  buildingDropdown,
                  const SizedBox(height: 8),
                  statusDropdown,
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: buildingDropdown),
                  const SizedBox(width: 8),
                  Expanded(child: statusDropdown),
                ],
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final m = _items[i];
                        return ListTile(
                          title: Text(
                            m.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${s.networkBuildingArea}: ${_areaLabel(m) ?? s.networkNone}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Chip(
                              label: dropdownItemText(_stateLabel(m.state)),
                              backgroundColor: _stateColor(m.state),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
      ],
    );
  }
}
