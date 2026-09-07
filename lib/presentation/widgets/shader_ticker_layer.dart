import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../core/debug_log.dart';
import '../../core/performance_tier_service.dart';

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
  Ticker? _ticker;
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

  bool _startedOnce = false;
  Worker? _tierWorker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery can't be read in initState (no inherited-widget lookups
    // are allowed before it completes) — didChangeDependencies is the
    // earliest safe place, and runs once before the first build. The OS
    // Reduce Motion flag is fixed for the process, so checking once here
    // (not re-checking on later calls) is enough — this class's job is to
    // skip a purely decorative, GPU-heavy effect entirely for
    // motion-sensitive users, not toggle it live mid-session. Reduce Motion
    // is a stronger, static veto than the performance tier below: if it's
    // on, bail out before even looking at PerformanceTierService, so the
    // live tier listener never gets registered and can never re-enable
    // this layer mid-session.
    if (_startedOnce) return;
    _startedOnce = true;
    if (MediaQuery.of(context).disableAnimations) return;

    // Separate, genuinely dynamic check (unlike Reduce Motion above): a
    // device that's hot/throttling can flip PerformanceTierService's tier
    // to `low` mid-session, so this doesn't just gate the initial start —
    // it also reacts live via the `ever()` listener below.
    final tierService = PerformanceTierService.maybe;
    if (tierService?.tier.value != PerformanceTier.low) {
      _ticker = createTicker(_onTick)..start();
      _load();
    }

    if (tierService != null) {
      _tierWorker = ever<PerformanceTier>(tierService.tier, (tier) {
        if (tier == PerformanceTier.low) {
          _ticker?.stop();
        } else if (_ticker == null) {
          // Tier was already low at mount, so the ticker was never created
          // in the first place (see above) — recovering to `high` must
          // create it now, not just call `.start()` on a null ticker.
          _ticker = createTicker(_onTick)..start();
          _load();
        } else {
          _ticker!.start();
        }
      });
    }
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(shaderAssetPath);
      if (mounted) setState(() => _shader = program.fragmentShader());
    } catch (e) {
      dlog('$debugLabel: load shader thất bại, bỏ qua $effectNoun ($e)');
    }
  }

  void _onTick(Duration elapsed) {
    time = (elapsed.inMicroseconds / 1e6) * speedMultiplier;
    _skipFrame = !_skipFrame;
    if (_skipFrame && _shader != null && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tierWorker?.dispose();
    _ticker?.dispose();
    _shader?.dispose();
    super.dispose();
  }
}
