import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/raid_boss_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T2 — `RaidBossController` giữ vị từ cửa sổ cuối tuần, giới hạn lượt/ngày và
/// bậc thưởng damage, mà trước batch này không có test nào.
///
/// **Không đọc đồng hồ thật.** `_todayEpochDay()` dùng `todayEpochDayClamped()`
/// (X22), trả `max(ngày thật, maxEpochDaySeen)` — nên gieo `maxEpochDaySeen`
/// bằng một ngày tương lai đã chọn là ép được ngày trong game, đi đúng code
/// path production, không cần thêm API override chỉ để test.
///
/// Ràng buộc: ngày gieo phải **lớn hơn** ngày thật (lớp kẹp không lùi được),
/// nên mọi mốc dưới đây nằm ở tương lai xa.
///
/// Quy đổi thứ: epoch day 0 = 1970-01-01 = thứ Năm, nên
/// `(epochDay + 3) % 7` cho 0=T2 … 4=T6, 5=T7, 6=CN. Raid mở T6-CN.
const int _friday = 30003; // (30003+3)%7 == 4
const int _saturday = 30004;
const int _sunday = 30005;
const int _monday = 30006;

/// Ngày đầu tuần sau `_friday` — dùng để kiểm rollover theo tuần.
/// `_currentWeek()` là `epochDay ~/ 7`, nên +7 chắc chắn sang tuần mới.
const int _nextWeekFriday = _friday + 7;

