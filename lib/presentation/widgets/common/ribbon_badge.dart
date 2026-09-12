import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Diagonal corner-ribbon overlay (e.g. "NEW"/"SALE"/"BEST VALUE") wrapping
/// any [child] — shop/IAP item badge. Draws into its own internal [Stack]
/// sized to [child], independent of any [Stack] the caller might have
/// (avoids the caller-owned-`Stack` coupling problem noted for
/// [LoadingOverlay]/ENH-03 — just wrap: `RibbonBadge(text: 'SALE',
/// child: myCard)`).
///
/// Pops in (scale 0.8→1.0, `Curves.easeOutBack`) on mount — a label meant
/// to grab attention shouldn't just appear flat alongside its child.
class RibbonBadge extends StatefulWidget {
  const RibbonBadge({
    super.key,
    required this.child,
    required this.text,
    this.color,
  });

  final Widget child;

  /// Ribbon label, e.g. "NEW", "SALE", "-50%".
  final String text;

  /// Ribbon background color. Default: [NeonTheme.red].
  final Color? color;

  @override
  State<RibbonBadge> createState() => _RibbonBadgeState();
}

class _RibbonBadgeState extends State<RibbonBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _startedOnce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery không đọc được trong initState — didChangeDependencies là
    // nơi an toàn sớm nhất, chạy 1 lần trước build đầu tiên (cùng convention
    // đã dùng ở ConfettiOverlay).
    if (_startedOnce) return;
    _startedOnce = true;
    if (NeonTheme.reducedMotion(context)) {
      _controller.value = 1.0;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? NeonTheme.red;
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            top: 14,
            right: -34,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: AnimatedBuilder(
                animation: _scale,
                builder: (context, child) => Transform.scale(
                  key: const Key('ribbonBadgeScale'),
                  scale: _scale.value,
                  child: child,
                ),
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [c, c.withValues(alpha: 0.85)],
                    ),
                  ),
                  child: Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
