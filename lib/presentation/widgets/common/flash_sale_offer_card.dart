import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';
import 'common_button.dart';
import 'ribbon_badge.dart';

/// A high-urgency Flash Sale / Starter Pack offer card (FEAT-127).
///
/// Combines a discount ribbon badge, animated neon sweep border, countdown
/// clock driven by [fmtDurLong], and caller-owned purchase flow.
/// When [expiresAt] is reached:
/// - border animation stops,
/// - the buy button is disabled with an 'Expired' label,
/// - [onExpired] is fired once.
class FlashSaleOfferCard extends StatefulWidget {
  FlashSaleOfferCard({
    super.key,
    required this.title,
    required this.priceLabel,
    required this.discountPercent,
    required this.expiresAt,
    required this.onBuyTap,
    this.originalPriceLabel,
    this.onExpired,
    this.icon,
    this.iconData = Icons.bolt_rounded,
    this.subtitle,
    this.accentColor,
    this.width = 220,
    this.loading = false,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (priceLabel.trim().isEmpty) {
      throw ArgumentError.value(priceLabel, 'priceLabel', 'must not be empty');
    }
    if (discountPercent < 1 || discountPercent > 99) {
      throw ArgumentError.value(
        discountPercent,
        'discountPercent',
        'must be between 1 and 99',
      );
    }
    if (width <= 0) {
      throw ArgumentError.value(width, 'width', 'must be positive');
    }
  }

  final String title;
  final String priceLabel;
  final String? originalPriceLabel;
  final int discountPercent;
  final DateTime expiresAt;
  final VoidCallback? onBuyTap;
  final VoidCallback? onExpired;
  final Widget? icon;
  final IconData iconData;
  final String? subtitle;
  final Color? accentColor;
  final double width;
  final bool loading;

  @override
  State<FlashSaleOfferCard> createState() => _FlashSaleOfferCardState();
}

class _FlashSaleOfferCardState extends State<FlashSaleOfferCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  Timer? _timer;
  late Duration _remaining;
  bool _expiredFired = false;

  Duration _calculateRemaining() {
    final diff = widget.expiresAt.difference(DateTime.now());
    if (diff <= Duration.zero) return Duration.zero;
    return Duration(seconds: (diff.inMilliseconds / 1000).ceil());
  }

  bool get isExpired => _remaining <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = _calculateRemaining();
    if (isExpired) {
      _notifyExpiredDeferred();
    } else {
      _startTimer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NeonTheme.reducedMotion(context)) {
      _stopSweep();
    } else if (!isExpired) {
      _startSweep();
    }
  }

  @override
  void didUpdateWidget(covariant FlashSaleOfferCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _timer?.cancel();
      _remaining = _calculateRemaining();
      _expiredFired = false;
      if (isExpired) {
        _stopSweep();
        _notifyExpiredDeferred();
      } else {
        _startTimer();
        if (!NeonTheme.reducedMotion(context)) {
          _startSweep();
        }
      }
    }
  }

  void _startSweep() {
    if (NeonTheme.reducedMotion(context) || isExpired) return;
    if (!_sweepController.isAnimating) {
      _sweepController.repeat();
    }
  }

  void _stopSweep() {
    if (_sweepController.isAnimating) {
      _sweepController.stop();
      _sweepController.value = 0;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final next = _remaining - const Duration(seconds: 1);
    final clamped = next.isNegative ? Duration.zero : next;
    setState(() => _remaining = clamped);
    if (clamped == Duration.zero) {
      _timer?.cancel();
      _stopSweep();
      _notifyExpired();
    }
  }

  void _notifyExpiredDeferred() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyExpired();
    });
  }

  void _notifyExpired() {
    if (_expiredFired) return;
    _expiredFired = true;
    widget.onExpired?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? NeonTheme.gold;
    final expired = isExpired;
    final clockColor = expired ? NeonTheme.muted : accent;

    final cardBody = Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: NeonTheme.s16),
          // Icon with accent glow
          Container(
            padding: const EdgeInsets.all(NeonTheme.s8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NeonTheme.cardAlt,
              boxShadow: expired ? null : NeonTheme.glow(accent, blur: 12),
            ),
            child:
                widget.icon ??
                Icon(
                  widget.iconData,
                  size: 38,
                  color: expired ? NeonTheme.muted : accent,
                ),
          ),
          const SizedBox(height: NeonTheme.s8),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NeonTheme.s8),
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: NeonTheme.ink,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NeonTheme.s8),
              child: Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: NeonTheme.s8),
          // Countdown pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: NeonTheme.cardAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: clockColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 14, color: clockColor),
                const SizedBox(width: 4),
                Text(
                  expired ? 'Expired' : fmtDurLong(_remaining),
                  key: const ValueKey('flashSaleCountdownText'),
                  style: TextStyle(
                    color: clockColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Original strikethrough price if provided
          if (widget.originalPriceLabel != null)
            Text(
              widget.originalPriceLabel!,
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          const SizedBox(height: 6),
          // Buy button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NeonTheme.s16),
            child: CommonButton(
              key: const ValueKey('flashSaleBuyBtn'),
              label: expired ? 'Expired' : widget.priceLabel,
              onTap: expired ? null : widget.onBuyTap,
              width: double.infinity,
              color: expired ? NeonTheme.muted : accent,
              loading: widget.loading,
            ),
          ),
          const SizedBox(height: NeonTheme.s16),
        ],
      ),
    );

    // Neon sweep border around card
    final cardWithBorder = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _sweepController,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: expired || NeonTheme.reducedMotion(context)
                ? _StaticBorderPainter(
                    color: expired
                        ? NeonTheme.cardAlt
                        : accent.withValues(alpha: 0.6),
                    radius: 20,
                    strokeWidth: 2.0,
                  )
                : _NeonSweepBorderPainter(
                    progress: _sweepController.value,
                    accentColor: accent,
                    radius: 20,
                    strokeWidth: 2.5,
                  ),
            child: child,
          );
        },
        child: cardBody,
      ),
    );

    final withRibbon = RibbonBadge(
      text: '-${widget.discountPercent}%',
      color: expired ? NeonTheme.muted : NeonTheme.red,
      child: cardWithBorder,
    );

    return Semantics(
      container: true,
      label:
          '${widget.title}, -${widget.discountPercent}% flash sale, ${expired ? 'expired' : '${widget.priceLabel}, ends in ${fmtDurLong(_remaining)}'}',
      child: withRibbon,
    );
  }
}

class _StaticBorderPainter extends CustomPainter {
  const _StaticBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _StaticBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth;
}

class _NeonSweepBorderPainter extends CustomPainter {
  const _NeonSweepBorderPainter({
    required this.progress,
    required this.accentColor,
    required this.radius,
    required this.strokeWidth,
  });

  final double progress;
  final Color accentColor;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final rotation = progress * 2 * math.pi;
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(rotation),
      colors: [
        accentColor.withValues(alpha: 0.1),
        accentColor,
        accentColor.withValues(alpha: 0.1),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _NeonSweepBorderPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      accentColor != oldDelegate.accentColor;
}
