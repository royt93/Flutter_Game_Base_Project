import 'package:flutter/material.dart';

import '../../../core/haptics.dart';
import '../../../core/neon_theme.dart';
import '../../../core/storage_service.dart';
import '../pressable_scale.dart';
import '../spring_scale_transition.dart';

enum SwipeSide { start, end }

class SwipeableAction {
  SwipeableAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.semanticLabel,
    this.width = 72,
  }) {
    if (!width.isFinite || width <= 0) {
      throw ArgumentError.value(width, 'width', 'must be positive and finite');
    }
  }

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  final String? semanticLabel;
  final double width;
}

class SwipeableActionTile extends StatefulWidget {
  SwipeableActionTile({
    super.key,
    required this.child,
    this.leadingActions = const [],
    this.trailingActions = const [],
    this.revealThreshold = 0.4,
    this.hapticThreshold = 0.5,
    this.enableHaptic = true,
    this.resistance = 0.3,
    this.onRevealed,
    this.onClosed,
  }) {
    if (!revealThreshold.isFinite ||
        revealThreshold <= 0 ||
        revealThreshold >= 1) {
      throw ArgumentError.value(
        revealThreshold,
        'revealThreshold',
        'must be strictly between 0 and 1',
      );
    }
    if (!hapticThreshold.isFinite ||
        hapticThreshold <= 0 ||
        hapticThreshold >= 1) {
      throw ArgumentError.value(
        hapticThreshold,
        'hapticThreshold',
        'must be strictly between 0 and 1',
      );
    }
    if (!resistance.isFinite || resistance <= 0 || resistance > 1) {
      throw ArgumentError.value(
        resistance,
        'resistance',
        'must be between 0 and 1',
      );
    }
  }

  final Widget child;
  final List<SwipeableAction> leadingActions;
  final List<SwipeableAction> trailingActions;
  final double revealThreshold;
  final double hapticThreshold;
  final bool enableHaptic;
  final double resistance;
  final ValueChanged<SwipeSide>? onRevealed;
  final VoidCallback? onClosed;

  @override
  State<SwipeableActionTile> createState() => SwipeableActionTileState();
}

class SwipeableActionTileState extends State<SwipeableActionTile>
    with SingleTickerProviderStateMixin {
  late final SpringSimulationController _spring = SpringSimulationController(
    vsync: this,
    preset: SpringMotionPreset.snappy,
    initialValue: 0,
  );

  bool _thresholdCrossed = false;
  double _dragOffset = 0;
  bool _isDragging = false;

  double get offset => _spring.value;
  bool get isOpen => _spring.value != 0;

  double get _leadingWidth =>
      widget.leadingActions.fold<double>(0, (acc, item) => acc + item.width);

  double get _trailingWidth =>
      widget.trailingActions.fold<double>(0, (acc, item) => acc + item.width);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void openLeading() {
    if (_leadingWidth <= 0) return;
    _animateToOffset(_leadingWidth);
    widget.onRevealed?.call(SwipeSide.start);
  }

  void openTrailing() {
    if (_trailingWidth <= 0) return;
    _animateToOffset(-_trailingWidth);
    widget.onRevealed?.call(SwipeSide.end);
  }

  void close() {
    if (_spring.value == 0) return;
    _animateToOffset(0);
    widget.onClosed?.call();
  }

  void _animateToOffset(double target) {
    _spring.animateTo(target, reducedMotion: NeonTheme.reducedMotion(context));
  }

  double _applyResistance(double delta, double maxExtent) {
    if (maxExtent <= 0) return delta * 0.1;
    if (delta > maxExtent) {
      return maxExtent + (delta - maxExtent) * widget.resistance;
    }
    if (delta < -maxExtent) {
      return -maxExtent + (delta + maxExtent) * widget.resistance;
    }
    return delta;
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragOffset = _spring.value;
    _thresholdCrossed = false;
  }

  void _handleDragUpdate(DragUpdateDetails details, bool isRtl) {
    final logicalDelta = isRtl ? -details.delta.dx : details.delta.dx;
    _dragOffset += logicalDelta;

    final targetOffset = _dragOffset >= 0
        ? _applyResistance(_dragOffset, _leadingWidth)
        : _applyResistance(_dragOffset, _trailingWidth);

    _spring.jumpTo(targetOffset);

    // Haptic threshold check
    final activeWidth = targetOffset > 0 ? _leadingWidth : _trailingWidth;
    if (activeWidth > 0) {
      final progress = targetOffset.abs() / activeWidth;
      final crossed = progress >= widget.hapticThreshold;
      if (crossed && !_thresholdCrossed) {
        _thresholdCrossed = true;
        if (widget.enableHaptic && StorageService.maybe != null) {
          fireHaptic(HapticLevel.light);
        }
      }
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    final current = _spring.value;
    if (current > 0 && _leadingWidth > 0) {
      final ratio = current / _leadingWidth;
      if (ratio >= widget.revealThreshold) {
        _animateToOffset(_leadingWidth);
        widget.onRevealed?.call(SwipeSide.start);
      } else {
        close();
      }
    } else if (current < 0 && _trailingWidth > 0) {
      final ratio = -current / _trailingWidth;
      if (ratio >= widget.revealThreshold) {
        _animateToOffset(-_trailingWidth);
        widget.onRevealed?.call(SwipeSide.end);
      } else {
        close();
      }
    } else {
      close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return AnimatedBuilder(
      animation: _spring.animation,
      builder: (context, _) {
        final currentOffset = _spring.value;
        final physicalOffset = isRtl ? -currentOffset : currentOffset;
        final hasLeading = widget.leadingActions.isNotEmpty;
        final hasTrailing = widget.trailingActions.isNotEmpty;
        final showLeading = currentOffset > 0 && hasLeading;
        final showTrailing = currentOffset < 0 && hasTrailing;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Background actions layer
            Positioned.fill(
              child: Row(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  if (hasLeading)
                    ExcludeSemantics(
                      excluding: !showLeading,
                      child: IgnorePointer(
                        ignoring: !showLeading,
                        child: Row(
                          children: [
                            for (final action in widget.leadingActions)
                              _buildActionButton(action),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (hasTrailing)
                    ExcludeSemantics(
                      excluding: !showTrailing,
                      child: IgnorePointer(
                        ignoring: !showTrailing,
                        child: Row(
                          children: [
                            for (final action in widget.trailingActions)
                              _buildActionButton(action),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Foreground sliding child
            Transform.translate(
              offset: Offset(physicalOffset, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: (d) => _handleDragUpdate(d, isRtl),
                onHorizontalDragEnd: _handleDragEnd,
                onTap: isOpen && !_isDragging ? close : null,
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton(SwipeableAction action) {
    final bg = action.color ?? NeonTheme.purple;
    return Semantics(
      button: true,
      label: action.semanticLabel ?? action.label,
      child: PressableScale(
        key: ValueKey('swipeAction_${action.label}'),
        onTap: () {
          action.onTap();
          close();
        },
        child: Container(
          width: action.width,
          color: bg,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: NeonTheme.s8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (action.icon != null) ...[
                Icon(action.icon, color: Colors.white, size: 24),
                const SizedBox(height: 4),
              ],
              Text(
                action.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
