import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Celebration popup (level-up, reward unlocked, ...) — a panel layout like
/// `NeonDialog.panel` (rounded `NeonTheme.card` card, colored border,
/// glow+drop shadow, title/message) but a standalone widget that doesn't
/// route through `NeonDialog`, since it needs the confetti burst effect
/// radiating around the panel, which `NeonDialog` doesn't support. [content]
/// is a free slot — the caller drops in a `StarRating`/`CurrencyCounter`/...
class RewardPopup extends StatefulWidget {
  const RewardPopup({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.color,
    this.content,
    this.enableParticles = true,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final Color? color;
  final Widget? content;

  /// Disables the confetti burst (e.g. the user enabled reduced motion, or
  /// this is a test).
  final bool enableParticles;

  @override
  State<RewardPopup> createState() => _RewardPopupState();
}

class _RewardPopupState extends State<RewardPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final List<_Confetto> _bits;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _bits = List.generate(28, (i) {
      final angle = rng.nextDouble() * 2 * pi;
      return _Confetto(
        angle: angle,
        speed: 120 + rng.nextDouble() * 160,
        size: 6 + rng.nextDouble() * 6,
        rot: rng.nextDouble() * pi,
        rotV: (rng.nextDouble() - 0.5) * 10,
        color: NeonTheme.gemColors[rng.nextInt(NeonTheme.gemColors.length)],
      );
    });
    if (widget.enableParticles) _burst.forward();
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? NeonTheme.gold;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (widget.enableParticles)
          IgnorePointer(
            child: CustomPaint(
              painter: _BurstPainter(_burst, _bits),
              size: const Size(320, 320),
            ),
          ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
          ),
          child: _panel(color),
        ),
      ],
    );
  }

  Widget _panel(Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(NeonTheme.s24),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color, width: 4),
        boxShadow: [
          ...NeonTheme.glow(color, blur: 26, spread: 2),
          ...NeonTheme.drop(y: 8, blur: 24),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Container(
              padding: const EdgeInsets.all(NeonTheme.s16),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: NeonTheme.drop(y: 3, blur: 8),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 40),
            ),
            const SizedBox(height: NeonTheme.s16),
          ],
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: NeonTheme.s16),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (widget.content != null) ...[
            const SizedBox(height: NeonTheme.s16),
            widget.content!,
          ],
        ],
      ),
    );
  }
}

class _Confetto {
  _Confetto({
    required this.angle,
    required this.speed,
    required this.size,
    required this.rot,
    required this.rotV,
    required this.color,
  });

  final double angle, speed, size, rot, rotV;
  final Color color;
}

/// Burst 1 lần từ tâm ra ngoài (khác `ConfettiOverlay` cũ vốn là mưa rơi từ
/// trên xuống) — mảnh giấy bắn toả tia rồi rơi nhẹ + mờ dần cuối animation.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.anim, this.bits) : super(repaint: anim);

  final Animation<double> anim;
  final List<_Confetto> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    if (t <= 0) return;
    final center = size.center(Offset.zero);
    final fade = t > 0.6 ? (1 - (t - 0.6) / 0.4) : 1.0;
    for (final b in bits) {
      final dist = b.speed * t;
      final dx = cos(b.angle) * dist;
      final dy = sin(b.angle) * dist + 60 * t * t; // rơi nhẹ theo trọng lực
      canvas.save();
      canvas.translate(center.dx + dx, center.dy + dy);
      canvas.rotate(b.rot + b.rotV * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.6),
          const Radius.circular(2),
        ),
        Paint()..color = b.color.withValues(alpha: fade.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => false;
}
