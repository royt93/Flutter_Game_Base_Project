import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Compact player level badge with an XP bar toward the next level.
/// Presentation-only: the caller computes XP, persists it and detects level-ups.
class XpLevelHeader extends StatefulWidget {
  XpLevelHeader({
    super.key,
    required this.level,
    required this.currentXp,
    this.xpForNextLevel,
    this.title,
    this.xpText,
    this.levelLabel = 'Lv',
    this.maxLabel = 'MAX',
    this.onTap,
    this.semanticLabel,
  }) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'must be >= 1');
    }
    if (currentXp < 0) {
      throw ArgumentError.value(currentXp, 'currentXp', 'must be >= 0');
    }
    final next = xpForNextLevel;
    if (next != null) {
      if (next <= 0) {
        throw ArgumentError.value(next, 'xpForNextLevel', 'must be > 0');
      }
      if (currentXp > next) {
        throw ArgumentError.value(
          currentXp,
          'currentXp',
          'must be <= xpForNextLevel',
        );
      }
    }
    for (final (name, value) in [
      ('levelLabel', levelLabel),
      ('maxLabel', maxLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
    for (final (name, value) in [
      ('title', title),
      ('xpText', xpText),
      ('semanticLabel', semanticLabel),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final int level;
  final int currentXp;

  /// `null` means the player is at the maximum level.
  final int? xpForNextLevel;
  final String? title;

  /// Caller-formatted XP text; defaults to `current/next`.
  final String? xpText;
  final String levelLabel;
  final String maxLabel;
  final VoidCallback? onTap;

  /// Replaces the default English screen-reader text (caller owns i18n).
  final String? semanticLabel;

  @override
  State<XpLevelHeader> createState() => _XpLevelHeaderState();
}

class _XpLevelHeaderState extends State<XpLevelHeader> {
  late double _from = _fractionOf(widget);

  static double _fractionOf(XpLevelHeader w) =>
      w.xpForNextLevel == null ? 1 : w.currentXp / w.xpForNextLevel!;

  @override
  void didUpdateWidget(covariant XpLevelHeader old) {
    super.didUpdateWidget(old);
    _from = _fractionOf(old);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final level = w.level;
    final currentXp = w.currentXp;
    final xpForNextLevel = w.xpForNextLevel;
    final title = w.title;
    final onTap = w.onTap;
    final levelLabel = w.levelLabel;
    final maxLabel = w.maxLabel;
    final xpText = w.xpText;
    final semanticLabel = w.semanticLabel;
    final isMax = xpForNextLevel == null;
    final fraction = _fractionOf(w);
    final duration = NeonTheme.reducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 400);
    final accent = isMax ? NeonTheme.gold : NeonTheme.purple;
    final shownXp = isMax ? maxLabel : (xpText ?? '$currentXp/$xpForNextLevel');
    final spoken =
        semanticLabel ??
        '${title == null ? '' : '$title, '}Level $level, '
            '${isMax ? 'max level' : '$currentXp of $xpForNextLevel XP, '
                      '${(fraction * 100).floor()} percent'}';

    final content = Container(
      constraints: BoxConstraints(minHeight: onTap == null ? 0 : 48),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            key: const ValueKey('xpLevelBadge'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$levelLabel $level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                Text(
                  shownXp,
                  key: const ValueKey('xpLevelText'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: NeonTheme.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    key: const ValueKey('xpLevelBar'),
                    tween: Tween(begin: _from, end: fraction),
                    duration: duration,
                    curve: Curves.easeOut,
                    builder: (_, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      color: accent,
                      backgroundColor: NeonTheme.cardAlt,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(label: spoken, excludeSemantics: true, child: content);
    }
    return Semantics(
      button: true,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('xpLevelHeaderTap'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
