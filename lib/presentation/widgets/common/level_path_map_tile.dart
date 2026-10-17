import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'level_select_grid.dart' show LevelState;

/// Pure math helper: computes center position of node [index] along an S-curve saga path (FEAT-133).
Offset levelPathNodeCenter(
  int index,
  double width, {
  double rowHeight = 96,
  double amplitude = 0.62,
}) {
  if (width <= 0) {
    throw ArgumentError.value(width, 'width', 'must be positive');
  }
  if (rowHeight <= 0) {
    throw ArgumentError.value(rowHeight, 'rowHeight', 'must be positive');
  }
  final xCenter = width / 2;
  final xOffset = math.sin(index * math.pi / 2) * (width * amplitude / 2);
  final y = (index + 0.5) * rowHeight;
  return Offset(xCenter + xOffset, y);
}

/// Data model for one level node along a [LevelPathMap] (FEAT-133).
class LevelPathNode {
  LevelPathNode({
    required this.level,
    required this.state,
    this.starsEarned = 0,
    this.isCurrent = false,
  }) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'must be at least 1');
    }
    if (starsEarned < 0 || starsEarned > 3) {
      throw ArgumentError.value(
        starsEarned,
        'starsEarned',
        'must be between 0 and 3',
      );
    }
  }

  final int level;
  final LevelState state;
  final int starsEarned;
  final bool isCurrent;

  bool get isLocked => state == LevelState.locked;
  bool get isCompleted => state == LevelState.completed;
  bool get isUnlocked => state == LevelState.unlocked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelPathNode &&
          level == other.level &&
          state == other.state &&
          starsEarned == other.starsEarned &&
          isCurrent == other.isCurrent;

  @override
  int get hashCode => Object.hash(level, state, starsEarned, isCurrent);
}

/// A single level map node representing a level button on a saga path (FEAT-133).
///
/// Features:
/// - Distinct visual states: Completed (gold with stars), Current (pulsing cyan glow), Locked (muted lock icon).
/// - Pulsing ring around the current node, disabled under Reduced Motion.
/// - Tap invokes [onTap] when unlocked or completed.
class LevelPathMapTile extends StatefulWidget {
  LevelPathMapTile({
    super.key,
    required this.node,
    this.onTap,
    this.size = 54,
  }) {
    if (!size.isFinite || size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be finite and positive');
    }
  }

  final LevelPathNode node;
  final VoidCallback? onTap;
  final double size;

  @override
  State<LevelPathMapTile> createState() => _LevelPathMapTileState();
}

class _LevelPathMapTileState extends State<LevelPathMapTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool get _shouldPulse => widget.node.isCurrent && !widget.node.isLocked;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant LevelPathMapTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    final run = _shouldPulse && !NeonTheme.reducedMotion(context);
    if (run && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!run &&
        (_pulseController.isAnimating || _pulseController.value != 0)) {
      _pulseController
        ..stop()
        ..value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final locked = node.isLocked;
    final completed = node.isCompleted;
    final current = node.isCurrent;
    final reducedMotion = NeonTheme.reducedMotion(context);

    final Color bgColor;
    final Color borderColor;
    if (locked) {
      bgColor = NeonTheme.lockedFill;
      borderColor = NeonTheme.lockedBorder;
    } else if (completed) {
      bgColor = NeonTheme.gold;
      borderColor = Colors.white;
    } else {
      bgColor = NeonTheme.card;
      borderColor = NeonTheme.cyan;
    }

    final String semanticsDesc;
    if (locked) {
      semanticsDesc = 'Level ${node.level}, locked';
    } else if (completed) {
      semanticsDesc =
          'Level ${node.level}, completed, ${node.starsEarned} stars';
    } else if (current) {
      semanticsDesc = 'Level ${node.level}, current, ready to play';
    } else {
      semanticsDesc = 'Level ${node.level}, unlocked';
    }

    final nodeButton = AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseT = reducedMotion || !_shouldPulse
            ? 0.0
            : _pulseController.value;
        final scale = 1.0 + 0.06 * pulseT;
        final glowColor = NeonTheme.cyan.withValues(alpha: 0.3 + 0.5 * pulseT);

        return Transform.scale(
          key: ValueKey('levelPathNodeScale_${node.level}'),
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(color: borderColor, width: 2.5),
              boxShadow: current
                  ? NeonTheme.glow(glowColor, blur: 10)
                  : (completed
                        ? NeonTheme.glow(NeonTheme.gold, blur: 6)
                        : NeonTheme.drop(blur: 4)),
            ),
            child: Center(
              child: locked
                  ? Icon(
                      Icons.lock_rounded,
                      key: ValueKey('levelPathLock_${node.level}'),
                      size: widget.size * 0.45,
                      color: NeonTheme.muted,
                    )
                  : Text(
                      '${node.level}',
                      key: ValueKey('levelPathNumber_${node.level}'),
                      style: TextStyle(
                        color: completed ? Colors.white : NeonTheme.ink,
                        fontSize: widget.size * 0.42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        );
      },
    );

    // Stars row for completed nodes
    final starsWidget = completed
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final earned = index < node.starsEarned;
              return Icon(
                Icons.star_rounded,
                size: 14,
                color: earned ? NeonTheme.gold : NeonTheme.cardAlt,
              );
            }),
          )
        : null;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        nodeButton,
        if (starsWidget != null) ...[const SizedBox(height: 2), starsWidget],
      ],
    );

    return Semantics(
      button: !locked,
      label: semanticsDesc,
      enabled: !locked,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('levelPathNodeTap_${node.level}'),
          behavior: HitTestBehavior.opaque,
          onTap: locked ? null : widget.onTap,
          child: RepaintBoundary(child: content),
        ),
      ),
    );
  }
}

