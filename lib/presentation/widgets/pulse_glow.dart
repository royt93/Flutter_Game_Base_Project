import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';

/// G3: viền glow nhịp thở chậm quanh CTA chính (vd. PLAY). Chỉ animate
/// boxShadow (rẻ) — dùng cho 1-2 nút nổi bật, không áp đại trà.
class PulseGlow extends StatefulWidget {
  const PulseGlow({
    super.key,
    required this.color,
    required this.child,
    this.borderRadius = 22,
  });

  final Color color;
  final Widget child;
  final double borderRadius;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: NeonTheme.glow(
                widget.color,
                blur: 12 + 10 * t,
                spread: 0.5 + 1.2 * t,
              ),
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
