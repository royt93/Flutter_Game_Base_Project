import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/energy_service.dart';
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
    this.semanticLabel,
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

  /// Overrides the default "Energy: N/M" (or "Energy: infinite") Semantics
  /// label (ENH-37).
  final String? semanticLabel;

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
    final label =
        widget.semanticLabel ??
        (widget.hasInfiniteLives
            ? 'Energy: infinite'
            : 'Energy: ${widget.currentEnergy}/${widget.maxEnergy}'
                  '${widget.currentEnergy < widget.maxEnergy ? ', next in ${fmtDur(_remaining)}' : ''}');
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
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
          if (showCountdown) ...[
            const SizedBox(width: NeonTheme.s8),
            countdown,
          ],
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

/// Service-bound freshness wrapper for [EnergyBar] (BUG-95).
///
/// [EnergyBar] intentionally remains a plain-data display widget (same
/// convention as `LevelSelectGrid`/`DailyLoginCalendarWidget`) so it is easy
/// to reuse and test without GetX. This wrapper is the opt-in bridge for live
/// HUDs that DO want to follow [EnergyService]'s lazy refill state: it polls
/// the service at [pollInterval], which causes [EnergyService.currentEnergy]
/// to run its lazy `_regen()` calculation and rebuilds the child only when
/// the rendered values actually change.
///
/// If no service is supplied and [EnergyService.maybe] is unavailable, this
/// renders [SizedBox.shrink] rather than throwing — same null-safe startup
/// convention as `AudioManager.maybe`/`EnergyService.maybe` elsewhere.
class ReactiveEnergyBar extends StatefulWidget {
  const ReactiveEnergyBar({
    super.key,
    this.energyService,
    this.pollInterval = const Duration(seconds: 1),
    this.direction = Axis.vertical,
    this.icon = Icons.favorite,
    this.emptyIcon = Icons.favorite_border,
    this.color,
    this.semanticLabel,
  });

  final EnergyService? energyService;
  final Duration pollInterval;
  final Axis direction;
  final IconData icon;
  final IconData emptyIcon;
  final Color? color;
  final String? semanticLabel;

  @override
  State<ReactiveEnergyBar> createState() => _ReactiveEnergyBarState();
}

class _ReactiveEnergyBarState extends State<ReactiveEnergyBar> {
  Timer? _timer;
  int? _energy;
  Duration _untilNext = Duration.zero;
  bool _infinite = false;

  EnergyService? get _service => widget.energyService ?? EnergyService.maybe;

  @override
  void initState() {
    super.initState();
    _refresh(force: true);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant ReactiveEnergyBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pollInterval != widget.pollInterval ||
        oldWidget.energyService != widget.energyService) {
      _refresh(force: true);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.pollInterval <= Duration.zero) return;
    _timer = Timer.periodic(widget.pollInterval, (_) => _refresh());
  }

  void _refresh({bool force = false}) {
    final service = _service;
    if (service == null) {
      if (force) _energy = null;
      return;
    }
    final nextEnergy = service.currentEnergy;
    final nextUntil = service.timeUntilNextEnergy;
    final nextInfinite = service.hasInfiniteLives;
    final changed =
        force ||
        _energy != nextEnergy ||
        _untilNext != nextUntil ||
        _infinite != nextInfinite;
    if (!changed) return;
    if (!mounted) {
      _energy = nextEnergy;
      _untilNext = nextUntil;
      _infinite = nextInfinite;
      return;
    }
    setState(() {
      _energy = nextEnergy;
      _untilNext = nextUntil;
      _infinite = nextInfinite;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    final energy = _energy;
    if (service == null || energy == null) return const SizedBox.shrink();
    return EnergyBar(
      currentEnergy: energy,
      maxEnergy: service.maxEnergy,
      timeUntilNextEnergy: _untilNext,
      hasInfiniteLives: _infinite,
      direction: widget.direction,
      icon: widget.icon,
      emptyIcon: widget.emptyIcon,
      color: widget.color,
      semanticLabel: widget.semanticLabel,
    );
  }
}
