import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/site_network.dart';
import '../theme/app_colors.dart';

const double kNetworkNodeWidth = 148;
const double kNetworkNodeHeight = 64;
const double kNetworkCanvasWidth = 2400;
const double kNetworkCanvasHeight = 1600;

Color networkNodeColor(NetworkNodeKind kind) {
  return switch (kind) {
    NetworkNodeKind.meter => AppColors.navy,
    NetworkNodeKind.tank => const Color(0xFF0D9488),
    NetworkNodeKind.tankerDischarge => const Color(0xFFB45309),
    NetworkNodeKind.groundDrain => const Color(0xFF64748B),
  };
}

IconData networkNodeIcon(NetworkNodeKind kind) {
  return switch (kind) {
    NetworkNodeKind.meter => Icons.speed,
    NetworkNodeKind.tank => Icons.water_drop_outlined,
    NetworkNodeKind.tankerDischarge => Icons.local_shipping_outlined,
    NetworkNodeKind.groundDrain => Icons.water_damage_outlined,
  };
}

class SiteNetworkCanvas extends StatefulWidget {
  const SiteNetworkCanvas({
    super.key,
    required this.graph,
    required this.isArabic,
    this.readOnly = true,
    this.selectedNodeId,
    this.selectedEdgeId,
    this.onNodeTap,
    this.onEdgeTap,
    this.onNodeMoved,
    this.onConnect,
    this.onEmptyLongPress,
  });

  final SiteNetworkGraph graph;
  final bool isArabic;
  final bool readOnly;
  final String? selectedNodeId;
  final String? selectedEdgeId;
  final ValueChanged<SiteNetworkNode>? onNodeTap;
  final ValueChanged<SiteNetworkEdge>? onEdgeTap;
  final void Function(SiteNetworkNode node, Offset position)? onNodeMoved;
  final void Function(SiteNetworkNode from, SiteNetworkNode to)? onConnect;
  final ValueChanged<Offset>? onEmptyLongPress;

  @override
  State<SiteNetworkCanvas> createState() => _SiteNetworkCanvasState();
}

class _SiteNetworkCanvasState extends State<SiteNetworkCanvas> {
  String? _connectingFromId;
  bool _interactionLocked = false;

