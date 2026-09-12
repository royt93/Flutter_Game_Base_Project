import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../stroke_text.dart';
import 'common_button.dart';
import 'panel_card.dart';

/// Pre-built "game over" card — the loss/retry counterpart to
/// [PanelCard]-based `VictoryCardTemplate` for a level-complete moment.
/// Deliberately smaller: no avatar/QR/share wiring (a losing moment has no
/// invite-link/share use case), just a headline, optional message and stat
/// lines, plus one or two action buttons (typically "Retry" and "Home").
///
/// Every piece of dynamic content is caller-supplied — [statLines] are
/// plain strings the consumer app has already worded/localized/computed,
/// same convention as `VictoryCardTemplate`.
class GameOverCardTemplate extends StatelessWidget {
  const GameOverCardTemplate({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.statLines = const [],
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.accentColor,
  }) : assert(
         (secondaryActionLabel == null) == (onSecondaryAction == null),
         'secondaryActionLabel and onSecondaryAction must be supplied together',
       );

  /// Caller-supplied headline, e.g. "Out of moves!" — no i18n baked in.
  final String title;

  /// Optional caller-supplied subtitle, e.g. "So close!".
  final String? message;

  /// Optional icon shown above the title (no avatar slot here, unlike
  /// `VictoryCardTemplate` — a loss moment has no player identity to show).
  final IconData? icon;

  /// Caller-supplied stat strings, rendered as a simple vertical list.
  final List<String> statLines;

  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;

  /// Optional second action (e.g. "Home") — omit both this and
  /// [onSecondaryAction] for a single-button card.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Defaults to [NeonTheme.muted] — a loss moment reads better in a
  /// subdued tone than `VictoryCardTemplate`'s default gold.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? NeonTheme.muted;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NeonTheme.reducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: PanelCard(
        borderColor: accent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: accent, size: 48),
              const SizedBox(height: NeonTheme.s16),
            ],
            StrokeText(title, fontSize: 22, color: accent),
            if (message != null) ...[
              const SizedBox(height: NeonTheme.s8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (statLines.isNotEmpty) const SizedBox(height: NeonTheme.s16),
            for (final line in statLines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NeonTheme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: NeonTheme.s16),
            // ENH-51: full width of the card instead of CommonButton's
            // fixed 240px default — a narrower card (e.g. inside a small
            // dialog) no longer overflows or looks disproportionate.
            SizedBox(
              width: double.infinity,
              child: CommonButton(
                label: primaryActionLabel,
                color: accent,
                onTap: onPrimaryAction,
              ),
            ),
            if (secondaryActionLabel != null) ...[
              const SizedBox(height: NeonTheme.s8),
              SizedBox(
                width: double.infinity,
                child: CommonButton(
                  label: secondaryActionLabel,
                  variant: CommonButtonVariant.secondary,
                  color: accent,
                  onTap: onSecondaryAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
