import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Single level goal model representing one objective in a level HUD (FEAT-125).
class GoalItem {
  GoalItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.target,
    this.current = 0,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (label.isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
    if (target < 1) {
      throw ArgumentError.value(target, 'target', 'must be at least 1');
    }
    if (current < 0) {
      throw ArgumentError.value(current, 'current', 'must be non-negative');
    }
  }

  final String id;
  final String label;
  final Widget icon;
  final int target;
  final int current;

  /// Remaining count needed to complete this goal (clamped to >= 0).
  int get remaining => math.max(0, target - current);

  /// Whether this goal has reached or exceeded its target.
  bool get isCompleted => current >= target;

  bool _matches(GoalItem other) =>
      id == other.id &&
      label == other.label &&
      target == other.target &&
      current == other.current &&
      icon == other.icon;
}

/// A compact, candy-styled HUD showing 1–4 level goals (FEAT-125).
///
/// Each goal displays its icon and remaining count. When a goal reaches its
/// target (`current >= target`), the count transitions to a bouncing checkmark
/// animated via [NeonTheme.curvePop]. Goals already complete on initial mount
/// stay at rest without replaying celebratory animation. Unchanged goal items
/// do not rebuild when another goal's progress updates.
class LevelGoalTracker extends StatefulWidget {
  LevelGoalTracker({
    super.key,
    required this.goals,
    this.direction = Axis.horizontal,
    this.showLabel = false,
    this.spacing = NeonTheme.s8,
    this.padding,
    this.itemDecoration,
  }) {
    if (goals.isEmpty || goals.length > 4) {
      throw ArgumentError.value(
        goals.length,
        'goals.length',
        'must have 1 to 4 goals',
      );
    }
    final ids = <String>{};
    for (final goal in goals) {
      if (!ids.add(goal.id)) {
        throw ArgumentError.value(
          goal.id,
          'goals',
          'duplicate goal id: "${goal.id}"',
        );
      }
    }
  }

  /// 1 to 4 goals to track.
  final List<GoalItem> goals;

  /// Layout direction (horizontal for top game HUD, vertical for dialogs/panels).
  final Axis direction;

  /// Whether to display [GoalItem.label] alongside the icon and remaining count.
  final bool showLabel;

  /// Spacing between goal chips.
  final double spacing;

  /// Padding around the goal group.
  final EdgeInsetsGeometry? padding;

  /// Optional custom decoration for goal chips.
  final BoxDecoration? itemDecoration;

  @override
  State<LevelGoalTracker> createState() => _LevelGoalTrackerState();
}

class _LevelGoalTrackerState extends State<LevelGoalTracker> {
  @override
  Widget build(BuildContext context) {
    final children = [
      for (var i = 0; i < widget.goals.length; i++) ...[
        if (i > 0)
          widget.direction == Axis.horizontal
              ? SizedBox(width: widget.spacing)
              : SizedBox(height: widget.spacing),
        RepaintBoundary(
          key: ValueKey('goalBoundary_${widget.goals[i].id}'),
          child: _LevelGoalRow(
            key: ValueKey('goalChip_${widget.goals[i].id}'),
            goal: widget.goals[i],
            showLabel: widget.showLabel,
            decoration: widget.itemDecoration,
          ),
        ),
      ],
    ];

    Widget body = widget.direction == Axis.horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: children)
        : Column(mainAxisSize: MainAxisSize.min, children: children);

    if (widget.padding != null) {
      body = Padding(padding: widget.padding!, child: body);
    }

    return body;
  }
}

class _LevelGoalRow extends StatefulWidget {
  const _LevelGoalRow({
    super.key,
    required this.goal,
    required this.showLabel,
    this.decoration,
  });

  final GoalItem goal;
  final bool showLabel;
  final BoxDecoration? decoration;

  @override
  State<_LevelGoalRow> createState() => _LevelGoalRowState();
}

class _LevelGoalRowState extends State<_LevelGoalRow> {
  late Widget _builtChip;
  late GoalItem _currentGoal;

  @override
  void initState() {
    super.initState();
    _currentGoal = widget.goal;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _builtChip = _buildChip();
  }

  @override
  void didUpdateWidget(covariant _LevelGoalRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_currentGoal._matches(widget.goal) ||
        widget.showLabel != oldWidget.showLabel ||
        widget.decoration != oldWidget.decoration) {
      _currentGoal = widget.goal;
      _builtChip = _buildChip();
    }
  }

  Widget _buildChip() {
    final goal = widget.goal;
    final completed = goal.isCompleted;
    final duration = NeonTheme.motionDuration(
      context,
      const Duration(milliseconds: 300),
    );

    final chipDecoration =
        widget.decoration ??
        BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: completed
                ? NeonTheme.lime.withValues(alpha: 0.8)
                : NeonTheme.cardAlt,
            width: 1.5,
          ),
          boxShadow: completed
              ? NeonTheme.glow(NeonTheme.lime, blur: 8)
              : NeonTheme.drop(blur: 4),
        );

    return Semantics(
      label:
          '${goal.label}: ${completed ? 'completed' : '${goal.remaining} remaining'}',
      value: '${goal.current}/${goal.target}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: chipDecoration,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 24, height: 24, child: goal.icon),
              if (widget.showLabel) ...[
                const SizedBox(width: 6),
                Text(
                  goal.label,
                  style: TextStyle(
                    color: NeonTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: completed ? 0.0 : 1.0,
                      duration: duration,
                      child: Text(
                        '${goal.remaining}',
                        key: ValueKey('goalRemaining_${goal.id}'),
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    AnimatedScale(
                      scale: completed ? 1.0 : 0.0,
                      duration: duration,
                      curve: NeonTheme.curvePop,
                      child: Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('goalCheck_${goal.id}'),
                        color: NeonTheme.lime,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _builtChip;
}
