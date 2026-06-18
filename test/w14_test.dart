import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/collection.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/data/tournament.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/presentation/controllers/collection_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/piggy_controller.dart';
import 'package:neon_jewels/presentation/controllers/tournament_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ----------------------------------------------------------- Obstacle weave
  group('Wave 14 — obstacle licorice/jam (levels)', () {
    test('màn licorice = clearObstacle + pattern center', () {
      for (final idx in kLicoriceLevels) {
        final lv = kLevels[idx - 1];
        expect(lv.objective, ObjectiveType.clearObstacle);
        expect(lv.obstacle, ObstacleType.licorice);
        expect(lv.obstaclePattern, JellyPattern.center);
      }
    });

    test('màn jam = clearObstacle + pattern center', () {
      for (final idx in kJamLevels) {
        final lv = kLevels[idx - 1];
        expect(lv.objective, ObjectiveType.clearObstacle);
        expect(lv.obstacle, ObstacleType.jam);
        expect(lv.obstaclePattern, JellyPattern.center);
      }
    });

    test('winnability: obstacle KHOÁ swap không bao giờ dùng all/checker', () {
      // chain/stone/licorice/jam khoá swap → pattern dày sẽ bí bàn. Chỉ ice mới
      // được pattern dày. Regression guard cho cả 2 loại mới.
      for (final lv in kLevels) {
        if (lv.objective != ObjectiveType.clearObstacle) continue;
        final locking = lv.obstacle == ObstacleType.chain ||
            lv.obstacle == ObstacleType.stone ||
            lv.obstacle == ObstacleType.licorice ||
            lv.obstacle == ObstacleType.jam;
        if (locking) {
          expect(lv.obstaclePattern, JellyPattern.center,
              reason: 'màn ${lv.index} obstacle khoá phải dùng center');
        }
      }
    });
  });

  // ------------------------------------------------------------------ Soda mode
  group('Wave 14 — Soda mode', () {
    test('startSoda đặt cờ + side-mode + mục tiêu', () {
      c.startSoda();
      expect(c.isSoda.value, isTrue);
      expect(c.isSideMode, isTrue);
      expect(c.level.objective, ObjectiveType.soda);
      expect(c.level.sodaTarget, kSodaBottles);
      expect(c.movesLeft.value, kSodaMoves);
      expect(c.sodaCollected.value, 0);
    });

    test('clear đủ gem → chai nổi lên (mỗi kSodaFillPerBottle = 1 chai)', () {
      c.startSoda();
      for (var i = 0; i < kSodaFillPerBottle; i++) {
        c.registerClear(GemColor.cyan, false);
      }
      expect(c.sodaCollected.value, 1);
      expect(c.hasWon, isFalse);
    });

    test('đủ chai → hasWon + checkEnd win (side-mode không đụng tiến trình)', () {
      c.startSoda();
      final before = c.unlockedLevel.value;
      for (var i = 0; i < kSodaFillPerBottle * kSodaBottles; i++) {
        c.registerClear(GemColor.lime, false);
      }
      expect(c.sodaCollected.value, kSodaBottles);
      expect(c.hasWon, isTrue);
      expect(c.checkEnd(), 'win');
      expect(c.winStreak.value, 0, reason: 'soda không đụng win-streak');
      expect(c.unlockedLevel.value, before, reason: 'soda không mở khoá màn');
    });

    test('hết lượt chưa đủ chai → lose', () {
      c.startSoda();
      for (var i = 0; i < kSodaMoves; i++) {
        c.useMove();
      }
      expect(c.checkEnd(), 'lose');
    });
  });

  // ------------------------------------------------------------ Collection/Album
  group('Wave 14 — Collection', () {
    test('addWin cộng điểm, đạt mốc → claim được + grant', () {
      final cc = Get.put(CollectionController(c));
      final coins0 = c.coins.value;
      final item = kCollectionItems[0]; // ngưỡng 30, thưởng coins 40
      // cộng đủ điểm: addWin(3) = 3+3*2 = 9/lần → cần ≥4 lần cho 30 điểm
      for (var i = 0; i < 4; i++) {
        cc.addWin(3);
      }
      expect(cc.points.value, greaterThanOrEqualTo(item.threshold));
      expect(cc.canClaim(0), isTrue);
      expect(cc.claim(0), isTrue);
      expect(cc.isClaimed(0), isTrue);
      expect(c.coins.value, coins0 + item.amount);
      expect(cc.canClaim(0), isFalse, reason: 'không nhận lại');
    });

    test('persist + resetState', () async {
      final cc = Get.put(CollectionController(c));
      for (var i = 0; i < 10; i++) {
        cc.addWin(3);
      }
      cc.claim(0);
      await Future.delayed(const Duration(milliseconds: 20));
      cc.resetState();
      expect(cc.points.value, 0);
      expect(cc.claimed, isEmpty);
    });
  });

  // ----------------------------------------------------------------- Piggy bank
  group('Wave 14 — Piggy bank', () {
    test('addWin bỏ ống, đạt min → smash nhận xu', () {
      final pc = Get.put(PiggyController(c));
      final coins0 = c.coins.value;
      expect(pc.canSmash, isFalse);
      // depositForWin(3) = 6+3*4 = 18/lần → cần ≥7 lần cho 120
      for (var i = 0; i < 8; i++) {
        pc.addWin(3);
      }
      expect(pc.saved.value, greaterThanOrEqualTo(PiggyController.kPiggyMin));
      expect(pc.canSmash, isTrue);
      final got = pc.smash();
      expect(got, greaterThan(0));
      expect(pc.saved.value, 0);
      expect(c.coins.value, coins0 + got);
    });

    test('không vượt cap + resetState', () {
      final pc = Get.put(PiggyController(c));
      for (var i = 0; i < 200; i++) {
        pc.addWin(3);
      }
      expect(pc.saved.value, PiggyController.kPiggyCap);
      expect(pc.isFull, isTrue);
      pc.resetState();
      expect(pc.saved.value, 0);
    });
  });

  // -------------------------------------------------------------- Tournament
  group('Wave 14 — Tournament', () {
    test('botScore tất định theo tuần + ngày', () {
      // cùng (tuần, bot, ngày) → cùng điểm; ngày sau ≥ ngày trước (leo dần).
      expect(botScore(100, 0, 3), botScore(100, 0, 3));
      expect(botScore(100, 0, 6), greaterThanOrEqualTo(botScore(100, 0, 0)));
    });

    test('addWin cộng điểm + hạng theo bot', () {
      c.clock = () => DateTime(2026, 6, 18);
      final tc = Get.put(TournamentController(c));
      tc.addWin(3); // 12+18 = 30
      expect(tc.points.value, tournamentPointsForWin(3));
      expect(tc.playerRank, inInclusiveRange(1, kTournamentBots.length + 1));
    });

    test('claim 1 lần/tuần + đổi tuần reset điểm', () {
      c.clock = () => DateTime(2026, 6, 18);
      final tc = Get.put(TournamentController(c));
      tc.addWin(3);
      final coins0 = c.coins.value;
      final r = tc.claim();
      expect(r, isNotNull);
      expect(c.coins.value, greaterThan(coins0));
      expect(tc.canClaim, isFalse);
      expect(tc.claim(), isNull, reason: 'không nhận 2 lần/tuần');
      // sang tuần mới (≥7 ngày sau) → điểm reset
      c.clock = () => DateTime(2026, 6, 30);
      tc.addWin(1);
      expect(tc.points.value, tournamentPointsForWin(1));
      expect(tc.claimedThisWeek.value, isFalse);
    });

    test('resetState', () {
      c.clock = () => DateTime(2026, 6, 18);
      final tc = Get.put(TournamentController(c));
      tc.addWin(3);
      tc.resetState();
      expect(tc.points.value, 0);
      expect(tc.claimedThisWeek.value, isFalse);
    });

    test('M1 fix: xếp hạng dùng điểm bot CUỐI tuần (cố định cả tuần)', () {
      c.clock = () => DateTime(2026, 6, 18);
      final tc = Get.put(TournamentController(c));
      // botScoreNow = botScore(week, i, kTournamentDays-1) — không phụ thuộc ngày
      // hiện tại → đầu tuần KHÔNG còn yếu → hết ăn hạng 1 sớm.
      for (var i = 0; i < kTournamentBots.length; i++) {
        expect(tc.botScoreNow(i), botScore(tc.week, i, kTournamentDays - 1));
      }
    });
  });

  // ----------------------------------------------- H1 fix — chỉ first-clear
  group('Wave 14 — meta chỉ tính first-clear (chống farm)', () {
    test('lastFirstClear: lần đầu thắng → true; thắng lại màn → false', () async {
      c.startLevel(1);
      c.score.value = c.targetScore.value;
      expect(c.checkEnd(), 'win');
      expect(c.lastFirstClear, isTrue);
      await Future.delayed(const Duration(milliseconds: 30)); // _saveProgress ghi sao
      expect((c.stars[1] ?? 0), greaterThan(0));
      // thắng lại CÙNG màn → đã có sao → first-clear false (meta không cộng)
      c.startLevel(1);
      c.score.value = c.targetScore.value;
      expect(c.checkEnd(), 'win');
      expect(c.lastFirstClear, isFalse);
    });
  });

  // --------------------------------------- L3 — winnability obstacle (sim)
  group('Wave 14 — winnability obstacle (invariant + sim)', () {
    int centerCount() {
      var n = 0;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          if (patternHas(JellyPattern.center, r, c, 8, 8)) n++;
        }
      }
      return n;
    }

    test('jam cap < ô bàn → luôn còn vùng tự do (≥16 ô)', () {
      expect(kJamSpreadCap, lessThan(8 * 8));
      expect(8 * 8 - kJamSpreadCap, greaterThanOrEqualTo(16));
    });

    test('đủ lượt dọn obstacleTotal ban đầu (jam + licorice ≥ số ô center)', () {
      final cells = centerCount();
      for (final idx in {...kJamLevels, ...kLicoriceLevels}) {
        expect(kLevels[idx - 1].moves, greaterThanOrEqualTo(cells),
            reason: 'L$idx thiếu lượt so với số ô obstacle');
      }
    });

    test('sim greedy dọn viền jam: đạt total, KHÔNG deadlock, free>0', () {
      // Mô phỏng kế toán _damageObstacles(adjacent) ở mức lưới: greedy luôn tìm
      // được 1 ô jam còn lớp có ô KỀ tự do để clear-kề (pattern center chừa viền).
      const n = 8;
      final jam = List.generate(n, (_) => List<int>.filled(n, 0));
      var total = 0;
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          if (patternHas(JellyPattern.center, r, c, n, n)) {
            jam[r][c] = 1;
            total++;
          }
        }
      }
      bool inb(int r, int c) => r >= 0 && r < n && c >= 0 && c < n;
      var cleared = 0, moves = 0;
      while (cleared < total && moves < 500) {
        moves++;
        var hit = false;
        for (var r = 0; r < n && !hit; r++) {
          for (var c = 0; c < n && !hit; c++) {
            if (jam[r][c] <= 0) continue;
            for (final d in const [
              [-1, 0],
              [1, 0],
              [0, -1],
              [0, 1]
            ]) {
              if (inb(r + d[0], c + d[1]) && jam[r + d[0]][c + d[1]] == 0) {
                jam[r][c]--;
                cleared++;
                hit = true;
                break;
              }
            }
          }
        }
        expect(hit, isTrue, reason: 'deadlock: không còn ô kề tự do để dọn jam');
        var jamCount = 0;
        for (final row in jam) {
          for (final v in row) {
            if (v > 0) jamCount++;
          }
        }
        expect(n * n - jamCount, greaterThan(0));
      }
      expect(cleared, greaterThanOrEqualTo(total));
    });
  });
}
