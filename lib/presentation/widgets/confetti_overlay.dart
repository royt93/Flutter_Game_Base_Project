import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';

/// Mưa confetti kẹo chơi 1 lần — phủ full màn phía sau dialog thắng. Không nhận
/// tương tác (IgnorePointer). Tự dừng khi animation xong.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, this.count = 80});

  final int count;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool get _reduceMotion =>
      StorageService.maybe?.getBool(StorageKeys.reduceMotion) ?? false;

  late final List<_Bit> _bits;

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) _c.forward();
    final rng = Random();
    _bits = List.generate(widget.count, (i) {
      return _Bit(
        x: rng.nextDouble(),
        delay: rng.nextDouble() * 0.35,
        fall: 0.7 + rng.nextDouble() * 0.5,
        drift: (rng.nextDouble() - 0.5) * 0.3,
        size: 7 + rng.nextDouble() * 9,
        rot: rng.nextDouble() * pi,
        rotV: (rng.nextDouble() - 0.5) * 12,
        color: NeonTheme.gemColors[rng.nextInt(NeonTheme.gemColors.length)],
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ConfettiPainter(_c, _bits),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Bit {
  _Bit({
    required this.x,
    required this.delay,
    required this.fall,
    required this.drift,
    required this.size,
    required this.rot,
    required this.rotV,
    required this.color,
  });

  final double x, delay, fall, drift, size, rot, rotV;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim, this.bits) : super(repaint: anim);

  final Animation<double> anim;
  final List<_Bit> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    for (final b in bits) {
      final lt = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final y = (-0.1 + lt * b.fall * 1.25) * size.height;
      final x = (b.x + b.drift * lt) * size.width;
      final fade = lt > 0.8 ? (1 - (lt - 0.8) / 0.2) : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.rot + b.rotV * lt);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: b.size,
            height: b.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = b.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => false;
}
