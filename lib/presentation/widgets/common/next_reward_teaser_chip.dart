import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'badge_dot.dart';

/// Short "next reward" nudge: reward name, caller-formatted remaining text and
/// optional progress. Presentation-only: the caller owns progress and the
/// destination screen.
class NextRewardTeaserChip extends StatelessWidget {
  NextRewardTeaserChip({
    super.key,
    required this.rewardLabel,
    required this.remainingText,
    required this.onTap,
    this.progress,
    this.ready = false,
    this.readyLabel = 'Claim',
    this.icon = Icons.card_giftcard_rounded,
    this.semanticLabel,
  }) {
    if (rewardLabel.trim().isEmpty) {
      throw ArgumentError.value(rewardLabel, 'rewardLabel', 'must not be blank');
    }
    if (remainingText.trim().isEmpty) {
      throw ArgumentError.value(
        remainingText,
        'remainingText',
        'must not be blank',
      );
    }
    if (readyLabel.trim().isEmpty) {
      throw ArgumentError.value(readyLabel, 'readyLabel', 'must not be blank');
    }
    final value = progress;
    if (value != null && (!value.isFinite || value < 0 || value > 1)) {
      throw ArgumentError.value(value, 'progress', 'must be finite and in 0..1');
    }
    if (semanticLabel != null && semanticLabel!.trim().isEmpty) {
      throw ArgumentError.value(
        semanticLabel,
        'semanticLabel',
        'must not be blank',
      );
    }
  }

  final String rewardLabel;

  /// Caller-formatted, e.g. "2 wins to go". Ignored visually when [ready].
  final String remainingText;
  final VoidCallback onTap;

  /// 0..1, or `null` to hide the bar.
  final double? progress;
  final bool ready;
  final String readyLabel;
  final IconData icon;

  /// Replaces the default English screen-reader text (caller owns i18n).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final accent = ready ? NeonTheme.pink : NeonTheme.purple;
    final duration = NeonTheme.reducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final secondary = ready ? readyLabel : remainingText;
    final spoken = semanticLabel ?? '$rewardLabel, $secondary';

    return Semantics(
      button: true,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('nextRewardChipTap'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ready ? accent.withValues(alpha: 0.12) : NeonTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withValues(alpha: ready ? 0.9 : 0.5),
              width: ready ? 2 : 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rewardLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      secondary,
                      key: const ValueKey('nextRewardChipSecondary'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ready ? accent : NeonTheme.inkSoft,
                        fontSize: 12,
                        fontWeight: ready ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                    if (progress != null && !ready) ...[
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          key: const ValueKey('nextRewardChipBar'),
                          tween: Tween(end: progress),
                          duration: duration,
                          curve: Curves.easeOut,
                          builder: (_, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 5,
                            color: accent,
                            backgroundColor: NeonTheme.cardAlt,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (ready) ...[
                const SizedBox(width: 8),
                const BadgeDot(
                  key: ValueKey('nextRewardChipDot'),
                  size: 9,
                  pulse: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
