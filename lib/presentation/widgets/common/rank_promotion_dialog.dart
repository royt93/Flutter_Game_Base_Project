import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';
import 'milestone_celebration_dialog.dart' show MilestoneReward;
import 'mystery_chest_opening.dart' show SunburstGodRays;
import 'tiered_leaderboard_row.dart' show LeaderboardTier;

extension _LeaderboardTierColor on LeaderboardTier {
  Color get color => switch (this) {
    LeaderboardTier.bronze => NeonTheme.orange,
    LeaderboardTier.silver => NeonTheme.cyan,
    LeaderboardTier.gold => NeonTheme.gold,
    LeaderboardTier.diamond => NeonTheme.purple,
  };

  String get label => switch (this) {
    LeaderboardTier.bronze => 'Bronze',
    LeaderboardTier.silver => 'Silver',
    LeaderboardTier.gold => 'Gold',
    LeaderboardTier.diamond => 'Diamond',
  };

  IconData get icon => switch (this) {
    LeaderboardTier.bronze => Icons.military_tech_rounded,
    LeaderboardTier.silver => Icons.shield_rounded,
    LeaderboardTier.gold => Icons.workspace_premium_rounded,
    LeaderboardTier.diamond => Icons.diamond_rounded,
  };
}

/// Presentation-only modal celebrating promotion between leaderboard tiers (FEAT-147).
///
/// Features animated sunburst god rays behind the newly unlocked tier badge,
/// promotion rewards, and continue/share actions. Caller owns tier progression
/// and reward grant logic.
class RankPromotionDialog extends StatefulWidget {
  RankPromotionDialog({
    super.key,
    required this.fromTier,
    required this.toTier,
    required this.onContinue,
    this.onShare,
    this.rewards = const [],
    this.title = 'Rank Promoted!',
    this.subtitle,
    this.continueLabel = 'Continue',
    this.shareLabel = 'Share',
    this.semanticLabel,
  }) {
    if (toTier.index <= fromTier.index) {
      throw ArgumentError(
        'toTier ($toTier) must be higher than fromTier ($fromTier)',
      );
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (continueLabel.trim().isEmpty) {
      throw ArgumentError.value(
        continueLabel,
        'continueLabel',
        'must not be empty',
      );
    }
    if (shareLabel.trim().isEmpty) {
      throw ArgumentError.value(shareLabel, 'shareLabel', 'must not be empty');
    }
  }

  final LeaderboardTier fromTier;
  final LeaderboardTier toTier;
  final VoidCallback onContinue;
  final VoidCallback? onShare;
  final List<MilestoneReward> rewards;
  final String title;
  final String? subtitle;
  final String continueLabel;
  final String shareLabel;
  final String? semanticLabel;

  /// Shows the promotion celebration via [NeonDialog.show] (in-tree overlay,
  /// safe over Flame `GameWidget`).
  static Future<void> show(
    BuildContext context, {
    required LeaderboardTier fromTier,
    required LeaderboardTier toTier,
    required VoidCallback onContinue,
    VoidCallback? onShare,
    List<MilestoneReward> rewards = const [],
    String title = 'Rank Promoted!',
    String? subtitle,
    String continueLabel = 'Continue',
    String shareLabel = 'Share',
    String? semanticLabel,
  }) {
    if (toTier.index <= fromTier.index) {
      throw ArgumentError(
        'toTier ($toTier) must be higher than fromTier ($fromTier)',
      );
    }

    final accent = toTier.color;
    return NeonDialog.show<void>(
      context: context,
      title: title,
      color: accent,
      content: _RankPromotionBody(
        fromTier: fromTier,
        toTier: toTier,
        rewards: rewards,
        subtitle: subtitle,
        semanticLabel: semanticLabel,
      ),
      actions: [
        if (onShare != null)
          NeonDialogAction(
            label: shareLabel,
            color: NeonTheme.muted,
            onTap: onShare,
          ),
        NeonDialogAction(
          label: continueLabel,
          color: accent,
          onTap: onContinue,
        ),
      ],
    );
  }

  @override
  State<RankPromotionDialog> createState() => _RankPromotionDialogState();
}

class _RankPromotionDialogState extends State<RankPromotionDialog> {
  @override
  Widget build(BuildContext context) {
    return NeonDialog.panel(
      title: widget.title,
      color: widget.toTier.color,
      content: _RankPromotionBody(
        fromTier: widget.fromTier,
        toTier: widget.toTier,
        rewards: widget.rewards,
        subtitle: widget.subtitle,
        semanticLabel: widget.semanticLabel,
      ),
      actions: [
        if (widget.onShare != null)
          NeonDialogAction(
            label: widget.shareLabel,
            color: NeonTheme.muted,
            onTap: widget.onShare!,
          ),
        NeonDialogAction(
          label: widget.continueLabel,
          color: widget.toTier.color,
          onTap: widget.onContinue,
        ),
      ],
    );
  }
}

class _RankPromotionBody extends StatefulWidget {
  const _RankPromotionBody({
    required this.fromTier,
    required this.toTier,
    required this.rewards,
    this.subtitle,
    this.semanticLabel,
  });