/// S-curve winding saga path container holding 1 to N [LevelPathNode]s (FEAT-133).
///
/// Nodes are connected by a continuous dotted candy trail (Bézier curves).
/// By default, progresses bottom-up (`bottomUp = true`, Level 1 at the base).
class LevelPathMap extends StatelessWidget {
  LevelPathMap({
    super.key,
    required this.nodes,
    this.onLevelTap,
    this.bottomUp = true,
    this.rowHeight = 96,
    this.width = 320,
  }) {
    if (nodes.isEmpty) {
      throw ArgumentError.value(nodes, 'nodes', 'must not be empty');
    }
    if (!width.isFinite || width <= 0) {
      throw ArgumentError.value(width, 'width', 'must be positive and finite');
    }
    if (!rowHeight.isFinite || rowHeight <= 0) {
      throw ArgumentError.value(
        rowHeight,
        'rowHeight',
        'must be positive and finite',
      );
    }
  }

  final List<LevelPathNode> nodes;
  final void Function(int level)? onLevelTap;
  final bool bottomUp;
  final double rowHeight;
  final double width;

  @override
  Widget build(BuildContext context) {
    final orderedNodes = bottomUp ? nodes.reversed.toList() : nodes;
    final totalHeight = nodes.length * rowHeight;

    // Calculate node center positions
    final points = <Offset>[];
    for (var i = 0; i < orderedNodes.length; i++) {
      points.add(levelPathNodeCenter(i, width, rowHeight: rowHeight));
    }

    return SizedBox(
      width: width,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background dotted Bézier curve
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DottedPathPainter(
                  points: points,
                  nodes: orderedNodes,
                  bottomUp: bottomUp,
                ),
              ),
            ),
          ),

          // Nodes
          for (var i = 0; i < orderedNodes.length; i++)
            PositionedDirectional(
              start: points[i].dx - 32,
              top: points[i].dy - 32,
              child: LevelPathMapTile(
                node: orderedNodes[i],
                onTap: onLevelTap != null
                    ? () => onLevelTap!(orderedNodes[i].level)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _DottedPathPainter extends CustomPainter {
  const _DottedPathPainter({
    required this.points,
    required this.nodes,
    required this.bottomUp,
  });

  final List<Offset> points;
  final List<LevelPathNode> nodes;
  final bool bottomUp;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      // Segment path connecting p0 and p1
      final path = Path()..moveTo(p0.dx, p0.dy);
      final midY = (p0.dy + p1.dy) / 2;
      path.cubicTo(p0.dx, midY, p1.dx, midY, p1.dx, p1.dy);

      final nextNode = bottomUp ? nodes[i] : nodes[i + 1];
      final isUnlocked = !nextNode.isLocked;

      dotPaint.color = isUnlocked
          ? NeonTheme.gold.withValues(alpha: 0.85)
          : NeonTheme.cardAlt;

      final metrics = path.computeMetrics();
      for (final metric in metrics) {
        final length = metric.length;
        const step = 16.0;
        // Avoid placing dots right under the node circles
        for (var d = 24.0; d < length - 24.0; d += step) {
          final tangent = metric.getTangentForOffset(d);
          if (tangent != null) {
            canvas.drawCircle(tangent.position, 3.5, dotPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedPathPainter oldDelegate) =>
      points != oldDelegate.points || nodes != oldDelegate.nodes;
}
