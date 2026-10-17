import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'mystery_chest_opening.dart' show SunburstGodRays;

/// Upgrade ladder for [TieredRewardChest] (FEAT-124).
enum ChestTier {
  wood('Wood', Color(0xFF9A5B2B), Color(0xFFC98A4B), Color(0xFFE0B27A)),
  silver('Silver', Color(0xFF7D8794), Color(0xFFC3CBD6), Color(0xFFE9EEF5)),
  gold('Gold', Color(0xFFB8860B), Color(0xFFFFC928), Color(0xFFFFE27A)),
  diamond('Diamond', Color(0xFF1E88A8), Color(0xFF4DD0E1), Color(0xFFB2F5FF));

  const ChestTier(
    this.displayName,
    this.bodyColor,
    this.lidColor,
    this.rayColor,
  );

  final String displayName;
  final Color bodyColor;
  final Color lidColor;
  final Color rayColor;
}

/// Chest that visually upgrades Wood -> Silver -> Gold -> Diamond as the
/// caller raises [currentTier], then opens with tier-colored rays and the
/// caller-supplied reward for that tier (FEAT-124).
///
/// Pure presentation: the caller owns tier progression, the [isOpened] flag
/// and the reward widgets; this widget only animates. An upgrade (tier index
/// increases while closed) plays a squash-stretch + shake bounce; flipping
/// [isOpened] to `true` swings the lid open. Mounting already opened settles
/// without replaying the opening. Reduce Motion skips both animations.
class TieredRewardChest extends StatefulWidget {
  TieredRewardChest({
    super.key,
    required this.currentTier,
    required this.onOpen,
    this.isOpened = false,
    this.tierRewards,
    this.size = const Size(200, 180),
  }) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      throw ArgumentError.value(size, 'size', 'must be finite and positive');
    }
  }

  final ChestTier currentTier;

  /// Called when a closed chest is tapped; the caller then sets [isOpened].
  final VoidCallback onOpen;
  final bool isOpened;

  /// Reward widget to reveal per tier; the entry for [currentTier] is shown.
  final Map<ChestTier, Widget>? tierRewards;
  final Size size;

  @override
  State<TieredRewardChest> createState() => _TieredRewardChestState();
}

class _TieredRewardChestState extends State<TieredRewardChest>
    with TickerProviderStateMixin {
  late final AnimationController _upgrade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: NeonTheme.motionCelebrate,
    value: widget.isOpened ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant TieredRewardChest oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduced = NeonTheme.reducedMotion(context);
    if (widget.currentTier.index > oldWidget.currentTier.index &&
        !widget.isOpened &&
        !reduced) {
      _upgrade.forward(from: 0);
    }
    if (widget.isOpened != oldWidget.isOpened) {
      if (!widget.isOpened) {
        _open.value = 0;
      } else if (reduced) {
        _open.value = 1;
      } else {
        _open.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _upgrade.dispose();
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.currentTier;
    final reduced = NeonTheme.reducedMotion(context);
    return Semantics(
      key: const ValueKey('tieredChestTap'),
      button: !widget.isOpened,
      label: '${tier.displayName} chest',
      value: widget.isOpened ? 'opened' : 'closed',
      onTap: widget.isOpened ? null : widget.onOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isOpened ? null : widget.onOpen,
        child: SizedBox.fromSize(
          size: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_upgrade, _open]),
            builder: (context, _) {
              final t = _upgrade.value;
              final bump = math.sin(t * math.pi);
              final scaleX = 1 - 0.08 * bump;
              final scaleY = 1 + 0.15 * bump;
              final shake = math.sin(t * math.pi * 8) * 4 * (1 - t);
              final openValue = _open.value;
              final reward = widget.tierRewards?[tier];
              final rewardOpacity = ((openValue - 0.6) / 0.4).clamp(0.0, 1.0);

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (openValue > 0 && !reduced)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: SunburstGodRays(
                              animation: _open,
                              color: tier.rayColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Align(
                    alignment: const Alignment(0, -0.1),
                    child: Transform(
                      key: const ValueKey('tieredChestBounce'),
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.translationValues(shake, 0, 0)
                        ..scaleByDouble(scaleX, scaleY, 1, 1),
                      child: RepaintBoundary(
                        child: SizedBox(
                          width: widget.size.width * 0.72,
                          height: widget.size.height * 0.62,
                          child: CustomPaint(
                            painter: _TierChestPainter(tier, openValue),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (reward != null && rewardOpacity > 0)
                    PositionedDirectional(
                      bottom: 0,
                      start: 0,
                      end: 0,
                      child: Opacity(opacity: rewardOpacity, child: reward),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TierChestPainter extends CustomPainter {
  _TierChestPainter(this.tier, this.openProgress);

  final ChestTier tier;
  final double openProgress;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.38,
        size.width * 0.84,
        size.height * 0.54,
      ),
      const Radius.circular(14),
    );
    _paint.color = tier.bodyColor;
    canvas.drawRRect(body.shift(const Offset(0, 7)), _paint);
    _paint.color = tier.lidColor;
    canvas.drawRRect(body, _paint);
    _paint.color = tier.rayColor;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.43,
        size.height * 0.4,
        size.width * 0.14,
        size.height * 0.52,
      ),
      _paint,
    );

    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        -size.width * 0.45,
        -size.height * 0.28,
        size.width * 0.9,
        size.height * 0.26,
      ),
      const Radius.circular(12),
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.4);
    canvas.rotate(-1.25 * openProgress);
    _paint
      ..style = PaintingStyle.fill
      ..color = tier.lidColor;
    canvas.drawRRect(lid, _paint);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = tier.bodyColor;
    canvas.drawRRect(lid, _paint);
    _paint.style = PaintingStyle.fill;
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TierChestPainter oldDelegate) =>
      oldDelegate.tier != tier || oldDelegate.openProgress != openProgress;
}