Future<RaidBossController> _boot({
  required int epochDay,
  Map<String, Object> extra = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.maxEpochDaySeen: epochDay,
    ...extra,
  });
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  Get.put(GameController(), permanent: true);
  return Get.put(RaidBossController());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('isRaidActiveForEpochDay — vị từ thuần', () {
    test('mở đúng thứ Sáu / Bảy / Chủ nhật', () {
      expect(isRaidActiveForEpochDay(_friday), isTrue);
      expect(isRaidActiveForEpochDay(_saturday), isTrue);
      expect(isRaidActiveForEpochDay(_sunday), isTrue);
    });

    test('đóng thứ Hai đến thứ Năm', () {
      for (var i = 0; i < 4; i++) {
        expect(
          isRaidActiveForEpochDay(_monday + i),
          isFalse,
          reason: 'ngày ${_monday + i} phải nằm ngoài cửa sổ raid',
        );
      }
    });

    test('đúng 3/7 ngày mỗi tuần, không lệch khi trượt qua nhiều tuần', () {
      var active = 0;
      for (var d = _friday; d < _friday + 70; d++) {
        if (isRaidActiveForEpochDay(d)) active++;
      }
      expect(active, 30); // 10 tuần × 3 ngày
    });
  });

  group('cửa sổ cuối tuần qua controller', () {
    test('thứ Sáu: raid mở, còn lượt → bắt đầu được', () async {
      final ctrl = await _boot(epochDay: _friday);
      expect(ctrl.isRaidActive, isTrue);
      expect(ctrl.canStartRaid(), isTrue);
    });

    test('thứ Hai: raid đóng dù còn đủ lượt', () async {
      final ctrl = await _boot(epochDay: _monday);
      expect(ctrl.isRaidActive, isFalse);
      expect(ctrl.attemptsRemaining.value, RaidBossController.maxDailyAttempts);
      expect(
        ctrl.canStartRaid(),
        isFalse,
        reason: 'còn lượt nhưng ngoài cửa sổ sự kiện',
      );
    });
  });

  group('giới hạn lượt mỗi ngày', () {
    test('mặc định 3 lượt, tiêu hết thì không bắt đầu được nữa', () async {
      final ctrl = await _boot(epochDay: _friday);
      expect(ctrl.attemptsRemaining.value, 3);

      ctrl.consumeAttempt();
      ctrl.consumeAttempt();
      expect(ctrl.attemptsRemaining.value, 1);
      expect(ctrl.canStartRaid(), isTrue);

      ctrl.consumeAttempt();
      expect(ctrl.attemptsRemaining.value, 0);
      expect(ctrl.canStartRaid(), isFalse);
    });

    test('tiêu quá số lượt không làm âm', () async {
      final ctrl = await _boot(epochDay: _friday);
      for (var i = 0; i < 10; i++) {
        ctrl.consumeAttempt();
      }
      expect(ctrl.attemptsRemaining.value, 0);
    });

    test(
      'sang ngày mới trong cùng tuần → lượt reset, damage GIỮ nguyên',
      () async {
        final fri = await _boot(
          epochDay: _friday,
          extra: {
            StorageKeys.raidBossEventWeek: _friday ~/ 7,
            StorageKeys.raidBossLastAttemptDay: _friday,
            StorageKeys.raidBossAttemptsUsed: 3,
            StorageKeys.raidBossTotalDamage: 120,
          },
        );
        expect(fri.attemptsRemaining.value, 0);
        Get.reset();

        // Thứ Bảy cùng tuần.
        final sat = await _boot(
          epochDay: _saturday,
          extra: {
            StorageKeys.raidBossEventWeek: _friday ~/ 7,
            StorageKeys.raidBossLastAttemptDay: _friday,
            StorageKeys.raidBossAttemptsUsed: 3,
            StorageKeys.raidBossTotalDamage: 120,
          },
        );
        expect(sat.attemptsRemaining.value, 3, reason: 'ngày mới → lại 3 lượt');
        expect(
          sat.totalDamageThisEvent.value,
          120,
          reason: 'damage cộng dồn cả tuần, không reset theo ngày',
        );
      },
    );

    test('mở lại app trong cùng ngày → giữ nguyên số lượt đã dùng', () async {
      final ctrl = await _boot(
        epochDay: _friday,
        extra: {
          StorageKeys.raidBossEventWeek: _friday ~/ 7,
          StorageKeys.raidBossLastAttemptDay: _friday,
          StorageKeys.raidBossAttemptsUsed: 2,
        },
      );
      expect(ctrl.attemptsRemaining.value, 1);
    });
  });

  group('rollover theo tuần', () {
    test('sang tuần mới → damage và lượt reset về 0/3', () async {
      final ctrl = await _boot(
        epochDay: _nextWeekFriday,
        extra: {
          StorageKeys.raidBossEventWeek: _friday ~/ 7, // tuần cũ
          StorageKeys.raidBossTotalDamage: 999,
          StorageKeys.raidBossAttemptsUsed: 3,
        },
      );
      expect(ctrl.totalDamageThisEvent.value, 0);
      expect(ctrl.attemptsRemaining.value, 3);
      expect(ctrl.currentEventWeek.value, _nextWeekFriday ~/ 7);
    });

    test('cùng tuần → nạp lại damage đã tích, không reset', () async {
      final ctrl = await _boot(
        epochDay: _saturday,
        extra: {
          StorageKeys.raidBossEventWeek: _friday ~/ 7,
          StorageKeys.raidBossTotalDamage: 240,
          StorageKeys.raidBossLastAttemptDay: _saturday,
          StorageKeys.raidBossAttemptsUsed: 1,
        },
      );
      expect(ctrl.totalDamageThisEvent.value, 240);
      expect(ctrl.attemptsRemaining.value, 2);
    });
  });

  group('recordDamage', () {
    test('cộng dồn và persist', () async {
      final ctrl = await _boot(epochDay: _friday);
      ctrl.recordDamage(30);
      ctrl.recordDamage(45);
      expect(ctrl.totalDamageThisEvent.value, 75);
      expect(StorageService.to.getInt(StorageKeys.raidBossTotalDamage), 75);
    });

    test('damage <= 0 bị bỏ qua', () async {
      final ctrl = await _boot(epochDay: _friday);
      ctrl.recordDamage(0);
      ctrl.recordDamage(-50);
      expect(ctrl.totalDamageThisEvent.value, 0);
    });
  });

  group('bậc thưởng damage', () {
    test('dưới mốc thấp nhất → chưa nhận được', () async {
      final ctrl = await _boot(epochDay: _friday);
      ctrl.recordDamage(kRaidRewardTiers.first.requiredDamage - 1);
      expect(ctrl.canClaimWeeklyReward(), isFalse);
      expect(ctrl.claimWeeklyReward(Get.find<GameController>()), 0);
    });

    test('thưởng CỘNG DỒN mọi bậc đã đạt, không chỉ bậc cao nhất', () async {
      final ctrl = await _boot(epochDay: _friday);
      final gameCtrl = Get.find<GameController>();
      ctrl.recordDamage(kRaidRewardTiers.last.requiredDamage);

      final coins = ctrl.claimWeeklyReward(gameCtrl);
      final expected = kRaidRewardTiers.fold<int>(
        0,
        (sum, t) => sum + t.coinReward,
      );
      expect(coins, expected);
      expect(gameCtrl.coins.value, expected);
      expect(StorageService.to.getInt(StorageKeys.coins), expected);
    });

    test('đạt đúng bậc giữa → chỉ cộng 2 bậc đầu', () async {
      final ctrl = await _boot(epochDay: _friday);
      ctrl.recordDamage(kRaidRewardTiers[1].requiredDamage);
      expect(
        ctrl.claimWeeklyReward(Get.find<GameController>()),
        kRaidRewardTiers[0].coinReward + kRaidRewardTiers[1].coinReward,
      );
    });

    test('nhận rồi thì không nhận lại trong cùng tuần', () async {
      final ctrl = await _boot(epochDay: _friday);
      final gameCtrl = Get.find<GameController>();
      ctrl.recordDamage(kRaidRewardTiers.last.requiredDamage);

      final first = ctrl.claimWeeklyReward(gameCtrl);
      expect(first, greaterThan(0));
      final coinsAfterFirst = gameCtrl.coins.value;

      expect(ctrl.canClaimWeeklyReward(), isFalse);
      expect(ctrl.claimWeeklyReward(gameCtrl), 0);
      expect(gameCtrl.coins.value, coinsAfterFirst);
    });

    test('tuần mới → nhận lại được (sau khi tích đủ damage mới)', () async {
      final ctrl = await _boot(
        epochDay: _nextWeekFriday,
        extra: {
          // Tuần trước đã nhận thưởng.
          StorageKeys.raidBossRewardClaimedWeek: _friday ~/ 7,
          StorageKeys.raidBossEventWeek: _friday ~/ 7,
          StorageKeys.raidBossTotalDamage: 999,
        },
      );
      // Rollover đã xoá damage tuần trước.
      expect(ctrl.totalDamageThisEvent.value, 0);
      expect(ctrl.canClaimWeeklyReward(), isFalse);

      ctrl.recordDamage(kRaidRewardTiers.first.requiredDamage);
      expect(ctrl.canClaimWeeklyReward(), isTrue);
      expect(
        ctrl.claimWeeklyReward(Get.find<GameController>()),
        kRaidRewardTiers.first.coinReward,
      );
    });
  });
}
