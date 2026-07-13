import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/debug_log.dart';

/// I16: dải aurora phủ lên nền, chỉ world cuối. Cùng hạ tầng
/// `FragmentProgram.fromAsset` + fallback ẩn hẳn khi load lỗi như
/// `neon_aura_layer.dart` (không viết lại logic phát hiện hỗ trợ shader).
class AuroraBgLayer extends StatefulWidget {
  const AuroraBgLayer({super.key, required this.color});
  final Color color;

  @override
  State<AuroraBgLayer> createState() => _AuroraBgLayerState();
}

class _AuroraBgLayerState extends State<AuroraBgLayer>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  double _time = 0;
  // Cùng lý do throttle ~30fps như NeonAuraLayer: shader full-screen mỗi
  // frame khá nặng, _time vẫn cập nhật mỗi tick nên không giật.
  bool _skipFrame = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/aurora_bg.frag',
      );
      if (mounted) setState(() => _shader = program.fragmentShader());
    } catch (e) {
      dlog('roy93~ AuroraBgLayer: load shader thất bại, bỏ qua aurora ($e)');
    }
  }

  void _onTick(Duration elapsed) {
    _time = elapsed.inMicroseconds / 1e6;
    _skipFrame = !_skipFrame;
    if (_skipFrame && _shader != null && mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AuroraPainter(
            shader: shader,
            time: _time,
            color: widget.color,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.shader,
    required this.time,
    required this.color,
  });
  final ui.FragmentShader shader;
  final double time;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, color.r)
      ..setFloat(4, color.g)
      ..setFloat(5, color.b)
      ..setFloat(6, color.a);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.color != color;
}
