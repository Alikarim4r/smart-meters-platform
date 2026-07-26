import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/utility_network_models.dart';

/// Card background from `properties['image_url']` (http URL or data URI).
Widget? utilityNetworkCardBackground(Map<String, dynamic> properties) {
  final raw = properties['image_url'];
  if (raw is! String) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return Image.network(
      value,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
  Uint8List? bytes;
  if (value.startsWith('data:image')) {
    final comma = value.indexOf(',');
    if (comma > 0) {
      try {
        bytes = base64Decode(value.substring(comma + 1));
      } catch (_) {
        return null;
      }
    }
  }
  if (bytes == null || bytes.isEmpty) return null;
  return Image.memory(
    bytes,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
  );
}

const double kUtilityNetworkNodeWidth = 170;
const double kUtilityNetworkNodeHeight = 86;
const double kUtilityNetworkMeterSize = 112;
const double kUtilityNetworkPumpWidth = 156;
const double kUtilityNetworkPumpHeight = 92;
const double kUtilityNetworkTankWidth = 156;
const double kUtilityNetworkTankHeight = 100;
const double kUtilityNetworkNodeMinWidth = 72;
const double kUtilityNetworkNodeMinHeight = 64;
const double kUtilityNetworkNodeMaxWidth = 360;
const double kUtilityNetworkNodeMaxHeight = 240;
const double kUtilityNetworkPortSize = 14;

double utilityNetworkNodeWidth(
  UtilityViewNode placement, {
  String? assetType,
}) {
  final fallback = switch (assetType) {
    'meter' => kUtilityNetworkMeterSize,
    'pump' => kUtilityNetworkPumpWidth,
    'tank' => kUtilityNetworkTankWidth,
    'junction' => 120.0,
    _ => kUtilityNetworkNodeWidth,
  };
  var w = (placement.width ?? fallback).clamp(
    kUtilityNetworkNodeMinWidth,
    kUtilityNetworkNodeMaxWidth,
  );
  if (assetType == 'meter') {
    final h = (placement.height ?? fallback).clamp(
      kUtilityNetworkNodeMinHeight,
      kUtilityNetworkNodeMaxHeight,
    );
    // Always render meters as true circles (equal sides).
    w = math.max(w, h);
  }
  return w;
}

double utilityNetworkNodeHeight(
  UtilityViewNode placement, {
  String? assetType,
}) {
  final fallback = switch (assetType) {
    'meter' => kUtilityNetworkMeterSize,
    'pump' => kUtilityNetworkPumpHeight,
    'tank' => kUtilityNetworkTankHeight,
    'junction' => 88.0,
    _ => kUtilityNetworkNodeHeight,
  };
  var h = (placement.height ?? fallback).clamp(
    kUtilityNetworkNodeMinHeight,
    kUtilityNetworkNodeMaxHeight,
  );
  if (assetType == 'meter') {
    final w = (placement.width ?? fallback).clamp(
      kUtilityNetworkNodeMinWidth,
      kUtilityNetworkNodeMaxWidth,
    );
    h = math.max(w, h);
  }
  return h;
}

String? utilityNetworkAssetTypeForNode(
  UtilityNetworkSnapshot snapshot,
  String nodeId,
) =>
    snapshot.nodes
        .where((n) => n.id == nodeId)
        .firstOrNull
        ?.asset
        ?.assetType
        .dbValue;

/// Bounds used by the canvas, including node dimensions and padding.
Rect utilityNetworkFitBounds(
  UtilityNetworkSnapshot snapshot,
  String viewId, {
  double padding = 80,
}) {
  final placements = snapshot.placements.where((p) => p.viewId == viewId);
  if (placements.isEmpty) {
    return const Rect.fromLTWH(0, 0, 600, 400);
  }
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final p in placements) {
    final type = utilityNetworkAssetTypeForNode(snapshot, p.nodeId);
    left = math.min(left, p.posX);
    top = math.min(top, p.posY);
    right = math.max(
      right,
      p.posX + utilityNetworkNodeWidth(p, assetType: type),
    );
    bottom = math.max(
      bottom,
      p.posY + utilityNetworkNodeHeight(p, assetType: type),
    );
  }
  return Rect.fromLTRB(
    left - padding,
    top - padding,
    right + padding,
    bottom + padding,
  );
}

/// Visible revision nodes for a view (asset not duplicated across views).
List<UtilityRevisionNode> utilityNetworkNodesForView(
  UtilityNetworkSnapshot snapshot,
  String viewId,
) {
  final placed = {
    for (final p in snapshot.placements.where((p) => p.viewId == viewId))
      p.nodeId,
  };
  return snapshot.nodes.where((n) => placed.contains(n.id)).toList();
}

/// Connections with both endpoints placed in [viewId].
List<UtilityConnection> utilityNetworkConnectionsForView(
  UtilityNetworkSnapshot snapshot,
  String viewId,
) {
  final placed = {
    for (final p in snapshot.placements.where((p) => p.viewId == viewId))
      p.nodeId,
  };
  return snapshot.connections
      .where(
        (c) => placed.contains(c.fromNodeId) && placed.contains(c.toNodeId),
      )
      .toList();
}

