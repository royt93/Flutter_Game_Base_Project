import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/haptics.dart';
import '../../../core/neon_theme.dart';
import '../../../core/player_progression_service.dart';
import 'confetti_overlay.dart';

/// Lifecycle of one queued level-up celebration: [idle] (no overlay) →
/// [xpFill] (bar animates to full) → [levelPop] (level number bounces in)
/// → [rewardReveal] (reward lines fade in) → back to [idle] once the whole
/// queue is done, or [xpFill] again for the next queued level.
enum LevelUpPhase { idle, xpFill, levelPop, rewardReveal }

/// One [LevelUpEvent] plus the extra presentation detail
/// [LevelUpOverlayController] needs that [LevelUpEvent] itself doesn't
/// carry: where its XP bar starts filling FROM. Every level after the
/// first in a queue starts a fresh bar at 0 — only the very first queued
/// event might start partway through (wherever the player's bar actually
/// was right before the `grantXp` call that crossed it).
class LevelUpCelebration {
  const LevelUpCelebration({required this.event, this.startFraction = 0.0});

  final LevelUpEvent event;

  /// 0.0–1.0 — the XP bar's starting position for this event's [xpFill]
  /// phase. Always fills TO 1.0, since reaching 1.0 is what crossing this
  /// level means.
  final double startFraction;
}

/// Pure state machine driving [LevelUpOverlay] — no `Animation`/
/// `BuildContext` here, so it's unit-testable without pumping a widget
/// tree (same shape as `SceneTransitionController`, FEAT-58).
///
/// **Never grants anything**: this controller only presents
/// [LevelUpEvent]s a caller already obtained from
/// `PlayerProgressionService.grantXp` — it has no reference to that
/// service or to `RewardTransactionPipeline`, and calls neither. The
/// reward was already committed before [show] is ever called.
///
/// **Token-guarded**: every [show] mints a new token, and only that
/// token's continuation may mutate [phase]/[queueIndex] — a previous,
/// still-in-flight [show] superseded by a newer one silently drops its
/// own late completion instead of stomping the newer sequence's state or
/// double-firing its `onComplete`. The same guard makes [skip] and
/// [dispose] immediately stop any in-flight [show] from mutating state
/// further.
class LevelUpOverlayController {
  LevelUpOverlayController({
    this.xpFillDuration = const Duration(milliseconds: 600),
    this.levelPopDuration = const Duration(milliseconds: 400),
    this.rewardRevealDuration = const Duration(milliseconds: 500),
  });

  final Duration xpFillDuration;
  final Duration levelPopDuration;
  final Duration rewardRevealDuration;

  final phase = LevelUpPhase.idle.obs;
  final queueIndex = 0.obs;

  List<LevelUpCelebration> _queue = const [];
  VoidCallback? _onComplete;

  int _tokenCounter = 0;
  int? _activeToken;
  bool _disposed = false;

  /// Completed by [skip]/[dispose] to wake up whichever `_waitOrSkip` call
  /// is currently suspended — without this, [skip] would only flip
  /// [phase] synchronously while the ORIGINAL `show()` call's returned
  /// `Future` stayed suspended in `Future.delayed` for the rest of its
  /// real wall-clock duration, which a caller `await`-ing that `Future`
  /// (e.g. to chain work after the celebration) would otherwise be stuck
  /// behind.
  Completer<void>? _skipSignal;

  bool get isActive => phase.value != LevelUpPhase.idle;

  /// The celebration currently being shown, or `null` when [isActive] is
  /// `false`.
  LevelUpCelebration? get current =>
      queueIndex.value < _queue.length ? _queue[queueIndex.value] : null;

  /// Starts the celebration sequence for [celebrations], shown in list
  /// order (already-ascending, since that's how
  /// `PlayerProgressionService.grantXp` fires them). Starting a new
  /// [show] while a previous one is still running supersedes it — the old
  /// one's `onComplete` is dropped, never called.
  ///
  /// [onComplete] fires exactly once: after the LAST queued celebration's
  /// [LevelUpPhase.rewardReveal] finishes, or immediately if
  /// [celebrations] is empty. It never fires twice, including when
  /// [skip] cuts the sequence short.
  Future<void> show(
    List<LevelUpCelebration> celebrations, {
    VoidCallback? onComplete,
  }) async {
    if (_disposed) return;
    if (celebrations.isEmpty) {
      onComplete?.call();
      return;
    }

    final token = ++_tokenCounter;
    _activeToken = token;
    _queue = celebrations;
    _onComplete = onComplete;
    queueIndex.value = 0;
    await _runCurrent(token);
  }

