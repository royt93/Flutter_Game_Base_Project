import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/achievement_service.dart';
import '../../../core/neon_theme.dart';
import 'toast_banner.dart';

/// Wraps [child] and shows a [ToastBanner] every time
/// `AchievementService.onUnlock` fires (IDEA-43) — the ready-to-use
/// on-screen counterpart to `AchievementService`, which the rest of the kit
/// had no widget consuming at all before this.
///
/// Reuses `ToastBanner.show` as-is (its overlay insertion, slide/fade-in
/// animation and `NeonTheme.reducedMotion` handling) rather than building a
/// new toast from scratch — this widget's only job is turning an unlock
/// event into a message string and calling that existing helper.
///
/// No-ops (never throws) if no `AchievementService` is registered via
/// `Get.put` yet — same defensive convention as `DebugQaOverlay`.
class AchievementUnlockListener extends StatefulWidget {
  const AchievementUnlockListener({
    super.key,
    required this.child,
    this.labelFor,
    this.color,
  });

  final Widget child;

  /// Builds the toast message shown for a given achievement id. Defaults to
  /// the id itself — callers that want a human-readable name (the service
  /// itself doesn't store one, see its class doc) should supply this.
  final String Function(String achievementId)? labelFor;

  /// Toast accent color. Defaults to [NeonTheme.gold] — a celebratory color
  /// distinct from `ToastBanner.show`'s own default (purple), since an
  /// achievement unlock is a reward moment, not a generic status message.
  final Color? color;

  @override
  State<AchievementUnlockListener> createState() =>
      _AchievementUnlockListenerState();
}

class _AchievementUnlockListenerState
    extends State<AchievementUnlockListener> {
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = AchievementService.maybe?.onUnlock.listen(_onUnlock);
  }

  void _onUnlock(String achievementId) {
    if (!mounted) return;
    ToastBanner.show(
      context,
      message: widget.labelFor?.call(achievementId) ?? achievementId,
      color: widget.color ?? NeonTheme.gold,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
