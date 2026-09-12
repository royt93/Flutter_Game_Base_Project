import 'storage_service.dart';
import 'utils/clamped_clock.dart';

/// Decision logic for "should we ask for a store review right now" — the
/// classic casual-game pattern of prompting right after a happy moment
/// (e.g. a win streak), without asking too often.
///
/// This package stays neutral of any concrete review-prompt SDK (same
/// convention as `crash_reporter.dart`/`cloud_save_provider.dart`): it does
/// NOT depend on the `in_app_review` package. The actual "show the native
/// prompt" call is injected via [showReview] — a consuming app supplies
/// `() => InAppReview.instance.requestReview()` itself.
///
/// **`everDeclined` is a caller-supplied param, not internal state.** The
/// real store SDKs (Apple/Google) deliberately never tell the app whether
/// the user actually rated or dismissed the native prompt — that's a
/// privacy/anti-gaming policy, not an oversight — so this helper has no way
/// to learn "declined" from [showReview] alone (it only returns whether the
/// prompt request itself was invoked). A consuming app that wants to gate on
/// a decline typically runs its own pre-prompt UI first ("Enjoying the
/// game?" Yes/No) and passes that answer in here every call.
///
/// Returns whether [showReview] was actually invoked.
Future<bool> maybeRequestReview({
  required int recentWinStreak,
  required Future<void> Function() showReview,
  int minWinStreak = 3,
  bool everDeclined = false,
  Duration cooldown = const Duration(days: 30),
}) async {
  if (everDeclined) return false;
  if (recentWinStreak < minWinStreak) return false;

  final now = nowMsClamped();
  final lastAskedMs = StorageService.to.getInt(
    StorageKeys.reviewLastAskedMs,
    def: -1,
  );
  if (lastAskedMs >= 0 && now - lastAskedMs < cooldown.inMilliseconds) {
    return false;
  }

  // BUG-25: call showReview() FIRST, persist the timestamp only after it
  // succeeds. Persisting first (the old order) meant a throwing/failed
  // platform call still burned the entire cooldown — every retry for the
  // next `cooldown` duration was blocked despite never having actually
  // shown a prompt.
  await showReview();
  await StorageService.to.setInt(StorageKeys.reviewLastAskedMs, now);
  return true;
}
