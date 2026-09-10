import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';

/// Bọc 1 nút bấm để co nhẹ (scale) lúc nhấn xuống — micro-bounce dùng chung
/// cho mọi nút (A3). Tái dùng 1 chỗ thay vì lặp GestureDetector+AnimatedScale
/// ở từng widget nút.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.94,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => _setDown(true) : null,
      onTapCancel: enabled ? () => _setDown(false) : null,
      onTapUp: enabled ? (_) => _setDown(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: NeonTheme.reducedMotion(context)
            ? Duration.zero
            : Duration(milliseconds: _down ? 90 : 150),
        // Nhấn xuống: easeOut (nhanh, dứt khoát). Thả tay: easeOutBack
        // (nảy nhẹ quá 1.0 rồi mới ổn định) — cùng "ngôn ngữ chuyển động"
        // đã dùng ở RewardPopup/NeonDialog's entrance animation.
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
