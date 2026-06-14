import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/achievements.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/data/wheel.dart';
import 'package:neon_jewels/presentation/controllers/achievement_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/lucky_wheel_controller.dart';
import 'package:neon_jewels/presentation/controllers/pregame_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Random giả: nextInt luôn trả [value] (mod max) → ép vòng quay vào ô cụ thể.
class _FixedRandom implements Random {
  final int value;
  _FixedRandom(this.value);
  @override
  int nextInt(int max) => value % max;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    c = Get.put(GameController());
  });

  tearDown(Get.reset);

  int scoreLevel() =>
      kLevels.indexWhere((l) => l.objective == ObjectiveType.score) + 1;

  /// Thắng 1 màn score: nạp điểm đủ rồi checkEnd.
  void winOnce() {
    final idx = scoreLevel();
    c.startLevel(idx);
    c.score.value = c.targetScore.value;
    final r = c.checkEnd();
    expect(r, 'win');
  }

  group('Win streak', () {
    test('thắng liên tiếp tăng chuỗi; thua reset về 0', () {
      winOnce();
      expect(c.winStreak.value, 1);
      expect(c.totalWins.value, 1);
      expect(c.lastStreakBonus, 0); // bậc 1 chưa thưởng

      winOnce();
      expect(c.winStreak.value, 2);
      expect(c.lastStreakBonus, 2 * 5); // bậc 2 → +10

      // thua: bắt đầu màn mới, không đạt điểm, hết lượt
      final idx = scoreLevel();
      c.startLevel(idx);
      c.movesLeft.value = 0;
      expect(c.checkEnd(), 'lose');
      expect(c.winStreak.value, 0);
    });

    test('bonus chuỗi bị chặn trần (cap)', () {
      for (var i = 0; i < 10; i++) {
        winOnce();
      }
      expect(c.winStreak.value, 10);
      // cap = 6 bậc → bonus tối đa 6*5
      expect(c.lastStreakBonus, 6 * 5);
      expect(c.bestWinStreak.value, 10);
    });

    test('bestCombo cập nhật qua addScore', () {
      c.startLevel(scoreLevel());
      c.addScore(3, 4);
      expect(c.bestCombo.value, 4);
      c.addScore(3, 2); // nhỏ hơn không hạ
      expect(c.bestCombo.value, 4);
      c.addScore(3, 7);
      expect(c.bestCombo.value, 7);
    });
  });

  group('Achievements', () {
    late AchievementController ac;
    setUp(() => ac = Get.put(AchievementController(c)));

    Achievement byId(String id) => kAchievements.firstWhere((a) => a.id == id);

    test('chưa đạt → không claim được', () {
      final a = byId('first_win');
      expect(ac.isUnlocked(a), false);
      expect(ac.canClaim(a), false);
      expect(ac.claim(a), 0);
    });

    test('đạt ngưỡng → claim cộng xu + không nhận lại lần 2', () {
      winOnce(); // totalWins = 1
      final a = byId('first_win');
      expect(ac.isUnlocked(a), true);
      expect(ac.canClaim(a), true);

      final before = c.coins.value;
      final got = ac.claim(a);
      expect(got, a.reward);
      expect(c.coins.value, before + a.reward);
      expect(ac.isClaimed(a), true);
      expect(ac.canClaim(a), false);
      // nhận lại → 0
      expect(ac.claim(a), 0);
    });

    test('hasUnclaimed phản ánh trạng thái', () {
      expect(ac.hasUnclaimed, false);
      winOnce();
      expect(ac.hasUnclaimed, true);
      ac.claim(byId('first_win'));
      // có thể vẫn còn 'world' khác? first_win mở, world_2 chưa. Sau claim
      // first_win, không còn cái nào đạt mà chưa nhận.
      expect(ac.hasUnclaimed, false);
    });
  });

  group('Lucky Wheel', () {
    late LuckyWheelController lw;
    setUp(() {
      lw = Get.put(LuckyWheelController(c));
      lw.rng = Random(1); // xác định
    });

    test('quay 1 lần/ngày: trao thưởng + chặn quay lại trong ngày', () {
      expect(lw.canSpin, true);
      final before = c.coins.value;
      final idx = lw.spin();
      expect(idx, inInclusiveRange(0, kWheel.length - 1));

      final s = kWheel[idx];
      if (s.isCoins) {
        expect(c.coins.value, before + s.amount);
      }
      // đã tiêu lượt hôm nay
      expect(lw.canSpin, false);
      // quay lại trong ngày → -1 (no-op)
      expect(lw.spin(), -1);
    });

    test('sang ngày mới lại quay được', () {
      lw.spin();
      expect(lw.canSpin, false);
      // dịch đồng hồ sang hôm sau
      final base = c.clock();
      c.clock = () => base.add(const Duration(days: 1));
      expect(lw.canSpin, true);
    });

    test('mọi ô thưởng: coins cộng xu, booster cộng đúng loại', () {
      for (var idx = 0; idx < kWheel.length; idx++) {
        StorageService.to.remove(StorageKeys.wheelLastSpin); // reset lượt quay
        final lw2 = LuckyWheelController(c)..rng = _FixedRandom(idx);
        final coins0 = c.coins.value;
        final moves0 = c.boosterMoves.value;
        final hammer0 = c.boosterHammer.value;
        final bomb0 = c.boosterBomb.value;
        final swap0 = c.boosterSwap.value;
        final landed = lw2.spin();
        expect(landed, idx);
        final s = kWheel[idx];
        switch (s.kind) {
          case WheelKind.coins:
            expect(c.coins.value, coins0 + s.amount);
            break;
          case WheelKind.moves:
            expect(c.boosterMoves.value, moves0 + s.amount);
            break;
          case WheelKind.hammer:
            expect(c.boosterHammer.value, hammer0 + s.amount);
            break;
          case WheelKind.bomb:
            expect(c.boosterBomb.value, bomb0 + s.amount);
            break;
          case WheelKind.swap:
            expect(c.boosterSwap.value, swap0 + s.amount);
            break;
        }
      }
    });
  });

  group('View mode persist', () {
    test('mặc định map (0); ghi/đọc 0↔1', () {
      final store = StorageService.to;
      expect(store.getInt(StorageKeys.viewMode, def: 0), 0);
      store.setInt(StorageKeys.viewMode, 1);
      expect(store.getInt(StorageKeys.viewMode, def: 0), 1);
      store.setInt(StorageKeys.viewMode, 0);
      expect(store.getInt(StorageKeys.viewMode, def: 0), 0);
    });
  });

  group('resetProgress', () {
    late AchievementController ac;
    setUp(() => ac = Get.put(AchievementController(c)));

    test('xoá sạch streak/thống kê + cờ thành tựu đã nhận', () async {
      // tạo tiến trình
      final idx = scoreLevel();
      c.startLevel(idx);
      c.score.value = c.targetScore.value;
      c.checkEnd(); // win → totalWins=1, winStreak=1
      ac.claim(kAchievements.firstWhere((a) => a.id == 'first_win'));
      expect(c.totalWins.value, 1);
      expect(ac.isClaimed(kAchievements.first), true);

      await c.resetProgress();
      expect(c.totalWins.value, 0);
      expect(c.winStreak.value, 0);
      expect(c.bestWinStreak.value, 0);
      expect(c.bestCombo.value, 0);
      expect(c.coinsEarnedTotal.value, 0);
      // cờ thành tựu trong store đã bị xoá
      expect(
          StorageService.to.getInt(
              StorageKeys.achievementClaimed('first_win'),
              def: 0),
          0);
    });
  });

  group('Pre-game booster', () {
    late PregameController pg;
    setUp(() => pg = Get.put(PregameController(c)));

    test('hasAny phản ánh sở hữu booster', () {
      c.boosterMoves.value = 0;
      c.boosterHammer.value = 0;
      expect(pg.hasAny, false);
      c.boosterHammer.value = 1;
      expect(pg.hasAny, true);
    });

    test('toggle chỉ bật khi sở hữu', () {
      c.boosterMoves.value = 0;
      pg.toggleMoves();
      expect(pg.useMoves.value, false); // không sở hữu → không bật
      c.boosterMoves.value = 2;
      pg.toggleMoves();
      expect(pg.useMoves.value, true);
    });

    test('start ghi cờ pending cho game', () {
      c.boosterMoves.value = 2;
      c.boosterHammer.value = 2;
      pg.openFor(3);
      pg.toggleMoves();
      pg.toggleHammer();
      pg.start();
      expect(c.pendingMovesBoost, true);
      expect(c.pendingArmHammer, true);
      expect(pg.open.value, false);
    });
  });

  group('Achievement coverage (mọi thành tựu)', () {
    test('mỗi thành tựu mở khoá khi đạt ngưỡng', () {
      final ac = Get.put(AchievementController(c));
      for (final a in kAchievements) {
        switch (a.stat) {
          case AchStat.totalWins:
            c.totalWins.value = a.threshold;
            break;
          case AchStat.totalStars:
            c.stars.clear();
            var rem = a.threshold, lv = 1;
            while (rem > 0) {
              final v = rem > 3 ? 3 : rem;
              c.stars[lv] = v;
              rem -= v;
              lv++;
            }
            break;
          case AchStat.bestCombo:
            c.bestCombo.value = a.threshold;
            break;
          case AchStat.bestWinStreak:
            c.bestWinStreak.value = a.threshold;
            break;
          case AchStat.unlockedLevel:
            c.unlockedLevel.value = a.threshold;
            break;
          case AchStat.coinsEarned:
            c.coinsEarnedTotal.value = a.threshold;
            break;
        }
        expect(ac.isUnlocked(a), true, reason: 'thành tựu ${a.id} phải mở khoá');
      }
    });

    test('đạt hết → claim tất cả → hasUnclaimed false + xu tăng', () {
      final ac = Get.put(AchievementController(c));
      c.totalWins.value = 100;
      c.bestCombo.value = 20;
      c.bestWinStreak.value = 20;
      c.unlockedLevel.value = 100;
      c.coinsEarnedTotal.value = 5000;
      c.stars.clear();
      for (var lv = 1; lv <= 40; lv++) {
        c.stars[lv] = 3; // 120 sao
      }
      for (final a in kAchievements) {
        expect(ac.isUnlocked(a), true, reason: a.id);
      }
      expect(ac.hasUnclaimed, true);
      final coins0 = c.coins.value;
      var totalReward = 0;
      for (final a in kAchievements) {
        totalReward += ac.claim(a);
      }
      expect(ac.hasUnclaimed, false);
      expect(c.coins.value, coins0 + totalReward);
      expect(totalReward, greaterThan(0));
    });
  });

  group('Spread obstacle (chocolate)', () {
    test('các màn spread là score + obstacle=spread + thêm lượt', () {
      for (final lv in kSpreadLevels) {
        final cfg = kLevels[lv - 1];
        expect(cfg.objective, ObjectiveType.score,
            reason: 'màn $lv phải là score');
        expect(cfg.obstacle, ObstacleType.spread,
            reason: 'màn $lv phải có obstacle spread');
      }
    });

    test('spread không trùng các màn clearObstacle (ice/chain/stone)', () {
      for (final lv in kSpreadLevels) {
        final cfg = kLevels[lv - 1];
        expect(cfg.objective != ObjectiveType.clearObstacle, true);
      }
      // các màn clearObstacle vẫn chỉ dùng ice/chain/stone, không spread
      for (final cfg in kLevels) {
        if (cfg.objective == ObjectiveType.clearObstacle) {
          expect(cfg.obstacle != ObstacleType.spread, true);
        }
      }
    });
  });
}
