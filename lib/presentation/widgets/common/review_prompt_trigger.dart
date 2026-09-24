import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/in_app_review_helper.dart';

/// Wraps [child] and calls [maybeRequestReview] every time
/// [winStreakEvents] fires (ENH-87) — the ready-to-use widget counterpart
/// to `in_app_review_helper.dart`'s decision logic, which the rest of the
/// kit had no widget consuming at all before this. Same "core service has
/// timing logic → widget listener wired to it" pattern as
/// `AchievementUnlockListener`/`AchievementService`.
///
/// [winStreakEvents] is entirely caller-supplied — this widget doesn't
/// invent its own "happy moment" source (there's no single game-agnostic
/// event for that in this kit, unlike `AchievementService.onUnlock`). A
/// consumer app fires an event on it with the player's CURRENT win streak
/// count whenever a moment worth asking after happens (e.g. right after a
/// level win), and [maybeRequestReview]'s own `minWinStreak`/`cooldown`
/// policy decides whether that particular event actually triggers a
/// prompt.
///
/// [everDeclined] is read fresh from [State.widget] on every event (not
/// cached at listen time), so a caller can flip it via `setState` on a
/// parent and have the very next event respect the new value.
///
/// A [showReview] that throws (or a missing `StorageService`
/// registration) is swallowed — same "never throws" defensive convention
/// as `AchievementUnlockListener` — since a review-prompt failure must
/// never crash the gameplay moment that triggered it.
class ReviewPromptTrigger extends StatefulWidget {
  const ReviewPromptTrigger({
    super.key,
    required this.child,
    required this.winStreakEvents,
    required this.showReview,
    this.minWinStreak = 3,
    this.everDeclined = false,
    this.cooldown = const Duration(days: 30),
    this.onRequested,
  });

  final Widget child;

  /// Emits the player's current win-streak count at each "happy moment" a
  /// consumer app wants considered as a review-prompt opportunity.
  final Stream<int> winStreakEvents;

  /// Forwarded to [maybeRequestReview] — the actual "show the native
  /// prompt" call, injected by the consumer app (same seam convention as
  /// every other concrete-SDK-free service in this kit).
  final Future<void> Function() showReview;

  final int minWinStreak;
  final bool everDeclined;
  final Duration cooldown;

  /// Fires after [maybeRequestReview] actually invoked [showReview] for a
  /// given event — e.g. for a consumer to log an analytics event. Never
  /// called when the policy decided NOT to prompt.
  final VoidCallback? onRequested;

  @override
  State<ReviewPromptTrigger> createState() => _ReviewPromptTriggerState();
}

class _ReviewPromptTriggerState extends State<ReviewPromptTrigger> {
  StreamSubscription<int>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.winStreakEvents.listen(_onEvent);
  }

  // BUG-70: without this, a parent rebuilding this widget with a
  // DIFFERENT winStreakEvents Stream (e.g. switching game mode, a fresh
  // StreamController) left _subscription listening to the OLD stream
  // forever — every event on the new one was silently lost, no error, no
  // log. Same resubscribe-on-change pattern ScreenShake's own
  // didUpdateWidget already uses for its controller.
  @override
  void didUpdateWidget(covariant ReviewPromptTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.winStreakEvents != widget.winStreakEvents) {
      _subscription?.cancel();
      _subscription = widget.winStreakEvents.listen(_onEvent);
    }
  }

  Future<void> _onEvent(int recentWinStreak) async {
    bool requested;
    try {
      requested = await maybeRequestReview(
        recentWinStreak: recentWinStreak,
        showReview: widget.showReview,
        minWinStreak: widget.minWinStreak,
        everDeclined: widget.everDeclined,
        cooldown: widget.cooldown,
      );
    } catch (_) {
      return;
    }
    if (requested && mounted) {
      widget.onRequested?.call();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
