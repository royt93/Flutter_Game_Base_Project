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

/// Offset of item [index] from the primary button's centre, for a fan of
/// [itemCount] items spread evenly over [sweepAngleDegrees] starting at
/// [startAngleDegrees].
///
/// Angles are in degrees with 0 pointing right and positive values turning
/// clockwise on screen (y grows downward). The first item sits exactly at
/// [startAngleDegrees] and the last at `start + sweep`; a single item is
/// placed at the middle of the sweep. Throws [ArgumentError] for a non-positive
/// [itemCount], an [index] outside `0..itemCount-1`, a [radius] that is not
/// finite and positive, or a non-finite angle.
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

/// One button in a [RadialActionMenu]'s fan.
class RadialActionItem {
  /// [onTap] runs first, then the menu closes itself; if it was still open
  /// that also fires [RadialActionMenu.onDismissed].
  const RadialActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.color,
  });

  /// Used as the accessibility label when [semanticLabel] is null, and as part
  /// of the button's `ValueKey` (`radialAction_<index>_<label>`).
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Screen-reader label that overrides [label] when set.
  final String? semanticLabel;

  /// Button colour; falls back to [RadialActionMenu.color], then
  /// [NeonTheme.magenta], when null.
  final Color? color;
}

/// A floating "+" button that fans [items] out along an arc when tapped.
///
/// The menu sizes itself to the maximum incoming constraints, so place it in
/// a bounded area (for example a `Stack` child with a known size);
/// [alignment] then decides which corner/edge the primary button anchors to.
/// While open, a full-area barrier closes the menu on any tap outside the
/// buttons. An item ignores taps until its own reveal progress reaches 0.5.
/// With reduced motion enabled opening is instant; closing still animates.
class RadialActionMenu extends StatefulWidget {
  /// [items] must not be empty, [radius] and [buttonSize] must be finite and
  /// positive, and the angles must be finite with `|sweepAngleDegrees| <= 360`;
  /// otherwise an [ArgumentError] is thrown when the state is created or the
  /// widget is updated.
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

  /// Actions in fan order, from [startAngleDegrees] towards
  /// `startAngleDegrees + sweepAngleDegrees`.
  final List<RadialActionItem> items;

  /// Where the primary button sits inside the available area (default bottom
  /// right). This is a physical [Alignment], so it is not flipped in
  /// right-to-left text directions.
  final Alignment alignment;

  /// Distance in logical pixels from the primary button's centre to each
  /// item's centre once fully open.
  final double radius;

  /// Angle of the first item; see [radialActionOffsetForIndex] for the
  /// convention. The default 180 points left.
  final double startAngleDegrees;

  /// Angle covered by the fan. With the defaults (180 and 90) the items arc
  /// from left to straight up, suiting the bottom-right default alignment.
  final double sweepAngleDegrees;

  /// Width given to the primary button and to each item button; the primary
  /// button is also given this height.
  final double buttonSize;

  /// Primary button colour (default [NeonTheme.magenta]); an item's own
  /// [RadialActionItem.color] takes precedence for that item.
  final Color? color;

  /// Accessibility label of the primary button.
  final String semanticLabel;

  /// Called whenever the menu goes from open to closed — barrier tap, item
  /// tap, the primary button, or a call to [RadialActionMenuState.close].
  /// Not called when the menu opens or when [RadialActionMenuState.close] is a
  /// no-op because it is already closed.
  final VoidCallback? onDismissed;

  @override
  State<RadialActionMenu> createState() => RadialActionMenuState();
}

/// State of [RadialActionMenu]; obtain it with a `GlobalKey` to open or close
/// the fan from outside (for example on a back-button press).
class RadialActionMenuState extends State<RadialActionMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isOpen = false;

  /// True from the moment [open] is called until [close] is called; it does
  /// not wait for the animation to finish.
  bool get isOpen => _isOpen;

  /// Reveal animation value from 0 (fully collapsed) to 1 (fully fanned out).
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

  /// Fans the items out. Does nothing if already open. Jumps straight to the
  /// fully open state when reduced motion is enabled.
  void open() {
    if (isOpen) return;
    setState(() => _isOpen = true);
    if (NeonTheme.reducedMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  /// Collapses the items and calls [RadialActionMenu.onDismissed]. Does
  /// nothing (and does not call it) if already closed.
  void close() {
    if (!isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse();
    widget.onDismissed?.call();
  }

  /// [close] if open, otherwise [open].
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
