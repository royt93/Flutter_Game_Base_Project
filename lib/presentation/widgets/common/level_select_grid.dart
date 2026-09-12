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
///
/// [pulse] draws the eye to "the next level to play" — a gentle, continuous
/// glow breathing (~1.8s cycle) around the node. The caller decides which
/// single node gets it (see [LevelSelectGrid], which only pulses the FIRST
/// `unlocked` node — running a ticker per grid cell would be wasteful on a
/// large grid). Has no effect unless [state] is `unlocked`. Respects
/// [NeonTheme.reducedMotion] (no ticker at all when it's on).
class LevelNodeButton extends StatefulWidget {
  const LevelNodeButton({
    super.key,
    required this.levelNumber,
    required this.state,
    this.starsEarned = 0,
    this.onTap,
    this.size = 64,
    this.pulse = false,
  });

  final int levelNumber;
  final LevelState state;

  /// 0-3, only meaningful (and only shown) when [state] is `completed`.
  final int starsEarned;
  final VoidCallback? onTap;
  final double size;
  final bool pulse;

  @override
  State<LevelNodeButton> createState() => _LevelNodeButtonState();
}

class _LevelNodeButtonState extends State<LevelNodeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _glowIntensity = Tween<double>(
    begin: 0.35,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  bool get _shouldPulse =>
      widget.pulse && widget.state == LevelState.unlocked;

  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery không đọc được trong initState — didChangeDependencies là
    // nơi an toàn sớm nhất (cùng convention đã dùng ở ConfettiOverlay/
    // RibbonBadge trong session này).
    _reducedMotion = NeonTheme.reducedMotion(context);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant LevelNodeButton old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  void _syncTicker() {
    if (_shouldPulse && !_reducedMotion) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final icon = levelStateIcon(state);
    final textColor = switch (state) {
      LevelState.completed => Colors.white,
      LevelState.locked => NeonTheme.inkSoft,
      LevelState.unlocked => NeonTheme.ink,
    };
    // SingleChildScrollView (never actually scrolls — NeverScrollableScrollPhysics):
    // the GridView cell height (from childAspectRatio) and this Column's
    // natural height (circle + gap + StarRating) are meant to match
    // exactly, but floating-point division doesn't always land on the
    // same value — real device testing (Samsung S24 Ultra, narrow
    // effective width from a display-zoom override) hit a genuine
    // "RenderFlex overflowed by 0.0328 pixels" from this. A `ClipRect`
    // was tried first and does NOT fix it — that only clips *painting*,
    // the RenderFlex still computes and flags the overflow at layout
    // time regardless of an ancestor clip. A scrollable's child is
    // allowed to exceed its viewport without violating any constraint,
    // so wrapping in one — Flutter's own suggested remedy for exactly
    // this class of issue — makes the sub-pixel mismatch a non-issue
    // instead of merely hiding its visual symptom.
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PressableScale(
            onTap: levelStateTappable(state) ? widget.onTap : null,
            child: AnimatedBuilder(
              animation: _glowIntensity,
              builder: (context, child) {
                final List<BoxShadow>? boxShadow = switch (state) {
                  LevelState.locked => null,
                  LevelState.completed => [
                    ...NeonTheme.drop(y: 3, blur: 8),
                    ...NeonTheme.glow(NeonTheme.gold, blur: 14),
                  ],
                  LevelState.unlocked => _shouldPulse && !_reducedMotion
                      ? [
                          ...NeonTheme.drop(y: 3, blur: 8),
                          ...NeonTheme.glow(
                            NeonTheme.cyan,
                            blur: 16,
                            intensity: _glowIntensity.value,
                          ),
                        ]
                      : NeonTheme.drop(y: 3, blur: 8),
                };
                return Container(
                  width: widget.size,
                  height: widget.size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: levelStateFillColor(state),
                    border: Border.all(
                      color: levelStateBorderColor(state),
                      width: 3,
                    ),
                    boxShadow: boxShadow,
                  ),
                  child: child,
                );
              },
              child: icon != null
                  ? Icon(icon, color: textColor, size: widget.size * 0.4)
                  : Text(
                      '${widget.levelNumber}',
                      style: TextStyle(
                        color: textColor,
                        fontSize: widget.size * 0.32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          if (state == LevelState.completed) ...[
            const SizedBox(height: 4),
            StarRating(earned: widget.starsEarned, size: widget.size * 0.18),
          ],
        ],
      ),
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
    // Chỉ pulse node unlocked ĐẦU TIÊN (level tiếp theo thật sự sẽ chơi) —
    // chạy ticker cho MỌI node unlocked trên 1 lưới nhiều ô sẽ tốn hiệu
    // năng hơn hẳn so với 1 node đơn lẻ (xem Ghi chú độ tin cậy, IDEA-25).
    final firstUnlockedIndex = states.indexOf(LevelState.unlocked);
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
          pulse: index == firstUnlockedIndex,
          onTap: onLevelTap == null ? null : () => onLevelTap!(levelNumber),
        );
      },
    );
  }
}