  final LeaderboardTier fromTier;
  final LeaderboardTier toTier;
  final List<MilestoneReward> rewards;
  final String? subtitle;
  final String? semanticLabel;

  @override
  State<_RankPromotionBody> createState() => _RankPromotionBodyState();
}

class _RankPromotionBodyState extends State<_RankPromotionBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NeonTheme.reducedMotion(context)) {
      if (_sweep.isAnimating || _sweep.value != 0) {
        _sweep
          ..stop()
          ..value = 0;
      }
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toColor = widget.toTier.color;
    final fromColor = widget.fromTier.color;
    final rewardText = widget.rewards.isEmpty
        ? 'No bonus rewards'
        : widget.rewards
              .map(
                (r) => r.amountLabel == null
                    ? r.label
                    : '${r.label} ${r.amountLabel}',
              )
              .join(', ');

    final effectiveSemantics =
        widget.semanticLabel ??
        'Promoted from ${widget.fromTier.label} to ${widget.toTier.label}. Rewards: $rewardText.';

    final body = Semantics(
      key: const ValueKey('rankPromotionSemantics'),
      container: true,
      label: effectiveSemantics,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tier transition badge
            SizedBox(
              width: 170,
              height: 150,
              child: RepaintBoundary(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        key: const ValueKey('rankPromotionRays'),
                        painter: SunburstGodRays(
                          animation: _sweep,
                          color: toColor,
                        ),
                      ),
                    ),
                    Container(
                      width: 86,
                      height: 86,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: toColor,
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: NeonTheme.glow(toColor, blur: 14),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.toTier.icon,
                                color: Colors.white,
                                size: 36,
                              ),
                              Text(
                                widget.toTier.label.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Subtitle or Tier transition label
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: NeonTheme.s8,
              children: [
                Text(
                  widget.fromTier.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fromColor,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: NeonTheme.inkSoft,
                ),
                Text(
                  widget.toTier.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: toColor,
                  ),
                ),
              ],
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: NeonTheme.inkSoft,
                ),
              ),
            ],
            if (widget.rewards.isNotEmpty) ...[
              const SizedBox(height: NeonTheme.s16),
              Text(
                'Promotion Rewards',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: NeonTheme.inkSoft,
                ),
              ),
              const SizedBox(height: 6),
              for (final reward in widget.rewards)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: NeonTheme.s8,
                    children: [
                      Icon(
                        reward.icon,
                        color: reward.color ?? toColor,
                        size: 20,
                      ),
                      Text(
                        reward.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: NeonTheme.ink,
                        ),
                      ),
                      if (reward.amountLabel != null)
                        Text(
                          reward.amountLabel!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: toColor,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height * 0.32).clamp(
          150.0,
          190.0,
        ),
      ),
      child: SingleChildScrollView(child: body),
    );
  }
}
