import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Full-screen dimmed barrier + centered candy-styled spinner.
///
/// Pattern chosen: a plain widget the caller conditionally includes inside
/// their own `Stack` (e.g. `if (isLoading.value) const LoadingOverlay()`) —
/// same "in-tree overlay" convention as [NeonDialog.overlay]/`.overlaySlot`,
/// so it works whether the screen is a normal route or has a Flame
/// `GameWidget` on top of it. No `show()`/`hide()` statics: there is no
/// global overlay slot to manage, the caller's own reactive flag already is
/// the show/hide switch.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.message,
    this.color,
    this.backgroundColor,
  });

  /// Optional short label shown below the spinner (e.g. "Loading...").
  final String? message;

  /// Spinner's active arc color. Defaults to [NeonTheme.magenta] (ENH-49).
  final Color? color;

  /// Spinner's track (resting) color. Defaults to a translucent
  /// [NeonTheme.purple] (ENH-49).
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    assert(
      context.findAncestorWidgetOfExactType<Stack>() != null,
      'LoadingOverlay must be a direct child of a Stack. '
      'Wrap it in your own Stack, e.g. '
      'Stack(children: [..., if (isLoading) const LoadingOverlay()]).',
    );
    return Positioned.fill(
      // ENH-37: this Flutter SDK's Semantics widget has no `modal` param
      // (confirmed in framework source — only the lower-level
      // SemanticsConfiguration has one, not exposed here), and this overlay
      // deliberately isn't a real Navigator route either (see class doc —
      // that's the whole reason it exists instead of showDialog), so
      // scopesRoute wouldn't be accurate. liveRegion announces the barrier
      // the moment it appears (same reasoning as ToastBanner/
      // NetworkStatusBanner), and container groups it as 1 node instead of
      // leaking the spinner + message as 2 separate ones.
      child: Semantics(
        label: message ?? 'Loading',
        liveRegion: true,
        container: true,
        excludeSemantics: true,
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation(
                    color ?? NeonTheme.magenta,
                  ),
                  backgroundColor:
                      backgroundColor ??
                      NeonTheme.purple.withValues(alpha: 0.3),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: NeonTheme.s16),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
