import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Candy-styled panel for the bottom of a sheet: rounded top corners, a drag
/// handle bar, [NeonTheme.card] background. Pure visual container — pair it
/// with [showCommonBottomSheet] to actually present it.
class BottomSheetPanel extends StatelessWidget {
  const BottomSheetPanel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(NeonTheme.s24),
  });

  final Widget child;

  /// Defaults to [NeonTheme.purple] — nullable because a `NeonTheme` color
  /// field is no longer a compile-time constant, so it can't be a `const`
  /// constructor default value.
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? NeonTheme.purple;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          ...NeonTheme.glow(color, blur: 20, spread: 1, intensity: 0.4),
          ...NeonTheme.drop(y: -2, blur: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: NeonTheme.s16),
              decoration: BoxDecoration(
                color: NeonTheme.inkSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Presents [child] wrapped in a [BottomSheetPanel] via Flutter's native
/// `showModalBottomSheet`.
///
/// Safe to call from any normal routed Material screen. **Do not** call this
/// from a screen that has an active Flame `GameWidget` on top without
/// checking first — per this repo's Dialog pattern (CLAUDE.md "Dialog
/// pattern" / `neon_dialog.dart`), `Get.dialog`/`showDialog` are no-ops once
/// a `GameWidget` is on screen, and `showModalBottomSheet` rides the same
/// `Navigator`/route machinery, so it likely has the same problem there.
/// This base project currently has no Flame `GameWidget` screen, so it's
/// safe everywhere today — a future game build should verify before reusing
/// this helper on a game screen (fall back to `NeonDialog.overlay` instead).
Future<T?> showCommonBottomSheet<T>(
  BuildContext context, {
  required Widget child,
  Color? color,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    barrierColor: barrierColor,
    builder: (_) => SafeArea(
      child: BottomSheetPanel(color: color, child: child),
    ),
  );
}
