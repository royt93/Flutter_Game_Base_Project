import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'shader_ticker_layer.dart';

/// I16: dải aurora phủ lên nền, chỉ world cuối. Cùng hạ tầng
/// `FragmentProgram.fromAsset` + fallback ẩn hẳn khi load lỗi như
/// `neon_aura_layer.dart` (không viết lại logic phát hiện hỗ trợ shader).
class AuroraBgLayer extends StatefulWidget {
  const AuroraBgLayer({
    super.key,
    required this.color,
    this.variant = 'default',
  });
  final Color color;
  final String variant;

  @override
  State<AuroraBgLayer> createState() => _AuroraBgLayerState();
}

class _AuroraBgLayerState extends ShaderTickerLayerState<AuroraBgLayer> {
  @override
  String get shaderAssetPath => 'packages/roy_casual_kit/shaders/aurora_bg.frag';

  @override
  String get debugLabel => 'AuroraBgLayer';

  @override
  String get effectNoun => 'aurora';

  @override
  double get speedMultiplier => switch (widget.variant) {
    'starlight' => 1.3,
    'cyan_blaze' => 1.8,
    'nebula_pulse' => 0.8,
    'cosmic_drift' => 2.2,
    _ => 1.0,
  };

  @override
  Widget build(BuildContext context) {
    final shader = this.shader;
    if (shader == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AuroraPainter(
            shader: shader,
            time: time,
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
