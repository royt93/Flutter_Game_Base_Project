import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/season.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/season_league_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;
  late SeasonLeagueController sc;

  Future<void> boot({DateTime? now}) async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
    g.clock = () => now ?? DateTime(2026, 6, 14);
    sc = Get.put(SeasonLeagueController(g));
  }

  setUp(() => boot());
  tearDown(Get.reset);

  group('Season index', () {
    test('seasonIndex tăng mỗi 7 ngày', () {
      expect(seasonIndex(0), 0);
      expect(seasonIndex(6), 0);
      expect(seasonIndex(7), 1);
      expect(seasonIndex(13), 1);
      expect(seasonIndex(14), 2);
    });

    test('seasonName + accent xoay vòng theo idx', () {
      expect(seasonWorldAccent(0), 1);
      expect(seasonWorldAccent(5), 1);
      expect(seasonNameKey(0), 'season_cyan');
    });
  });

  group('Tích điểm + claim', () {
    test('addWin cộng điểm theo sao + persist', () {
      sc.addWin(2); // 10 + 2*8 = 26
      expect(sc.points.value, 26);
      sc.addWin(0); // +10
      expect(sc.points.value, 36);
      expect(StorageService.to.getInt(StorageKeys.seasonPoints), 36);
    });

    test('claim mốc khi đủ điểm, 1 lần, persist tuyệt đối theo mùa', () {
      final first = kSeasonMilestones[0];
      // dồn đủ điểm
      while (sc.points.value < first.points) {
        sc.addWin(3);
      }
      expect(sc.canClaimMilestone(0), isTrue);
      final coins0 = g.coins.value;
      expect(sc.claimMilestone(0), isTrue);
      expect(sc.isClaimed(0), isTrue);
      expect(sc.claimMilestone(0), isFalse);
      expect(g.coins.value, coins0 + first.amount);
      expect(
          StorageService.to.getInt(StorageKeys.seasonClaimed(sc.idx, 0)), 1);
    });

    test('chưa đủ điểm → không claim', () {
      expect(sc.points.value, 0);
      expect(sc.canClaimMilestone(0), isFalse);
      expect(sc.claimMilestone(0), isFalse);
    });
  });

  group('Sang mùa mới', () {
    test('đổi mùa reset điểm; cờ nhận của mùa cũ vẫn giữ (chống chỉnh giờ lùi)',
        () async {
      sc.addWin(3);
      expect(sc.points.value, greaterThan(0));
      final oldIdx = sc.idx;

      // sang tuần sau → mùa mới
      await boot(now: DateTime(2026, 6, 14).add(const Duration(days: 7)));
      expect(sc.idx, oldIdx + 1);
      expect(sc.points.value, 0); // điểm reset

      // quay LẠI mùa cũ: cờ nhận mốc cũ (nếu có) phải còn — ở đây chưa claim
      // nên chỉ kiểm tra điểm mùa cũ không "sống lại"
      await boot(now: DateTime(2026, 6, 14));
      expect(sc.idx, oldIdx);
      expect(sc.points.value, 0); // mùa cũ đã bị reset khi storedIdx đổi
    });
  });

  group('Đếm ngược', () {
    test('timeToEnd > 0 và <= 7 ngày', () {
      expect(sc.timeToEnd.inSeconds, greaterThan(0));
      expect(sc.timeToEnd.inDays, lessThanOrEqualTo(kSeasonDays));
    });
  });
}
