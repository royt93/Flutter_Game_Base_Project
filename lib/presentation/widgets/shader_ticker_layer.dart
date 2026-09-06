import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/debug_log.dart';

/// Hạ tầng dùng chung cho các layer full-screen chạy 1 `FragmentShader`
/// (`AuroraBgLayer`, `NeonAuraLayer`): load `FragmentProgram.fromAsset` với
/// try/catch (ẩn hẳn hiệu ứng nếu load lỗi, không crash), throttle ticker
/// repaint xuống ~30fps, và dispose đúng cả ticker lẫn shader.
///
/// Subclass chỉ còn phần riêng: asset path, tốc độ theo `variant`, và
/// painter/uniform-setting logic của chính nó trong `build()`.
abstract class ShaderTickerLayerState<T extends StatefulWidget>
    extends State<T> with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  double time = 0;
  // Shader full-screen mỗi frame khá nặng — hạ tần suất repaint thật sự
  // xuống ~30fps (bỏ qua mỗi tick lẻ), `time` vẫn cập nhật mỗi tick nên
  // animation không bị giật khi throttle.
  bool _skipFrame = false;

  /// Đường dẫn asset shader, ví dụ `packages/roy_casual_kit/shaders/foo.frag`.
  String get shaderAssetPath;

  /// Tên hiển thị trong log lỗi (thường trùng tên class widget).
  String get debugLabel;

  /// Danh từ mô tả hiệu ứng trong log lỗi (vd. "aurora", "aura").
  String get effectNoun;

  /// Tốc độ animation hiện tại (thường tính theo `variant` của widget).
  double get speedMultiplier;

  ui.FragmentShader? get shader => _shader;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(shaderAssetPath);
      if (mounted) setState(() => _shader = program.fragmentShader());
    } catch (e) {
      dlog(
        'roy93~ $debugLabel: load shader thất bại, bỏ qua $effectNoun ($e)',
      );
    }
  }

  void _onTick(Duration elapsed) {
    time = (elapsed.inMicroseconds / 1e6) * speedMultiplier;
    _skipFrame = !_skipFrame;
    if (_skipFrame && _shader != null && mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }
}
