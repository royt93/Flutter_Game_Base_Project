import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/achievements.dart';
import 'package:neon_jewels/data/challenge_cards.dart';
import 'package:neon_jewels/data/side_mode_records.dart';
import 'package:neon_jewels/presentation/controllers/achievement_controller.dart';
import 'package:neon_jewels/presentation/controllers/battle_pass_controller.dart';
import 'package:neon_jewels/presentation/controllers/challenge_card_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/progression_tree_controller.dart';
import 'package:neon_jewels/presentation/controllers/side_mode_record_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 25.3 — meta gắn side-mode: mốc Platinum + trục điểm side-mode/tuần +
/// quest kỹ năng reachRecordTier + liên kết Progression Tree/Battle Pass.
/// KHÔNG đụng win-streak/unlock campaign/lives ([[side-mode-isolation]]).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('W25.3 — Platinum tier', () {
    test(
      '30 lần thắng Gravity (winCount) → tierOf = platinum, thưởng cộng dồn đủ 4 mốc',
      () {
        final rec = Get.put(SideModeRecordController(g));
        g.startGravity();
        for (var i = 0; i < 30; i++) {
          rec.recordResult(won: true);
        }
        expect(rec.tierOf(SideModeKind.gravity), RecordTier.platinum);
        expect(g.coins.value, greaterThanOrEqualTo(30 + 60 + 120 + 220));
      },
    );

    test('platinumMilestonesCount đếm đúng số mode đạt Platinum', () {
      final rec = Get.put(SideModeRecordController(g));
      expect(g.platinumMilestonesCount, 0);
      rec.claimedTier[SideModeKind.gravity] = RecordTier.platinum.index;
      rec.claimedTier[SideModeKind.soda] = RecordTier.gold.index; // chưa đủ
      expect(g.platinumMilestonesCount, 1);
    });

    test('achievement platinum_1 mở khoá khi đạt 1 mode Platinum', () {
      final rec = Get.put(SideModeRecordController(g));
      final ac = Get.put(AchievementController(g));
      rec.claimedTier[SideModeKind.gravity] = RecordTier.platinum.index;
      final a = kAchievements.firstWhere((x) => x.id == 'platinum_1');
      expect(ac.isUnlocked(a), isTrue);
    });
  });

  group('W25.3 — điểm side-mode/tuần', () {
    test('thắng side-mode +điểm; thua không cộng', () {
      final cc = Get.put(ChallengeCardController(g));
      cc.addSideModePoints(won: true);
      expect(cc.sideWeeklyPoints.value, kSideWeeklyPointsPerWin);
      cc.addSideModePoints(won: false);
      expect(cc.sideWeeklyPoints.value, kSideWeeklyPointsPerWin); // không đổi
    });

    test('vừa mở mốc kỷ lục mới → cộng thêm bonus điểm', () {
      final cc = Get.put(ChallengeCardController(g));
      cc.addSideModePoints(won: true, reachedNewMilestone: true);
      expect(
        cc.sideWeeklyPoints.value,
        kSideWeeklyPointsPerWin + kSideWeeklyPointsPerMilestoneUnlock,
      );
    });

    test('đủ điểm mốc 1 → claim 1 lần, lần 2 trả 0 (anti-double)', () {
      final cc = Get.put(ChallengeCardController(g));
      final bp = Get.put(BattlePassController(g));
      final bpXpBefore = bp.xp.value;
      while (cc.sideWeeklyPoints.value < kSideWeeklyGoals[0]) {
        cc.addSideModePoints(won: true);
      }
      expect(cc.sideMilestoneClaimable, isTrue);
      final coinsBefore = g.coins.value;
      final r = cc.claimSideMilestone();
      expect(r, kSideWeeklyRewards[0]);
      expect(g.coins.value, coinsBefore + kSideWeeklyRewards[0]);
      expect(cc.sideMilestoneClaimed.value, 1);
      expect(bp.xp.value, bpXpBefore + kSideMilestoneBpBonusXp);

      final coins2 = g.coins.value;
      expect(cc.claimSideMilestone(), 0); // mốc 1 đã nhận, chưa đủ điểm mốc 2
      expect(g.coins.value, coins2);
    });

    test('tuần cũ trong storage → điểm/mốc reset về 0', () {
      final store = StorageService.to;
      final currentWeek = g.todayEpochDay ~/ 7;
      store.setInt(StorageKeys.ccWeekIdx, currentWeek - 1);
      store.setInt(StorageKeys.ccSideWeekPoints, 999);
      store.setInt(StorageKeys.ccSideMilestone, 2);
      final cc2 = ChallengeCardController(g)..onInit();
      expect(cc2.sideWeeklyPoints.value, 0);
      expect(cc2.sideMilestoneClaimed.value, 0);
    });
  });

  group('W25.3 — quest kỹ năng reachRecordTier', () {
    test(
      'tuần chẵn = playMode (không đổi hành vi cũ), tuần lẻ = reachRecordTier',
      () {
        final evenCards = buildWeeklyChallenges(10);
        final oddCards = buildWeeklyChallenges(11);
        expect(evenCards[2].type, ChallengeType.playMode);
        expect(oddCards[2].type, ChallengeType.reachRecordTier);
        expect(oddCards[2].recordKind, isNotNull);
        expect(oddCards[2].recordTier, RecordTier.bronze);
      },
    );

    test(
      'đạt tier từ trước (lifetime) → quest tự "done" khi mở lại (không cần chơi lại)',
      () {
        // Ép ngày để weekIdx lẻ (bắt buộc slot reachRecordTier xuất hiện).
        var day = DateTime(2026, 7, 6);
        g.clock = () => day;
        var weekIdx = g.todayEpochDay ~/ 7;
        if (weekIdx.isEven) {
          day = day.add(const Duration(days: 7));
          g.clock = () => day;
          weekIdx = g.todayEpochDay ~/ 7;
        }
        expect(weekIdx.isOdd, isTrue);

        final rec = Get.put(SideModeRecordController(g));
        final card = buildWeeklyChallenges(weekIdx)[2];
        expect(card.type, ChallengeType.reachRecordTier);
        rec.claimedTier[card.recordKind!] =
            card.recordTier!.index; // đã đủ trình từ trước

        final cc = Get.put(ChallengeCardController(g)); // _load() tự sync
        expect(cc.challenges[2].type, ChallengeType.reachRecordTier);
        expect(cc.progress[2], 1); // tự "done" ngay, không cần chơi lại
      },
    );
  });

  group('W25.3 — liên kết Progression Tree', () {
    test(
      '3 mode Platinum → node ascendant mở khoá, particle multiplier cao nhất',
      () {
        final rec = Get.put(SideModeRecordController(g));
        final pt = Get.put(ProgressionTreeController(g));
        expect(pt.platinumMilestonesCount(), 0);
        for (final k in [
          SideModeKind.gravity,
          SideModeKind.soda,
          SideModeKind.rhythm,
        ]) {
          rec.claimedTier[k] = RecordTier.platinum.index;
        }
        expect(pt.platinumMilestonesCount(), 3);
        pt.checkAndUnlock();
        expect(pt.unlockedNodes.contains('ascendant'), isTrue);
      },
    );
  });

  group('W25.3 — resetProgress dọn sạch', () {
    test('resetProgress xoá điểm side-mode/tuần + mốc claimed', () async {
      final cc = Get.put(ChallengeCardController(g));
      cc.addSideModePoints(won: true, reachedNewMilestone: true);
      while (cc.sideMilestoneClaimable) {
        cc.claimSideMilestone();
      }
      expect(cc.sideWeeklyPoints.value, greaterThan(0));

      await g.resetProgress();
      expect(cc.sideWeeklyPoints.value, 0);
      expect(cc.sideMilestoneClaimed.value, 0);
    });
  });
}
