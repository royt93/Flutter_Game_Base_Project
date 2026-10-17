import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';
import 'avatar_frame.dart';

/// Competitive league for a [TieredLeaderboardRow] (FEAT-139).
enum LeaderboardTier { bronze, silver, gold, diamond }

extension LeaderboardTierPresentation on LeaderboardTier {
  String get displayName => switch (this) {
    LeaderboardTier.bronze => 'Bronze',
    LeaderboardTier.silver => 'Silver',
    LeaderboardTier.gold => 'Gold',
    LeaderboardTier.diamond => 'Diamond',
  };

  Color get color => switch (this) {
    LeaderboardTier.bronze => const Color(0xFFCD7F32),
    LeaderboardTier.silver => const Color(0xFFC0C0C0),
    LeaderboardTier.gold => NeonTheme.gold,
    LeaderboardTier.diamond => NeonTheme.cyan,
  };

  IconData get icon => switch (this) {
    LeaderboardTier.bronze => Icons.shield_rounded,
    LeaderboardTier.silver => Icons.workspace_premium_rounded,
    LeaderboardTier.gold => Icons.military_tech_rounded,
    LeaderboardTier.diamond => Icons.diamond_rounded,
  };
}

/// Competition zone based on weekly league rank — caller computes it (FEAT-139).
enum TierZone { promotion, safe, demotion }

extension TierZonePresentation on TierZone {
  IconData get icon => switch (this) {
    TierZone.promotion => Icons.arrow_upward_rounded,
    TierZone.safe => Icons.remove_rounded,
    TierZone.demotion => Icons.arrow_downward_rounded,
  };

  Color get color => switch (this) {
    TierZone.promotion => NeonTheme.lime,
    TierZone.safe => NeonTheme.muted,
    TierZone.demotion => NeonTheme.red,
  };

  String get description => switch (this) {
    TierZone.promotion => 'promotion zone',
    TierZone.safe => 'safe zone',
    TierZone.demotion => 'demotion zone',
  };
}

/// One tiered leaderboard competitor row (FEAT-139).
///
/// Pure presentation: rank, preformatted [score], league [tier], and [zone]
/// are caller-owned. A changed rank/score fades/slides to its new value; Reduce
/// Motion skips the transition. No network or leaderboard service is accessed.
class TieredLeaderboardRow extends StatefulWidget {
  TieredLeaderboardRow({
    super.key,
    required this.rank,
    required this.playerName,
    required this.score,
    required this.tier,
    this.zone = TierZone.safe,
    this.isCurrentPlayer = false,
    this.avatar,
    this.onTap,
    this.height = 64,
    this.semanticLabel,
  }) {
    if (rank < 1) {
      throw ArgumentError.value(rank, 'rank', 'must be at least 1');
    }
    if (playerName.trim().isEmpty) {
      throw ArgumentError.value(playerName, 'playerName', 'must not be empty');
    }
    if (score.trim().isEmpty) {
      throw ArgumentError.value(score, 'score', 'must not be empty');
    }
    if (!height.isFinite || height <= 0) {
      throw ArgumentError.value(
        height,
        'height',
        'must be positive and finite',
      );
    }
  }

  final int rank;
  final String playerName;
  final String score;
  final LeaderboardTier tier;
  final TierZone zone;
  final bool isCurrentPlayer;
  final Widget? avatar;
  final VoidCallback? onTap;
  final double height;
  final String? semanticLabel;

  @override
  State<TieredLeaderboardRow> createState() => _TieredLeaderboardRowState();
}

class _TieredLeaderboardRowState extends State<TieredLeaderboardRow> {
  late int _visibleRank = widget.rank;
  late String _visibleScore = widget.score;

  @override
  void didUpdateWidget(covariant TieredLeaderboardRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rank != widget.rank || oldWidget.score != widget.score) {
      if (NeonTheme.reducedMotion(context)) {
        _visibleRank = widget.rank;
        _visibleScore = widget.score;
      } else {
        _visibleRank = oldWidget.rank;
        _visibleScore = oldWidget.score;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _visibleRank = widget.rank;
            _visibleScore = widget.score;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = widget.tier.color;
    final zoneColor = widget.zone.color;
    final semanticLabel =
        widget.semanticLabel ??
        'Rank ${widget.rank}, ${widget.playerName}, ${widget.tier.displayName} tier, '
            '${widget.score} points, in ${widget.zone.description}';

    return Semantics(
      container: true,
      button: widget.onTap != null,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: PressableScale(
          onTap: widget.onTap,
          child: RepaintBoundary(
            child: Container(
              key: ValueKey('tieredLeaderboardRow_${widget.rank}'),
              constraints: BoxConstraints(minHeight: widget.height),
              padding: const EdgeInsetsDirectional.only(
                start: 8,
                end: NeonTheme.s16,
                top: 6,
                bottom: 6,
              ),
              decoration: BoxDecoration(
                color: widget.isCurrentPlayer
                    ? NeonTheme.cardAlt
                    : NeonTheme.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.isCurrentPlayer ? NeonTheme.gold : tierColor,
                  width: widget.isCurrentPlayer ? 2.5 : 1.5,
                ),
                boxShadow: widget.isCurrentPlayer
                    ? NeonTheme.glow(NeonTheme.gold, blur: 8)
                    : NeonTheme.drop(y: 2, blur: 6),
              ),
              child: Row(
                children: [
                  // Promotion/safe/demotion indicator and tier-colored rail.
                  Container(
                    width: 4,
                    height: widget.height - 12,
                    decoration: BoxDecoration(
                      color: zoneColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: NeonTheme.s8),
                  SizedBox(
                    width: 26,
                    child: Icon(
                      widget.zone.icon,
                      key: ValueKey('leaderboardZone_${widget.rank}'),
                      color: zoneColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: NeonTheme.s8),
                  SizedBox(
                    width: 28,
                    child: AnimatedSwitcher(
                      duration: NeonTheme.motionDuration(
                        context,
                        const Duration(milliseconds: 250),
                      ),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        '$_visibleRank',
                        key: ValueKey('rank_$_visibleRank'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: NeonTheme.s8),
                  if (widget.avatar != null) ...[
                    AvatarFrame(
                      size: widget.height - 14,
                      ringWidth: 2,
                      child: widget.avatar!,
                    ),
                    const SizedBox(width: NeonTheme.s8),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.playerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: NeonTheme.ink,
                            fontSize: 14,
                            fontWeight: widget.isCurrentPlayer
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.18),
                            border: Border.all(color: tierColor, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.tier.displayName,
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: NeonTheme.s8),
                  AnimatedSwitcher(
                    duration: NeonTheme.motionDuration(
                      context,
                      const Duration(milliseconds: 250),
                    ),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: Text(
                      _visibleScore,
                      key: ValueKey('score_$_visibleScore'),
                      style: TextStyle(
                        color: NeonTheme.inkSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
