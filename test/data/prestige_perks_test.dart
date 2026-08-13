import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/constellations.dart';
import 'package:pop_star_blast/data/perks.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I83 — Sky Shrine thành cây kỹ năng cho New Game+.
///
/// Task gốc đề xuất một hệ buff riêng. Đã KHÔNG làm vậy: `PerkEffect` (F14) và
/// `PetPassive` ([[I82]]) vốn đã trùng nhau ba hiệu ứng, thêm hệ thứ ba nói
/// cùng điều đó là nhiễu. Constellation mở thêm perk vào **chính** hệ F14 —
/// cùng `activePerkIds`, cùng `togglePerk`, cùng `PerksScreen`.
///
/// Bất biến quan trọng nhất ở đây: **không perk prestige nào chạm điểm số**.
/// Nhờ vậy `levels_achievability_test` giữ nguyên kết quả ở mọi tier, không
/// cần mô phỏng lại — và không có đường nào làm màn bất khả thi HOẶC dễ tới
/// mức 3 sao tự động.
late GameController ctrl;

Future<void> _boot({
  int prestigeTier = 0,
  int stars = 0,
  int unlockedLevel = 1,
  List<String> activePerks = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.prestigeTier: prestigeTier,
    StorageKeys.unlockedLevel: unlockedLevel,
    if (activePerks.isNotEmpty) StorageKeys.activePerks: activePerks.join(','),
    // Rải sao thật để `_recomputeTotalStars` cộng ra đúng số.
    for (var i = 1; i <= (stars / 3).ceil(); i++)
      StorageKeys.star(i): (stars - (i - 1) * 3).clamp(0, 3),
  });
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

