import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/season.dart';
import 'package:neon_jewels/data/tournament.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/season_league_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// W18.1 — Mùa giải (gộp Mùa + Giải đấu): 1 điểm/thắng nuôi 2 trục (mốc + hạng).
/// Test: 1 addWin → 1 pool (không double), 2 trục claim độc lập, migration
/// an toàn (max, anti-exploit), reset, badge tổng hợp.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;
  late SeasonLeagueController lc;

  Future<void> boot({Map<String, Object>? seed, DateTime? now}) async {
    SharedPreferences.setMockInitialValues(seed ?? {});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
    g.clock = () => now ?? DateTime(2026, 6, 18);
    lc = Get.put(SeasonLeagueController(g));
  }

  setUp(() => boot());
  tearDown(Get.reset);

  group('1 điểm/thắng nuôi 2 trục (không double-count)', () {
    test('addWin cộng 1 pool, dùng công thức Season', () {
      lc.addWin(3);
      expect(lc.points.value, seasonPointsForWin(3)); // 10+24=34
      expect(StorageService.to.getInt(StorageKeys.seasonPoints), 34);
    });

    test('cùng pool quyết định CẢ mốc lẫn hạng', () {
      // dồn điểm đủ mốc 0 (50)
      while (lc.points.value < kSeasonMilestones[0].points) {
        lc.addWin(3);
      }
      // pool vừa mở mốc 0...
      expect(lc.canClaimMilestone(0), isTrue);
      // ...vừa là điểm so hạng (playerRank phản ánh cùng pool)
      expect(lc.playerRank, inInclusiveRange(1, kTournamentBots.length + 1));
    });
  });

  group('2 trục claim ĐỘC LẬP', () {
    test('claim mốc KHÔNG ảnh hưởng claim hạng', () {
      while (lc.points.value < kSeasonMilestones[0].points) {
        lc.addWin(3);
      }
      final coins0 = g.coins.value;
      expect(lc.claimMilestone(0), isTrue);
      expect(g.coins.value, coins0 + kSeasonMilestones[0].amount);
      // hạng vẫn claim được riêng
      expect(lc.canClaimRank, isTrue);
      final coins1 = g.coins.value;
      final r = lc.claimRank();
      expect(r, isNotNull);
      expect(g.coins.value, greaterThan(coins1));
    });

    test('claim hạng 1 lần/tuần', () {
      lc.addWin(3);
      expect(lc.claimRank(), isNotNull);
      expect(lc.canClaimRank, isFalse);
      expect(lc.claimRank(), isNull);
    });

    test('mốc claim 1 lần', () {
      while (lc.points.value < kSeasonMilestones[0].points) {
        lc.addWin(3);
      }
      expect(lc.claimMilestone(0), isTrue);
      expect(lc.claimMilestone(0), isFalse);
    });

    test('chưa điểm → không claim hạng', () {
      expect(lc.points.value, 0);
      expect(lc.canClaimRank, isFalse);
      expect(lc.claimRank(), isNull);
    });
  });

  group('hasClaimable tổng hợp (badge Home)', () {
    test('false khi chưa có gì', () {
      expect(lc.hasClaimable, isFalse);
    });
    test('true khi có điểm (hạng claim được)', () {
      lc.addWin(3);
      expect(lc.hasClaimable, isTrue);
    });
    test('true khi mốc claim được', () {
      while (lc.points.value < kSeasonMilestones[0].points) {
        lc.addWin(3);
      }
      lc.claimRank(); // tắt trục hạng
      expect(lc.hasClaimable, isTrue, reason: 'vẫn còn mốc 0 chưa nhận');
    });
  });

  group('Migration an toàn (gộp dữ liệu cũ)', () {
    test('pool = max(điểm mùa, điểm giải) của ĐÚNG kỳ', () async {
      // Giả lập dữ liệu cũ cùng kỳ hiện tại (idx của 2026-06-18).
      final idx = seasonIndex(
          DateTime(2026, 6, 18).millisecondsSinceEpoch ~/ 86400000);
      await boot(seed: {
        StorageKeys.seasonIdx: idx,
        StorageKeys.seasonPoints: 120,
        StorageKeys.tournamentWeek: idx,
        StorageKeys.tournamentPoints: 200, // giải cao hơn
      });
      expect(lc.points.value, 200, reason: 'lấy max(120, 200)');
      expect(StorageService.to.getInt(StorageKeys.leagueMigrated), 1);
    });

    test('migrate chỉ chạy 1 lần (cờ leagueMigrated)', () async {
      final idx = seasonIndex(
          DateTime(2026, 6, 18).millisecondsSinceEpoch ~/ 86400000);
      await boot(seed: {
        StorageKeys.leagueMigrated: 1, // đã migrate
        StorageKeys.seasonIdx: idx,
        StorageKeys.seasonPoints: 120,
        StorageKeys.tournamentWeek: idx,
        StorageKeys.tournamentPoints: 200,
      });
      expect(lc.points.value, 120, reason: 'đã migrate → giữ seasonPoints, bỏ qua max');
    });

    test('KHÔNG kéo điểm kỳ CŨ (chỉ lấy điểm thuộc kỳ hiện tại)', () async {
      final idx = seasonIndex(
          DateTime(2026, 6, 18).millisecondsSinceEpoch ~/ 86400000);
      await boot(seed: {
        StorageKeys.seasonIdx: idx - 5, // mùa cũ
        StorageKeys.seasonPoints: 999,
        StorageKeys.tournamentWeek: idx - 5,
        StorageKeys.tournamentPoints: 999,
      });
      expect(lc.points.value, 0, reason: 'điểm kỳ cũ không sống lại');
    });

    test('anti-exploit: cờ đã-nhận mốc cũ được tôn trọng', () async {
      final idx = seasonIndex(
          DateTime(2026, 6, 18).millisecondsSinceEpoch ~/ 86400000);
      await boot(seed: {
        StorageKeys.seasonIdx: idx,
        StorageKeys.seasonPoints: 999, // đủ mọi mốc
        StorageKeys.seasonClaimed(idx, 0): 1, // ĐÃ nhận mốc 0
        StorageKeys.tournamentClaimedWeek: idx, // ĐÃ nhận hạng tuần này
      });
      expect(lc.isClaimed(0), isTrue);
      expect(lc.canClaimMilestone(0), isFalse, reason: 'không nhận lại mốc 0');
      expect(lc.canClaimRank, isFalse, reason: 'không nhận lại hạng tuần này');
    });
  });

  group('Đổi kỳ + reset', () {
    test('sang tuần mới → pool reset', () async {
      lc.addWin(3);
      expect(lc.points.value, greaterThan(0));
      await boot(now: DateTime(2026, 6, 18).add(const Duration(days: 7)));
      expect(lc.points.value, 0);
      expect(lc.claimedRankThisWeek.value, isFalse);
    });

    test('resetState xoá pool + cờ 2 trục', () {
      lc.addWin(3);
      lc.resetState();
      expect(lc.points.value, 0);
      expect(lc.claimedMilestones, isEmpty);
      expect(lc.claimedRankThisWeek.value, isFalse);
    });
  });

  group('Hạng vs bot (giữ logic Tournament)', () {
    test('botScoreNow dùng điểm cuối tuần (cố định)', () {
      for (var i = 0; i < kTournamentBots.length; i++) {
        expect(lc.botScoreNow(i), botScore(lc.idx, i, kTournamentDays - 1));
      }
    });
    test('điểm cao → hạng tốt hơn', () {
      lc.points.value = 0;
      final lowRank = lc.playerRank;
      lc.points.value = 1 << 20; // điểm khổng lồ
      expect(lc.playerRank, lessThanOrEqualTo(lowRank));
      expect(lc.playerRank, 1, reason: 'điểm vô địch → hạng 1');
    });
  });

  group('Tích lũy điểm qua nhiều ván', () {
    test('addWin nhiều lần → tổng đúng (không mất điểm)', () {
      lc.addWin(3); // 3 sao
      final p1 = lc.points.value;
      lc.addWin(1); // 1 sao
      final p2 = lc.points.value;
      lc.addWin(2); // 2 sao
      final p3 = lc.points.value;

      expect(p2, greaterThan(p1), reason: 'thêm ván 2 → điểm tăng');
      expect(p3, greaterThan(p2), reason: 'thêm ván 3 → điểm tăng');
      // Tổng phải bằng đúng tổng điểm từng ván
      final expected = seasonPointsForWin(3) + seasonPointsForWin(1) + seasonPointsForWin(2);
      expect(p3, expected);
    });
  });
}
