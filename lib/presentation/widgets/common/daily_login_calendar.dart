import 'package:flutter/material.dart';

import '../../../core/daily_login_service.dart' show kDailyLoginCycleLength;
import '../../../core/neon_theme.dart';
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
        CommonButton(label: 'Claim', onTap: canClaimToday ? onClaim : null),
      ],
    );
  }
}

class _DaySlot extends StatelessWidget {
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
  Widget build(BuildContext context) {
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

    final slot = Container(
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
    );
    return onTap == null ? slot : GestureDetector(onTap: onTap, child: slot);
  }
}
