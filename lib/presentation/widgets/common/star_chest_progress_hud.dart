import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Pure math helper: computes the clamped progress fraction [0.0..1.0] for star chest collection (FEAT-134).
double starChestProgressFraction(int current, int target) {
  if (target <= 0) {
    throw ArgumentError.value(target, 'target', 'must be positive');
  }
  if (current < 0) {
    throw ArgumentError.value(current, 'current', 'must be non-negative');
  }
  return (current / target).clamp(0.0, 1.0);
}

/// A compact horizontal capsule HUD displaying accumulated stars toward unlocking a Star Chest (FEAT-134).
///
/// Features:
/// - Chest icon on the left with a mini star emblem.
/// - Star collection progress bar on the right with actual count e.g. "24/20 ⭐" when exceeded.
/// - Golden pulse celebration effect and "Open!" callout when ready (`currentStars >= targetStars`).
/// - Tap invokes [onOpenChestTap] when ready, or [onInfoTap] when not yet ready.
/// - Reduced Motion: bypasses repeating golden pulse and shows a clean static ready state.
/// - Pure presentation: caller owns star balances and chest reward transactions.
class StarChestProgressHud extends StatefulWidget {
  StarChestProgressHud({
    super.key,
    required this.currentStars,
    required this.targetStars,
    this.onOpenChestTap,
    this.onInfoTap,
    this.height = 38,
    this.width = 160,
    this.chestColor,
    this.trackColor,
    this.semanticLabel,
  }) {
    if (currentStars < 0) {
      throw ArgumentError.value(
        currentStars,
        'currentStars',
        'must be non-negative',
      );
    }
    if (targetStars <= 0) {
      throw ArgumentError.value(targetStars, 'targetStars', 'must be positive');
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

  final int currentStars;
  final int targetStars;
  final VoidCallback? onOpenChestTap;
  final VoidCallback? onInfoTap;
  final double height;
  final double? width;
  final Color? chestColor;
  final Color? trackColor;
  final String? semanticLabel;

  @override
  State<StarChestProgressHud> createState() => _StarChestProgressHudState();
}

class _StarChestProgressHudState extends State<StarChestProgressHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  bool get _isReady => widget.currentStars >= widget.targetStars;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant StarChestProgressHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStars != widget.currentStars ||
        oldWidget.targetStars != widget.targetStars) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    final run = _isReady && !NeonTheme.reducedMotion(context);
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
    final reducedMotion = NeonTheme.reducedMotion(context);
    final gold = widget.chestColor ?? NeonTheme.gold;
    final track = widget.trackColor ?? NeonTheme.cardAlt;
    final ready = _isReady;
    final fraction = starChestProgressFraction(
      widget.currentStars,
      widget.targetStars,
    );
    final radius = BorderRadius.circular(widget.height / 2);

    final String defaultSemantics;
    if (ready) {
      defaultSemantics =
          'Star chest ready to open, ${widget.currentStars} of ${widget.targetStars} stars, tap to open';
    } else {
      defaultSemantics =
          'Star chest, ${widget.currentStars} of ${widget.targetStars} stars';
    }

    final hudContent = AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseT = reducedMotion || !ready ? 0.0 : _pulseController.value;
        final pulseScale = 1.0 + 0.04 * pulseT;
        final glowColor = gold.withValues(alpha: 0.2 + 0.45 * pulseT);

        return Transform.scale(
          key: const ValueKey('starChestPulseScale'),
          scale: pulseScale,
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
            decoration: BoxDecoration(
              color: NeonTheme.card,
              borderRadius: radius,
              border: Border.all(
                color: ready ? gold : NeonTheme.cardAlt,
                width: ready ? 2.0 : 1.5,
              ),
              boxShadow: ready
                  ? NeonTheme.glow(glowColor, blur: 10)
                  : NeonTheme.drop(blur: 4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Chest Icon with Star Emblem
                Container(
                  width: widget.height - 8,
                  height: widget.height - 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NeonTheme.cardAlt,
                    border: Border.all(
                      color: ready ? gold : NeonTheme.inkSoft,
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        size: (widget.height - 8) * 0.58,
                        color: ready ? gold : NeonTheme.inkSoft,
                      ),
                      PositionedDirectional(
                        end: 0,
                        top: 0,
                        child: Icon(
                          Icons.star_rounded,
                          size: (widget.height - 8) * 0.42,
                          color: gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: NeonTheme.s8),

                // Star progress bar or Open! badge
                Expanded(
                  child: ready
                      ? Container(
                          key: const ValueKey('starChestOpenBadge'),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: gold,
                            borderRadius: BorderRadius.circular(
                              widget.height / 3,
                            ),
                            boxShadow: NeonTheme.drop(blur: 3),
                          ),
                          child: Text(
                            'Open!',
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fraction bar
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final totalWidth = constraints.maxWidth;
                                final fillWidth = totalWidth * fraction;

                                return Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: track,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Stack(
                                    alignment: AlignmentDirectional.centerStart,
                                    children: [
                                      AnimatedContainer(
                                        duration: reducedMotion
                                            ? Duration.zero
                                            : const Duration(milliseconds: 250),
                                        curve: Curves.easeOut,
                                        width: fillWidth,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: gold,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 2),
                            // Actual count text e.g. "24/20 ⭐"
                            Text(
                              '${widget.currentStars}/${widget.targetStars} ⭐',
                              key: const ValueKey('starChestCountText'),
                              style: TextStyle(
                                color: NeonTheme.ink,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return Semantics(
      container: true,
      button: true,
      label: widget.semanticLabel ?? defaultSemantics,
      value: ready ? 'ready' : '$fraction',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('starChestTapTarget'),
          behavior: HitTestBehavior.opaque,
          onTap: ready ? widget.onOpenChestTap : widget.onInfoTap,
          child: RepaintBoundary(child: hudContent),
        ),
      ),
    );
  }
}
