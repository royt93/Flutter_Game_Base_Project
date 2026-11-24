import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Small candy-styled toast banner + a static [ToastBanner.show] helper.
///
/// This repo's Dialog pattern convention (see `neon_dialog.dart` /
/// CLAUDE.md) is that `Get.dialog`/`showDialog`/a `Scaffold`'s
/// `ScaffoldMessenger` are unreliable once a Flame `GameWidget` is on
/// screen — routes/snackbars can no-op over it. So this toast is inserted
/// directly as an [OverlayEntry] via `Overlay.of(context)`, which sits
/// above whatever is on screen (game or normal route) and self-removes
/// after [duration]. No `Scaffold`/`ScaffoldMessenger` dependency at all.
class ToastBanner extends StatelessWidget {
  const ToastBanner({super.key, required this.message, this.color});

  final String message;

  /// Defaults to [NeonTheme.purple] — nullable because a `NeonTheme` color
  /// field is no longer a compile-time constant.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? NeonTheme.purple;
    // ENH-37: liveRegion so a screen reader announces the toast the moment
    // it appears, without the user needing to manually move focus to it —
    // the whole point of a toast is a message nobody explicitly navigated
    // to. `message` itself is already the ideal label; no separate
    // semanticLabel override needed for a widget whose only content IS
    // that string.
    return Semantics(
      liveRegion: true,
      label: message,
      // The child Text's own automatic semantics label would otherwise
      // merge with (duplicate) the explicit label above.
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: NeonTheme.s24),
          padding: const EdgeInsets.symmetric(
            horizontal: NeonTheme.s16,
            vertical: NeonTheme.s16,
          ),
          decoration: BoxDecoration(
            color: NeonTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color, width: 3),
            boxShadow: [
              ...NeonTheme.glow(color, blur: 16, spread: 1),
              ...NeonTheme.drop(y: 4, blur: 12),
            ],
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  /// Inserts a self-removing toast at the top of [context]'s [Overlay].
  /// Slides + fades in from the top, holds for [duration], then removes
  /// itself — no ambient state, safe to call from any screen (game or not).
  static void show(
    BuildContext context, {
    required String message,
    Color? color,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final reduced = NeonTheme.reducedMotion(context);
    late OverlayEntry entry;
    var disposed = false;
    entry = OverlayEntry(
      builder: (context) => _ToastBannerOverlay(
        message: message,
        color: color ?? NeonTheme.purple,
        duration: duration,
        reducedMotion: reduced,
        onDismissed: () {
          // Once only: OverlayEntry.dispose() asserts against a second call.
          if (disposed) return;
          disposed = true;
          if (entry.mounted) entry.remove();
          entry.dispose();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _ToastBannerOverlay extends StatefulWidget {
  const _ToastBannerOverlay({
    required this.message,
    required this.color,
    required this.duration,
    required this.reducedMotion,
    required this.onDismissed,
  });

  final String message;
  final Color color;
  final Duration duration;
  final bool reducedMotion;
  final VoidCallback onDismissed;

  @override
  State<_ToastBannerOverlay> createState() => _ToastBannerOverlayState();
}

class _ToastBannerOverlayState extends State<_ToastBannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      reverseDuration: widget.reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(_curve);
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: MediaQuery.of(context).padding.top + NeonTheme.s16,
    left: 0,
    right: 0,
    child: FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: _slide,
        child: ToastBanner(message: widget.message, color: widget.color),
      ),
    ),
  );
}
