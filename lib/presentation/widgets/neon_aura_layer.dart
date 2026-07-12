import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/debug_log.dart';

/// G5: aura bloom động sau bàn, dùng shader `shaders/neon_glow.frag` (đã có
/// sẵn trong repo). Load lỗi (thiết bị không hỗ trợ) → ẩn hẳn, không crash.
class NeonAuraLayer extends StatefulWidget {
  const NeonAuraLayer({super.key, required this.color});
  final Color color;

  @override
  State<NeonAuraLayer> createState() => _NeonAuraLayerState();
}

class _NeonAuraLayerState extends State<NeonAuraLayer>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/neon_glow.frag',
      );
      if (mounted) setState(() => _shader = program.fragmentShader());
    } catch (e) {
      dlog('roy93~ NeonAuraLayer: load shader thất bại, bỏ qua aura ($e)');
    }
  }

  void _onTick(Duration elapsed) {
    _time = elapsed.inMicroseconds / 1e6;
    if (_shader != null && mounted) setState(() {});
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
      child: CustomPaint(
        painter: _AuraPainter(shader: shader, time: _time, color: widget.color),
        size: Size.infinite,
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  _AuraPainter({required this.shader, required this.time, required this.color});
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
  bool shouldRepaint(covariant _AuraPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.color != color;
}
