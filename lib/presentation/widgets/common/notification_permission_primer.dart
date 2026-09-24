import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';

/// Which branch [showNotificationPermissionPrimer] resolved to.
enum NotificationPermissionPrimerChoice {
  /// The user tapped accept — [showNotificationPermissionPrimer]'s
  /// `onAccept` (the caller's real `ReminderService` permission flow) was
  /// invoked.
  accepted,

  /// The user tapped decline — the native OS permission dialog was never
  /// touched, `onAccept` was never called.
  declined,

  /// Neither button was tapped (barrier/back dismissed the dialog) —
  /// treated the same as declining: `onAccept` is never called.
  dismissed,
}

/// (IDEA-68) A soft "ask before you ask" primer shown BEFORE
/// [ReminderService]'s first `scheduleNext()`/`cancel()` call triggers the
/// real native OS notification-permission dialog — same "soft-ask first"
/// pattern [showSmartReviewFunnel] (IDEA-61) already uses for store
/// reviews.
///
/// `ReminderService`'s native permission prompt only fires once per app
/// install; if the player declines it there, nothing in-app can ask again
/// until they leave the app and flip it on in system Settings themselves.
/// This primer lets the caller filter that one shot behind a dismissible,
/// re-askable in-app dialog first — decline here costs nothing, the native
/// dialog is simply never opened.
///
/// ```dart
/// showNotificationPermissionPrimer(
///   context,
///   onAccept: () => ReminderService.to.scheduleNext(...),
/// );
/// ```
Future<NotificationPermissionPrimerChoice> showNotificationPermissionPrimer(
  BuildContext context, {
  required Future<void> Function() onAccept,
  Future<void> Function()? onDecline,
  String title = 'Bật thông báo để không bỏ lỡ phần thưởng?',
  String? message,
  String acceptLabel = 'Bật thông báo',
  String declineLabel = 'Để sau',
}) async {
  final completer = Completer<NotificationPermissionPrimerChoice>();
  unawaited(
    NeonDialog.show<void>(
      context: context,
      title: title,
      message: message,
      color: NeonTheme.purple,
      actions: [
        NeonDialogAction(
          label: declineLabel,
          color: NeonTheme.muted,
          onTap: () =>
              completer.complete(NotificationPermissionPrimerChoice.declined),
        ),
        NeonDialogAction(
          label: acceptLabel,
          color: NeonTheme.lime,
          onTap: () =>
              completer.complete(NotificationPermissionPrimerChoice.accepted),
        ),
      ],
    ).then((_) {
      // Same "route closed some other way (back button/gesture)" guard as
      // showConfirmDialog/showSmartReviewFunnel — defer past any
      // already-scheduled action callback instead of racing it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) {
          completer.complete(NotificationPermissionPrimerChoice.dismissed);
        }
      });
    }),
  );

  final choice = await completer.future;
  if (choice == NotificationPermissionPrimerChoice.accepted) {
    await onAccept();
  } else if (choice == NotificationPermissionPrimerChoice.declined) {
    await onDecline?.call();
  }
  return choice;
}