/// Anchor point (canvas coords, before shift) for [portId] on a placed node.
///
/// Mirrors the port handle layout in `_UtilityNode` so edges start/end
/// exactly on the visible port dots (or on the card edge when ports are
/// hidden).
Offset utilityNetworkPortAnchor({
  required UtilityViewNode placement,
  required UtilityAsset asset,
  required String portId,
  required bool showPorts,
  required bool outgoing,
}) {
  final type = asset.assetType.dbValue;
  final cardTop = showPorts ? 9.0 : 0.0;
  final cardW = utilityNetworkNodeWidth(placement, assetType: type);
  final cardH = utilityNetworkNodeHeight(placement, assetType: type);
  double centerY(int index, int count) =>
      cardTop +
      (cardH - kUtilityNetworkPortSize) * ((index + 1) / (count + 1)) +
      kUtilityNetworkPortSize / 2;
  final inPorts = asset.ports
      .where((p) => p.direction.dbValue != 'out')
      .toList();
  final outPorts = asset.ports
      .where((p) => p.direction.dbValue == 'out')
      .toList();
  final outIdx = outPorts.indexWhere((p) => p.id == portId);
  if (outIdx >= 0) {
    return Offset(
      placement.posX + cardW,
      placement.posY + centerY(outIdx, outPorts.length),
    );
  }
  final inIdx = inPorts.indexWhere((p) => p.id == portId);
  if (inIdx >= 0) {
    return Offset(
      placement.posX,
      placement.posY + centerY(inIdx, inPorts.length),
    );
  }
  return Offset(
    placement.posX + (outgoing ? cardW : 0.0),
    placement.posY + cardTop + cardH / 2,
  );
}

/// Orthogonal polyline route between two anchors.
///
/// Segments are horizontal/vertical; corners are later cut with small 45°
/// bevels (see [utilityNetworkBeveledPath]).
List<Offset> utilityNetworkOrthogonalRoute(Offset a, Offset b) {
  const stub = 16.0;
  if ((b.dy - a.dy).abs() < 1 && b.dx >= a.dx) return [a, b];
  if (b.dx - a.dx >= 2 * stub) {
    final midX = (a.dx + b.dx) / 2;
    return [a, Offset(midX, a.dy), Offset(midX, b.dy), b];
  }
  // Target is behind (or too close to) the source: route around it.
  final midY = (a.dy + b.dy) / 2;
  return [
    a,
    Offset(a.dx + stub, a.dy),
    Offset(a.dx + stub, midY),
    Offset(b.dx - stub, midY),
    Offset(b.dx - stub, b.dy),
    b,
  ];
}

/// Route (with [shift] applied) for a connection, anchored to its real ports.
List<Offset>? utilityNetworkConnectionRoute({
  required UtilityConnection connection,
  required Map<String, UtilityViewNode> placements,
  required Map<String, UtilityRevisionNode> nodeById,
  required Offset shift,
  required bool showPorts,
}) {
  final from = placements[connection.fromNodeId];
  final to = placements[connection.toNodeId];
  final fromAsset = nodeById[connection.fromNodeId]?.asset;
  final toAsset = nodeById[connection.toNodeId]?.asset;
  if (from == null || to == null || fromAsset == null || toAsset == null) {
    return null;
  }
  final a =
      utilityNetworkPortAnchor(
        placement: from,
        asset: fromAsset,
        portId: connection.fromPortId,
        showPorts: showPorts,
        outgoing: true,
      ) +
      shift;
  final b =
      utilityNetworkPortAnchor(
        placement: to,
        asset: toAsset,
        portId: connection.toPortId,
        showPorts: showPorts,
        outgoing: false,
      ) +
      shift;
  return utilityNetworkOrthogonalRoute(a, b);
}

/// Builds a path from [points] cutting each corner with a small 45° bevel.
Path utilityNetworkBeveledPath(List<Offset> points, {double bevel = 8}) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length - 1; i++) {
    final prev = points[i - 1];
    final corner = points[i];
    final next = points[i + 1];
    final inVec = corner - prev;
    final outVec = next - corner;
    final inLen = inVec.distance;
    final outLen = outVec.distance;
    if (inLen == 0 || outLen == 0) continue;
    final cut = math.min(bevel, math.min(inLen / 2, outLen / 2));
    final p1 = corner - inVec / inLen * cut;
    final p2 = corner + outVec / outLen * cut;
    path
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

Matrix4 utilityNetworkFitMatrix({
  required Rect contentBounds,
  required Size viewport,
  double minScale = 0.25,
  double maxScale = 5.0,
}) {
  final contentW = math.max(1.0, contentBounds.width);
  final contentH = math.max(1.0, contentBounds.height);
  final scale = (math.min(
    viewport.width / contentW,
    viewport.height / contentH,
  )).clamp(minScale, maxScale);
  final dx =
      (viewport.width - contentW * scale) / 2 - contentBounds.left * scale;
  final dy =
      (viewport.height - contentH * scale) / 2 - contentBounds.top * scale;
  return Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);
}

