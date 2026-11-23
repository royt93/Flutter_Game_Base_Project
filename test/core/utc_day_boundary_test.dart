import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/daily_login_service.dart';
import 'package:roy_casual_kit/core/daily_quest_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/clamped_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ENH-114: locks the documented rule that the kit's "day" is the UTC calendar
/// day. The day flips at exactly 00:00 UTC, never at the player's local
/// midnight, so these tests drive the clock to one minute either side of a UTC
/// midnight and assert what every daily/weekly system does there.
const _dayMs = 86400000;
const _minuteMs = 60000;

Future<void> _boot() async {
  SharedPreferences.setMockInitialValues({});
  Get.put(
    StorageService(await SharedPreferences.getInstance()),
    permanent: true,
  );
}

int get _nowUtcMs => DateTime.now().toUtc().millisecondsSinceEpoch;

/// Moves the (debug-offset) clock so that "now" is [msFromMidnight] away from
/// the NEXT UTC midnight (negative = before it). Returns that midnight's day.
int _travelTo(int msFromMidnight) {
  final nextMidnight = (_nowUtcMs ~/ _dayMs + 1) * _dayMs;
  setDebugTimeOffsetMs(nextMidnight + msFromMidnight - _nowUtcMs);
  return nextMidnight ~/ _dayMs;
}

void main() {
  setUp(() => clockRewindBlockedCount = 0);
  tearDown(() {
    setDebugTimeOffsetMs(0);
    Get.reset();
  });

  test('the day flips at exactly 00:00 UTC', () async {
    await _boot();
    final newDay = _travelTo(-_minuteMs);
    expect(todayEpochDayClamped(), newDay - 1, reason: '23:59 UTC');

    _travelTo(_minuteMs);
    expect(todayEpochDayClamped(), newDay, reason: '00:01 UTC');
  });

  test(
    'the day follows the UTC instant, not any local representation',
    () async {
      await _boot();
      // 17:00 UTC is local midnight in UTC+7: still the SAME kit day on both
      // sides of it. Local time must not matter.
      final newDay = _travelTo(-7 * 3600000 - _minuteMs); // 16:59 UTC
      final before = todayEpochDayClamped();
      _travelTo(-7 * 3600000 + _minuteMs); // 17:01 UTC
      final after = todayEpochDayClamped();
      expect(before, newDay - 1);
      expect(after, before, reason: 'UTC+7 local midnight is not a reset');
    },
  );

  test(
    'DailyLoginService resets at 00:00 UTC, not at local midnight',
    () async {
      await _boot();
      final login = DailyLoginService();
      _travelTo(-7 * 3600000 - _minuteMs); // 16:59 UTC = 23:59 in UTC+7
      expect(login.claimToday().streakDay, 1);
      expect(login.canClaimToday(), isFalse);

      _travelTo(-7 * 3600000 + _minuteMs); // 17:01 UTC = 00:01 local next day
      expect(
        login.canClaimToday(),
        isFalse,
        reason: 'a UTC+7 player crossing their own midnight is not a new day',
      );

      _travelTo(-_minuteMs); // 23:59 UTC
      expect(login.canClaimToday(), isFalse);

      _travelTo(_minuteMs); // 00:01 UTC
      expect(login.canClaimToday(), isTrue);
      final next = login.claimToday();
      expect(
        next.streakDay,
        2,
        reason: 'consecutive UTC days continue the streak',
      );
      expect(next.streakWasReset, isFalse);
    },
  );

  test('a daily quest resets across 00:00 UTC', () async {
    await _boot();
    final quests = DailyQuestService()
      ..register('win', 3, period: QuestPeriod.daily);
    _travelTo(-_minuteMs);
    quests.incrementProgress('win', 2);
    expect(quests.progressOf('win'), 2);

    _travelTo(_minuteMs);
    expect(quests.progressOf('win'), 0, reason: 'new UTC day, quest restarts');
  });

  test('the weekly block is day ~/ 7 on the UTC day', () async {
    await _boot();
    _travelTo(-_minuteMs);
    final day = todayEpochDayClamped();
    final quests = DailyQuestService()
      ..register('wk', 5, period: QuestPeriod.weekly);
    quests.incrementProgress('wk', 1);
    expect(quests.progressOf('wk'), 1);
    // Move to the next day: the weekly block only changes when day ~/ 7 does.
    setDebugTimeOffsetMs(debugTimeOffsetMs + _dayMs);
    final next = todayEpochDayClamped();
    expect(next, day + 1);
    expect(
      quests.progressOf('wk'),
      next ~/ 7 == day ~/ 7 ? 1 : 0,
      reason: 'resets exactly when the 7-day block index changes',
    );
  });
}