/// Số sao đủ thắp constellation thứ [index].
int _starsFor(int index) => kConstellations[index].starsRequired;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('bảng dữ liệu', () {
    test('mỗi constellation có đúng 1 perk prestige', () {
      expect(kPrestigePerks.length, kConstellations.length);
    });

    test('id perk prestige không trùng perk F14', () {
      final f14 = kPerks.map((p) => p.id).toSet();
      for (final p in kPrestigePerks) {
        expect(f14.contains(p.id), isFalse, reason: p.id);
      }
    });

    test('hiệu ứng perk prestige không trùng hiệu ứng F14', () {
      // Chính là lý do task này KHÔNG dựng hệ thứ ba: nếu trùng thì nó chỉ là
      // F14 nói lại lần nữa.
      final f14 = kPerks.map((p) => p.effect).toSet();
      for (final p in kPrestigePerks) {
        expect(f14.contains(p.effect), isFalse, reason: p.effect.name);
      }
    });

    test('mọi hiệu ứng prestige đều thuộc kinh tế/tiện ích', () {
      // Chốt an toàn cân bằng: không hiệu ứng nào đổi ĐIỂM. Ai thêm hiệu ứng
      // chạm điểm phải sửa ca này và khi đó buộc phải chạy lại achievability
      // ở mọi tier.
      const scoreFree = {
        PerkEffect.boosterDiscount,
        PerkEffect.starDustBonus,
        PerkEffect.craftBonus,
        PerkEffect.freeSecondChance,
      };
      for (final p in kPrestigePerks) {
        expect(scoreFree.contains(p.effect), isTrue, reason: p.id);
      }
    });
  });

  group('bảng ô perk theo tier', () {
    test('tier 0 giữ nguyên 2 ô như F14 gốc', () {
      expect(perkSlotsForPrestigeTier(0), 2);
    });

    test('tier tăng thì ô tăng, không bao giờ giảm', () {
      var last = perkSlotsForPrestigeTier(0);
      for (var t = 1; t <= 10; t++) {
        final now = perkSlotsForPrestigeTier(t);
        expect(now, greaterThanOrEqualTo(last), reason: 'tier $t');
        last = now;
      }
    });

    test('tier vượt bảng KHÔNG ngoại suy vô hạn', () {
      expect(perkSlotsForPrestigeTier(999), lessThanOrEqualTo(kMaxPerkSlots));
    });

    test('tier âm (save hỏng) -> về mặc định', () {
      expect(perkSlotsForPrestigeTier(-5), 2);
    });

    test('trần cứng không vượt tổng số perk có thật', () {
      expect(kMaxPerkSlots, lessThanOrEqualTo(
        kPerks.length + kPrestigePerks.length,
      ));
    });
  });

  group('mở khoá', () {
    test('tier 0: không perk prestige nào mở, dù đủ sao', () async {
      await _boot(prestigeTier: 0, stars: _starsFor(kConstellations.length - 1));
      expect(
        ctrl.unlockedPrestigePerksList,
        isEmpty,
        reason: 'chưa prestige thì đây chỉ là bản xem trước',
      );
    });

    test('tier 1 + đủ sao chòm đầu -> mở đúng 1 perk', () async {
      await _boot(prestigeTier: 1, stars: _starsFor(0));
      expect(ctrl.unlockedPrestigePerksList.length, 1);
      expect(ctrl.unlockedPrestigePerksList.single.id, kPrestigePerks.first.id);
    });

    test('tier 1 nhưng thiếu sao -> không mở gì', () async {
      await _boot(prestigeTier: 1, stars: _starsFor(0) - 1);
      expect(ctrl.unlockedPrestigePerksList, isEmpty);
    });

    test('nhiều chòm sáng -> mở đúng số perk tương ứng', () async {
      await _boot(prestigeTier: 3, stars: _starsFor(1));
      expect(ctrl.unlockedPrestigePerksList.length, 2);
    });

    test('allUnlockedPerks gộp cả hai nguồn, không trùng', () async {
      await _boot(prestigeTier: 1, stars: _starsFor(0));
      final ids = ctrl.allUnlockedPerks.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('chọn perk', () {
    test('tier 0 vẫn chỉ bật được 2', () async {
      await _boot(prestigeTier: 0);
      expect(ctrl.perkSlots, 2);
    });

    test('tier 1 mở thêm ô', () async {
      await _boot(prestigeTier: 1);
      expect(ctrl.perkSlots, greaterThan(2));
    });

    test('không bật quá số ô cho phép', () async {
      await _boot(prestigeTier: 0, stars: 900);
      for (final p in [...kPerks, ...kPrestigePerks]) {
        ctrl.togglePerk(p.id);
      }
      expect(ctrl.activePerkIds.length, ctrl.perkSlots);
    });

    test('tier >= 1 bật được NHIỀU HƠN 2 perk cùng lúc', () async {
      // Mutation-check bắt được lỗ: ca "không bật quá số ô" ở trên boot ở tier
      // 0 (2 ô) nên không phân biệt được với bản hard-code `max: 2`. Ca này
      // mới thật sự chứng minh trần đi theo tier.
      await _boot(prestigeTier: 1, stars: 900, unlockedLevel: 260);
      expect(ctrl.perkSlots, greaterThan(2));

      for (final p in [...kPerks, ...kPrestigePerks]) {
        if (ctrl.activePerkIds.length >= ctrl.perkSlots) break;
        ctrl.togglePerk(p.id);
      }

      expect(
        ctrl.activePerkIds.length,
        greaterThan(2),
        reason: 'prestige mở thêm ô mà vẫn chỉ bật được 2 thì I83 vô nghĩa',
      );
      expect(ctrl.activePerkIds.length, ctrl.perkSlots);
    });

    test('perk prestige chưa mở -> hasPerk false dù id lọt vào active', () async {
      await _boot(prestigeTier: 0);
      ctrl.activePerkIds.value = [kPrestigePerks.first.id];
      expect(ctrl.hasPerk(kPrestigePerks.first.id), isFalse);
    });
  });

  group('hiệu lực', () {
    Future<void> bootWith(PerkEffect effect) async {
      final idx = kPrestigePerks.indexWhere((p) => p.effect == effect);
      await _boot(
        prestigeTier: 3,
        stars: _starsFor(idx),
        activePerks: [kPrestigePerks[idx].id],
      );
      ctrl.startLevel(1);
    }

    test('boosterDiscount: giá booster giảm, không bao giờ về 0', () async {
      await bootWith(PerkEffect.boosterDiscount);
      final full = GameController.bombPrice;
      final cut = ctrl.discountedPrice(full);
      expect(cut, lessThan(full));
      expect(cut, greaterThan(0));
      expect(ctrl.discountedPrice(1), greaterThan(0));
    });

    test('boosterDiscount: mua thật chỉ trừ giá đã giảm', () async {
      await bootWith(PerkEffect.boosterDiscount);
      ctrl.coins.value = 1000;
      expect(ctrl.buyBomb(), isTrue);
      expect(1000 - ctrl.coins.value, ctrl.discountedPrice(GameController.bombPrice));
    });

    test('không có perk -> giá nguyên', () async {
      await _boot(prestigeTier: 3, stars: 900);
      ctrl.startLevel(1);
      expect(
        ctrl.discountedPrice(GameController.bombPrice),
        GameController.bombPrice,
      );
    });

    test('freeSecondChance: không trừ xu', () async {
      await bootWith(PerkEffect.freeSecondChance);
      ctrl.score.value = 0;
      ctrl.coins.value = 5000;
      ctrl.ended.value = true;
      final before = ctrl.coins.value;
      if (ctrl.canBuySecondChance) {
        expect(ctrl.buySecondChance(), isTrue);
        expect(ctrl.coins.value, before);
      }
    });
  });

  group('loại trừ mode best-score', () {
    for (final mode in [
      GameMode.timeAttack,
      GameMode.comboRush,
      GameMode.endless,
      GameMode.mirrorMode,
    ]) {
      test('$mode: perk prestige KHÔNG hiệu lực', () async {
        final idx = kPrestigePerks.indexWhere(
          (p) => p.effect == PerkEffect.boosterDiscount,
        );
        await _boot(
          prestigeTier: 3,
          stars: _starsFor(idx),
          activePerks: [kPrestigePerks[idx].id],
        );
        ctrl.mode.value = mode;
        expect(
          ctrl.hasPrestigePerk(PerkEffect.boosterDiscount),
          isFalse,
          reason: 'cho chạy ở đây thì mọi kỷ lục cũ bị vô hiệu',
        );
      });
    }

    test('campaign vẫn có hiệu lực', () async {
      final idx = kPrestigePerks.indexWhere(
        (p) => p.effect == PerkEffect.boosterDiscount,
      );
      await _boot(
        prestigeTier: 3,
        stars: _starsFor(idx),
        activePerks: [kPrestigePerks[idx].id],
      );
      ctrl.startLevel(1);
      expect(ctrl.hasPrestigePerk(PerkEffect.boosterDiscount), isTrue);
    });
  });

  group('save hỏng', () {
    test('id perk không còn tồn tại -> bị loại khi nạp', () async {
      await _boot(prestigeTier: 1, activePerks: ['perk_da_bi_go']);
      expect(ctrl.activePerkIds, isEmpty);
    });

    test('save dư perk so với trần tier -> bị kẹp khi nạp', () async {
      // Save từ tier cao rồi tiến độ bị reset: không được giữ 4 perk ở tier 0.
      await _boot(
        prestigeTier: 0,
        activePerks: [...kPerks.map((p) => p.id), kPrestigePerks.first.id],
      );
      expect(ctrl.activePerkIds.length, lessThanOrEqualTo(ctrl.perkSlots));
    });
  });
}
