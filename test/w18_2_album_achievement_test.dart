import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/achievements.dart';
import 'package:neon_jewels/data/collection.dart';
import 'package:neon_jewels/presentation/controllers/achievement_controller.dart';
import 'package:neon_jewels/presentation/controllers/collection_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// W18.2 — Khác-biệt-hoá Album & Thành tựu.
/// Album = vật sưu tập (KHÔNG xu/sticker) + thưởng hoàn-tất-bộ (skin + xu 1 lần).
/// Thành tựu = giữ xu + thêm DANH HIỆU đeo được.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  Future<void> boot([Map<String, Object>? seed]) async {
    SharedPreferences.setMockInitialValues(seed ?? {});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  }

  setUp(() => boot());
  tearDown(Get.reset);

  // ─── Album = vật sưu tập (không xu) ─────────────────────────────────────

  group('Album — thu thập KHÔNG thưởng xu', () {
    test('claim sticker không cộng xu (chỉ unlock)', () {
      final cc = Get.put(CollectionController(g));
      cc.points.value = kCollectionItems[0].threshold;
      final coins0 = g.coins.value;
      expect(cc.claim(0), isTrue);
      expect(cc.isClaimed(0), isTrue);
      expect(g.coins.value, coins0, reason: 'sticker là vật sưu tập, không xu');
    });

    test('claim 1 lần (không thu lại)', () {
      final cc = Get.put(CollectionController(g));
      cc.points.value = kCollectionItems[0].threshold;
      expect(cc.claim(0), isTrue);
      expect(cc.claim(0), isFalse);
    });

    test('chưa đủ điểm → không thu được', () {
      final cc = Get.put(CollectionController(g));
      expect(cc.canClaim(0), isFalse);
      expect(cc.claim(0), isFalse);
    });
  });

  // ─── Album — thưởng hoàn tất bộ ─────────────────────────────────────────

  group('Album — thưởng HOÀN TẤT BỘ (1 lần)', () {
    CollectionController collectAll() {
      final cc = Get.put(CollectionController(g));
      cc.points.value = kCollectionItems.last.threshold; // đủ mọi mốc
      for (var i = 0; i < kCollectionItems.length; i++) {
        cc.claim(i);
      }
      return cc;
    }

    test('chưa đủ bộ → không nhận được thưởng bộ', () {
      final cc = Get.put(CollectionController(g));
      cc.points.value = kCollectionItems.last.threshold;
      cc.claim(0); // mới 1 sticker
      expect(cc.allCollected, isFalse);
      expect(cc.canClaimSet, isFalse);
      expect(cc.claimSetReward(), isFalse);
    });

    test('đủ bộ → nhận skin độc quyền + xu (1 lần)', () {
      final cc = collectAll();
      expect(cc.allCollected, isTrue);
      expect(cc.canClaimSet, isTrue);
      final coins0 = g.coins.value;
      expect(g.isSkinOwned(kCollectionSetSkin), isFalse);
      expect(cc.claimSetReward(), isTrue);
      expect(g.isSkinOwned(kCollectionSetSkin), isTrue);
      expect(g.coins.value, coins0 + kCollectionSetCoins);
      // nhận lại → false, không cộng thêm
      final coins1 = g.coins.value;
      expect(cc.claimSetReward(), isFalse);
      expect(g.coins.value, coins1);
      expect(cc.canClaimSet, isFalse);
    });

    test('persist: thưởng bộ đã nhận → reload vẫn không nhận lại', () async {
      collectAll().claimSetReward();
      // controller mới đọc lại đĩa
      final cc2 = CollectionController(g);
      cc2.onInit();
      expect(cc2.setRewardClaimed.value, isTrue);
      expect(cc2.canClaimSet, isFalse);
    });

    test('hasClaimable true khi còn thưởng bộ chưa nhận', () {
      final cc = collectAll();
      expect(cc.hasClaimable, isTrue);
      cc.claimSetReward();
      expect(cc.hasClaimable, isFalse);
    });

    test('resetState xoá cờ thưởng bộ', () {
      final cc = collectAll();
      cc.claimSetReward();
      cc.resetState();
      expect(cc.setRewardClaimed.value, isFalse);
      expect(cc.claimed, isEmpty);
    });

    test('player đã mua skin từ Shop → claimSetReward bù đắp kCollectionSetSkinPrice xu', () {
      // Giả lập player mua skin 'void' trước từ Shop (giá 900 xu)
      g.ownedSkins.add(kCollectionSetSkin);
      final cc = collectAll();
      final coins0 = g.coins.value;
      expect(cc.claimSetReward(), isTrue);
      // skin đã có → bù đắp kCollectionSetSkinPrice xu thay vì kCollectionSetCoins
      expect(g.isSkinOwned(kCollectionSetSkin), isTrue);
      expect(g.coins.value, coins0 + kCollectionSetSkinPrice,
          reason: 'bù đắp bằng giá skin (900 xu) khi skin đã sở hữu từ Shop');
      expect(g.coins.value - coins0,
          greaterThan(kCollectionSetCoins),
          reason: 'xu bù (900) > xu thường (200) → công bằng cho player đã mua');
      // lần 2 → false (đã claim)
      final coins1 = g.coins.value;
      expect(cc.claimSetReward(), isFalse);
      expect(g.coins.value, coins1);
    });
  });

  // ─── Thành tựu — danh hiệu đeo được ─────────────────────────────────────

  group('Thành tựu — danh hiệu (title)', () {
    test('claim vẫn cộng xu (giữ nguyên)', () {
      final ac = Get.put(AchievementController(g));
      g.totalWins.value = 1; // mở first_win
      final a = kAchievements.firstWhere((x) => x.id == 'first_win');
      expect(ac.isUnlocked(a), isTrue);
      final coins0 = g.coins.value;
      final got = ac.claim(a);
      expect(got, greaterThan(0));
      expect(g.coins.value, coins0 + got);
    });

    test('chỉ đeo được danh hiệu của thành tựu ĐÃ nhận', () {
      final ac = Get.put(AchievementController(g));
      // chưa nhận → không đeo được
      expect(ac.equipTitle('first_win'), isFalse);
      expect(ac.equippedTitle.value, '');
      // nhận rồi → đeo được
      g.totalWins.value = 1;
      ac.claim(kAchievements.firstWhere((x) => x.id == 'first_win'));
      expect(ac.equipTitle('first_win'), isTrue);
      expect(ac.equippedTitle.value, 'first_win');
      expect(ac.equippedTitleKey, 'ach_first_win_t');
    });

    test('đeo lại cái đang đeo → gỡ (toggle)', () {
      final ac = Get.put(AchievementController(g));
      g.totalWins.value = 1;
      ac.claim(kAchievements.firstWhere((x) => x.id == 'first_win'));
      ac.equipTitle('first_win');
      expect(ac.equippedTitle.value, 'first_win');
      ac.equipTitle('first_win'); // toggle off
      expect(ac.equippedTitle.value, '');
      expect(ac.equippedTitleKey, isNull);
    });

    test('persist danh hiệu đeo', () async {
      final ac = Get.put(AchievementController(g));
      g.totalWins.value = 1;
      ac.claim(kAchievements.firstWhere((x) => x.id == 'first_win'));
      ac.equipTitle('first_win');
      final ac2 = AchievementController(g);
      ac2.onInit();
      expect(ac2.equippedTitle.value, 'first_win');
    });

    test('gỡ danh hiệu → key bị remove (không còn empty string trên đĩa)', () async {
      final ac = Get.put(AchievementController(g));
      g.totalWins.value = 1;
      ac.claim(kAchievements.firstWhere((x) => x.id == 'first_win'));
      ac.equipTitle('first_win');
      ac.equipTitle('first_win'); // gỡ
      expect(ac.equippedTitle.value, '');
      // đĩa phải null (đã remove) chứ không phải ''
      expect(StorageService.to.getString(StorageKeys.equippedTitle), isNull,
          reason: 'gỡ danh hiệu nên xoá key, không setString empty');
    });

    test('resetState gỡ danh hiệu', () {
      final ac = Get.put(AchievementController(g));
      g.totalWins.value = 1;
      ac.claim(kAchievements.firstWhere((x) => x.id == 'first_win'));
      ac.equipTitle('first_win');
      ac.resetState();
      expect(ac.equippedTitle.value, '');
      expect(ac.claimed, isEmpty);
    });
  });
}
