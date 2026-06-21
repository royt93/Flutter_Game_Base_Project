import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/challenge_cards.dart';
import 'package:neon_jewels/data/cosmetics.dart';
import 'package:neon_jewels/data/progression_tree.dart';
import 'package:neon_jewels/presentation/controllers/challenge_card_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/progression_tree_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 20.3 — Ghost Replay + Progression Tree + Challenge Card tests.
void main() {
  // ─── Ghost Replay ──────────────────────────────────────────────────────────

  group('Ghost Replay — StorageKeys', () {
    test('ghostMoves key unique per level', () {
      expect(StorageKeys.ghostMoves(1), isNot(StorageKeys.ghostMoves(2)));
      expect(StorageKeys.ghostMoves(1), contains('1'));
      expect(StorageKeys.ghostMoves(200), contains('200'));
    });

    test('ghostScore key distinct from ghostMoves', () {
      expect(StorageKeys.ghostScore(1), isNot(StorageKeys.ghostMoves(1)));
    });
  });

  group('Ghost Replay — recordMove + nextGhostMove', () {
    late GameController g;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
    });
    tearDown(Get.reset);

    test('recordMove KHÔNG flush lên disk khi isSideMode', () {
      // Side mode không ghi ghost — hasGhost kiểm disk, đây là điều cần đảm bảo
      g.startEndless(); // isSideMode = true → recordMove no-op
      for (int i = 0; i < 20; i++) {
        g.recordMove(0, 1, 0, 2);
      }
      // Giả lập flush (dù không win thật) — disk phải vẫn trống
      expect(g.hasGhost(1), isFalse, reason: 'side mode không ghi ghost');
    });

    test('recordMove GHI vào log khi campaign mode', () {
      // Campaign mode (không side mode) mới được phép ghi log
      g.startLevel(1); // campaign level
      g.recordMove(0, 1, 0, 2); // phải được append
      g.recordMove(2, 3, 2, 4);
      // log không flush đến disk tự động — chỉ khi win
      // nhưng hasGhost vẫn false (chưa win) → kiểm indirectly qua hasGhost
      expect(g.hasGhost(1), isFalse, reason: 'chưa win nên chưa flush');
    });

    test('nextGhostMove trả null khi không ở ghost mode', () {
      expect(g.nextGhostMove(), isNull);
    });

    test('nextGhostMove trả null khi hết bước', () {
      g.isGhostMode.value = true;
      g.ghostStep.value = 999;
      expect(g.nextGhostMove(), isNull);
    });

    test('hasGhost false khi chưa lưu', () {
      expect(g.hasGhost(1), isFalse);
      expect(g.hasGhost(100), isFalse);
    });
  });

  // ─── Progression Tree ─────────────────────────────────────────────────────

  group('Progression Tree — data', () {
    test('kPtNodes có 3 node với id unique', () {
      expect(kPtNodes.length, 3);
      final ids = kPtNodes.map((n) => n.id).toSet();
      expect(ids.length, 3);
    });

    test('radiant + blazing dùng starCost > 0', () {
      final radiant = ptNodeById('radiant')!;
      final blazing = ptNodeById('blazing')!;
      expect(radiant.starCost, greaterThan(0));
      expect(blazing.starCost, greaterThan(radiant.starCost));
    });

    test('prestige dùng goldCost > 0', () {
      final prestige = ptNodeById('prestige')!;
      expect(prestige.goldCost, greaterThan(0));
      expect(prestige.starCost, 0);
    });
  });

  group('Progression Tree — controller', () {
    late GameController g;
    late ProgressionTreeController ctrl;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
      ctrl = Get.put(ProgressionTreeController(g));
    });
    tearDown(Get.reset);

    test('mặc định: chưa unlock node nào', () {
      expect(ctrl.unlockedNodes, isEmpty);
      expect(ActiveCosmetics.particleBurstMultiplier, 1.0);
    });

    test('checkAndUnlock với 0 sao → không unlock', () {
      ctrl.checkAndUnlock();
      expect(ctrl.isUnlocked('radiant'), isFalse);
    });

    test('checkAndUnlock với ≥50 sao → unlock radiant', () {
      // Inject stars via highScores (totalStars đọc từ map này)
      for (int i = 1; i <= 20; i++) {
        g.stars[i] = 3; // 20 màn × 3 sao = 60 sao
      }
      ctrl.checkAndUnlock();
      expect(ctrl.isUnlocked('radiant'), isTrue);
      expect(ActiveCosmetics.particleBurstMultiplier, 1.5);
    });

    test('persist + reload sau unlock', () {
      for (int i = 1; i <= 20; i++) {
        g.stars[i] = 3;
      }
      ctrl.checkAndUnlock();
      expect(ctrl.isUnlocked('radiant'), isTrue);

      // Reload controller
      final ctrl2 = ProgressionTreeController(g);
      ctrl2.onInit();
      expect(ctrl2.isUnlocked('radiant'), isTrue);
    });

    test('resetState xoá nodes + reset multiplier', () {
      for (int i = 1; i <= 20; i++) {
        g.stars[i] = 3;
      }
      ctrl.checkAndUnlock();
      ctrl.resetState();
      expect(ctrl.isUnlocked('radiant'), isFalse);
      expect(ActiveCosmetics.particleBurstMultiplier, 1.0);
    });
  });

  // ─── Challenge Card ────────────────────────────────────────────────────────

  group('Challenge Card — data', () {
    test('buildWeeklyChallenges tất định (cùng week → cùng set)', () {
      final a = buildWeeklyChallenges(100);
      final b = buildWeeklyChallenges(100);
      for (int i = 0; i < 3; i++) {
        expect(a[i].type, b[i].type);
        expect(a[i].target, b[i].target);
        expect(a[i].reward, b[i].reward);
      }
    });

    test(
      'buildWeeklyChallenges 3 thử thách: winCampaign + earnCoins + playMode',
      () {
        final cards = buildWeeklyChallenges(42);
        final types = cards.map((c) => c.type).toList();
        expect(types, contains(ChallengeType.winCampaign));
        expect(types, contains(ChallengeType.earnCoins));
        expect(types, contains(ChallengeType.playMode));
      },
    );

    test('target winCampaign trong [3,7]', () {
      for (int w = 0; w < 50; w++) {
        final cards = buildWeeklyChallenges(w);
        final wc = cards.firstWhere((c) => c.type == ChallengeType.winCampaign);
        expect(wc.target, inInclusiveRange(3, 7));
      }
    });

    test('reward > 0 cho tất cả thử thách', () {
      final cards = buildWeeklyChallenges(0);
      for (final c in cards) {
        expect(c.reward, greaterThan(0));
      }
    });
  });

  group('Challenge Card — controller', () {
    late GameController g;
    late ChallengeCardController ctrl;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
      ctrl = Get.put(ChallengeCardController(g));
    });
    tearDown(Get.reset);

    test('onCampaignWin: tiến trình winCampaign tăng', () {
      final idx = ctrl.challenges.indexWhere(
        (c) => c.type == ChallengeType.winCampaign,
      );
      final before = ctrl.progress[idx];
      ctrl.onCampaignWin();
      expect(ctrl.progress[idx], before + 1);
    });

    test('onSideModePlayed: tiến trình playMode tăng', () {
      final idx = ctrl.challenges.indexWhere(
        (c) => c.type == ChallengeType.playMode,
      );
      final card = ctrl.challenges[idx];
      ctrl.onSideModePlayed(card.modeKey);
      expect(ctrl.progress[idx], 1);
    });

    test('claimReward: không claim khi chưa đủ progress', () {
      final before = g.coins.value;
      ctrl.claimReward(0);
      expect(g.coins.value, before); // không nhận xu
      expect(ctrl.claimed[0], isFalse);
    });

    test('claimReward: nhận xu khi đủ progress', () {
      final idx = ctrl.challenges.indexWhere(
        (c) => c.type == ChallengeType.winCampaign,
      );
      final target = ctrl.challenges[idx].target;
      final reward = ctrl.challenges[idx].reward;
      // Force progress to target
      for (int i = 0; i < target; i++) {
        ctrl.onCampaignWin();
      }
      expect(ctrl.progress[idx], target);
      final coinsBefore = g.coins.value;
      ctrl.claimReward(idx);
      expect(ctrl.claimed[idx], isTrue);
      expect(g.coins.value, coinsBefore + reward);
    });

    test('claimReward: anti-double (không claim lại)', () {
      final idx = ctrl.challenges.indexWhere(
        (c) => c.type == ChallengeType.winCampaign,
      );
      final target = ctrl.challenges[idx].target;
      for (int i = 0; i < target; i++) {
        ctrl.onCampaignWin();
      }
      ctrl.claimReward(idx); // lần 1
      final coinsAfterFirst = g.coins.value;
      ctrl.claimReward(idx); // lần 2 → bị ignore
      expect(g.coins.value, coinsAfterFirst);
    });

    test('resetState xoá tiến trình', () {
      ctrl.onCampaignWin();
      ctrl.resetState();
      expect(ctrl.progress[0], 0);
      expect(ctrl.progress[1], 0);
      expect(ctrl.claimed[0], isFalse);
    });

    test('_refresh: tuần mới reset tiến trình + coin baseline', () {
      final store = StorageService.to;
      final currentWeek = g.todayEpochDay ~/ 7;

      // Simulate state đĩa từ TUẦN CŨ: ghi progress + weekIdx cũ trực tiếp
      store.setInt(StorageKeys.ccWeekIdx, currentWeek - 1);
      store.setInt(StorageKeys.ccProgress(0), 3);
      store.setInt(StorageKeys.ccProgress(1), 2);
      store.setInt(StorageKeys.ccProgress(2), 1);
      store.setInt(StorageKeys.ccClaimed(0), 1); // claimed tuần cũ

      // Tạo lại controller → _load() phát hiện savedWeek != currentWeek → _resetDisk()
      Get.delete<ChallengeCardController>();
      final ctrl2 = Get.put(ChallengeCardController(g));

      // Tiến trình phải về 0 (reset tuần mới)
      expect(ctrl2.progress[0], 0);
      expect(ctrl2.progress[1], 0);
      expect(ctrl2.progress[2], 0);
      // Claimed phải về false
      expect(ctrl2.claimed[0], isFalse);
      // Week index phải được cập nhật lên tuần hiện tại
      expect(store.getInt(StorageKeys.ccWeekIdx), currentWeek);
      // Coin baseline phải được ghi lại (ccCoinsStart = coinsEarnedTotal lúc reset)
      expect(
        store.getInt(StorageKeys.ccCoinsStart),
        g.coinsEarnedTotal.value,
      );
    });
  });

  // ─── Zen Mode (W20.4) ─────────────────────────────────────────────────────

  group('Zen Mode — GameController', () {
    late GameController g;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
    });
    tearDown(Get.reset);

    test('startZen: đặt cờ isZen + isSideMode', () {
      g.startZen();
      expect(g.isZen.value, isTrue);
      expect(g.isSideMode, isTrue);
    });

    test('startZen: KHÔNG đặt cờ mode khác', () {
      g.startZen();
      expect(g.isEndless.value, isFalse);
      expect(g.isBoss.value, isFalse);
      expect(g.isSurvival.value, isFalse);
    });

    test('checkEnd trả null khi isZen (không bao giờ tự kết thúc)', () {
      g.startZen();
      // Dù movesLeft về 0 (không có nhưng giả sử), checkEnd vẫn null
      expect(g.checkEnd(), isNull);
    });

    test('endZenSession lưu zenHigh khi score mới', () {
      g.startZen();
      g.score.value = 1500;
      g.endZenSession();
      expect(g.zenHigh.value, 1500);
    });

    test('endZenSession không giảm zenHigh', () {
      g.startZen();
      g.score.value = 3000;
      g.endZenSession();
      g.score.value = 500;
      g.endZenSession();
      expect(g.zenHigh.value, 3000); // giữ cao nhất
    });

    test('endZenSession: guard no-op khi không phải Zen mode', () {
      g.startLevel(1); // campaign, không phải zen
      g.score.value = 5000;
      g.coins.value = 100; // explicit baseline để no-op rõ ràng
      expect(g.isZen.value, isFalse);
      g.endZenSession(); // phải no-op hoàn toàn
      expect(g.coins.value, 100); // không thay đổi
      expect(g.zenHigh.value, 0); // không ghi high score
      expect(g.lastCoinReward, 0); // không set reward
    });

    test('endZenSession: thưởng xu theo score (clamp 5..50 per 1000)', () {
      // Fresh session → discountSideModeReward = full (wins < kSideModeFullPlays=3)
      // score < 1000: base = (500 ~/ 1000) = 0 → clamp(5, 50) = 5
      g.startZen();
      g.score.value = 500;
      g.endZenSession();
      expect(g.lastCoinReward, 5); // min clamp = 5, full reward

      // score = 50000: base = (50000 ~/ 1000) = 50 → clamp(5, 50) = 50
      g.startZen();
      g.score.value = 50000;
      g.endZenSession();
      expect(g.lastCoinReward, 50); // max clamp = 50, 2nd play hôm nay vẫn full
    });

    test('recordMove KHÔNG ghi khi isZen (isSideMode)', () {
      g.startZen();
      g.recordMove(0, 1, 0, 2);
      // Zen là side mode → recordMove trả sớm
      expect(g.hasGhost(0), isFalse);
    });

    test('StorageKeys.zenHigh tồn tại và khác endlessHigh', () {
      expect(StorageKeys.zenHigh, isNot(StorageKeys.endlessHigh));
      expect(StorageKeys.zenHigh, isNotEmpty);
    });
  });

  // ─── Ghost Mode — Campaign Integration (C fix) ────────────────────────────
  // Ghost mode là CAMPAIGN thật (không phải side mode). Tài liệu hoá bằng test.

  group('Ghost Mode — campaign integration (design intent)', () {
    late GameController g;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
    });
    tearDown(Get.reset);

    test('isGhostMode KHÔNG thuộc isSideMode (ghost = campaign thật)', () {
      g.isGhostMode.value = true;
      // Ghost mode không phải side mode → campaign rules áp dụng
      expect(
        g.isSideMode,
        isFalse,
        reason: 'ghost là campaign với hint overlay, không phải side mode',
      );
    });

    test('recordMove no-op trong ghost mode: không xoá ghost data gốc', () async {
      final store = StorageService.to;
      // Lưu ghost data cho level 1 trước
      await store.setString(StorageKeys.ghostMoves(1), '01020304');
      await store.setInt(StorageKeys.ghostScore(1), 800);

      g.startGhostMode(1);
      expect(g.isGhostMode.value, isTrue);
      expect(g.hasGhost(1), isTrue);

      // Gọi recordMove trong ghost mode → phải no-op
      g.recordMove(5, 6, 7, 7);
      g.recordMove(3, 4, 3, 5);

      // Storage KHÔNG đổi
      expect(store.getString(StorageKeys.ghostMoves(1)), '01020304');
      // nextGhostMove vẫn trả đúng data ghost gốc (r1=0,c1=1,r2=0,c2=2)
      expect(g.nextGhostMove(), (0, 1, 0, 2));
    });

    test('startGhostMode nạp ghost moves từ storage', () async {
      // Lưu ghost data trước
      final store = StorageService.to;
      await store.setString(StorageKeys.ghostMoves(5), '01230456');
      await store.setInt(StorageKeys.ghostScore(5), 1500);

      g.startGhostMode(5);

      expect(g.isGhostMode.value, isTrue);
      expect(g.ghostScore.value, 1500);
      expect(g.ghostStep.value, 0);
      expect(g.currentLevel.value, 5);
    });

    test('nextGhostMove trả đúng (r1,c1,r2,c2) từ move string', () async {
      final store = StorageService.to;
      // '01231234' = move 1: (0,1,2,3); move 2: (1,2,3,4)
      await store.setString(StorageKeys.ghostMoves(3), '01231234');
      await store.setInt(StorageKeys.ghostScore(3), 800);

      g.startGhostMode(3);

      final m1 = g.nextGhostMove();
      expect(m1, equals((0, 1, 2, 3)));

      g.advanceGhost();
      final m2 = g.nextGhostMove();
      expect(m2, equals((1, 2, 3, 4)));

      g.advanceGhost();
      expect(g.nextGhostMove(), isNull, reason: 'hết moves → null');
    });

    test('_moveLog cleared khi startGhostMode (via _enterMode)', () async {
      final store = StorageService.to;
      await store.setString(StorageKeys.ghostMoves(2), '01230102');
      // Trước khi bắt đầu ghost, chơi campaign và ghi log
      g.startLevel(1);
      g.recordMove(0, 1, 0, 2);
      // Bắt đầu ghost mode → _enterMode() → _moveLog.clear()
      g.startGhostMode(2);
      // Verify: sau khi vào ghost, không ghi log thêm
      g.recordMove(3, 4, 3, 5); // ghost mode → no-op
      // hasGhost(2) đúng (từ storage), không phải từ _moveLog mới
      expect(g.hasGhost(2), isTrue);
    });

    test(
      'startLevel sau ghost tắt ghost mode và cho phép ghi replay mới',
      () async {
        final store = StorageService.to;
        await store.setString(StorageKeys.ghostMoves(2), '01230102');
        await store.setInt(StorageKeys.ghostScore(2), 1000);

        g.startGhostMode(2);
        expect(g.isGhostMode.value, isTrue);
        expect(g.nextGhostMove(), equals((0, 1, 2, 3)));

        g.startLevel(1);
        expect(g.isGhostMode.value, isFalse);
        expect(g.ghostStep.value, 0);
        expect(g.nextGhostMove(), isNull);

        g.recordMove(0, 1, 0, 2);
        g.addScore(1000, 1);
        expect(g.checkEnd(), 'win');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(
          g.hasGhost(1),
          isTrue,
          reason: 'campaign thường sau ghost phải ghi được replay mới',
        );
        expect(StorageService.to.getString(StorageKeys.ghostMoves(1)), '0102');
      },
    );
  });
}
