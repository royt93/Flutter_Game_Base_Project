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
    this.onRefillTap,
    this.enableStatusPulse = true,
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

  /// When non-null, a compact (+) button is shown after the pips/countdown
  /// and calls this on tap — the caller decides what "refill" means (open a
  /// shop, ask friends, watch an ad). `null` (default) shows no button, so
  /// existing callers are unchanged. Hidden while [hasInfiniteLives].
  final VoidCallback? onRefillTap;

  /// Heartbeat pulse on the pips while lives are at zero (danger) — skipped
  /// under Reduce Motion, when [hasInfiniteLives], or when `false`.
  final bool enableStatusPulse;

  @override
  State<EnergyBar> createState() => _EnergyBarState();
}

class _EnergyBarState extends State<EnergyBar>
    with SingleTickerProviderStateMixin {
  late Duration _remaining = widget.timeUntilNextEnergy;
  Timer? _timer;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool get _wantsPulse =>
      widget.enableStatusPulse &&
      !widget.hasInfiniteLives &&
      widget.currentEnergy <= 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(EnergyBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeUntilNextEnergy != widget.timeUntilNextEnergy) {
      _remaining = widget.timeUntilNextEnergy;
      _startTimer();
    }
    _syncPulse();
  }

  void _syncPulse() {
    final run = _wantsPulse && !NeonTheme.reducedMotion(context);
    if (run && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!run && (_pulse.isAnimating || _pulse.value != 0)) {
      _pulse
        ..stop()
        ..value = 0;
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
    _pulse.dispose();
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
    final mainBar = Semantics(
      label: label,
      excludeSemantics: true,
      child: _buildContent(context),
    );

    if (widget.onRefillTap == null || widget.hasInfiniteLives) {
      return mainBar;
    }

    final refillButton = Padding(
      padding: const EdgeInsetsDirectional.only(start: NeonTheme.s8),
      child: Semantics(
        button: true,
        label: 'Refill lives',
        child: GestureDetector(
          key: const ValueKey('energyBarRefillBtn'),
          onTap: widget.onRefillTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: NeonTheme.card,
              shape: BoxShape.circle,
              border: Border.all(color: NeonTheme.lime, width: 2),
              boxShadow: NeonTheme.drop(blur: 4),
            ),
            child: Icon(Icons.add_rounded, color: NeonTheme.lime, size: 20),
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [mainBar, refillButton],
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
    final pips = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final pulseScale = _wantsPulse && !reducedMotion
            ? 1 + 0.05 * _pulse.value
            : 1.0;
        return Transform.scale(
          key: const ValueKey('energyBarPulse'),
          scale: pulseScale,
          child: child,
        );
      },
      child: Wrap(
        spacing: 4,
        children: List.generate(widget.maxEnergy, (i) {
          final filled = i < widget.currentEnergy;
          final icon = Icon(
            filled ? widget.icon : widget.emptyIcon,
            color: filled ? fillColor : NeonTheme.muted,
            size: 24,
          );
          return reducedMotion
              ? icon
              : AnimatedScale(
                  scale: filled ? 1.0 : 0.9,
                  duration: const Duration(milliseconds: 150),
                  child: icon,
                );
        }),
      ),
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

    final pipsAndCountdown = widget.direction == Axis.horizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              pips,
              if (showCountdown) ...[
                const SizedBox(width: NeonTheme.s8),
                countdown,
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              pips,
              if (showCountdown) ...[
                const SizedBox(height: NeonTheme.s8),
                countdown,
              ],
            ],
          );

    return pipsAndCountdown;
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
    this.onRefillTap,
    this.enableStatusPulse = true,
  });

  final EnergyService? energyService;
  final Duration pollInterval;
  final Axis direction;
  final IconData icon;
  final IconData emptyIcon;
  final Color? color;
  final String? semanticLabel;
  final VoidCallback? onRefillTap;
  final bool enableStatusPulse;

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
      onRefillTap: widget.onRefillTap,
      enableStatusPulse: widget.enableStatusPulse,
    );
  }
}

/// Semantic alias for [EnergyBar] matching the Lives/Heart HUD pattern (FEAT-126).
typedef LivesHeartHud = EnergyBar;

/// Semantic alias for [ReactiveEnergyBar] matching the Lives/Heart HUD pattern (FEAT-126).
typedef ReactiveLivesHeartHud = ReactiveEnergyBar;
