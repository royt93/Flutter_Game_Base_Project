import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';
import 'common_button.dart';

/// Categories for caller-supplied puzzle-move hints (FEAT-138).
enum MoveHintType { swap, booster, goal, custom }

extension MoveHintTypePresentation on MoveHintType {
  IconData get defaultIcon => switch (this) {
    MoveHintType.swap => Icons.swap_horiz_rounded,
    MoveHintType.booster => Icons.bolt_rounded,
    MoveHintType.goal => Icons.flag_rounded,
    MoveHintType.custom => Icons.lightbulb_rounded,
  };

  Color get defaultColor => switch (this) {
    MoveHintType.swap => NeonTheme.cyan,
    MoveHintType.booster => NeonTheme.orange,
    MoveHintType.goal => NeonTheme.lime,
    MoveHintType.custom => NeonTheme.purple,
  };
}

/// In-tree puzzle hint panel. Caller owns hint selection, board logic, and
/// optional refill/purchase flow; this widget only presents provided content.
class MoveHintPopup extends StatelessWidget {
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

  final MoveHintType type;
  final String title;
  final String message;
  final VoidCallback onDismiss;
  final Widget? hintContent;
  final GlobalKey? fromKey;
  final GlobalKey? toKey;
  final Offset? from;
  final Offset? to;
  final int remainingHints;
  final VoidCallback? onHintTap;
  final VoidCallback? onEmptyHintTap;
  final String? hintLabel;
  final String dismissLabel;
  final Color? color;
  final String? semanticLabel;

  /// Displays the panel via [NeonDialog.show], safe over Flame `GameWidget`.
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
                        child: Icon(type.defaultIcon, color: accent, size: 30),
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
    );
  }
}
