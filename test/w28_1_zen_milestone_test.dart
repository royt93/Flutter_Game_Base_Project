import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 28.1 — Zen milestone: thưởng xu one-time khi vượt mốc điểm mới, KHÔNG
/// thêm currency/tier ngoài coin, KHÔNG đụng SideModeKind (Zen giữ "không áp lực").
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

  group('W28.1 — endZenSession mốc thưởng', () {
    test('chưa đạt mốc đầu → không thưởng thêm, tier vẫn 0', () {
      g.startZen();
      g.score.value = kZenMilestones[0] - 1;
      g.endZenSession();
      expect(g.zenMilestoneTier.value, 0);
    });

    test('vượt mốc đầu → cộng xu mốc + lưu tier=1', () {
      g.startZen();
      g.score.value = kZenMilestones[0];
      final before = g.coins.value;
      g.endZenSession();
      expect(g.zenMilestoneTier.value, 1);
      expect(
        g.coins.value,
        greaterThanOrEqualTo(before + kZenMilestoneCoins[0]),
      );
    });

    test('đạt mốc rồi lặp lại KHÔNG thưởng thêm lần 2 (one-time)', () {
      g.startZen();
      g.score.value = kZenMilestones[0];
      g.endZenSession();
      final coinsAfterFirst = g.coins.value;

      g.startZen();
      g.score.value = kZenMilestones[0]; // vẫn cùng mốc, KHÔNG mốc mới
      g.endZenSession();
      // chỉ còn thưởng "theo điểm" nhỏ (discountSideModeReward), không có
      // phần milestone cộng thêm nữa → tier giữ nguyên 1.
      expect(g.zenMilestoneTier.value, 1);
      expect(g.coins.value, greaterThanOrEqualTo(coinsAfterFirst));
    });

    test(
      'nhảy thẳng qua nhiều mốc 1 lượt → chỉ tính mốc CAO NHẤT vượt được',
      () {
        g.startZen();
        g.score.value = kZenMilestones[2]; // vượt mốc 0,1,2 cùng lúc
        final before = g.coins.value;
        g.endZenSession();
        expect(g.zenMilestoneTier.value, 3);
        expect(
          g.coins.value,
          greaterThanOrEqualTo(before + kZenMilestoneCoins[2]),
        );
      },
    );
  });

  group('W28.1 — resetProgress dọn sạch mốc Zen', () {
    test('reset xoá zenMilestoneTier về 0', () async {
      g.startZen();
      g.score.value = kZenMilestones[0];
      g.endZenSession();
      expect(g.zenMilestoneTier.value, 1);

      await g.resetProgress();
      expect(g.zenMilestoneTier.value, 0);
    });
  });
}