  Future<void> _runCurrent(int token) async {
    if (!_isCurrent(token)) return;

    phase.value = LevelUpPhase.xpFill;
    await _waitOrSkip(xpFillDuration);
    if (!_isCurrent(token)) return;

    phase.value = LevelUpPhase.levelPop;
    await _waitOrSkip(levelPopDuration);
    if (!_isCurrent(token)) return;

    phase.value = LevelUpPhase.rewardReveal;
    await _waitOrSkip(rewardRevealDuration);
    if (!_isCurrent(token)) return;

    if (queueIndex.value + 1 < _queue.length) {
      queueIndex.value++;
      await _runCurrent(token);
    } else {
      _finish(token);
    }
  }

  /// Waits [duration] OR until [_skipSignal] completes, whichever comes
  /// first — [skip]/[dispose] complete it to wake this up immediately
  /// instead of leaving it suspended for the rest of [duration].
  Future<void> _waitOrSkip(Duration duration) async {
    final signal = _skipSignal = Completer<void>();
    // A real Timer (not Future.any([Future.delayed(...), ...])) so the
    // LOSING side can actually be cancelled — Future.any never cancels
    // whichever future doesn't win, which would otherwise leave a real
    // pending Timer alive (and ticking toward its own late completion)
    // for the rest of `duration` even after skip/dispose resolved early.
    final timer = Timer(duration, () {
      if (!signal.isCompleted) signal.complete();
    });
    await signal.future;
    timer.cancel();
  }

  void _finish(int token) {
    if (!_isCurrent(token)) return;
    phase.value = LevelUpPhase.idle;
    _activeToken = null;
    final onComplete = _onComplete;
    _onComplete = null;
    onComplete?.call();
  }

  /// Immediately ends the whole queue, jumping straight to [LevelUpPhase.idle]
  /// and firing `onComplete` (once) as if it had finished naturally — for a
  /// player tapping "skip" through a celebration they don't want to watch.
  /// Safe to call multiple times or after the sequence already finished —
  /// only the first call after an active [show] actually fires anything.
  void skip() {
    final token = _activeToken;
    if (token == null) return;
    _finish(token);
    _wakeSuspendedWait();
  }

  void _wakeSuspendedWait() {
    final signal = _skipSignal;
    if (signal != null && !signal.isCompleted) signal.complete();
  }

  /// Marks this controller disposed — any in-flight [show] stops mutating
  /// state from this point on and its `onComplete` is dropped, never
  /// called (same reasoning as `SceneTransitionController.dispose`: a
  /// widget tearing down shouldn't have a stale timer reach back into it
  /// later). [show] called after [dispose] is a safe no-op.
  void dispose() {
    _disposed = true;
    _activeToken = null;
    _onComplete = null;
    _wakeSuspendedWait();
  }

  bool _isCurrent(int token) => !_disposed && _activeToken == token;
}