  SiteNetworkEdge? _hitEdge(Offset canvasPoint) {
    for (final edge in widget.graph.edges) {
      final from = widget.graph.nodeById(edge.fromNodeId);
      final to = widget.graph.nodeById(edge.toNodeId);
      if (from == null || to == null) continue;
      final a = Offset(
        from.posX + kNetworkNodeWidth,
        from.posY + kNetworkNodeHeight / 2,
      );
      final b = Offset(to.posX, to.posY + kNetworkNodeHeight / 2);
      if (_distanceToSegment(canvasPoint, a, b) < 12) return edge;
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

  void _handleNodeTap(SiteNetworkNode node) {
    final fromId = _connectingFromId;
    if (!widget.readOnly && fromId != null) {
      final from = widget.graph.nodeById(fromId);
      setState(() => _connectingFromId = null);
      if (from != null && from.id != node.id) {
        widget.onConnect?.call(from, node);
      }
      return;
    }
    widget.onNodeTap?.call(node);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerLowest,
        child: InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(400),
          minScale: 0.35,
          maxScale: 2.5,
          panEnabled: !_interactionLocked,
          scaleEnabled: !_interactionLocked,
          child: SizedBox(
            width: kNetworkCanvasWidth,
            height: kNetworkCanvasHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                final edge = _hitEdge(details.localPosition);
                if (edge != null) {
                  widget.onEdgeTap?.call(edge);
                  return;
                }
                if (_connectingFromId != null) {
                  setState(() => _connectingFromId = null);
                }
              },
              onLongPressStart: widget.readOnly
                  ? null
                  : (details) {
                      for (final node in widget.graph.nodes) {
                        final rect = Rect.fromLTWH(
                          node.posX,
                          node.posY,
                          kNetworkNodeWidth,
                          kNetworkNodeHeight,
                        );
                        if (rect.contains(details.localPosition)) return;
                      }
                      widget.onEmptyLongPress?.call(details.localPosition);
                    },
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(kNetworkCanvasWidth, kNetworkCanvasHeight),
                    painter: _NetworkEdgesPainter(
                      graph: widget.graph,
                      selectedEdgeId: widget.selectedEdgeId,
                      connectFromId: _connectingFromId,
                    ),
                  ),
                  for (final node in widget.graph.nodes)
                    Positioned(
                      left: node.posX,
                      top: node.posY,
                      child: _NetworkNodeChip(
                        node: node,
                        isArabic: widget.isArabic,
                        selected: node.id == widget.selectedNodeId,
                        showConnectHandle: !widget.readOnly,
                        connecting: node.id == _connectingFromId,
                        readOnly: widget.readOnly,
                        onTap: () => _handleNodeTap(node),
                        onMoved: (pos) => widget.onNodeMoved?.call(node, pos),
                        onDragLock: (locked) =>
                            setState(() => _interactionLocked = locked),
                        onConnectStart: () {
                          setState(() => _connectingFromId = node.id);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkNodeChip extends StatelessWidget {
  const _NetworkNodeChip({
    required this.node,
    required this.isArabic,
    required this.selected,
    required this.showConnectHandle,
    required this.connecting,
    required this.readOnly,
    required this.onTap,
    required this.onMoved,
    required this.onDragLock,
    required this.onConnectStart,
  });

  final SiteNetworkNode node;
  final bool isArabic;
  final bool selected;
  final bool showConnectHandle;
  final bool connecting;
  final bool readOnly;
  final VoidCallback onTap;
  final ValueChanged<Offset> onMoved;
  final ValueChanged<bool> onDragLock;
  final VoidCallback onConnectStart;

  @override
  Widget build(BuildContext context) {
    final color = networkNodeColor(node.kind);
    final subtitle = node.displaySubtitle(isAr: isArabic);
    return GestureDetector(
      onTap: onTap,
      onPanStart: readOnly ? null : (_) => onDragLock(true),
      onPanUpdate: readOnly
          ? null
          : (details) {
              final next = Offset(
                (node.posX + details.delta.dx).clamp(
                  0,
                  kNetworkCanvasWidth - kNetworkNodeWidth,
                ),
                (node.posY + details.delta.dy).clamp(
                  0,
                  kNetworkCanvasHeight - kNetworkNodeHeight,
                ),
              );
              onMoved(next);
            },
      onPanEnd: readOnly ? null : (_) => onDragLock(false),
      child: SizedBox(
        width: kNetworkNodeWidth,
        height: kNetworkNodeHeight,
        child: Material(
          elevation: selected || connecting ? 4 : 1,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected || connecting
                  ? color
                  : color.withValues(alpha: 0.35),
              width: selected || connecting ? 2.2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              children: [
                Icon(networkNodeIcon(node.kind), color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        node.displayTitle(isAr: isArabic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                if (showConnectHandle)
                  GestureDetector(
                    onTap: onConnectStart,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkEdgesPainter extends CustomPainter {
  _NetworkEdgesPainter({
    required this.graph,
    this.selectedEdgeId,
    this.connectFromId,
  });

  final SiteNetworkGraph graph;
  final String? selectedEdgeId;
  final String? connectFromId;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (final edge in graph.edges) {
      final from = graph.nodeById(edge.fromNodeId);
      final to = graph.nodeById(edge.toNodeId);
      if (from == null || to == null) continue;
      final a = Offset(
        from.posX + kNetworkNodeWidth,
        from.posY + kNetworkNodeHeight / 2,
      );
      final b = Offset(to.posX, to.posY + kNetworkNodeHeight / 2);
      paint.color = edge.id == selectedEdgeId
          ? AppColors.navy
          : _edgeColor(edge.edgeKind);
      paint.strokeWidth = edge.id == selectedEdgeId ? 3 : 2;
      _drawArrow(canvas, a, b, paint);
    }

    if (connectFromId != null) {
      final from = graph.nodeById(connectFromId!);
      if (from != null) {
        final a = Offset(
          from.posX + kNetworkNodeWidth + 8,
          from.posY + kNetworkNodeHeight / 2,
        );
        paint
          ..color = AppColors.gold.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(a, 6, paint);
        paint.style = PaintingStyle.stroke;
      }
    }
  }

  Color _edgeColor(NetworkEdgeKind kind) {
    return switch (kind) {
      NetworkEdgeKind.supply => const Color(0xFF2563EB),
      NetworkEdgeKind.pour => const Color(0xFF0D9488),
      NetworkEdgeKind.overflow => const Color(0xFF7C3AED),
      NetworkEdgeKind.discharge => const Color(0xFFB45309),
    };
  }

  void _drawArrow(Canvas canvas, Offset a, Offset b, Paint paint) {
    canvas.drawLine(a, b, paint);
    final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
    const arrow = 10.0;
    final p1 = Offset(
      b.dx - arrow * math.cos(angle - 0.4),
      b.dy - arrow * math.sin(angle - 0.4),
    );
    final p2 = Offset(
      b.dx - arrow * math.cos(angle + 0.4),
      b.dy - arrow * math.sin(angle + 0.4),
    );
    final path = Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo(p1.dx, p1.dy)
      ..moveTo(b.dx, b.dy)
      ..lineTo(p2.dx, p2.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NetworkEdgesPainter oldDelegate) {
    return oldDelegate.graph != graph ||
        oldDelegate.selectedEdgeId != selectedEdgeId ||
        oldDelegate.connectFromId != connectFromId;
  }
}
