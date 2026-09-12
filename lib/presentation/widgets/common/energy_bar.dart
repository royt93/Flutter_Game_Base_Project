import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';

/// Row of `maxEnergy` heart pips (filled up to `currentEnergy`, dimmed
/// beyond), plus a live-ticking `mm:ss` countdown to the next regen point —
/// a pure display widget, it holds no energy state of its own. The caller
/// reads `EnergyService` and hands in [currentEnergy]/[maxEnergy]/
/// [timeUntilNextEnergy]/[hasInfiniteLives], matching this kit's convention
/// (see `LevelSelectGrid`/`DailyLoginCalendarWidget`) of widgets taking
/// plain data rather than reaching into a GetX service directly.
///
/// [timeUntilNextEnergy] is only the STARTING point for the countdown —
/// this widget drives its own `Timer.periodic` to animate it down to zero
/// for a live feel, it never re-queries `EnergyService` itself. A parent
/// that consumes energy (or otherwise learns of a fresh
/// `EnergyService.timeUntilNextEnergy`) should pass the new value back down
/// to restart the countdown from the correct point.
class EnergyBar extends StatefulWidget {
  const EnergyBar({
    super.key,
    required this.currentEnergy,
    required this.maxEnergy,
    required this.timeUntilNextEnergy,
    this.hasInfiniteLives = false,
    this.direction = Axis.vertical,
    this.icon = Icons.favorite,
    this.emptyIcon = Icons.favorite_border,
    this.color,
  });

  final int currentEnergy;
  final int maxEnergy;
  final Duration timeUntilNextEnergy;
  final bool hasInfiniteLives;

  /// `Axis.vertical` (default) stacks the pips above the countdown, e.g.
  /// for a standalone panel. `Axis.horizontal` lays them out side by side
  /// instead, for a compact app-bar-style placement.
  final Axis direction;

  /// Pip icon for a filled slot — swap for a different energy theme
  /// (bolt, shield, stamina, ...) instead of the default heart.
  final IconData icon;

  /// Pip icon for a dimmed/empty slot.
  final IconData emptyIcon;

  /// Filled pip color — defaults to [NeonTheme.red].
  final Color? color;

  @override
  State<EnergyBar> createState() => _EnergyBarState();
}

class _EnergyBarState extends State<EnergyBar> {
  late Duration _remaining = widget.timeUntilNextEnergy;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(EnergyBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeUntilNextEnergy != widget.timeUntilNextEnergy) {
      _remaining = widget.timeUntilNextEnergy;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_remaining <= Duration.zero) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final next = _remaining - const Duration(seconds: 1);
    setState(() => _remaining = next.isNegative ? Duration.zero : next);
    if (_remaining == Duration.zero) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasInfiniteLives) {
      return Text(
        '∞',
        style: TextStyle(
          color: NeonTheme.gold,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    final reducedMotion = NeonTheme.reducedMotion(context);
    final fillColor = widget.color ?? NeonTheme.red;
    final pips = Wrap(
      spacing: 4,
      children: List.generate(widget.maxEnergy, (i) {
        final filled = i < widget.currentEnergy;
        final icon = Icon(
          filled ? widget.icon : widget.emptyIcon,
          color: filled ? fillColor : NeonTheme.muted,
          size: 24,
        );
        // Decorative pop only for the pip that just changed state —
        // skipped entirely under Reduce Motion.
        return reducedMotion
            ? icon
            : AnimatedScale(
                scale: filled ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 150),
                child: icon,
              );
      }),
    );
    final showCountdown = widget.currentEnergy < widget.maxEnergy;
    final countdown = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, color: NeonTheme.inkSoft, size: 16),
        const SizedBox(width: 4),
        Text(
          fmtDur(_remaining),
          style: TextStyle(
            color: NeonTheme.inkSoft,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    // ENH-42: horizontal lays pips + countdown side by side (compact
    // app-bar placement); vertical (default) keeps the original stacked
    // layout unchanged.
    if (widget.direction == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pips,
          if (showCountdown) ...[const SizedBox(width: NeonTheme.s8), countdown],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        pips,
        if (showCountdown) ...[const SizedBox(height: NeonTheme.s8), countdown],
      ],
    );
  }
}
