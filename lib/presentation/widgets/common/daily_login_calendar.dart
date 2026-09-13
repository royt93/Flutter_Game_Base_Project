import 'package:flutter/material.dart';

import '../../../core/daily_login_service.dart' show kDailyLoginCycleLength;
import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';
import 'common_button.dart';

/// Read-only 7-day (configurable via [cycleLength]) login-streak calendar —
/// a pure display widget, it holds no streak state of its own. The caller
/// reads `DailyLoginService` and hands in [currentStreakDay]/
/// [claimedDaysInCycle]/[canClaimToday], matching this kit's convention (see
/// `LevelSelectGrid`) of widgets taking plain data rather than reaching into
/// a GetX service directly.
///
/// The highlighted/tappable "current" slot is `currentStreakDay %
/// cycleLength + 1` — the SAME formula `DailyLoginService.claimToday()` uses
/// for the ordinary "continues streak" case. This is a display-only
/// approximation: it can't know in advance whether claiming today will
/// actually reset the streak (that depends on the service's internal
/// last-claimed-day bookkeeping, which this widget deliberately doesn't
/// see) — it just shows where the *next* claim naturally lands.
class DailyLoginCalendarWidget extends StatelessWidget {
  const DailyLoginCalendarWidget({
    super.key,
    required this.currentStreakDay,
    required this.claimedDaysInCycle,
    required this.canClaimToday,
    required this.onClaim,
    this.cycleLength = kDailyLoginCycleLength,
    this.claimLabel = 'Claim',
  });

  /// Current streak position, 1..[cycleLength]; 0 before the first claim.
  final int currentStreakDay;

  /// Which cycle days (1..[cycleLength]) have already been claimed.
  final Set<int> claimedDaysInCycle;

  /// Whether today's reward is still claimable.
  final bool canClaimToday;

  /// Fired by tapping the highlighted "current" slot or the Claim button.
  final VoidCallback onClaim;

  final int cycleLength;

  /// Label for the bottom Claim button. Defaults to the hardcoded English
  /// 'Claim' — the caller's own localized copy overrides it (ENH-39; this
  /// package doesn't own app-facing translation keys for game-specific copy
  /// like this).
  final String claimLabel;

  @override
  Widget build(BuildContext context) {
    final highlightDay = (currentStreakDay % cycleLength) + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: NeonTheme.s8,
          runSpacing: NeonTheme.s8,
          children: List.generate(cycleLength, (i) {
            final day = i + 1;
            final isCurrent = canClaimToday && day == highlightDay;
            return _DaySlot(
              day: day,
              claimed: claimedDaysInCycle.contains(day),
              current: isCurrent,
              onTap: isCurrent ? onClaim : null,
            );
          }),
        ),
        const SizedBox(height: NeonTheme.s16),
        CommonButton(label: claimLabel, onTap: canClaimToday ? onClaim : null),
      ],
    );
  }
}

class _DaySlot extends StatefulWidget {
  const _DaySlot({
    required this.day,
    required this.claimed,
    required this.current,
    this.onTap,
  });

  final int day;
  final bool claimed;
  final bool current;
  final VoidCallback? onTap;

  @override
  State<_DaySlot> createState() => _DaySlotState();
}

class _DaySlotState extends State<_DaySlot>
    with SingleTickerProviderStateMixin {
  // Bắt đầu đã settled (value 1.0) — không pop lúc mount dù ô đã claimed
  // sẵn. Chỉ forward(from: 0.0) khi thực sự vừa chuyển sang claimed, cùng
  // convention đã dùng ở StreakCounter (ENH-31)/IconBadgeButton (IDEA-16).
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _scale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(covariant _DaySlot old) {
    super.didUpdateWidget(old);
    if (!old.claimed && widget.claimed && !NeonTheme.reducedMotion(context)) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final claimed = widget.claimed;
    final current = widget.current;
    final onTap = widget.onTap;
    final Color fill;
    final Color border;
    final Color textColor;
    if (claimed) {
      fill = NeonTheme.gold;
      border = NeonTheme.gold;
      textColor = Colors.white;
    } else if (current) {
      fill = NeonTheme.card;
      border = NeonTheme.cyan;
      textColor = NeonTheme.ink;
    } else {
      fill = NeonTheme.lockedFill;
      border = NeonTheme.lockedBorder;
      textColor = NeonTheme.inkSoft;
    }

    final slot = AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        key: const Key('daySlotScale'),
        scale: _scale.value,
        child: child,
      ),
      child: Container(
        width: 40,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: current ? 3 : 2),
          boxShadow: current ? NeonTheme.glow(border) : null,
        ),
        child: claimed
            ? Icon(Icons.check_rounded, color: textColor, size: 20)
            : Text(
                '$day',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
      ),
    );
    final pressable = onTap == null
        ? slot
        : PressableScale(onTap: onTap, child: slot);
    // ENH-37: "Day 3, claimed" / "Day 4, current, double tap to claim" /
    // "Day 5, upcoming" — the slot's own Icon/Text (a checkmark or bare
    // number) says nothing about WHY it looks that way.
    final status = claimed
        ? 'claimed'
        : current
        ? 'current, double tap to claim'
        : 'upcoming';
    return Semantics(
      button: onTap != null,
      label: 'Day $day, $status',
      excludeSemantics: true,
      child: pressable,
    );
  }
}
