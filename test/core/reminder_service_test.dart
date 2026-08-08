import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/reminder_service.dart';

void main() {
  group('timeUntilNextDailyReset', () {
    test('đúng giữa ngày UTC còn nguyên gần 1 ngày', () {
      final noon = DateTime.utc(2026, 3, 5, 12).millisecondsSinceEpoch;
      expect(
        timeUntilNextDailyReset(nowEpochMs: noon),
        const Duration(hours: 12),
      );
    });

    test('đúng lúc UTC midnight còn nguyên 1 ngày', () {
      final midnight = DateTime.utc(2026, 3, 5).millisecondsSinceEpoch;
      expect(
        timeUntilNextDailyReset(nowEpochMs: midnight),
        const Duration(days: 1),
      );
    });

    test('sát UTC midnight kế tiếp gần như bằng 0', () {
      final almostMidnight = DateTime.utc(
        2026,
        3,
        6,
      ).subtract(const Duration(milliseconds: 1)).millisecondsSinceEpoch;
      expect(
        timeUntilNextDailyReset(nowEpochMs: almostMidnight),
        const Duration(milliseconds: 1),
      );
    });
  });

  group('timeUntilNextWeeklyReset', () {
    test('epoch day 0 (đầu tuần 0) còn nguyên 7 ngày', () {
      expect(timeUntilNextWeeklyReset(nowEpochMs: 0), const Duration(days: 7));
    });

    test('giữa tuần còn đúng phần còn lại tới ranh giới tuần kế', () {
      final day3Noon = 3 * 86400000 + const Duration(hours: 12).inMilliseconds;
      expect(
        timeUntilNextWeeklyReset(nowEpochMs: day3Noon),
        const Duration(days: 3, hours: 12),
      );
    });

    test('sát cuối tuần gần như bằng 0', () {
      expect(
        timeUntilNextWeeklyReset(nowEpochMs: 7 * 86400000 - 1),
        const Duration(milliseconds: 1),
      );
    });
  });

  group('pickReminderKind', () {
    test('spin có ưu tiên cao nhất', () {
      expect(
        pickReminderKind(
          canClaimSpin: true,
          streakRewardUnclaimed: true,
          weeklyGoalIncomplete: true,
          weeklyRemaining: const Duration(hours: 1),
          questBoardClaimable: true,
        ),
        ReminderKind.spin,
      );
    });

    test('streak ưu tiên trên weekly goal khi hết spin', () {
      expect(
        pickReminderKind(
          canClaimSpin: false,
          streakRewardUnclaimed: true,
          weeklyGoalIncomplete: true,
          weeklyRemaining: const Duration(hours: 1),
          questBoardClaimable: true,
        ),
        ReminderKind.streak,
      );
    });

    test('weekly goal chỉ nhắc khi còn ≤1 ngày', () {
      expect(
        pickReminderKind(
          canClaimSpin: false,
          streakRewardUnclaimed: false,
          weeklyGoalIncomplete: true,
          weeklyRemaining: const Duration(days: 1),
          questBoardClaimable: true,
        ),
        ReminderKind.weeklyGoal,
      );
      expect(
        pickReminderKind(
          canClaimSpin: false,
          streakRewardUnclaimed: false,
          weeklyGoalIncomplete: true,
          weeklyRemaining: const Duration(days: 2),
          questBoardClaimable: false,
        ),
        null,
      );
    });

    test('không có điều kiện nào thoả thì không nhắc', () {
      expect(
        pickReminderKind(
          canClaimSpin: false,
          streakRewardUnclaimed: false,
          weeklyGoalIncomplete: false,
          weeklyRemaining: const Duration(hours: 1),
          questBoardClaimable: false,
        ),
        null,
      );
    });

    test('quest board (I78) chỉ nhắc khi không còn điều kiện nào khác', () {
      expect(
        pickReminderKind(
          canClaimSpin: false,
          streakRewardUnclaimed: false,
          weeklyGoalIncomplete: false,
          weeklyRemaining: const Duration(hours: 1),
          questBoardClaimable: true,
        ),
        ReminderKind.questBoard,
      );
    });

    test('quest board bị đè bởi weekly goal sắp hết (ưu tiên cao hơn)', () {
      expect(
        pickReminderKind(
          canClaimSpin: false,
          streakRewardUnclaimed: false,
          weeklyGoalIncomplete: true,
          weeklyRemaining: const Duration(hours: 1),
          questBoardClaimable: true,
        ),
        ReminderKind.weeklyGoal,
      );
    });

    test(
      'quest board chưa claimable thì không nhắc dù các loại khác cũng tắt',
      () {
        expect(
          pickReminderKind(
            canClaimSpin: false,
            streakRewardUnclaimed: false,
            weeklyGoalIncomplete: true,
            weeklyRemaining: const Duration(days: 2),
            questBoardClaimable: false,
          ),
          null,
        );
      },
    );
  });
}
