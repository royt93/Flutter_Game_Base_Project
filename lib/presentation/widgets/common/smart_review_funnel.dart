import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';

/// Which branch [showSmartReviewFunnel] resolved to.
enum SmartReviewFunnelChoice {
  /// "Thích" — the real store review flow ([showSmartReviewFunnel]'s
  /// `showReview`) was invoked.
  liked,

  /// "Chưa thích" — the internal feedback dialog was shown instead; the
  /// store was never opened.
  disliked,

  /// Neither button was tapped (barrier/back dismissed the first dialog)
  /// — nothing happened, same as declining a [showConfirmDialog].
  dismissed,
}

/// (IDEA-61) A 2-step "Bạn có thích game không?" micro-survey shown
/// BEFORE opening the real store review — routes a dissatisfied player to
/// an internal feedback step instead of straight to a public store
/// review, where a 1-star rating would otherwise be likely.
///
/// Meant as the `showReview` callback passed to `ReviewPromptTrigger`
/// (ENH-87)/[maybeRequestReview] — this widget is the extra filtering
/// step BETWEEN "now is a good moment to ask" (that policy's own job) and
/// actually opening the store, not a replacement for it:
/// ```dart
/// ReviewPromptTrigger(
///   winStreakEvents: winStreakEvents,
///   showReview: () => showSmartReviewFunnel(
///     context,
///     showReview: () => InAppReview.instance.requestReview(),
///   ),
///   child: ...,
/// );
/// ```
///
/// "Chưa thích" opens a plain in-tree feedback dialog (no backend baked
/// in — same seam convention as every other concrete-SDK-free piece of
/// this kit) — [onFeedback], if supplied, receives the typed text; left
/// `null`, submitting just closes the dialog with no external effect.
Future<SmartReviewFunnelChoice> showSmartReviewFunnel(
  BuildContext context, {
  required Future<void> Function() showReview,
  Future<void> Function(String feedback)? onFeedback,
  String title = 'Bạn có thích game không?',
  String likeLabel = 'Thích ❤️',
  String dislikeLabel = 'Chưa thích 💔',
  String feedbackTitle = 'Điều gì khiến bạn chưa hài lòng?',
  String feedbackHint = 'Góp ý của bạn (không bắt buộc)',
  String feedbackSubmitLabel = 'Gửi góp ý',
}) async {
  final completer = Completer<SmartReviewFunnelChoice>();
  unawaited(
    NeonDialog.show<void>(
      context: context,
      title: title,
      color: NeonTheme.purple,
      actions: [
        NeonDialogAction(
          label: dislikeLabel,
          color: NeonTheme.muted,
          onTap: () => completer.complete(SmartReviewFunnelChoice.disliked),
        ),
        NeonDialogAction(
          label: likeLabel,
          color: NeonTheme.lime,
          onTap: () => completer.complete(SmartReviewFunnelChoice.liked),
        ),
      ],
    ).then((_) {
      // Same "route closed some other way (back button/gesture)" guard as
      // showConfirmDialog — defer past any already-scheduled action
      // callback instead of racing it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) {
          completer.complete(SmartReviewFunnelChoice.dismissed);
        }
      });
    }),
  );

  final choice = await completer.future;
  if (choice == SmartReviewFunnelChoice.liked) {
    await showReview();
  } else if (choice == SmartReviewFunnelChoice.disliked) {
    if (!context.mounted) return choice;
    await _showFeedbackDialog(
      context,
      onFeedback: onFeedback,
      title: feedbackTitle,
      hint: feedbackHint,
      submitLabel: feedbackSubmitLabel,
    );
  }
  return choice;
}

Future<void> _showFeedbackDialog(
  BuildContext context, {
  required Future<void> Function(String feedback)? onFeedback,
  required String title,
  required String hint,
  required String submitLabel,
}) async {
  final controller = TextEditingController();
  final completer = Completer<void>();
  unawaited(
    NeonDialog.show<void>(
      context: context,
      title: title,
      color: NeonTheme.purple,
      content: TextField(
        key: const Key('smartReviewFunnelFeedbackField'),
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        NeonDialogAction(
          label: submitLabel,
          color: NeonTheme.purple,
          onTap: () {
            final future = onFeedback?.call(controller.text.trim());
            (future ?? Future<void>.value()).whenComplete(() {
              if (!completer.isCompleted) completer.complete();
            });
          },
        ),
      ],
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) completer.complete();
      });
    }),
  );
  await completer.future;
  controller.dispose();
}
