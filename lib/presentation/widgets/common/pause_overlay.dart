import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/game_session_controller.dart';
import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';
import 'common_button.dart';

/// Pause panel wired directly to [GameSessionController] — the pause
/// button/system-lifecycle-pause round trip this repo already has (see
/// `game_session_controller.dart`'s own [RoyLifecycleCoordinator] hook) gets
/// exactly one visible UI on top of it. Caller mounts this unconditionally
/// inside their own `Stack` (same "always mounted, `NeonDialog.overlaySlot`
/// animates the panel in/out" convention as every other in-tree overlay in
/// this kit) — it decides on its own, from [session], whether to show:
///
/// - Visible when [GameSessionController.snapshot] is
///   [GameSessionPhase.paused] AND [GamePauseReason.user] is one of the
///   active reasons — a background-triggered [GamePauseReason.system] pause
///   does NOT show this by default (a player didn't ask to see a pause
///   menu just because the app backgrounded), unless [showForSystemPause].
/// - The Android/back gesture resumes instead of popping the underlying
///   route while visible (a real [PopScope], not the show()-then-pop trick
///   [NeonDialog.show] uses for a route dialog — this overlay is never a
///   route, exactly like [NeonDialog.overlay]/`.overlaySlot`).
/// - [onResume]/[onRestart]/[onSettings]/[onQuit] are overridable; leaving
///   [onResume]/[onRestart] unset falls back to
///   [GameSessionController.resume]/[GameSessionController.restart].
///   [onSettings]/[onQuit] have no sensible package-level default (the kit
///   doesn't know a game's settings screen or what "quit" means for it) —
///   leaving either `null` hides that one button instead of wiring a no-op.
///
/// Focus: the panel is its own [FocusScope] and requests focus as soon as
/// it becomes visible, so a keyboard/TV-remote/screen-reader user lands on
/// the pause menu rather than whatever was focused behind it. This traps
/// *focus-scope ownership*, not per-button Tab activation — `CommonButton`
/// (like the rest of this kit's buttons) is gesture-only today with no
/// keyboard-activation wiring of its own; giving every button real keyboard
/// support is a separate, kit-wide change out of this widget's scope.
///
/// Game-time coordination is automatic and needs no wiring here: a
/// `GameTimeController` built with `session:` this same [session] already
/// freezes itself from [GameSessionController]'s own pause state (FEAT-49).
/// Audio is deliberately NOT auto-paused/resumed by this widget — whether
/// background music should keep playing behind a pause menu is a per-game
/// call this kit shouldn't make for every consumer; pause/resume `AudioManager`
/// yourself in [onResume]/wherever you call [GameSessionController.pause] if
/// your game wants that.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.session,
    this.showForSystemPause = false,
    this.onResume,
    this.onRestart,
    this.onSettings,
    this.onQuit,
    this.title,
    this.resumeLabel,
    this.restartLabel,
    this.settingsLabel,
    this.quitLabel,
    this.color,
  });

  final GameSessionController session;
  final bool showForSystemPause;
  final VoidCallback? onResume;
  final VoidCallback? onRestart;
  final VoidCallback? onSettings;
  final VoidCallback? onQuit;
  final String? title;
  final String? resumeLabel;
  final String? restartLabel;
  final String? settingsLabel;
  final String? quitLabel;
  final Color? color;

  bool _isVisible(GameSessionSnapshot snapshot) =>
      snapshot.phase == GameSessionPhase.paused &&
      (snapshot.pauseReasons.contains(GamePauseReason.user) ||
          (showForSystemPause &&
              snapshot.pauseReasons.contains(GamePauseReason.system)));

  void _handleResume() {
    final callback = onResume;
    if (callback != null) {
      callback();
    } else {
      session.resume(GamePauseReason.user);
    }
  }

  void _handleRestart() {
    final callback = onRestart;
    if (callback != null) {
      callback();
    } else {
      session.restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Obx(() {
        final visible = _isVisible(session.snapshot.value);
        return PopScope(
          canPop: !visible,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _handleResume();
          },
          child: NeonDialog.overlaySlot(
            panel: visible ? _buildPanel(context) : null,
            panelKey: 'pause_overlay',
          ),
        );
      }),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final c = color ?? NeonTheme.cyan;
    return FocusScope(
      autofocus: true,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.symmetric(horizontal: NeonTheme.s24),
        padding: const EdgeInsets.all(NeonTheme.s24),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c, width: 4),
          boxShadow: [
            ...NeonTheme.glow(c, blur: 26, spread: 2),
            ...NeonTheme.drop(y: 8, blur: 24),
          ],
        ),
        child: Semantics(
          container: true,
          label: title ?? 'Paused',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title ?? 'Paused',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: NeonTheme.s24),
              CommonButton(
                label: resumeLabel ?? 'Resume',
                onTap: _handleResume,
              ),
              const SizedBox(height: NeonTheme.s16),
              CommonButton(
                label: restartLabel ?? 'Restart',
                variant: CommonButtonVariant.secondary,
                onTap: _handleRestart,
              ),
              if (onSettings != null) ...[
                const SizedBox(height: NeonTheme.s16),
                CommonButton(
                  label: settingsLabel ?? 'Settings',
                  variant: CommonButtonVariant.secondary,
                  onTap: onSettings!,
                ),
              ],
              if (onQuit != null) ...[
                const SizedBox(height: NeonTheme.s16),
                CommonButton(
                  label: quitLabel ?? 'Quit',
                  variant: CommonButtonVariant.danger,
                  onTap: onQuit!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
