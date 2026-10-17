import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';

/// A reward milestone on a [WeeklyChallengeCard] progress track (FEAT-136).
/// The caller supplies display data; the widget does not grant rewards.
class ChallengeMilestone {
  ChallengeMilestone({
    required this.target,
    required this.label,
    this.icon,
    this.isClaimed = false,
  }) {
    if (target <= 0) {
      throw ArgumentError.value(target, 'target', 'must be positive');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
  }

  final int target;
  final String label;
  final IconData? icon;
  final bool isClaimed;
}

/// A weekly live-ops challenge card showing event progress and milestone rewards.
///
/// The countdown is local to the card, updates every second using [fmtDurDays],
/// and is cancelled when expired or unmounted. Caller owns progress state,
/// milestone claims, and all reward/business logic.
class WeeklyChallengeCard extends StatefulWidget {
  WeeklyChallengeCard({
    super.key,
    required this.title,
    required this.expiresAt,
    required this.currentProgress,
    required this.targetProgress,
    required this.milestones,
    this.subtitle,
    this.onTap,
    this.onClaimMilestone,
    this.onExpired,
    this.color,
    this.width,
    this.height = 156,
    this.semanticLabel,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (targetProgress <= 0) {
      throw ArgumentError.value(
        targetProgress,
        'targetProgress',
        'must be positive',
      );
    }
    if (currentProgress < 0) {
      throw ArgumentError.value(
        currentProgress,
        'currentProgress',
        'must be non-negative',
      );
    }
    if (milestones.isEmpty || milestones.length > 3) {
      throw ArgumentError.value(
        milestones.length,
        'milestones.length',
        'must have 1 to 3 milestones',
      );
    }
    var previous = 0;
    for (var i = 0; i < milestones.length; i++) {
      final milestone = milestones[i];
      if (milestone.target <= previous || milestone.target > targetProgress) {
        throw ArgumentError.value(
          milestone.target,
          'milestones[$i].target',
          'must be strictly increasing and no greater than targetProgress',
        );
      }
      previous = milestone.target;
    }
    if (!height.isFinite || height <= 0) {
      throw ArgumentError.value(
        height,
        'height',
        'must be finite and positive',
      );
    }
    if (width != null && (!width!.isFinite || width! <= 0)) {
      throw ArgumentError.value(width, 'width', 'must be finite and positive');
    }
  }

  final String title;
  final String? subtitle;
  final DateTime expiresAt;
  final int currentProgress;
  final int targetProgress;
  final List<ChallengeMilestone> milestones;
  final VoidCallback? onTap;
  final ValueChanged<int>? onClaimMilestone;
  final VoidCallback? onExpired;
  final Color? color;
  final double? width;
  final double height;
  final String? semanticLabel;

  @override
  State<WeeklyChallengeCard> createState() => _WeeklyChallengeCardState();
}

class _WeeklyChallengeCardState extends State<WeeklyChallengeCard> {
  Timer? _timer;
  late Duration _remaining;
  bool _expiredNotified = false;

  Duration _initialRemaining() {
    final difference = widget.expiresAt.difference(DateTime.now());
    if (difference <= Duration.zero) return Duration.zero;
    return Duration(seconds: (difference.inMilliseconds / 1000).ceil());
  }

  bool get _isExpired => _remaining <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = _initialRemaining();
    if (_isExpired) {
      _notifyExpiredDeferred();
    } else {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant WeeklyChallengeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _timer?.cancel();
      _remaining = _initialRemaining();
      _expiredNotified = false;
      if (_isExpired) {
        _notifyExpiredDeferred();
      } else {
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_remaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    if (!mounted) return;
    final next = _remaining - const Duration(seconds: 1);
    final clamped = next.isNegative ? Duration.zero : next;
    setState(() => _remaining = clamped);
    if (clamped == Duration.zero) {
      _timer?.cancel();
      _notifyExpired();
    }
  }

  void _notifyExpiredDeferred() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyExpired();
    });
  }

