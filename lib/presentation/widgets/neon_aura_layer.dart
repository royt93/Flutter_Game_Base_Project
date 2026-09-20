import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'shader_ticker_layer.dart';

/// G5: aura bloom động sau bàn, dùng shader `shaders/neon_glow.frag` (đã có
/// sẵn trong repo). Load lỗi (thiết bị không hỗ trợ) → ẩn hẳn, không crash.
class NeonAuraLayer extends StatefulWidget {
  const NeonAuraLayer({
    super.key,
    required this.color,
    this.variant = 'default',
  });
  final Color color;
  final String variant;

  @override
  State<NeonAuraLayer> createState() => _NeonAuraLayerState();
}

class _NeonAuraLayerState extends ShaderTickerLayerState<NeonAuraLayer> {
  @override
  String get shaderAssetPath =>
      'packages/roy_casual_kit/shaders/neon_glow.frag';

  @override
  String get debugLabel => 'NeonAuraLayer';

  @override
  String get effectNoun => 'aura';

  @override
  double get speedMultiplier => switch (widget.variant) {
    'starlight' => 1.5,
    'cyan_blaze' => 2.0,
    'nebula_pulse' => 0.7,
    'cosmic_drift' => 2.5,
    _ => 1.0,
  };

  @override
  Widget build(BuildContext context) {
    final shader = this.shader;
    if (shader == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AuraPainter(
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
