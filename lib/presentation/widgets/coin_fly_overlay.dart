import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';

/// Xu bay từ giữa màn lên góc phải-trên (nơi coin chip ở HUD) khi thắng. Chơi
/// 1 lần rồi tự gỡ. Không nhận tương tác.
class CoinFlyOverlay extends StatefulWidget {
  const CoinFlyOverlay({super.key, this.count = 14, this.onDone});

  final int count;
  final VoidCallback? onDone;

  @override
  State<CoinFlyOverlay> createState() => _CoinFlyOverlayState();
}

class _CoinFlyOverlayState extends State<CoinFlyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  late final List<_Coin> _coins;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _coins = List.generate(widget.count, (i) {
      return _Coin(
        delay: (i / widget.count) * 0.4,
        spread: Offset(
          (rng.nextDouble() - 0.5) * 0.24,
          (rng.nextDouble() - 0.5) * 0.14,
        ),
        size: 13 + rng.nextDouble() * 9,
      );
    });
    _c.forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CoinFlyPainter(_c, _coins),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Coin {
  _Coin({required this.delay, required this.spread, required this.size});

  final double delay;
  final Offset spread; // lệch điểm xuất phát (tỉ lệ theo màn)
  final double size;
}

class _CoinFlyPainter extends CustomPainter {
  _CoinFlyPainter(this.anim, this.coins) : super(repaint: anim);

  final Animation<double> anim;
  final List<_Coin> coins;

  @override
  void paint(Canvas canvas, Size size) {
    // đích ≈ coin chip góc phải-trên
    final target = Offset(size.width * 0.9, size.height * 0.055);
    for (final c in coins) {
      final lt = ((anim.value - c.delay) / (1 - c.delay)).clamp(0.0, 1.0);
      if (lt <= 0) return;
      final start = Offset(
        size.width * (0.5 + c.spread.dx),
        size.height * (0.55 + c.spread.dy),
      );
      // đường cong: control point kéo lên cao tạo vòng cung
      final ctrl = Offset(
        (start.dx + target.dx) / 2,
        min(start.dy, target.dy) - size.height * 0.12,
      );
      final e = Curves.easeInCubic.transform(lt);
      final pos = _bezier(start, ctrl, target, e);
      final fade = lt > 0.85 ? (1 - (lt - 0.85) / 0.15) : 1.0;
      _drawCoin(canvas, pos, c.size, fade);
    }
  }

  Offset _bezier(Offset a, Offset b, Offset d, double t) {
    final u = 1 - t;
    return a * (u * u) + b * (2 * u * t) + d * (t * t);
  }

  void _drawCoin(Canvas canvas, Offset p, double r, double fade) {
    canvas.drawCircle(
      p,
      r,
      Paint()..color = NeonTheme.gold.withValues(alpha: fade),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.18
        ..color = const Color(0xFFE59A1E).withValues(alpha: fade),
    );
    canvas.drawCircle(
      p - Offset(r * 0.3, r * 0.3),
      r * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.7 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _CoinFlyPainter old) => false;
}
