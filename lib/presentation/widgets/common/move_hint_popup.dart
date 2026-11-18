import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';
import 'common_button.dart';

/// Categories for caller-supplied puzzle-move hints (FEAT-138).
enum MoveHintType { swap, booster, goal, custom }

/// Default icon and accent color for each [MoveHintType]; used when the
/// popup is not given an explicit `color`.
extension MoveHintTypePresentation on MoveHintType {
  /// Icon shown in the header and in the default illustration.
  IconData get defaultIcon => switch (this) {
    MoveHintType.swap => Icons.swap_horiz_rounded,
    MoveHintType.booster => Icons.bolt_rounded,
    MoveHintType.goal => Icons.flag_rounded,
    MoveHintType.custom => Icons.lightbulb_rounded,
  };

  /// Accent color used for the icon ring and glow and, while hints remain,
  /// the action button.
  Color get defaultColor => switch (this) {
    MoveHintType.swap => NeonTheme.cyan,
    MoveHintType.booster => NeonTheme.orange,
    MoveHintType.goal => NeonTheme.lime,
    MoveHintType.custom => NeonTheme.purple,
  };
}

/// In-tree puzzle hint panel. Caller owns hint selection, board logic, and
/// optional refill/purchase flow; this widget only presents provided content.
///
/// The action button shows "Try Hint" (or [hintLabel]) and calls [onHintTap]
/// while [remainingHints] is above zero; at zero it shows "Get More (+)" and
/// calls [onEmptyHintTap]. The dismiss button always calls [onDismiss].
class MoveHintPopup extends StatelessWidget {
  /// Throws [ArgumentError] if [title] or [message] is blank, [remainingHints]
  /// is negative, only one of [fromKey]/[toKey] or of [from]/[to] is given, or
  /// a [from]/[to] coordinate is not finite.
  MoveHintPopup({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    required this.onDismiss,
    this.hintContent,
    this.fromKey,
    this.toKey,
    this.from,
    this.to,
    this.remainingHints = 0,
    this.onHintTap,
    this.onEmptyHintTap,
    this.hintLabel,
    this.dismissLabel = 'Got it',
    this.color,
    this.semanticLabel,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (message.trim().isEmpty) {
      throw ArgumentError.value(message, 'message', 'must not be empty');
    }
    if (remainingHints < 0) {
      throw ArgumentError.value(
        remainingHints,
        'remainingHints',
        'must be non-negative',
      );
    }
    if ((fromKey == null) != (toKey == null)) {
      throw ArgumentError('Provide both fromKey and toKey, or neither.');
    }
    if ((from == null) != (to == null)) {
      throw ArgumentError('Provide both from and to offsets, or neither.');
    }
    if (from != null && (!from!.dx.isFinite || !from!.dy.isFinite)) {
      throw ArgumentError.value(from, 'from', 'coordinates must be finite');
    }
    if (to != null && (!to!.dx.isFinite || !to!.dy.isFinite)) {
      throw ArgumentError.value(to, 'to', 'coordinates must be finite');
    }
  }

  /// Picks the default icon and accent color.
  final MoveHintType type;

  /// Heading; must not be blank.
  final String title;

  /// Body text; must not be blank.
  final String message;

  /// Called by the dismiss button.
  final VoidCallback onDismiss;

  /// Replaces the built-in illustration when non-null.
  final Widget? hintContent;

  /// Optional board anchors for the hint, validated as a pair with [toKey].
  /// This widget does not read them when rendering; they are carried for the
  /// caller.
  final GlobalKey? fromKey;

  /// See [fromKey].
  final GlobalKey? toKey;

  /// Optional hint start offset, validated as a pair with [to] and required to
  /// be finite. Not read when rendering.
  final Offset? from;

  /// See [from].
  final Offset? to;

  /// Hints left, shown as text. At zero the action button switches to the
  /// "Get More (+)" state. Must not be negative.
  final int remainingHints;

  /// Action button callback while [remainingHints] is above zero.
  final VoidCallback? onHintTap;

  /// Action button callback when no hints remain.
  final VoidCallback? onEmptyHintTap;

  /// Action button label while hints remain; defaults to "Try Hint". Ignored
  /// at zero hints, where the label is "Get More (+)".
  final String? hintLabel;

  /// Dismiss button label; defaults to "Got it".
  final String dismissLabel;

  /// Accent color; defaults to [MoveHintTypePresentation.defaultColor].
  final Color? color;

  /// Overrides the generated screen-reader description of the panel.
  final String? semanticLabel;

  /// Displays the panel via [NeonDialog.show], safe over Flame `GameWidget`.
  /// Parameters match the constructor except [semanticLabel], which is not
  /// forwarded; the dialog also gets a muted action labelled [dismissLabel]
  /// that calls [onDismiss].
  static Future<void> show(
    BuildContext context, {
    required MoveHintType type,
    required String title,
    required String message,
    required VoidCallback onDismiss,
    Widget? hintContent,
    GlobalKey? fromKey,
    GlobalKey? toKey,
    Offset? from,
    Offset? to,
    int remainingHints = 0,
    VoidCallback? onHintTap,
    VoidCallback? onEmptyHintTap,
    String? hintLabel,
    String dismissLabel = 'Got it',
    Color? color,
  }) {
    final accent = color ?? type.defaultColor;
    return NeonDialog.show<void>(
      context: context,
      title: title,
      color: accent,
      content: MoveHintPopup(
        type: type,
        title: title,
        message: message,
        onDismiss: onDismiss,
        hintContent: hintContent,
        fromKey: fromKey,
        toKey: toKey,
        from: from,
        to: to,
        remainingHints: remainingHints,
        onHintTap: onHintTap,
        onEmptyHintTap: onEmptyHintTap,
        hintLabel: hintLabel,
        dismissLabel: dismissLabel,
        color: accent,
      ),
      actions: [
        NeonDialogAction(
          label: dismissLabel,
          color: NeonTheme.muted,
          onTap: onDismiss,
        ),
      ],
    );
  }

  Widget _buildIllustration(Color accent) {
    if (hintContent != null) return hintContent!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: NeonTheme.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.defaultIcon, color: accent, size: 28),
          const SizedBox(width: NeonTheme.s8),
          Icon(Icons.arrow_forward_rounded, color: NeonTheme.inkSoft, size: 20),
          const SizedBox(width: NeonTheme.s8),
          Icon(
            Icons.check_circle_outline_rounded,
            color: NeonTheme.lime,
            size: 28,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = color ?? type.defaultColor;
    final hasHints = remainingHints > 0;
    final actionLabel = hasHints ? (hintLabel ?? 'Try Hint') : 'Get More (+)';
    final actionColor = hasHints ? accent : NeonTheme.lime;
    final semanticsDesc =
        semanticLabel ??
        '$title: $message. ${hasHints ? '$remainingHints hints remaining' : 'No hints remaining, get more'}.'
            '';

    return Container(
      constraints: BoxConstraints(
        maxWidth: 320,
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Semantics(
                  key: const ValueKey('moveHintSemantics'),
                  container: true,
                  label: semanticsDesc,
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: NeonTheme.cardAlt,
                            border: Border.all(color: accent, width: 2),
                            boxShadow: NeonTheme.glow(accent, blur: 10),
                          ),
                          child: Icon(
                            type.defaultIcon,
                            color: accent,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: NeonTheme.s8),
                        Text(
                          title,
                          key: const ValueKey('moveHintTitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: NeonTheme.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: NeonTheme.s8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: NeonTheme.inkSoft,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: NeonTheme.s16),
                        _buildIllustration(accent),
                        const SizedBox(height: NeonTheme.s16),
                        Text(
                          hasHints
                              ? '$remainingHints hints left'
                              : 'Out of hints!',
                          key: const ValueKey('moveHintRemainingText'),
                          style: TextStyle(
                            color: hasHints ? NeonTheme.inkSoft : NeonTheme.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: NeonTheme.s8),
            CommonButton(
              key: const ValueKey('moveHintActionBtn'),
              label: actionLabel,
              color: actionColor,
              width: double.infinity,
              onTap: hasHints ? onHintTap : onEmptyHintTap,
            ),
            const SizedBox(height: NeonTheme.s8),
            CommonButton(
              key: const ValueKey('moveHintDismissBtn'),
              label: dismissLabel,
              variant: CommonButtonVariant.secondary,
              width: double.infinity,
              onTap: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
