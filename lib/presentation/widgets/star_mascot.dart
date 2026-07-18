import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../data/mascot_skins.dart';

enum StarMood { idle, happy, sad, cheer }

/// Mascot ngôi sao vẽ bằng canvas (không cần asset). Idle nhún nhẹ + chớp mắt;
/// happy nảy lên; sad rũ xuống. Dùng ở Home + dialog thắng/thua.
///
/// X14: [onTap] (optional) — tap vào mascot chạy 1 animation phản ứng ngẫu
/// nhiên (scale-bounce/tilt-wiggle), độc lập với idle loop, tôn trọng
/// reduce-motion (bật thì tap không chạy animation, chỉ gọi callback).
///
/// I30: [palette] (optional, mặc định skin "classic") — chỉ đổi màu quầng
/// sáng/gradient thân/viền theo skin đang active, giữ nguyên hình dạng sao +
/// toàn bộ animation mood.
class StarMascot extends StatefulWidget {
  const StarMascot({
    super.key,
    this.size = 120,
    this.mood = StarMood.idle,
    this.onTap,
    this.palette = classicMascotPalette,
  });

  final double size;
  final StarMood mood;
  final VoidCallback? onTap;
  final MascotPalette palette;

  @override
  State<StarMascot> createState() => _StarMascotState();
}

enum _TapReaction { scaleBounce, tiltWiggle }

class _StarMascotState extends State<StarMascot> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final AnimationController _tapC = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  final _rng = Random();
  _TapReaction _reaction = _TapReaction.scaleBounce;

  bool get _reduceMotion =>
      StorageService.maybe?.getBool(StorageKeys.reduceMotion) ?? false;

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    _tapC.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap?.call();
    if (_reduceMotion) return;
    _reaction = _TapReaction.values[_rng.nextInt(_TapReaction.values.length)];
    _tapC.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap != null ? _handleTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _tapC]),
        builder: (context, _) {
          final t = _c.value;
          // nhún/nảy + nghiêng theo mood
          final double bob;
          double tilt = 0;
          switch (widget.mood) {
            case StarMood.happy:
              bob = -sin(t * pi * 4).abs() * widget.size * 0.10; // nảy nhanh
            case StarMood.cheer:
              bob = -sin(t * pi * 6).abs() * widget.size * 0.16; // nhảy dồn dập
              tilt = sin(t * pi * 6) * 0.16; // xoay lắc phấn khích
            case StarMood.sad:
              bob = widget.size * 0.09; // rũ xuống rõ hơn
              tilt = -0.08; // cúi đầu
            case StarMood.idle:
              bob = sin(t * pi * 2) * widget.size * 0.04; // bồng bềnh
              tilt = sin(t * pi * 2 + 1.3) * 0.06; // nghiêng đầu nhẹ
          }
          // chớp mắt: nháy nhanh quanh t≈0.5 (idle/happy/cheer), sad thì nhắm gần hết
          final double blink;
          if (widget.mood == StarMood.sad) {
            blink = 0.18;
          } else {
            final b = (t - 0.5).abs();
            blink = b < 0.03 ? (b / 0.03) : 1.0;
          }
          // X14: phản ứng tap chồng thêm lên idle — scale nảy hoặc lắc mạnh.
          var scale = 1.0;
          if (_tapC.isAnimating || _tapC.value > 0) {
            final tap = _tapC.value;
            if (_reaction == _TapReaction.scaleBounce) {
              scale = 1.0 + sin(tap * pi) * 0.22;
            } else {
              tilt += sin(tap * pi * 5) * (1 - tap) * 0.35;
            }
          }
          return Transform.translate(
            offset: Offset(0, bob),
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: scale,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _StarPainter(
                    mood: widget.mood,
                    blink: blink,
                    palette: widget.palette,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.mood,
    required this.blink,
    required this.palette,
  });

  final StarMood mood;
  final double blink;
  final MascotPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width * 0.48;
    final rInner = rOuter * 0.5;

    // thân sao 5 cánh
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? rOuter : rInner;
      final a = -pi / 2 + i * pi / 5;
      final p = c + Offset(cos(a) * r, sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();

    // quầng sáng
    canvas.drawPath(
      star,
      Paint()
        ..color = palette.glow.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.06),
    );
    // fill gradient
    canvas.drawPath(
      star,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.gradientStart, palette.gradientEnd],
        ).createShader(Rect.fromCircle(center: c, radius: rOuter)),
    );
    // viền
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03
        ..strokeJoin = StrokeJoin.round
        ..color = palette.outline,
    );

    // mặt
    final eyeDx = rOuter * 0.28;
    final eyeY = c.dy - rOuter * 0.05;
    final eyeW = size.width * 0.07;
    final eyeH = size.width * 0.11 * blink;
    final eyePaint = Paint()..color = NeonTheme.ink;
    for (final sx in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx + sx * eyeDx, eyeY),
          width: eyeW,
          height: eyeH.clamp(size.width * 0.012, size.width * 0.11),
        ),
        eyePaint,
      );
    }
    // má hồng
    final blush = Paint()..color = NeonTheme.pink.withValues(alpha: 0.55);
    for (final sx in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(c.dx + sx * rOuter * 0.34, eyeY + rOuter * 0.16),
        size.width * 0.05,
        blush,
      );
    }
    // miệng
    final mouth = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round
      ..color = NeonTheme.ink;
    final my = c.dy + rOuter * 0.22;
    final mw = rOuter * 0.34;
    final path = Path();
    switch (mood) {
      case StarMood.happy:
      case StarMood.cheer:
        path.moveTo(c.dx - mw, my - rOuter * 0.02);
        path.quadraticBezierTo(
          c.dx,
          my + rOuter * 0.26,
          c.dx + mw,
          my - rOuter * 0.02,
        );
      case StarMood.sad:
        path.moveTo(c.dx - mw * 0.7, my + rOuter * 0.12);
        path.quadraticBezierTo(
          c.dx,
          my - rOuter * 0.10,
          c.dx + mw * 0.7,
          my + rOuter * 0.12,
        );
      case StarMood.idle:
        path.moveTo(c.dx - mw * 0.6, my);
        path.quadraticBezierTo(c.dx, my + rOuter * 0.14, c.dx + mw * 0.6, my);
    }
    canvas.drawPath(path, mouth);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.blink != blink || old.mood != mood || old.palette != palette;
}
