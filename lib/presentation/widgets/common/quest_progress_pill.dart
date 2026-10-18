import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'badge_dot.dart';

/// Compact "completed/total quests" entry with a claimable-reward badge.
/// Presentation-only: the caller reads quest state and opens the board.
class QuestProgressPill extends StatelessWidget {
  QuestProgressPill({
    super.key,
    required this.completed,
    required this.total,
    required this.onTap,
    this.claimableCount = 0,
    this.label = 'Quests',
    this.semanticLabel,
  }) {
    if (total <= 0) {
      throw ArgumentError.value(total, 'total', 'must be > 0');
    }
    if (completed < 0 || completed > total) {
      throw ArgumentError.value(completed, 'completed', 'must be in 0..total');
    }
    if (claimableCount < 0 || claimableCount > completed) {
      throw ArgumentError.value(
        claimableCount,
        'claimableCount',
        'must be in 0..completed',
      );
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank');
    }
    if (semanticLabel != null && semanticLabel!.trim().isEmpty) {
      throw ArgumentError.value(
        semanticLabel,
        'semanticLabel',
        'must not be blank',
      );
    }
  }

  final int completed;
  final int total;
  final int claimableCount;
  final VoidCallback onTap;
  final String label;

  /// Replaces the default English screen-reader text (caller owns i18n).
  final String? semanticLabel;

  bool get _done => completed == total;

  @override
  Widget build(BuildContext context) {
    final accent = _done ? NeonTheme.lime : NeonTheme.purple;
    final duration = NeonTheme.reducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final spoken =
        semanticLabel ??
        '$label, $completed of $total complete'
            '${claimableCount > 0 ? ', $claimableCount ready to claim' : ''}';

    return Semantics(
      button: true,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('questProgressPillTap'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: NeonTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _done ? Icons.check_circle_rounded : Icons.flag_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label $completed/$total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        key: const ValueKey('questProgressPillBar'),
                        tween: Tween(end: completed / total),
                        duration: duration,
                        curve: Curves.easeOut,
                        builder: (_, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          color: accent,
                          backgroundColor: NeonTheme.cardAlt,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (claimableCount > 0) ...[
                const SizedBox(width: 8),
                const BadgeDot(size: 8, pulse: true),
                const SizedBox(width: 4),
                Container(
                  key: const ValueKey('questProgressPillBadge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: NeonTheme.pink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    claimableCount > 9 ? '9+' : '$claimableCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
