import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

Duration staggerGridDelayForIndex({
  required int index,
  required int crossAxisCount,
  Duration stagger = const Duration(milliseconds: 40),
}) {
  if (index < 0) {
    throw ArgumentError.value(index, 'index', 'must be non-negative');
  }
  if (crossAxisCount <= 0) {
    throw ArgumentError.value(
      crossAxisCount,
      'crossAxisCount',
      'must be positive',
    );
  }
  if (stagger < Duration.zero) {
    throw ArgumentError.value(stagger, 'stagger', 'must not be negative');
  }
  final row = index ~/ crossAxisCount;
  final column = index % crossAxisCount;
  return stagger * (row + column);
}

class StaggeredAnimatedGrid extends StatelessWidget {
  const StaggeredAnimatedGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.crossAxisCount = 3,
    this.spacing = NeonTheme.s8,
    this.padding,
    this.stagger = const Duration(milliseconds: 40),
    this.animationDuration = const Duration(milliseconds: 280),
    this.physics,
    this.shrinkWrap = false,
    this.childAspectRatio = 1,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int crossAxisCount;
  final double spacing;
  final EdgeInsetsGeometry? padding;
  final Duration stagger;
  final Duration animationDuration;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    if (itemCount < 0) {
      throw ArgumentError.value(itemCount, 'itemCount', 'must be non-negative');
    }
    if (crossAxisCount <= 0) {
      throw ArgumentError.value(
        crossAxisCount,
        'crossAxisCount',
        'must be positive',
      );
    }
    if (spacing < 0 || !spacing.isFinite) {
      throw ArgumentError.value(
        spacing,
        'spacing',
        'must be finite and non-negative',
      );
    }
    if (stagger < Duration.zero) {
      throw ArgumentError.value(stagger, 'stagger', 'must not be negative');
    }
    if (animationDuration <= Duration.zero) {
      throw ArgumentError.value(
        animationDuration,
        'animationDuration',
        'must be positive',
      );
    }
    if (childAspectRatio <= 0 || !childAspectRatio.isFinite) {
      throw ArgumentError.value(
        childAspectRatio,
        'childAspectRatio',
        'must be finite and positive',
      );
    }

    return GridView.builder(
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final child = itemBuilder(context, index);
        if (NeonTheme.reducedMotion(context)) return child;
        return _StaggeredGridItem(
          key: ValueKey(index),
          delay: staggerGridDelayForIndex(
            index: index,
            crossAxisCount: crossAxisCount,
            stagger: stagger,
          ),
          duration: animationDuration,
          child: child,
        );
      },
    );
  }
}

class _StaggeredGridItem extends StatefulWidget {
  const _StaggeredGridItem({
    super.key,
    required this.delay,
    required this.duration,
    required this.child,
  });

  final Duration delay;
  final Duration duration;
  final Widget child;

  @override
  State<_StaggeredGridItem> createState() => _StaggeredGridItemState();
}

class _StaggeredGridItemState extends State<_StaggeredGridItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );
  Timer? _delayTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _delayTimer = Timer(widget.delay, () {
      if (!mounted) return;
      _started = true;
      _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _StaggeredGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.delay != widget.delay && !_started) {
      _delayTimer?.cancel();
      _delayTimer = Timer(widget.delay, () {
        if (!mounted) return;
        _started = true;
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) {
      final t = _started ? _progress.value : 0.0;
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
        ),
      );
    },
  );
}
