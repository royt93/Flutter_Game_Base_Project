import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';
import 'mystery_chest_opening.dart' show SunburstGodRays;

/// One commemorative reward row shown in [MilestoneCelebrationDialog] (FEAT-135).
///
/// Presentation-only: the caller fills it in from its own reward system.
class MilestoneReward {
  MilestoneReward({
    required this.icon,
    required this.label,
    this.amountLabel,
    this.color,
  }) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
  }

  final IconData icon;
  final String label;
  final String? amountLabel;
  final Color? color;
}

/// Celebration panel for a major level milestone (25/50/100/500) — gold badge
/// with the level number and a slow rotating light sweep, the commemorative
/// reward list, and a Claim button (FEAT-135).
///
/// Use [MilestoneCelebrationDialog.show] to present it as an in-tree overlay
/// (safe above a Flame `GameWidget`). Pure presentation: the caller owns the
/// reward grant and what [onClaim] does. Reduce Motion keeps the badge static.
class MilestoneCelebrationDialog extends StatefulWidget {
  MilestoneCelebrationDialog({
    super.key,
    required this.level,
    required this.rewards,
    required this.onClaim,
    this.title = 'Milestone Reached!',
    this.subtitle,
    this.claimLabel = 'Claim',
  }) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'must be at least 1');
    }
    if (rewards.isEmpty) {
      throw ArgumentError.value(rewards, 'rewards', 'must not be empty');
    }
  }

  final int level;
  final List<MilestoneReward> rewards;
  final VoidCallback onClaim;
  final String title;
  final String? subtitle;
  final String claimLabel;

  /// Shows the celebration through [NeonDialog.show] (in-tree overlay, no route).
  static Future<void> show(
    BuildContext context, {
    required int level,
    required List<MilestoneReward> rewards,
    required VoidCallback onClaim,
    String title = 'Milestone Reached!',
    String? subtitle,
    String claimLabel = 'Claim',
  }) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'must be at least 1');
    }
    if (rewards.isEmpty) {
      throw ArgumentError.value(rewards, 'rewards', 'must not be empty');
    }
    return NeonDialog.show<void>(
      context: context,
      title: title,
      color: NeonTheme.gold,
      content: _MilestoneBody(
        level: level,
        rewards: rewards,
        subtitle: subtitle,
      ),
      actions: [
        NeonDialogAction(
          label: claimLabel,
          color: NeonTheme.gold,
          onTap: onClaim,
        ),
      ],
    );
  }

  @override
  State<MilestoneCelebrationDialog> createState() =>
      _MilestoneCelebrationDialogState();
}

class _MilestoneCelebrationDialogState
    extends State<MilestoneCelebrationDialog> {
  @override
  Widget build(BuildContext context) {
    return NeonDialog.panel(
      title: widget.title,
      color: NeonTheme.gold,
      content: _MilestoneBody(
        level: widget.level,
        rewards: widget.rewards,
        subtitle: widget.subtitle,
      ),
      actions: [
        NeonDialogAction(
          label: widget.claimLabel,
          color: NeonTheme.gold,
          onTap: widget.onClaim,
        ),
      ],
    );
  }
}

class _MilestoneBody extends StatefulWidget {
  const _MilestoneBody({
    required this.level,
    required this.rewards,
    this.subtitle,
  });

  final int level;
  final List<MilestoneReward> rewards;
  final String? subtitle;

  @override
  State<_MilestoneBody> createState() => _MilestoneBodyState();
}

class _MilestoneBodyState extends State<_MilestoneBody>
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
    final rewardText = widget.rewards
        .map(
          (r) =>
              r.amountLabel == null ? r.label : '${r.label} ${r.amountLabel}',
        )
        .join(', ');

    return Semantics(
      key: const ValueKey('milestoneSemantics'),
      container: true,
      label: 'Level ${widget.level} milestone, rewards: $rewardText',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: RepaintBoundary(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        key: const ValueKey('milestoneRays'),
                        painter: SunburstGodRays(
                          animation: _sweep,
                          color: NeonTheme.gold,
                        ),
                      ),
                    ),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NeonTheme.gold,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: NeonTheme.glow(NeonTheme.gold, blur: 14),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.level}',
                          key: const ValueKey('milestoneLevelText'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: NeonTheme.s8),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: NeonTheme.s16),
            for (final reward in widget.rewards)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      reward.icon,
                      color: reward.color ?? NeonTheme.gold,
                      size: 24,
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    Flexible(
                      child: Text(
                        reward.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (reward.amountLabel != null) ...[
                      const SizedBox(width: NeonTheme.s8),
                      Text(
                        reward.amountLabel!,
                        style: TextStyle(
                          color: NeonTheme.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
