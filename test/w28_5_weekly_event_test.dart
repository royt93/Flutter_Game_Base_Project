import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/season.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 28.5 — Weekly Rotating World Event: buff coin toàn app đổi mỗi tuần,
/// tất định theo epochDay (tái dùng [seasonIndex], cùng ranh giới tuần với
/// Season League). KHÔNG đụng công thức điểm/sao — chỉ nhân `lastCoinReward`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('W28.5 — currentWeeklyEvent tất định', () {
    test('cùng epochDay → cùng event (không đổi giữa 2 lần gọi)', () {
      expect(currentWeeklyEvent(20412), currentWeeklyEvent(20412));
    });

    test('cùng tuần (7 ngày) → event không đổi', () {
      final first = currentWeeklyEvent(20412);
      for (var d = 20412; d < 20412 + kSeasonDays; d++) {
        expect(currentWeeklyEvent(d), first);
      }
    });

    test('sang tuần kế tiếp (+7 ngày) → event đổi đúng chu kỳ', () {
      final e0 = currentWeeklyEvent(20412);
      final e1 = currentWeeklyEvent(20412 + kSeasonDays);
      expect(
        e1,
        kWeeklyEvents[(kWeeklyEvents.indexOf(e0) + 1) % kWeeklyEvents.length],
      );
    });

    test('cycle đúng độ dài kWeeklyEvents.length rồi lặp lại', () {
      final base = currentWeeklyEvent(20412);
      final after = currentWeeklyEvent(
        20412 + kSeasonDays * kWeeklyEvents.length,
      );
      expect(after, base);
    });
  });

  group('W28.5 — buff coin theo tuần khi thắng màn', () {
    late GameController c;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs));
      c = Get.put(GameController());
    });
    tearDown(Get.reset);

    // epochDay đầu tuần đã xác định trước (script tính từ seasonIndex % 4):
    // 2025-11-21 → mod4=0 (event_none, ×1.0)
    // 2025-11-28 → mod4=1 (event_coin, ×1.3)
    // 2025-12-05 → mod4=2 (event_combo, ×1.2)
    // 2025-11-14 → mod4=3 (event_bigcoin, ×1.5)
    final cases = {
      DateTime(2025, 11, 21): 1.0,
      DateTime(2025, 11, 28): 1.3,
      DateTime(2025, 12, 5): 1.2,
      DateTime(2025, 11, 14): 1.5,
    };

    for (final entry in cases.entries) {
      test(
        'thắng màn ở tuần ${entry.value}x → lastCoinReward nhân đúng hệ số',
        () {
          c.clock = () => entry.key;
          c.startLevel(1);
          c.addScore(1000, 1);
          expect(c.checkEnd(), 'win');
          final mult = currentWeeklyEvent(c.todayEpochDay).coinMult;
          expect(mult, entry.value);
          final base =
              10 +
              c.lastStars * 10 +
              c.lastStreakBonus +
              (1 + c.lastStars) * 10;
          expect(c.lastCoinReward, (base * mult).round());
        },
      );
    }
  });
}