/// Renders [LevelUpOverlayController]'s sequence over [child] — same
/// in-tree-overlay pattern as `NeonDialog`/`SceneTransitionOverlay` (see
/// `CLAUDE.md`'s "Dialog pattern" note), so it also works over a
/// full-screen Flame `GameWidget`.
///
/// [child] is excluded from the semantics tree and ignores pointer events
/// for as long as [LevelUpOverlayController.isActive] is `true`, except
/// for the overlay's own optional skip tap target — a stray tap can never
/// reach whatever's underneath mid-celebration.
///
/// Respects reduced motion: when `true` (or, left `null`, when
/// `MediaQuery.of(context).disableAnimations` is), every phase's visual
/// animation duration collapses to zero — the controller's own timing
/// (which drives WHEN each phase happens) is untouched, only what the
/// widget shows while waiting is instant instead of animated.
class LevelUpOverlay extends StatelessWidget {
  const LevelUpOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.enableHaptics = true,
    this.enableConfetti = true,
    this.reducedMotion,
    this.onSkipTap,
  });

  final LevelUpOverlayController controller;
  final Widget child;

  /// Fires [HapticLevel.medium] once per [LevelUpPhase.levelPop] — set
  /// `false` to opt out (e.g. under test, or a caller with its own
  /// haptic policy).
  final bool enableHaptics;

  /// Shows a confetti burst during [LevelUpPhase.rewardReveal] — vetoed
  /// automatically under reduced motion, same as `RewardPopup`.
  final bool enableConfetti;

  final bool? reducedMotion;

  /// Called when the caller-supplied skip affordance is tapped — normally
  /// just `controller.skip`. Left `null` hides the skip button entirely.
  final VoidCallback? onSkipTap;

  @override
  Widget build(BuildContext context) {
    final reduced =
        reducedMotion ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;

    return Obx(() {
      final phase = controller.phase.value;
      final active = phase != LevelUpPhase.idle;
      final celebration = controller.current;

      return Stack(
        children: [
          ExcludeSemantics(
            excluding: active,
            child: IgnorePointer(ignoring: active, child: child),
          ),
          if (active && celebration != null)
            Positioned.fill(
              child: Semantics(
                container: true,
                label: 'Level ${celebration.event.level}!',
                child: ColoredBox(
                  color: const Color(0x99000000),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (enableConfetti &&
                          !reduced &&
                          phase == LevelUpPhase.rewardReveal)
                        ConfettiOverlay(
                          key: ValueKey('level_up_confetti_${celebration.event.level}'),
                        ),
                      Center(
                        child: _LevelUpPanel(
                          celebration: celebration,
                          phase: phase,
                          xpFillDuration: controller.xpFillDuration,
                          levelPopDuration: controller.levelPopDuration,
                          enableHaptics: enableHaptics,
                          reducedMotion: reduced,
                          onSkipTap: onSkipTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _LevelUpPanel extends StatefulWidget {
  const _LevelUpPanel({
    required this.celebration,
    required this.phase,
    required this.xpFillDuration,
    required this.levelPopDuration,
    required this.enableHaptics,
    required this.reducedMotion,
    required this.onSkipTap,
  });

  final LevelUpCelebration celebration;
  final LevelUpPhase phase;
  final Duration xpFillDuration;
  final Duration levelPopDuration;
  final bool enableHaptics;
  final bool reducedMotion;
  final VoidCallback? onSkipTap;

  @override
  State<_LevelUpPanel> createState() => _LevelUpPanelState();
}

class _LevelUpPanelState extends State<_LevelUpPanel> {
  LevelUpPhase? _hapticFiredForPhase;

  @override
  void didUpdateWidget(covariant _LevelUpPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeFireHaptic();
  }

  @override
  void initState() {
    super.initState();
    _maybeFireHaptic();
  }

  void _maybeFireHaptic() {
    if (!widget.enableHaptics) return;
    if (widget.phase != LevelUpPhase.levelPop) return;
    if (_hapticFiredForPhase == widget.phase) return;
    _hapticFiredForPhase = widget.phase;
    fireHaptic(HapticLevel.medium);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.celebration.event;
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(NeonTheme.s24),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: NeonTheme.gold, width: 4),
        boxShadow: [
          ...NeonTheme.glow(NeonTheme.gold, blur: 26, spread: 2),
          ...NeonTheme.drop(y: 8, blur: 24),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey('level_pop_${event.level}'),
            tween: Tween(
              begin: widget.phase == LevelUpPhase.xpFill ? 0.85 : 1.0,
              end: 1.0,
            ),
            duration: widget.reducedMotion
                ? Duration.zero
                : widget.levelPopDuration,
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Text(
              'Level ${event.level}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: NeonTheme.s16),
          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: widget.celebration.startFraction,
              end: 1.0,
            ),
            duration: widget.reducedMotion
                ? Duration.zero
                : widget.xpFillDuration,
            curve: Curves.easeOut,
            builder: (context, fraction, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: NeonTheme.cardAlt,
                valueColor: AlwaysStoppedAnimation(NeonTheme.gold),
              ),
            ),
          ),
          if (widget.phase == LevelUpPhase.rewardReveal &&
              event.rewardLines.isNotEmpty) ...[
            const SizedBox(height: NeonTheme.s16),
            AnimatedOpacity(
              opacity: 1.0,
              duration: widget.reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in event.rewardLines)
                    Padding(
                      padding: const EdgeInsets.only(top: NeonTheme.s8),
                      child: Text(
                        '+${line.amount} ${line.currency}',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: NeonTheme.inkSoft,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (widget.onSkipTap != null) ...[
            const SizedBox(height: NeonTheme.s16),
            GestureDetector(
              onTap: widget.onSkipTap,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
