import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Combo/score text ("+10", "Combo x3") that floats up and fades out in
/// place, then removes itself — the FEAT-12 coin-fly widget flies *to* a
/// target, this one just pops where it appears (cheap but effective
/// "game-feel" juice).
///
/// Same self-cleaning usage convention as [ToastBanner.show]: call
/// [FloatingComboText.show] once, no ambient state to manage. The bare
/// widget itself owns the animation (unlike `ToastBanner`, where the static
/// helper owns it) so it can also be dropped straight into a tree and given
/// an [onDone] callback.
class FloatingComboText extends StatefulWidget {
  const FloatingComboText({
    super.key,
    required this.text,
    this.color,
    this.fontSize = 22,
    this.duration = const Duration(milliseconds: 900),
    this.riseDistance = 40,
    this.onDone,
  });

  final String text;

  /// Defaults to [NeonTheme.gold] — nullable because a `NeonTheme` color
  /// field is no longer a compile-time constant.
  final Color? color;
  final double fontSize;
  final Duration duration;
  final double riseDistance;

  /// Called once, when the rise+fade animation completes.
  final VoidCallback? onDone;

  @override
  State<FloatingComboText> createState() => _FloatingComboTextState();

  /// Inserts a self-removing [FloatingComboText] into [context]'s [Overlay]
  /// at [alignment], and removes it again once the animation finishes — no
  /// leftover [OverlayEntry] or `AnimationController` to manage.
  static void show(
    BuildContext context, {
    required String text,
    Color? color,
    double fontSize = 22,
    Duration duration = const Duration(milliseconds: 900),
    Alignment alignment = Alignment.center,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: Align(
            alignment: alignment,
            child: FloatingComboText(
              text: text,
              color: color,
              fontSize: fontSize,
              duration: duration,
              onDone: () {
                if (entry.mounted) entry.remove();
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }
}

class _FloatingComboTextState extends State<FloatingComboText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  bool _startedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery can't be read in initState — didChangeDependencies is the
    // earliest safe place, and runs once before the first build.
    if (_startedOnce) return;
    _startedOnce = true;
    final duration = NeonTheme.reducedMotion(context)
        ? Duration.zero
        : widget.duration;
    _controller = AnimationController(vsync: this, duration: duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
    _rise = Tween<double>(
      begin: 0,
      end: -widget.riseDistance,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
    // Pop-in trong 30% đầu animation, cùng "juice" convention với
    // RewardPopup/NeonDialog's entrance (scale từ nhỏ hơn 1, overshoot nhẹ).
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _rise.value),
        child: Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            key: const Key('floatingComboTextScale'),
            scale: _scale.value,
            child: child,
          ),
        ),
      ),
      child: Text(
        widget.text,
        style: TextStyle(
          color: widget.color ?? NeonTheme.gold,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
