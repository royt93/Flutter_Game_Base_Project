import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';

/// Thin convenience wrapper over [NeonDialog.show] for the common
/// "are you sure?" confirm/cancel case. Delegates all rendering to
/// [NeonDialog.show] (which already handles the Flame-`GameWidget`-safe
/// routing per this repo's Dialog pattern) — this just supplies the two
/// actions and resolves to `true`/`false` based on which one was tapped.
///
/// `dismissible` is left at its `NeonDialog.show` default (`false`) so the
/// barrier can't be tapped away without picking an action. The route can
/// still be popped without picking an action (Android hardware back/gesture
/// pops the topmost route regardless of `dismissible`) — [completer] guards
/// against that: if the route closes for any other reason, it defaults to
/// `false` instead of leaving the returned future pending forever.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
  Color? color,
  IconData? icon,
}) {
  color ??= NeonTheme.purple;
  // ENH-39: default labels go through AppTranslations (already has 'ok'/
  // 'cancel' keys) so this common confirm dialog respects the current
  // locale instead of always showing English — caller-supplied labels
  // (game-specific copy) still take priority when given.
  confirmLabel ??= 'ok'.tr;
  cancelLabel ??= 'cancel'.tr;
  final completer = Completer<bool>();
  NeonDialog.show<void>(
    context: context,
    title: title,
    message: message,
    color: color,
    icon: icon,
    actions: [
      NeonDialogAction(
        label: cancelLabel,
        color: NeonTheme.muted,
        onTap: () => completer.complete(false),
      ),
      NeonDialogAction(
        label: confirmLabel,
        color: color,
        onTap: () => completer.complete(true),
      ),
    ],
  ).then((_) {
    // NeonDialog.show's wrapped actions pop the route synchronously, then
    // run the real `onTap` (which completes `completer`) in a deferred
    // `addPostFrameCallback` (see neon_dialog.dart) — so this `.then()` can
    // fire BEFORE that callback runs. Defer the fallback the same way so it
    // queues after any already-scheduled action callback instead of racing
    // it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete(false);
    });
  });
  return completer.future;
}
