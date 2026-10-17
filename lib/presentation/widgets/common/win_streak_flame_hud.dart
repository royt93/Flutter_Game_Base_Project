import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Returns the flame tint for the current win [streakCount] tier (FEAT-137).
///
/// - 0 wins: muted/neutral (no flame activation).
/// - 1 win: cool cyan.
/// - 2-4 wins: warm gold.
/// - 5+ wins: hot orange.
Color winStreakFlameColor(int streakCount) {
  if (streakCount <= 0) return NeonTheme.muted;
  if (streakCount == 1) return NeonTheme.cyan;
  if (streakCount <= 4) return NeonTheme.gold;
  return NeonTheme.orange;
}

/// Win streak HUD with escalating flame tiers and caller-owned reward multiplier (FEAT-137).
///
/// Features:
/// - Distinct flame tiers (Tier 0: muted, Tier 1: cyan, Tier 2: gold, Tier 3: orange).
/// - Gentle breathing flame pulse when streak is active (`streakCount > 0`).
/// - Celebratory scale pop on the multiplier badge when [streakCount] increases.
/// - No celebratory animation on streak drops or resets.
/// - Full accessibility semantics and Reduced Motion support.
class WinStreakFlameHud extends StatefulWidget {
  WinStreakFlameHud({
    super.key,
    required this.streakCount,
    this.multiplierLabel,
    this.onInfoTap,
    this.height = 36,
    this.width,
    this.color,
    this.semanticLabel,
  }) {
    if (streakCount < 0) {
      throw ArgumentError.value(
        streakCount,
        'streakCount',
        'must be non-negative',
      );
    }
    if (!height.isFinite || height <= 0) {
      throw ArgumentError.value(
        height,
        'height',
        'must be positive and finite',
      );
    }
    if (width != null && (!width!.isFinite || width! <= 0)) {
      throw ArgumentError.value(width, 'width', 'must be positive and finite');
    }
  }

  final int streakCount;
  final String? multiplierLabel;
  final VoidCallback? onInfoTap;
  final double height;
  final double? width;
  final Color? color;
  final String? semanticLabel;

  @override
  State<WinStreakFlameHud> createState() => _WinStreakFlameHudState();
}

class _WinStreakFlameHudState extends State<WinStreakFlameHud>
    with TickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final AnimationController _popController;
  bool _reducedMotion = false;

  bool get _hasStreak => widget.streakCount > 0;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = NeonTheme.reducedMotion(context);
    _syncBreathe();
  }

  @override
  void didUpdateWidget(covariant WinStreakFlameHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streakCount > oldWidget.streakCount && !_reducedMotion) {
      _popController.forward(from: 0.0);
    }
    _syncBreathe();
  }

  void _syncBreathe() {
    final shouldBreathe = _hasStreak && !_reducedMotion;
    if (shouldBreathe && !_breatheController.isAnimating) {
      _breatheController.repeat(reverse: true);
    } else if (!shouldBreathe && _breatheController.isAnimating) {
      _breatheController
        ..stop()
        ..value = 0.0;
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flameColor = widget.color ?? winStreakFlameColor(widget.streakCount);
    final active = _hasStreak;
    final multiplier = widget.multiplierLabel ?? 'x1';
    final spokenLabel =
        widget.semanticLabel ??
        'Win streak ${widget.streakCount}, reward multiplier $multiplier';

    return Semantics(
      container: true,
      label: spokenLabel,
      value: active ? multiplier : 'inactive',
      button: widget.onInfoTap != null,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('winStreakFlameTapTarget'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onInfoTap,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_breatheController, _popController]),
              builder: (context, _) {
                final breatheT = active && !_reducedMotion
                    ? _breatheController.value
                    : 0.0;
                final flameScale = 1.0 + 0.08 * breatheT;
                final glowAlpha = active && !_reducedMotion
                    ? 0.25 + 0.5 * breatheT
                    : 0.25;

                final popT = _popController.value;
                final popCurve = NeonTheme.curvePop.transform(popT);
                final popScale = _reducedMotion || popT == 0.0 || popT == 1.0
                    ? 1.0
                    : 1.0 +
                          0.20 *
                              math.sin(popT * math.pi) *
                              popCurve.clamp(0.0, 1.0);

                return Container(
                  width: widget.width,
                  height: widget.height,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: NeonTheme.card,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                    border: Border.all(
                      color: flameColor.withValues(alpha: active ? 0.7 : 0.3),
                      width: 1.5,
                    ),
                    boxShadow: active
                        ? NeonTheme.glow(
                            flameColor.withValues(alpha: glowAlpha),
                            blur: 8,
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: widget.width == null
                        ? MainAxisSize.min
                        : MainAxisSize.max,
                    children: [
                      Transform.scale(
                        key: const ValueKey('winStreakFlameScale'),
                        scale: flameScale,
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          key: const ValueKey('winStreakFlameIcon'),
                          color: flameColor,
                          size: widget.height * 0.7,
                        ),
                      ),
                      const SizedBox(width: NeonTheme.s8),
                      Text(
                        '${widget.streakCount} wins',
                        key: const ValueKey('winStreakCountText'),
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: widget.height * 0.34,
                        ),
                      ),
                      const SizedBox(width: NeonTheme.s8),
                      Transform.scale(
                        key: const ValueKey('winStreakBadgePopScale'),
                        scale: popScale,
                        child: Container(
                          key: const ValueKey('winStreakMultiplierBadge'),
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: active ? flameColor : NeonTheme.muted,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            multiplier,
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: widget.height * 0.32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
