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
    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
      reverseDuration: reduced
          ? Duration.zero
          : const Duration(milliseconds: 180),
    );
    final slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: controller,
            curve: Curves.easeOutBack,
            // Không dùng lại easeOutBack cho chiều đóng — overshoot của nó rơi
            // ngay lúc bắt đầu reverse(), làm toast "nảy ngược" một nhịp trước
            // khi trượt lên. Cùng quy ước `neon_dialog.dart`'s
            // `_kDialogCurve`/`Curves.easeIn`: vào bouncy, ra êm.
            reverseCurve: Curves.easeIn,
          ),
        );

    // BUG-57: `controller.dispose()` must run even when the OverlayEntry
    // was already removed from under us (e.g. the screen was popped before
    // the toast's own timer fired) — the old early `if (!entry.mounted)
    // return;` skipped straight past dispose(), leaking the
    // AnimationController/Ticker every time that happened. `_disposed`
    // also makes this safe to call more than once.
    var disposed = false;
    Future<void> remove() async {
      if (entry.mounted) {
        try {
          await controller.reverse();
        } catch (_) {
          // vsync (the Navigator) may already be gone if the whole app was
          // torn down mid-toast — still clean up below regardless, so the
          // AnimationController/Ticker never leaks.
        }
        entry.remove();
      }
      if (!disposed) {
        disposed = true;
        controller.dispose();
      }
    }

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + NeonTheme.s16,
        left: 0,
        right: 0,
        child: FadeTransition(
          opacity: controller,
          child: SlideTransition(
            position: slide,
            child: ToastBanner(
              message: message,
              color: color ?? NeonTheme.purple,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    controller.forward();
    Future.delayed(duration, remove);
  }
}
