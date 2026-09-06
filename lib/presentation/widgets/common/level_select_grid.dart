import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';
import 'star_rating.dart';

/// Progress state of a single level node in a [LevelSelectGrid] — the grid
/// holds no progress logic of its own, this is what the caller's own
/// save/progress system hands in per level.
enum LevelState { locked, unlocked, completed }

/// Icon shown over a [LevelNodeButton] for [state] — only `locked` gets one
/// (a lock glyph instead of the level number); `unlocked`/`completed` just
/// show the number, distinguished from each other by fill/border color.
IconData? levelStateIcon(LevelState state) =>
    state == LevelState.locked ? Icons.lock_rounded : null;

/// Whether a node in [state] can be tapped at all.
bool levelStateTappable(LevelState state) => state != LevelState.locked;

/// Node fill color for [state] — dim gray for locked, card white for
/// unlocked, gold for completed.
Color levelStateFillColor(LevelState state) => switch (state) {
  LevelState.locked => NeonTheme.lockedFill,
  LevelState.unlocked => NeonTheme.card,
  LevelState.completed => NeonTheme.gold,
};

/// Node border color for [state].
Color levelStateBorderColor(LevelState state) => switch (state) {
  LevelState.locked => NeonTheme.lockedBorder,
  LevelState.unlocked => NeonTheme.cyan,
  LevelState.completed => NeonTheme.gold,
};

/// One round level node — the world-map/level-select building block. Shows
/// the level number, or a lock glyph (and blocks tap) when [state] is
/// `locked`, plus a mini [StarRating] badge underneath once `completed`.
class LevelNodeButton extends StatelessWidget {
  const LevelNodeButton({
    super.key,
    required this.levelNumber,
    required this.state,
    this.starsEarned = 0,
    this.onTap,
    this.size = 64,
  });

  final int levelNumber;
  final LevelState state;

  /// 0-3, only meaningful (and only shown) when [state] is `completed`.
  final int starsEarned;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = levelStateIcon(state);
    final textColor = switch (state) {
      LevelState.completed => Colors.white,
      LevelState.locked => NeonTheme.inkSoft,
      LevelState.unlocked => NeonTheme.ink,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressableScale(
          onTap: levelStateTappable(state) ? onTap : null,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: levelStateFillColor(state),
              border: Border.all(
                color: levelStateBorderColor(state),
                width: 3,
              ),
              boxShadow: state == LevelState.locked
                  ? null
                  : NeonTheme.drop(y: 3, blur: 8),
            ),
            child: icon != null
                ? Icon(icon, color: textColor, size: size * 0.4)
                : Text(
                    '$levelNumber',
                    style: TextStyle(
                      color: textColor,
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        if (state == LevelState.completed) ...[
          const SizedBox(height: 4),
          StarRating(earned: starsEarned, size: size * 0.18),
        ],
      ],
    );
  }
}

/// Read-only grid of [LevelNodeButton]s for a world-map/level-select screen
/// — a pure display widget, it holds no progress state itself. [states]
/// gives each level's [LevelState] in order (level 1 at index 0);
/// [starsEarnedByLevel] optionally maps a 1-based level number to its
/// earned star count. [onLevelTap] fires with the 1-based level number of
/// whichever `unlocked`/`completed` node was tapped — `locked` nodes never
/// fire it.
class LevelSelectGrid extends StatelessWidget {
  const LevelSelectGrid({
    super.key,
    required this.states,
    this.starsEarnedByLevel = const {},
    this.onLevelTap,
    this.crossAxisCount = 4,
    this.nodeSize = 64,
    this.spacing = NeonTheme.s16,
  });

  final List<LevelState> states;
  final Map<int, int> starsEarnedByLevel;
  final ValueChanged<int>? onLevelTap;
  final int crossAxisCount;
  final double nodeSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: states.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final levelNumber = index + 1;
        return LevelNodeButton(
          levelNumber: levelNumber,
          state: states[index],
          starsEarned: starsEarnedByLevel[levelNumber] ?? 0,
          size: nodeSize,
          onTap: onLevelTap == null ? null : () => onLevelTap!(levelNumber),
        );
      },
    );
  }
}
