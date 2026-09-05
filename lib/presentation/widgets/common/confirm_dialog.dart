import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';

/// Thin convenience wrapper over [NeonDialog.show] for the common
/// "are you sure?" confirm/cancel case. Delegates all rendering to
/// [NeonDialog.show] (which already handles the Flame-`GameWidget`-safe
/// routing per this repo's Dialog pattern) — this just supplies the two
/// actions and resolves to `true`/`false` based on which one was tapped.
///
/// `dismissible` is left at its `NeonDialog.show` default (`false`) so the
/// barrier can't be tapped away without picking an action — otherwise the
/// returned future would never complete.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
  Color color = NeonTheme.purple,
  IconData? icon,
}) {
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
  );
  return completer.future;
}
