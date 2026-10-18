import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// One long-term streak reward threshold (e.g. day 7, day 30).
@immutable
class StreakMilestone {
  const StreakMilestone({
    required this.days,
    required this.rewardLabel,
    this.icon,
  });

  final int days;
  final String rewardLabel;
  final IconData? icon;
}

String _defaultDayLabel(int days) => '$days days';

/// Horizontal strip of long-term streak milestones with claim state.
/// Presentation-only: the caller owns the streak, time and reward granting.
class StreakMilestoneStrip extends StatefulWidget {
  StreakMilestoneStrip({
    super.key,
    required this.milestones,
    required this.currentStreak,
    required this.onClaim,
    this.claimedDays = const <int>{},
    this.claimLabel = 'Claim',
    this.claimedLabel = 'Claimed',
    this.lockedLabel = 'Locked',
    this.dayLabel = _defaultDayLabel,
    this.guardWindow = const Duration(milliseconds: 600),
  }) {
    if (milestones.isEmpty) {
      throw ArgumentError.value(milestones, 'milestones', 'must not be empty');
    }
    var previous = 0;
    for (final milestone in milestones) {
      if (milestone.days <= 0) {
        throw ArgumentError.value(
          milestone.days,
          'milestones',
          'days must be > 0',
        );
      }
      if (milestone.days <= previous) {
        throw ArgumentError.value(
          milestone.days,
          'milestones',
          'days must be strictly increasing',
        );
      }
      if (milestone.rewardLabel.trim().isEmpty) {
        throw ArgumentError.value(
          milestone.rewardLabel,
          'milestones',
          'rewardLabel must not be blank',
        );
      }
      previous = milestone.days;
    }
    if (currentStreak < 0) {
      throw ArgumentError.value(currentStreak, 'currentStreak', 'must be >= 0');
    }
    // A claimed milestone may be above currentStreak: a broken streak resets
    // the count while the caller still remembers what was already claimed.
    final known = {for (final m in milestones) m.days};
    for (final day in claimedDays) {
      if (!known.contains(day)) {
        throw ArgumentError.value(
          day,
          'claimedDays',
          'must only contain milestone days',
        );
      }
    }
    for (final (name, value) in [
      ('claimLabel', claimLabel),
      ('claimedLabel', claimedLabel),
      ('lockedLabel', lockedLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
    if (guardWindow.isNegative) {
      throw ArgumentError.value(
        guardWindow,
        'guardWindow',
        'must not be negative',
      );
    }
  }

  /// Strictly increasing by [StreakMilestone.days], at least one entry.
  final List<StreakMilestone> milestones;
  final int currentStreak;
  final Set<int> claimedDays;
  final ValueChanged<int> onClaim;
  final String claimLabel;
  final String claimedLabel;
  final String lockedLabel;

  /// Caller-owned copy for "N days" (i18n).
  final String Function(int days) dayLabel;

  /// Repeat taps on the same milestone inside this window are dropped.
  final Duration guardWindow;

  @override
  State<StreakMilestoneStrip> createState() => _StreakMilestoneStripState();
}

class _StreakMilestoneStripState extends State<StreakMilestoneStrip>
    with SingleTickerProviderStateMixin {
  static const double _itemWidth = 116;

  // Created eagerly: a lazy `late final` first touched inside dispose() would
  // build its Ticker on an already-deactivated element and throw.
  late final AnimationController _pulse;
  Set<int> _pulsing = const <int>{};
  final Stopwatch _clock = Stopwatch();
  final Map<int, Duration> _lastClaim = {};

  @override
  void initState() {
    super.initState();
    // Starts settled so a milestone already reached on mount never pulses.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant StreakMilestoneStrip old) {
    super.didUpdateWidget(old);
    if (NeonTheme.reducedMotion(context)) return;
    final reached = {
      for (final m in widget.milestones)
        if (m.days > old.currentStreak &&
            m.days <= widget.currentStreak &&
            !widget.claimedDays.contains(m.days))
          m.days,
    };
    if (reached.isNotEmpty) {
      _pulsing = reached;
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _claim(int days) {
    if (!_clock.isRunning) _clock.start();
    final now = _clock.elapsed;
    final last = _lastClaim[days];
    if (last != null && now - last < widget.guardWindow) return;
    _lastClaim[days] = now;
    widget.onClaim(days);
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    int? nextDays;
    for (final m in widget.milestones) {
      if (m.days > widget.currentStreak) {
        nextDays = m.days;
        break;
      }
    }
    return SizedBox(
      height: 106 + 43 * textScale,
      child: ListView.builder(
        key: const ValueKey('streakMilestoneList'),
        scrollDirection: Axis.horizontal,
        itemExtent: _itemWidth,
        itemCount: widget.milestones.length,
        itemBuilder: (context, index) {
          final milestone = widget.milestones[index];
          final tile = _tile(milestone, isNext: milestone.days == nextDays);
          if (!_pulsing.contains(milestone.days)) return tile;
          return AnimatedBuilder(
            animation: _pulse,
            child: tile,
            builder: (_, child) => Transform.scale(
              scale: 1 + 0.08 * math.sin(math.pi * _pulse.value),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _tile(StreakMilestone milestone, {required bool isNext}) {
    final claimed = widget.claimedDays.contains(milestone.days);
    final claimable = !claimed && milestone.days <= widget.currentStreak;
    final accent = claimed
        ? NeonTheme.lime
        : claimable
        ? NeonTheme.pink
        : isNext
        ? NeonTheme.purple
        : NeonTheme.muted;
    final stateLabel = claimed
        ? widget.claimedLabel
        : claimable
        ? widget.claimLabel
        : widget.lockedLabel;
    final dayText = widget.dayLabel(milestone.days);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        container: true,
        label: '$dayText, ${milestone.rewardLabel}, $stateLabel',
        child: Container(
          key: ValueKey('streakMilestone_${milestone.days}'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: NeonTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(
                alpha: claimed || claimable || isNext ? 0.8 : 0.35,
              ),
              width: isNext ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(
                  milestone.icon ?? Icons.local_fire_department_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    dayText,
                    maxLines: 1,
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ExcludeSemantics(
                  child: Text(
                    milestone.rewardLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NeonTheme.inkSoft, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _action(
                milestone.days,
                dayText,
                claimed,
                claimable,
                accent,
                stateLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    int days,
    String dayText,
    bool claimed,
    bool claimable,
    Color accent,
    String stateLabel,
  ) {
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        stateLabel,
        maxLines: 1,
        style: TextStyle(
          color: claimable ? Colors.white : accent,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    if (!claimable) {
      return ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: claimed
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 14, color: accent),
                      const SizedBox(width: 2),
                      Flexible(child: label),
                    ],
                  )
                : label,
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: '${widget.claimLabel} $dayText',
      excludeSemantics: true,
      onTap: () => _claim(days),
      child: GestureDetector(
        key: ValueKey('streakClaim_$days'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _claim(days),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: label,
            ),
          ),
        ),
      ),
    );
  }
}
