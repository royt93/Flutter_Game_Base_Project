import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';

double _finitePositive(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'must be finite and positive');
  }
  return value;
}

Offset radialActionOffsetForIndex({
  required int index,
  required int itemCount,
  required double radius,
  required double startAngleDegrees,
  required double sweepAngleDegrees,
}) {
  if (itemCount <= 0) {
    throw ArgumentError.value(itemCount, 'itemCount', 'must be positive');
  }
  if (index < 0 || index >= itemCount) {
    throw ArgumentError.value(index, 'index', 'must be within the item range');
  }
  _finitePositive(radius, 'radius');
  if (!startAngleDegrees.isFinite || !sweepAngleDegrees.isFinite) {
    throw ArgumentError('angles must be finite');
  }
  final fraction = itemCount == 1 ? 0.5 : index / (itemCount - 1);
  final angle =
      (startAngleDegrees + sweepAngleDegrees * fraction) * math.pi / 180;
  return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
}

class RadialActionItem {
  const RadialActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;
  final Color? color;
}

class RadialActionMenu extends StatefulWidget {
  const RadialActionMenu({
    super.key,
    required this.items,
    this.alignment = Alignment.bottomRight,
    this.radius = 104,
    this.startAngleDegrees = 180,
    this.sweepAngleDegrees = 90,
    this.buttonSize = 56,
    this.color,
    this.semanticLabel = 'Actions',
    this.onDismissed,
  });

  final List<RadialActionItem> items;
  final Alignment alignment;
  final double radius;
  final double startAngleDegrees;
  final double sweepAngleDegrees;
  final double buttonSize;
  final Color? color;
  final String semanticLabel;
  final VoidCallback? onDismissed;

  @override
  State<RadialActionMenu> createState() => RadialActionMenuState();
}

class RadialActionMenuState extends State<RadialActionMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isOpen = false;

  bool get isOpen => _isOpen;
  double get progress => _controller.value;

  @override
  void initState() {
    super.initState();
    _validate();
    _controller = AnimationController(
      vsync: this,
      duration: NeonTheme.motionDefault,
    );
  }

  void _validate() {
    if (widget.items.isEmpty) {
      throw ArgumentError.value(widget.items, 'items', 'must not be empty');
    }
    _finitePositive(widget.radius, 'radius');
    _finitePositive(widget.buttonSize, 'buttonSize');
    if (!widget.startAngleDegrees.isFinite ||
        !widget.sweepAngleDegrees.isFinite ||
        widget.sweepAngleDegrees.abs() > 360) {
      throw ArgumentError(
        'angles must be finite and sweep must be at most 360°',
      );
    }
  }

  @override
  void didUpdateWidget(covariant RadialActionMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validate();
  }

  void open() {
    if (isOpen) return;
    setState(() => _isOpen = true);
    if (NeonTheme.reducedMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  void close() {
    if (!isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse();
    widget.onDismissed?.call();
  }

  void toggle() => isOpen ? close() : open();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NeonTheme.reducedMotion(context) && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? NeonTheme.magenta;
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final open = _controller.value > 0;
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (open)
                  Positioned.fill(
                    child: GestureDetector(
                      key: const ValueKey('radialActionBarrier'),
                      behavior: HitTestBehavior.opaque,
                      onTap: close,
                      child: const SizedBox.expand(),
                    ),
                  ),
                for (var i = 0; i < widget.items.length; i++)
                  _buildAction(i, color, size: size, open: open),
                Align(
                  alignment: widget.alignment,
                  child: Semantics(
                    button: true,
                    expanded: open,
                    label: widget.semanticLabel,
                    onTap: toggle,
                    child: SizedBox(
                      width: widget.buttonSize,
                      height: widget.buttonSize,
                      child: CommonButton(
                        key: const ValueKey('radialActionPrimary'),
                        icon: open ? Icons.close_rounded : Icons.add_rounded,
                        variant: CommonButtonVariant.icon,
                        color: color,
                        semanticLabel: widget.semanticLabel,
                        width: widget.buttonSize,
                        onTap: toggle,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAction(
    int index,
    Color color, {
    required Size size,
    required bool open,
  }) {
    final item = widget.items[index];
    final offset = radialActionOffsetForIndex(
      index: index,
      itemCount: widget.items.length,
      radius: widget.radius,
      startAngleDegrees: widget.startAngleDegrees,
      sweepAngleDegrees: widget.sweepAngleDegrees,
    );
    final intervalStart = index * 0.08;
    final textDirection = Directionality.of(context);
    final anchor = Offset(
      size.width / 2 +
          widget.alignment.x * (size.width - widget.buttonSize) / 2,
      size.height / 2 +
          widget.alignment.y * (size.height - widget.buttonSize) / 2,
    );
    final t = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        intervalStart.clamp(0.0, 0.9),
        (intervalStart + 0.8).clamp(0.1, 1.0),
        curve: Curves.easeOutBack,
      ),
    );
    return AnimatedBuilder(
      animation: t,
      child: Semantics(
        button: true,
        label: item.semanticLabel ?? item.label,
        child: CommonButton(
          key: ValueKey('radialAction_${index}_${item.label}'),
          icon: item.icon,
          variant: CommonButtonVariant.icon,
          semanticLabel: item.semanticLabel ?? item.label,
          color: item.color ?? color,
          width: widget.buttonSize,
          onTap: () {
            item.onTap();
            close();
          },
        ),
      ),
      builder: (context, child) {
        final progress = t.value;
        final physicalLeft =
            anchor.dx + offset.dx * progress - widget.buttonSize / 2;
        final start = textDirection == TextDirection.ltr
            ? physicalLeft
            : size.width - physicalLeft - widget.buttonSize;
        return PositionedDirectional(
          start: start,
          top: anchor.dy + offset.dy * progress - widget.buttonSize / 2,
          child: IgnorePointer(
            ignoring: !open || progress < 0.5,
            child: Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.72 + progress * 0.28,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
