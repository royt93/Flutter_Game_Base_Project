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
  const LoadingOverlay({super.key, this.message});

  /// Optional short label shown below the spinner (e.g. "Loading...").
  final String? message;

  @override
  Widget build(BuildContext context) {
    assert(
      context.findAncestorWidgetOfExactType<Stack>() != null,
      'LoadingOverlay must be a direct child of a Stack. '
      'Wrap it in your own Stack, e.g. '
      'Stack(children: [..., if (isLoading) const LoadingOverlay()]).',
    );
    return Positioned.fill(
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
                valueColor: AlwaysStoppedAnimation(NeonTheme.magenta),
                backgroundColor: NeonTheme.purple.withValues(alpha: 0.3),
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
    );
  }
}