typedef UtilityNetworkPortConnect =
    void Function(
      UtilityRevisionNode fromNode,
      UtilityAssetPort fromPort,
      UtilityRevisionNode toNode,
      UtilityAssetPort toPort,
    );

typedef UtilityNetworkNodeMoved =
    void Function(UtilityRevisionNode node, UtilityViewNode placement);

/// Utility network canvas — read-only by default; editable when [editMode].
class UtilityNetworkCanvas extends StatefulWidget {
  const UtilityNetworkCanvas({
    super.key,
    required this.snapshot,
    required this.viewId,
    required this.isArabic,
    this.selectedNodeId,
    this.selectedConnectionId,
    this.onNodeTap,
    this.onConnectionTap,
    this.editMode = false,
    this.showPorts = false,
    this.onNodeMoved,
    this.onConnectPorts,
    this.showLegend = true,
    this.autoFitOnLoad = true,
    this.showFitControl = true,
    this.lockInteraction = false,
  });

  final UtilityNetworkSnapshot snapshot;
  final String viewId;
  final bool isArabic;
  final String? selectedNodeId;
  final String? selectedConnectionId;
  final ValueChanged<UtilityRevisionNode>? onNodeTap;
  final ValueChanged<UtilityConnection>? onConnectionTap;
  final bool editMode;
  final bool showPorts;
  final UtilityNetworkNodeMoved? onNodeMoved;
  final UtilityNetworkPortConnect? onConnectPorts;
  final bool showLegend;
  final bool autoFitOnLoad;
  final bool showFitControl;
  /// When true, disables pan/zoom (e.g. while dragging from an external palette).
  final bool lockInteraction;

  @override
  State<UtilityNetworkCanvas> createState() => UtilityNetworkCanvasState();
}

class UtilityNetworkCanvasState extends State<UtilityNetworkCanvas> {
  final TransformationController _transform = TransformationController();
  bool _didAutoFit = false;
  Size? _viewport;
  bool _interactionLocked = false;
  _PortAnchor? _connectFrom;

  bool get _portsVisible => widget.editMode && widget.showPorts;

