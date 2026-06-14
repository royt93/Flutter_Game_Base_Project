import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../data/wheel.dart';
import '../controllers/lucky_wheel_controller.dart';

/// Vòng quay vẽ bằng CustomPainter + animation xoay tới ô trúng.
class LuckyWheelView extends StatefulWidget {
  final LuckyWheelController ctrl;
  const LuckyWheelView({super.key, required this.ctrl});

  @override
  State<LuckyWheelView> createState() => _LuckyWheelViewState();
}

class _LuckyWheelViewState extends State<LuckyWheelView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _turn;
  double _from = 0;
  double _to = 0;

  static const double _sliceAngle = 2 * math.pi / 8;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200));
    _turn = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.ctrl.finishSpin();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _spin() {
    final idx = widget.ctrl.spin();
    if (idx < 0) return;
    // đưa tâm ô idx về kim (đỉnh, -90°), thêm 5 vòng
    _from = _to;
    final target = 5 * 2 * math.pi - (idx + 0.5) * _sliceAngle;
    _to = target;
    _anim
      ..reset()
      ..forward();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 260,
          height: 270,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _turn,
                builder: (_, __) {
                  final angle = _from + (_to - _from) * _turn.value;
                  return Transform.rotate(
                    angle: angle,
                    child: CustomPaint(
                      size: const Size(248, 248),
                      painter: _WheelPainter(),
                    ),
                  );
                },
              ),
              // hub giữa
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NeonTheme.panel,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: NeonTheme.glow(Colors.white, blur: 8),
                ),
                child: const Icon(Icons.star_rounded,
                    color: NeonTheme.yellow, size: 26),
              ),
              // kim chỉ ở đỉnh
              Positioned(
                top: 0,
                child: Icon(Icons.arrow_drop_down_rounded,
                    color: Colors.white,
                    size: 46,
                    shadows: NeonTheme.glow(Colors.white, blur: 8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: NeonTheme.s16),
        Obx(() {
          final spinning = widget.ctrl.spinning.value;
          final idx = widget.ctrl.resultIndex.value;
          final canSpin = widget.ctrl.canSpin;
          if (!spinning && idx >= 0) {
            // đã quay xong → hiện kết quả
            final s = kWheel[idx];
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(s.icon, color: s.color, size: 22),
              const SizedBox(width: 6),
              Text(
                s.isCoins
                    ? '+${s.amount} 💰'
                    : '${'wheel_got_booster'.tr} ${s.label}',
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ]);
          }
          return GestureDetector(
            onTap: (canSpin && !spinning) ? _spin : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: (canSpin && !spinning)
                    ? NeonTheme.lime
                    : NeonTheme.panel.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                boxShadow: (canSpin && !spinning)
                    ? NeonTheme.glow(NeonTheme.lime, blur: 12)
                    : null,
              ),
              child: Text(
                spinning
                    ? '...'
                    : (canSpin ? 'wheel_spin'.tr : 'wheel_done'.tr),
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  color: (canSpin && !spinning) ? Colors.black : Colors.white54,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  static const double _sliceAngle = 2 * math.pi / 8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    // bắt đầu vẽ từ -90° (đỉnh) cho khớp công thức xoay
    var start = -math.pi / 2 - _sliceAngle / 2;
    for (var i = 0; i < kWheel.length; i++) {
      final s = kWheel[i];
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = s.color.withValues(alpha: i.isEven ? 0.85 : 0.6);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
          _sliceAngle, true, paint);
      // viền ô
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          _sliceAngle,
          true,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.5));
      // icon + nhãn theo bán kính
      final mid = start + _sliceAngle / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(s.icon.codePoint),
          style: TextStyle(
            fontFamily: s.icon.fontFamily,
            package: s.icon.fontPackage,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final ip = center +
          Offset(math.cos(mid), math.sin(mid)) * (radius * 0.66);
      tp.paint(canvas, ip - Offset(tp.width / 2, tp.height / 2));

      final lp = TextPainter(
        text: TextSpan(
          text: s.label,
          style: const TextStyle(
            fontFamily: 'Baloo2',
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lpos = center +
          Offset(math.cos(mid), math.sin(mid)) * (radius * 0.86);
      lp.paint(canvas, lpos - Offset(lp.width / 2, lp.height / 2));

      start += _sliceAngle;
    }
    // vành ngoài
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
