import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/collection.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/data/wheel.dart';
import 'package:neon_jewels/presentation/controllers/collection_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/lucky_wheel_controller.dart';
import 'package:neon_jewels/presentation/controllers/piggy_controller.dart';
import 'package:neon_jewels/presentation/controllers/progression_tree_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RNG giả — [nextInt] luôn trả `fixed % max` để test tất định (không phụ
/// thuộc thống kê). Đủ để verify pity xác định (không phải soft-bias).
class _FixedRandom implements Random {
  final int fixed;
  const _FixedRandom(this.fixed);
  @override
  int nextInt(int max) => fixed % max;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

/// Wave 28.3 — Dead-feature rescue: Piggy full-bonus, Collection milestone,
/// Progression Tree ascendant free-move, Lucky Wheel pity + resetProgress.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  Future<void> setup() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
  }

  // ─── Piggy Bank ────────────────────────────────────────────────────────────

  group('Piggy — bonus 10% khi đầy ống', () {
    late PiggyController ctrl;

    setUp(() async {
      await setup();
      ctrl = Get.put(PiggyController(g));
    });
    tearDown(Get.reset);

    test('đập khi CHƯA đầy → không bonus, nhận đúng số cũ', () {
      ctrl.saved.value = 200; // >= kPiggyMin, < kPiggyCap
      final coinsBefore = g.coins.value;
      final amount = ctrl.smash();
      expect(amount, 200);
      expect(g.coins.value, coinsBefore + 200);
    });

    test('đập khi ĐẦY (600) → nhận 660 (600 + 10%)', () {
      ctrl.saved.value = PiggyController.kPiggyCap;
      final coinsBefore = g.coins.value;
      final amount = ctrl.smash();
      expect(amount, 660);
      expect(g.coins.value, coinsBefore + 660);
    });

    test('đập xong → ống rỗng, disk cũng xoá', () {
      ctrl.saved.value = PiggyController.kPiggyCap;
      ctrl.smash();
      expect(ctrl.saved.value, 0);
      expect(StorageService.to.getInt(StorageKeys.piggySaved, def: -1), 0);
    });
  });

  // ─── Collection ────────────────────────────────────────────────────────────

  group('Collection — mốc thưởng giữa chừng 25/50/75%', () {
    late CollectionController ctrl;

    setUp(() async {
      await setup();
      ctrl = Get.put(CollectionController(g));
    });
    tearDown(Get.reset);

    void unlockN(int n) {
      ctrl.claimed.addAll(kCollectionItems.take(n).map((it) => it.id));
    }

    test('chưa đủ sticker → canClaimMilestone false', () {
      unlockN(2);
      expect(ctrl.canClaimMilestone(0), isFalse); // cần 3
    });

    for (var tier = 0; tier < 3; tier++) {
      test('đạt mốc tier $tier → claim đúng xu, không claim đôi', () {
        unlockN(CollectionController.kCollectionMilestoneCounts[tier]);
        expect(ctrl.canClaimMilestone(tier), isTrue);

        final coinsBefore = g.coins.value;
        final ok = ctrl.claimMilestone(tier);
        expect(ok, isTrue);
        expect(
          g.coins.value,
          coinsBefore + CollectionController.kCollectionMilestoneCoins[tier],
        );
        expect(
          StorageService.to.getInt(
            StorageKeys.collectionMilestoneClaimed(tier),
          ),
          1,
        );

        // Claim lại lần 2 → false, không cộng xu đôi.
        final coinsAfterFirst = g.coins.value;
        final ok2 = ctrl.claimMilestone(tier);
        expect(ok2, isFalse);
        expect(g.coins.value, coinsAfterFirst);
      });
    }

    test('milestonesClaimed persist qua reload', () {
      unlockN(3);
      ctrl.claimMilestone(0);
      final ctrl2 = CollectionController(g);
      ctrl2.onInit();
      expect(ctrl2.milestonesClaimed, contains(0));
    });
  });

  // ─── Progression Tree — ascendant ──────────────────────────────────────────

  group('Progression Tree — ascendant +1 lượt miễn phí/ngày', () {
    late ProgressionTreeController ptCtrl;

    setUp(() async {
      await setup();
      ptCtrl = Get.put(ProgressionTreeController(g));
    });
    tearDown(Get.reset);

    test('chưa unlock ascendant → không cộng lượt', () {
      g.clock = () => DateTime(2026, 1, 1);
      g.startLevel(1);
      expect(g.movesLeft.value, kLevels[0].moves);
    });

    test('unlock ascendant, chưa dùng hôm nay → +1 lượt', () {
      ptCtrl.unlockedNodes.add('ascendant');
      g.clock = () => DateTime(2026, 1, 1);
      g.startLevel(1);
      expect(g.movesLeft.value, kLevels[0].moves + 1);
    });

    test('cùng ngày chơi lại → không cộng thêm lần 2', () {
      ptCtrl.unlockedNodes.add('ascendant');
      g.clock = () => DateTime(2026, 1, 1);
      g.startLevel(1);
      expect(g.movesLeft.value, kLevels[0].moves + 1);

      g.startLevel(2);
      expect(g.movesLeft.value, kLevels[1].moves); // đã dùng hôm nay
    });

    test('sang ngày khác → cộng lại được', () {
      ptCtrl.unlockedNodes.add('ascendant');
      g.clock = () => DateTime(2026, 1, 1);
      g.startLevel(1);

      g.clock = () => DateTime(2026, 1, 2);
      g.startLevel(1);
      expect(g.movesLeft.value, kLevels[0].moves + 1);
    });
  });

  // ─── Lucky Wheel — pity ẩn ──────────────────────────────────────────────────

  group('Lucky Wheel — pity: 3 lần liên tiếp ra xu → lần kế đảm bảo booster', () {
    late LuckyWheelController wheelCtrl;

    setUp(() async {
      await setup();
      wheelCtrl = Get.put(LuckyWheelController(g));
    });
    tearDown(Get.reset);

    test(
      'rng luôn trả ô xu (index 0) → 3 lần đầu vẫn ra xu, lần 4 ép booster',
      () {
        wheelCtrl.rng = const _FixedRandom(
          0,
        ); // index 0 = kWheel[0] = coins(30)
        for (var d = 1; d <= 3; d++) {
          g.clock = () => DateTime(2026, 1, d);
          final idx = wheelCtrl.spin();
          expect(kWheel[idx].isCoins, isTrue);
          wheelCtrl
              .finishSpin(); // tắt cờ spinning để lần quay kế không bị chặn
        }
        expect(
          wheelCtrl.coinStreak.value,
          LuckyWheelController.kWheelPityStreak,
        );

        // Lần 4: rng vẫn "muốn" trả index 0 (coins) nhưng pity phải ép booster.
        g.clock = () => DateTime(2026, 1, 4);
        final idx4 = wheelCtrl.spin();
        expect(kWheel[idx4].isCoins, isFalse);
        expect(wheelCtrl.coinStreak.value, 0); // reset sau khi ra booster
      },
    );

    test('coinStreak persist qua ngày (không reset tự động theo ngày)', () {
      wheelCtrl.rng = const _FixedRandom(0);
      g.clock = () => DateTime(2026, 2, 1);
      wheelCtrl.spin();
      expect(wheelCtrl.coinStreak.value, 1);

      final wheelCtrl2 = LuckyWheelController(g);
      wheelCtrl2.onInit();
      expect(wheelCtrl2.coinStreak.value, 1);
    });

    test('canSpin: chỉ 1 lần/ngày', () {
      wheelCtrl.rng = const _FixedRandom(0);
      g.clock = () => DateTime(2026, 3, 1);
      expect(wheelCtrl.canSpin, isTrue);
      wheelCtrl.spin();
      expect(wheelCtrl.canSpin, isFalse);
    });
  });

  // ─── resetProgress — clear cả 4 hệ (RAM + disk) ─────────────────────────────

  group('resetProgress — xoá sạch cả 4 hệ dead-feature-rescue', () {
    late PiggyController piggyCtrl;
    late CollectionController collCtrl;
    late ProgressionTreeController ptCtrl;
    late LuckyWheelController wheelCtrl;

    setUp(() async {
      await setup();
      piggyCtrl = Get.put(PiggyController(g));
      collCtrl = Get.put(CollectionController(g));
      ptCtrl = Get.put(ProgressionTreeController(g));
      wheelCtrl = Get.put(LuckyWheelController(g));
    });
    tearDown(Get.reset);

    test(
      'piggy saved + collection milestone + pt free-move-day + wheel streak đều về 0/rỗng',
      () async {
        // Piggy: có xu trong ống.
        piggyCtrl.saved.value = 300;
        await StorageService.to.setInt(StorageKeys.piggySaved, 300);

        // Collection: đủ 3 sticker + đã nhận mốc tier 0.
        collCtrl.claimed.addAll(kCollectionItems.take(3).map((it) => it.id));
        collCtrl.claimMilestone(0);

        // Progression Tree: ascendant unlock + đã dùng lượt miễn phí hôm nay.
        ptCtrl.unlockedNodes.add('ascendant');
        g.clock = () => DateTime(2026, 4, 1);
        g.startLevel(1);
        expect(
          StorageService.to.getInt(StorageKeys.ptAscendantFreeMoveDay, def: -1),
          isNot(-1),
        );

        // Lucky Wheel: streak > 0.
        wheelCtrl.rng = const _FixedRandom(0);
        wheelCtrl.spin();
        expect(wheelCtrl.coinStreak.value, greaterThan(0));

        await g.resetProgress();

        // RAM
        expect(piggyCtrl.saved.value, 0);
        expect(collCtrl.claimed, isEmpty);
        expect(collCtrl.milestonesClaimed, isEmpty);
        expect(ptCtrl.unlockedNodes, isEmpty);
        expect(wheelCtrl.coinStreak.value, 0);

        // Disk
        final store = StorageService.to;
        expect(store.getInt(StorageKeys.piggySaved), 0);
        expect(store.getInt(StorageKeys.collectionMilestoneClaimed(0)), 0);
        expect(store.getInt(StorageKeys.ptAscendantFreeMoveDay, def: -1), -1);
        expect(store.getInt(StorageKeys.wheelCoinStreak), 0);
      },
    );
  });
}