  void _notifyExpired() {
    if (_expiredNotified) return;
    _expiredNotified = true;
    widget.onExpired?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleCardTap() {
    if (!_isExpired) widget.onTap?.call();
  }

  void _handleMilestoneTap(int index, ChallengeMilestone milestone) {
    if (_isExpired ||
        milestone.isClaimed ||
        widget.currentProgress < milestone.target) {
      return;
    }
    widget.onClaimMilestone?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final expired = _isExpired;
    final accent = widget.color ?? NeonTheme.purple;
    final fraction = (widget.currentProgress / widget.targetProgress).clamp(
      0.0,
      1.0,
    );
    final percent = (fraction * 100).round();
    final timeText = expired ? 'Ended' : fmtDurDays(_remaining);
    final semantic =
        widget.semanticLabel ??
        '${widget.title}, ${expired ? 'ended' : 'ends in $timeText'}, '
            '${widget.currentProgress} of ${widget.targetProgress} progress, '
            '$percent percent';

    return Semantics(
      container: true,
      label: semantic,
      value: '$percent%',
      child: RepaintBoundary(
        child: GestureDetector(
          key: const ValueKey('weeklyChallengeCardTap'),
          behavior: HitTestBehavior.opaque,
          onTap: expired ? null : _handleCardTap,
          child: Container(
            width: widget.width,
            constraints: BoxConstraints(minHeight: widget.height),
            padding: const EdgeInsets.all(NeonTheme.s16),
            decoration: BoxDecoration(
              color: NeonTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: expired
                    ? NeonTheme.muted
                    : accent.withValues(alpha: 0.7),
                width: 2,
              ),
              boxShadow: NeonTheme.drop(blur: 10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: expired ? NeonTheme.muted : accent,
                      size: 24,
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: NeonTheme.inkSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    Container(
                      key: const ValueKey('weeklyChallengeCountdownBadge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: expired ? NeonTheme.muted : accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        timeText,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NeonTheme.s16),
                Row(
                  children: [
                    Text(
                      '${widget.currentProgress}/${widget.targetProgress}',
                      key: const ValueKey('weeklyChallengeProgressText'),
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final barWidth = constraints.maxWidth;
                          return Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: NeonTheme.cardAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedContainer(
                                  key: const ValueKey(
                                    'weeklyChallengeProgressFill',
                                  ),
                                  duration: NeonTheme.motionDuration(
                                    context,
                                    const Duration(milliseconds: 300),
                                  ),
                                  curve: Curves.easeOut,
                                  width: barWidth * fraction,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: expired ? NeonTheme.muted : accent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                for (
                                  var i = 0;
                                  i < widget.milestones.length;
                                  i++
                                )
                                  PositionedDirectional(
                                    start:
                                        barWidth *
                                            widget.milestones[i].target /
                                            widget.targetProgress -
                                        5,
                                    top: -3,
                                    child: _MilestoneMarker(
                                      milestone: widget.milestones[i],
                                      reached:
                                          widget.currentProgress >=
                                          widget.milestones[i].target,
                                      expired: expired,
                                      onTap: () => _handleMilestoneTap(
                                        i,
                                        widget.milestones[i],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (widget.milestones.isNotEmpty) ...[
                  const SizedBox(height: NeonTheme.s8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Wrap(
                      spacing: NeonTheme.s8,
                      runSpacing: 2,
                      children: [
                        for (var i = 0; i < widget.milestones.length; i++)
                          _MilestoneClaimChip(
                            key: ValueKey('weeklyChallengeMilestone_$i'),
                            milestone: widget.milestones[i],
                            index: i,
                            enabled:
                                !expired &&
                                !widget.milestones[i].isClaimed &&
                                widget.currentProgress >=
                                    widget.milestones[i].target,
                            onTap: () =>
                                _handleMilestoneTap(i, widget.milestones[i]),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MilestoneClaimChip extends StatelessWidget {
  const _MilestoneClaimChip({
    super.key,
    required this.milestone,
    required this.index,
    required this.enabled,
    required this.onTap,
  });

  final ChallengeMilestone milestone;
  final int index;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? NeonTheme.gold : NeonTheme.inkSoft;
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: milestone.isClaimed
          ? '${milestone.label}, claimed'
          : '${milestone.label}, ${enabled ? 'ready to claim' : 'locked'}',
      child: ExcludeSemantics(
        child: GestureDetector(
          key: ValueKey('weeklyChallengeClaim_$index'),
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: enabled ? 0.2 : 0.1),
              border: Border.all(color: color.withValues(alpha: 0.7)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (milestone.icon != null) ...[
                  Icon(milestone.icon, size: 12, color: color),
                  const SizedBox(width: 3),
                ],
                Text(
                  milestone.isClaimed
                      ? '${milestone.label} ✓'
                      : milestone.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MilestoneMarker extends StatelessWidget {
  const _MilestoneMarker({
    required this.milestone,
    required this.reached,
    required this.expired,
    required this.onTap,
  });

  final ChallengeMilestone milestone;
  final bool reached;
  final bool expired;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = reached && !expired ? NeonTheme.gold : NeonTheme.muted;
    return Semantics(
      button: reached && !expired && !milestone.isClaimed,
      label: '${milestone.label} milestone at ${milestone.target}',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: reached && !expired && !milestone.isClaimed ? onTap : null,
          child: Icon(
            milestone.isClaimed
                ? Icons.check_circle_rounded
                : Icons.star_rounded,
            color: color,
            size: 12,
          ),
        ),
      ),
    );
  }
}