  @override
  void didUpdateWidget(covariant UtilityNetworkCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewId != widget.viewId ||
        oldWidget.snapshot.revision.id != widget.snapshot.revision.id ||
        oldWidget.snapshot.placements.length !=
            widget.snapshot.placements.length) {
      _didAutoFit = false;
      SchedulerBinding.instance.addPostFrameCallback((_) => fitToContent());
    }
    if (!widget.editMode && _connectFrom != null) {
      _connectFrom = null;
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void fitToContent() {
    final viewport = _viewport;
    if (viewport == null || !viewport.isFinite || viewport.isEmpty) return;
    final bounds = utilityNetworkFitBounds(widget.snapshot, widget.viewId);
    final shift = Offset(
      -math.min(0.0, bounds.left),
      -math.min(0.0, bounds.top),
    );
    final shifted = Rect.fromLTRB(
      bounds.left + shift.dx,
      bounds.top + shift.dy,
      bounds.right + shift.dx,
      bounds.bottom + shift.dy,
    );
    _transform.value = utilityNetworkFitMatrix(
      contentBounds: shifted,
      viewport: viewport,
    );
    _didAutoFit = true;
  }

  void resetView() => fitToContent();

  void focusNode(String nodeId) {
    final placement = widget.snapshot.placements
        .where((p) => p.viewId == widget.viewId && p.nodeId == nodeId)
        .firstOrNull;
    final viewport = _viewport;
    if (placement == null || viewport == null) return;
    final bounds = utilityNetworkFitBounds(widget.snapshot, widget.viewId);
    final shift = Offset(
      -math.min(0.0, bounds.left),
      -math.min(0.0, bounds.top),
    );
    final cx =
        placement.posX +
        shift.dx +
        utilityNetworkNodeWidth(
              placement,
              assetType: widget.snapshot.nodes
                  .where((n) => n.id == nodeId)
                  .firstOrNull
                  ?.asset
                  ?.assetType
                  .dbValue,
            ) /
            2;
    final cy =
        placement.posY +
        shift.dy +
        utilityNetworkNodeHeight(
              placement,
              assetType: widget.snapshot.nodes
                  .where((n) => n.id == nodeId)
                  .firstOrNull
                  ?.asset
                  ?.assetType
                  .dbValue,
            ) /
            2;
    final scale = _transform.value.getMaxScaleOnAxis().clamp(0.25, 5.0);
    final dx = viewport.width / 2 - cx * scale;
    final dy = viewport.height / 2 - cy * scale;
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// Converts a global (screen) point to pre-shift world canvas coordinates.
  Offset? globalToWorld(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(globalPosition);
    final Matrix4 inverse;
    try {
      inverse = Matrix4.inverted(_transform.value);
    } catch (_) {
      return null;
    }
    final scene = MatrixUtils.transformPoint(inverse, local);
    final bounds = utilityNetworkFitBounds(widget.snapshot, widget.viewId);
    final shift = Offset(
      -math.min(0.0, bounds.left),
      -math.min(0.0, bounds.top),
    );
    return scene - shift;
  }

  UtilityConnection? _hitConnection(
    Offset canvasPoint,
    Map<String, UtilityViewNode> placements,
    Offset shift,
  ) {
    final nodes = utilityNetworkNodesForView(widget.snapshot, widget.viewId);
    final nodeById = {for (final node in nodes) node.id: node};
    for (final connection in utilityNetworkConnectionsForView(
      widget.snapshot,
      widget.viewId,
    )) {
      final route = utilityNetworkConnectionRoute(
        connection: connection,
        placements: placements,
        nodeById: nodeById,
        shift: shift,
        showPorts: _portsVisible,
      );
      if (route == null) continue;
      for (var i = 0; i < route.length - 1; i++) {
        if (_distanceToSegment(canvasPoint, route[i], route[i + 1]) < 12) {
          return connection;
        }
      }
    }
    return null;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (ab2 == 0) return (p - a).distance;
    var t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }

  void _finishPortConnect(
    UtilityRevisionNode? toNode,
    UtilityAssetPort? toPort,
  ) {
    final from = _connectFrom;
    setState(() {
      _connectFrom = null;
      _interactionLocked = false;
    });
    if (from == null || toNode == null || toPort == null) return;
    if (from.node.id == toNode.id && from.port.id == toPort.id) return;
    widget.onConnectPorts?.call(from.node, from.port, toNode, toPort);
  }

  @override
  Widget build(BuildContext context) {
    final bounds = utilityNetworkFitBounds(widget.snapshot, widget.viewId);
    final placements = {
      for (final p in widget.snapshot.placements.where(
        (p) => p.viewId == widget.viewId,
      ))
        p.nodeId: p,
    };
    final nodes = utilityNetworkNodesForView(widget.snapshot, widget.viewId);
    final nodeById = {for (final node in nodes) node.id: node};
    final shift = Offset(
      -math.min(0.0, bounds.left),
      -math.min(0.0, bounds.top),
    );
    final canvasSize = Size(
      math.max(600, bounds.right - math.min(0, bounds.left) + 120),
      math.max(400, bounds.bottom - math.min(0, bounds.top) + 120),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _viewport = Size(constraints.maxWidth, constraints.maxHeight);
            if (widget.autoFitOnLoad && !_didAutoFit) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) fitToContent();
              });
            }
            return Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(240),
                  minScale: 0.25,
                  maxScale: 5.0,
                  panEnabled: !_interactionLocked && !widget.lockInteraction,
                  scaleEnabled: !_interactionLocked && !widget.lockInteraction,
                  child: SizedBox(
                    width: canvasSize.width,
                    height: canvasSize.height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (details) {
                        final hit = _hitConnection(
                          details.localPosition,
                          placements,
                          shift,
                        );
                        if (hit != null) {
                          widget.onConnectionTap?.call(hit);
                          return;
                        }
                        if (_connectFrom != null) {
                          _finishPortConnect(null, null);
                        }
                      },
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: canvasSize,
                            painter: _UtilityEdgesPainter(
                              snapshot: widget.snapshot,
                              nodeById: nodeById,
                              placements: placements,
                              shift: shift,
                              isArabic: widget.isArabic,
                              showPorts: _portsVisible,
                              selectedConnectionId: widget.selectedConnectionId,
                            ),
                          ),
                          for (final node in nodes)
                            if (placements[node.id] != null)
                              Positioned(
                                left: placements[node.id]!.posX + shift.dx,
                                top: placements[node.id]!.posY + shift.dy,
                                child: _UtilityNode(
                                  node: node,
                                  placement: placements[node.id]!,
                                  isArabic: widget.isArabic,
                                  selected: node.id == widget.selectedNodeId,
                                  editMode: widget.editMode,
                                  showPorts: _portsVisible,
                                  connectingPortId:
                                      _connectFrom?.node.id == node.id
                                      ? _connectFrom?.port.id
                                      : null,
                                  onTap: () {
                                    if (_connectFrom != null) {
                                      _finishPortConnect(null, null);
                                      return;
                                    }
                                    widget.onNodeTap?.call(node);
                                  },
                                  onChanged: widget.editMode
                                      ? (placement) => widget.onNodeMoved
                                            ?.call(node, placement)
                                      : null,
                                  onDragLock: (locked) => setState(
                                    () => _interactionLocked = locked,
                                  ),
                                  onPortTap: (port) {
                                    final from = _connectFrom;
                                    if (from != null) {
                                      _finishPortConnect(node, port);
                                    } else if (widget.editMode) {
                                      setState(() {
                                        _connectFrom = _PortAnchor(
                                          node: node,
                                          port: port,
                                        );
                                        _interactionLocked = false;
                                      });
                                    }
                                  },
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.showFitControl)
                  PositionedDirectional(
                    start: 12,
                    top: 12,
                    child: Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(8),
                      child: IconButton(
                        tooltip: widget.isArabic
                            ? 'إعادة ضبط العرض'
                            : 'Reset view',
                        onPressed: resetView,
                        icon: const Icon(Icons.fit_screen_outlined),
                      ),
                    ),
                  ),
                if (widget.editMode && _connectFrom != null)
                  PositionedDirectional(
                    start: 12,
                    top: widget.showFitControl ? 56 : 12,
                    child: Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiaryContainer.withValues(alpha: .95),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          widget.isArabic
                              ? 'اختر منفذ الوجهة…'
                              : 'Select target port…',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ),
                  ),
                if (widget.showLegend)
                  PositionedDirectional(
                    end: 12,
                    bottom: 12,
                    child: _Legend(isArabic: widget.isArabic),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PortAnchor {
  const _PortAnchor({required this.node, required this.port});
  final UtilityRevisionNode node;
  final UtilityAssetPort port;
}

class _UtilityNode extends StatefulWidget {
  const _UtilityNode({
    required this.node,
    required this.placement,
    required this.isArabic,
    required this.selected,
    required this.editMode,
    required this.showPorts,
    required this.onTap,
    this.connectingPortId,
    this.onChanged,
    this.onDragLock,
    this.onPortTap,
  });

  final UtilityRevisionNode node;
  final UtilityViewNode placement;
  final bool isArabic;
  final bool selected;
  final bool editMode;
  final bool showPorts;
  final String? connectingPortId;
  final VoidCallback onTap;
  final ValueChanged<UtilityViewNode>? onChanged;
  final ValueChanged<bool>? onDragLock;
  final ValueChanged<UtilityAssetPort>? onPortTap;

  @override
  State<_UtilityNode> createState() => _UtilityNodeState();
}

class _UtilityNodeState extends State<_UtilityNode> {
  UtilityViewNode? _dragPlacement;

  UtilityViewNode get _placement => _dragPlacement ?? widget.placement;

  @override
  void didUpdateWidget(covariant _UtilityNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Accept parent updates only when not mid-drag.
    if (_dragPlacement == null) return;
    if (oldWidget.placement.nodeId != widget.placement.nodeId) {
      _dragPlacement = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final placement = _placement;
    final isArabic = widget.isArabic;
    final selected = widget.selected;
    final editMode = widget.editMode;
    final showPorts = widget.showPorts;
    final onTap = widget.onTap;
    final onChanged = widget.onChanged;
    final onDragLock = widget.onDragLock;
    final onPortTap = widget.onPortTap;
    final connectingPortId = widget.connectingPortId;

    final asset = node.asset;
    if (asset == null) return const SizedBox.shrink();
    final assetType = asset.assetType.dbValue;
    final color = utilityNetworkNodeColor(asset);
    final name = isArabic && asset.nameAr.isNotEmpty
        ? asset.nameAr
        : asset.nameEn;
    final background = utilityNetworkCardBackground(asset.properties);
    final inPorts = asset.ports
        .where((p) => p.direction.dbValue != 'out')
        .toList();
    final outPorts = asset.ports
        .where((p) => p.direction.dbValue == 'out')
        .toList();
    final cardW = utilityNetworkNodeWidth(placement, assetType: assetType);
    final cardH = utilityNetworkNodeHeight(placement, assetType: assetType);
    final canEditGeometry = editMode && onChanged != null;
    final isDraft = asset.properties['draft'] == true;
    final cardColor = isDraft ? color.withValues(alpha: 0.55) : color;
    final isMeter = assetType == 'meter';
    final isRectCard = assetType == 'tank' || assetType == 'pump';
    // Keep meter text inside the inscribed square of the circle.
    final meterInset = math.max(14.0, cardW * 0.16);

    return SizedBox(
      width: cardW,
      height: cardH + (showPorts ? 18 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: showPorts ? 9 : 0,
            width: cardW,
            height: cardH,
            child: GestureDetector(
              onTap: onTap,
              onPanStart: canEditGeometry
                  ? (_) {
                      _dragPlacement = placement;
                      onDragLock?.call(true);
                    }
                  : null,
              onPanUpdate: canEditGeometry
                  ? (details) {
                      final next = (_dragPlacement ?? placement).copyWith(
                        posX: (_dragPlacement ?? placement).posX + details.delta.dx,
                        posY: (_dragPlacement ?? placement).posY + details.delta.dy,
                      );
                      _dragPlacement = next;
                      onChanged(next);
                    }
                  : null,
              onPanEnd: canEditGeometry
                  ? (_) {
                      _dragPlacement = null;
                      onDragLock?.call(false);
                    }
                  : null,
              child: Opacity(
                opacity: isDraft ? 0.78 : 1,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: selected ? 4 : 1,
                  clipBehavior: Clip.antiAlias,
                  shape: utilityNetworkNodeShape(
                    assetType,
                    Size(cardW, cardH),
                    side: BorderSide(
                      color: cardColor,
                      width: selected ? 2.5 : 1.2,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (background != null)
                        Opacity(opacity: .22, child: background),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMeter ? meterInset : 10,
                          vertical: isMeter ? meterInset * 0.85 : 8,
                        ),
                        child: isMeter
                            ? _MeterNodeContent(
                                code: asset.code,
                                name: name,
                                color: cardColor,
                                isDraft: isDraft,
                                isArabic: isArabic,
                                icon: utilityNetworkAssetIcon(assetType),
                              )
                            : _RectNodeContent(
                                code: asset.code,
                                name: name,
                                color: cardColor,
                                isDraft: isDraft,
                                isArabic: isArabic,
                                icon: utilityNetworkAssetIcon(assetType),
                                emphasizeIcon: isRectCard,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (canEditGeometry)
            Positioned(
              right: isMeter ? -4 : 0,
              bottom: (showPorts ? 9 : 0) + (isMeter ? -4 : 0),
              width: isMeter ? 32 : 28,
              height: isMeter ? 32 : 28,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  _dragPlacement = placement;
                  onDragLock?.call(true);
                },
                onPanUpdate: (details) {
                  final current = _dragPlacement ?? placement;
                  if (isMeter) {
                    // Bottom-right handle: size follows horizontal drag so the
                    // circle can shrink and grow (max(w,h) only grew).
                    final currentSide = utilityNetworkNodeWidth(
                      current,
                      assetType: assetType,
                    );
                    final nextSide = (currentSide + details.delta.dx).clamp(
                      kUtilityNetworkNodeMinWidth,
                      kUtilityNetworkNodeMaxWidth,
                    );
                    final next = current.copyWith(
                      width: nextSide,
                      height: nextSide,
                    );
                    _dragPlacement = next;
                    onChanged(next);
                    return;
                  }
                  final nextW =
                      (utilityNetworkNodeWidth(current, assetType: assetType) +
                              details.delta.dx)
                          .clamp(
                            kUtilityNetworkNodeMinWidth,
                            kUtilityNetworkNodeMaxWidth,
                          );
                  final nextH =
                      (utilityNetworkNodeHeight(current, assetType: assetType) +
                              details.delta.dy)
                          .clamp(
                            kUtilityNetworkNodeMinHeight,
                            kUtilityNetworkNodeMaxHeight,
                          );
                  final next = current.copyWith(width: nextW, height: nextH);
                  _dragPlacement = next;
                  onChanged(next);
                },
                onPanEnd: (_) {
                  _dragPlacement = null;
                  onDragLock?.call(false);
                },
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: isMeter ? 14 : 12,
                    height: isMeter ? 14 : 12,
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (showPorts) ...[
            for (var i = 0; i < inPorts.length; i++)
              Positioned(
                left: -kUtilityNetworkPortSize / 2,
                top:
                    9 +
                    (cardH - kUtilityNetworkPortSize) *
                        ((i + 1) / (inPorts.length + 1)),
                child: _PortHandle(
                  port: inPorts[i],
                  color: cardColor,
                  active: connectingPortId == inPorts[i].id,
                  onTap: () => onPortTap?.call(inPorts[i]),
                ),
              ),
            for (var i = 0; i < outPorts.length; i++)
              Positioned(
                right: -kUtilityNetworkPortSize / 2,
                top:
                    9 +
                    (cardH - kUtilityNetworkPortSize) *
                        ((i + 1) / (outPorts.length + 1)),
                child: _PortHandle(
                  port: outPorts[i],
                  color: cardColor,
                  active: connectingPortId == outPorts[i].id,
                  onTap: () => onPortTap?.call(outPorts[i]),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MeterNodeContent extends StatelessWidget {
  const _MeterNodeContent({
    required this.code,
    required this.name,
    required this.color,
    required this.isDraft,
    required this.isArabic,
    required this.icon,
  });

  final String code;
  final String name;
  final Color color;
  final bool isDraft;
  final bool isArabic;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1.15,
                ),
              ),
              if (name.trim().isNotEmpty && name.trim() != code) ...[
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    height: 1.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
              ],
              if (isDraft) ...[
                const SizedBox(height: 2),
                Text(
                  isArabic ? 'مسودة' : 'Draft',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RectNodeContent extends StatelessWidget {
  const _RectNodeContent({
    required this.code,
    required this.name,
    required this.color,
    required this.isDraft,
    required this.isArabic,
    required this.icon,
    this.emphasizeIcon = false,
  });

  final String code;
  final String name;
  final Color color;
  final bool isDraft;
  final bool isArabic;
  final IconData icon;
  final bool emphasizeIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: emphasizeIcon ? 20 : 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
            if (isDraft)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Text(
                  isArabic ? 'مسودة' : 'Draft',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Text(
              name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.25,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class _PortHandle extends StatelessWidget {
  const _PortHandle({
    required this.port,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final UtilityAssetPort port;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${port.code} (${port.direction.dbValue})',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: kUtilityNetworkPortSize,
          height: kUtilityNetworkPortSize,
          decoration: BoxDecoration(
            color: active ? color : Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
      ),
    );
  }
}

class _PortStrip extends StatelessWidget {
  const _PortStrip({required this.ports});
  final List<UtilityAssetPort> ports;

  @override
  Widget build(BuildContext context) {
    if (ports.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Wrap(
        spacing: 3,
        runSpacing: 2,
        children: [
          for (final p in ports.take(4))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                p.code,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontSize: 8, height: 1.1),
              ),
            ),
        ],
      ),
    );
  }
}

class _UtilityEdgesPainter extends CustomPainter {
  const _UtilityEdgesPainter({
    required this.snapshot,
    required this.nodeById,
    required this.placements,
    required this.shift,
    required this.isArabic,
    required this.showPorts,
    this.selectedConnectionId,
  });

  final UtilityNetworkSnapshot snapshot;
  final Map<String, UtilityRevisionNode> nodeById;
  final Map<String, UtilityViewNode> placements;
  final Offset shift;
  final bool isArabic;
  final bool showPorts;
  final String? selectedConnectionId;

  @override
  void paint(Canvas canvas, Size size) {
    final viewId = placements.values.isEmpty
        ? ''
        : placements.values.first.viewId;
    final visible = viewId.isEmpty
        ? snapshot.connections
        : utilityNetworkConnectionsForView(snapshot, viewId);

    for (final connection in visible) {
      final route = utilityNetworkConnectionRoute(
        connection: connection,
        placements: placements,
        nodeById: nodeById,
        shift: shift,
        showPorts: showPorts,
      );
      if (route == null) continue;
      final selected = connection.id == selectedConnectionId;
      final paint = Paint()
        ..color = utilityNetworkConnectionColor(
          connection.waterType,
          connection.connectionKind.dbValue,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3.4 : 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = utilityNetworkBeveledPath(route);
      _drawPath(
        canvas,
        path,
        paint,
        dashed: utilityNetworkConnectionIsDashed(connection),
      );
      _drawArrowHead(canvas, route, paint);
      final label = _edgeLabel(connection);
      if (label != null) {
        final mid = _routeMidpoint(route) - const Offset(0, 8);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: paint.color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        )..layout();
        tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  Offset _routeMidpoint(List<Offset> route) {
    var total = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      total += (route[i + 1] - route[i]).distance;
    }
    var remaining = total / 2;
    for (var i = 0; i < route.length - 1; i++) {
      final seg = route[i + 1] - route[i];
      final len = seg.distance;
      if (len >= remaining && len > 0) {
        return route[i] + seg * (remaining / len);
      }
      remaining -= len;
    }
    return route.last;
  }

  String? _edgeLabel(UtilityConnection c) {
    final kind = c.connectionKind.dbValue;
    if ({'overflow', 'washout', 'drain', 'tanker_transport'}.contains(kind)) {
      return kind;
    }
    if (c.transportMode.dbValue == 'tanker_transport' ||
        c.transportMode.dbValue == 'tanker') {
      return 'tanker';
    }
    if (c.waterType == 'reject' || c.waterType == 'product') {
      return c.waterType;
    }
    return null;
  }

  void _drawPath(Canvas canvas, Path path, Paint paint, {required bool dashed}) {
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = math.min(start + 8, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start += 14;
      }
    }
  }

  void _drawArrowHead(Canvas canvas, List<Offset> route, Paint paint) {
    final tip = route.last;
    final tail = route[route.length - 2];
    final angle = math.atan2(tip.dy - tail.dy, tip.dx - tail.dx);
    const length = 10.0;
    canvas.drawLine(
      tip,
      Offset(
        tip.dx - length * math.cos(angle - .45),
        tip.dy - length * math.sin(angle - .45),
      ),
      paint,
    );
    canvas.drawLine(
      tip,
      Offset(
        tip.dx - length * math.cos(angle + .45),
        tip.dy - length * math.sin(angle + .45),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _UtilityEdgesPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot ||
      oldDelegate.shift != shift ||
      oldDelegate.showPorts != showPorts ||
      oldDelegate.selectedConnectionId != selectedConnectionId;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final labels = isArabic
        ? [
            'مياه الشرب',
            'TSE صرف معالج',
            'منتجة RO',
            'أمطار / ري',
            'مرفوضة / تناكر',
            'Overflow / تنظيف',
            'مكافحة حريق',
          ]
        : [
            'Potable',
            'TSE',
            'RO product',
            'Rain / irrigation',
            'Reject / tanker',
            'Overflow / washout',
            'Firefighting',
          ];
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            _LegendItem(const Color(0xFF2563EB), labels[0]),
            _LegendItem(const Color(0xFF7C3AED), labels[1]),
            _LegendItem(const Color(0xFF0891B2), labels[2]),
            _LegendItem(const Color(0xFF0D9488), labels[3]),
            _LegendItem(const Color(0xFFEA580C), labels[4]),
            _LegendItem(const Color(0xFF64748B), labels[5]),
            _LegendItem(const Color(0xFFDC2626), labels[6]),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

Color utilityNetworkAssetColor(String type) => switch (type) {
  'meter' => const Color(0xFF1D4ED8),
  'tank' => const Color(0xFF0D9488),
  'treatment_unit' => const Color(0xFF7C3AED),
  'tanker_discharge' || 'tanker_loading' => const Color(0xFFB45309),
  'discharge_point' || 'ground_drain' => const Color(0xFF64748B),
  'pump' => const Color(0xFF0369A1),
  'filter' => const Color(0xFF4F46E5),
  'junction' => const Color(0xFF57534E),
  'external_source' => const Color(0xFF059669),
  'consumer' => const Color(0xFFBE185D),
  'building_portal' => const Color(0xFF9333EA),
  'cooling_tower' => const Color(0xFF0E7490),
  'chiller' => const Color(0xFF0284C7),
  _ => const Color(0xFF64748B),
};

/// Resolves potable / TSE / RO product (and similar) for node coloring.
String? utilityNetworkServiceWaterKey(UtilityAsset asset) {
  final raw = asset.serviceType?.dbValue ??
      asset.properties['service_type']?.toString() ??
      asset.properties['water_type']?.toString() ??
      asset.properties['source']?.toString();
  final key = raw?.trim().toLowerCase();
  if (key == null || key.isEmpty) return null;
  return switch (key) {
    'kahramaa' || 'drinking' || 'fresh' => 'potable',
    'ro' || 'ro_product' || 'desalinated' => 'product',
    'treated_sewage' || 'recycled' => 'tse',
    _ => key,
  };
}

Color utilityNetworkNodeColor(UtilityAsset asset) {
  final type = asset.assetType.dbValue;
  if (type == 'meter') {
    return switch (utilityNetworkServiceWaterKey(asset)) {
      'potable' || 'treated' => const Color(0xFF1D4ED8), // drinking
      'tse' || 'greywater' || 'reclaimed' => const Color(0xFF7C3AED), // TSE
      'product' => const Color(0xFF0891B2), // RO product
      'reject' || 'ro_reject' => const Color(0xFFEA580C),
      'raw' || 'irrigation' || 'rain' || 'rainwater' => const Color(0xFF0D9488),
      'firefighting' || 'fire' => const Color(0xFFDC2626),
      _ => const Color(0xFF1D4ED8),
    };
  }
  return utilityNetworkAssetColor(type);
}

ShapeBorder utilityNetworkNodeShape(
  String type,
  Size size, {
  BorderSide side = BorderSide.none,
}) {
  switch (type) {
    case 'meter':
      return CircleBorder(side: side);
    case 'tank':
    case 'pump':
    case 'cooling_tower':
    case 'chiller':
      // Explicit rectangles (slightly rounded corners only).
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: side,
      );
    case 'treatment_unit':
      return BeveledRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: side,
      );
    case 'junction':
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: side,
      );
    case 'filter':
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: side,
      );
    case 'external_source':
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: side,
      );
    default:
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: side,
      );
  }
}

IconData utilityNetworkAssetIcon(String type) => switch (type) {
  'meter' => Icons.speed,
  'tank' => Icons.water_drop_outlined,
  'treatment_unit' => Icons.filter_alt_outlined,
  'tanker_discharge' || 'tanker_loading' => Icons.local_shipping_outlined,
  'discharge_point' || 'ground_drain' => Icons.water_damage_outlined,
  'pump' => Icons.settings,
  'filter' => Icons.grain,
  'junction' => Icons.device_hub_outlined,
  'external_source' => Icons.water,
  'consumer' => Icons.home_outlined,
  'building_portal' => Icons.door_front_door_outlined,
  'cooling_tower' => Icons.cottage_outlined,
  'chiller' => Icons.ac_unit,
  _ => Icons.account_tree_outlined,
};

Color utilityNetworkConnectionColor(String? waterType, String kind) {
  if (kind == 'overflow' || kind == 'washout' || kind == 'drain') {
    return const Color(0xFF64748B);
  }
  if (kind == 'tanker_transport') return const Color(0xFFEA580C);
  return switch (waterType) {
    'treated' || 'potable' => const Color(0xFF2563EB),
    'product' || 'ro_product' => const Color(0xFF0891B2),
    'tse' || 'greywater' || 'reclaimed' => const Color(0xFF7C3AED),
    'waste' || 'reject' || 'ro_reject' => const Color(0xFFEA580C),
    'rain' || 'rainwater' || 'irrigation' || 'raw' => const Color(0xFF0D9488),
    'firefighting' || 'fire' => const Color(0xFFDC2626),
    _ => const Color(0xFF2563EB),
  };
}

bool utilityNetworkConnectionIsDashed(UtilityConnection c) =>
    {
      'overflow',
      'washout',
      'drain',
      'tanker_transport',
    }.contains(c.connectionKind.dbValue) ||
    c.transportMode.dbValue == 'tanker_transport' ||
    c.transportMode.dbValue == 'tanker';
