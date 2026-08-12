import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/star_pets.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/pet_habitat_screen.dart';
import 'package:pop_star_blast/presentation/widgets/pressable_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `PetHabitatScreen` (I65) — 272 dòng, trước batch này không có test nào.
///
/// Đáng test nhất vì nó là **mặt tiền của [X22]**: màn này gọi thẳng
/// `hatchPet` và `claimIdlePetReward`, hai hàm vừa đổi ở X22 (thưởng idle
/// tính per-pet theo `hatchedAtMs`, và đồng hồ kẹp chống chỉnh giờ). Unit test
/// đã phủ phần thuần; phần còn thiếu là "bấm nút trên UI có ra đúng kết quả
/// không".
late GameController gameCtrl;

Future<void> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  gameCtrl = Get.put(GameController(), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: const PetHabitatScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Nút "ấp" của loại pet [type].
///
/// Nút là `PressableScale` nằm trong cùng `Column` với tên pet — không tìm
/// theo nhãn nút vì mọi pet dùng chung nhãn giá, trùng nhau.
Finder _hatchButton(PetType type) => find.descendant(
  of: find
      .ancestor(of: find.text(type.nameKey.tr), matching: find.byType(Column))
      .first,
  matching: find.byType(PressableScale),
);

Future<void> _tapHatch(WidgetTester tester, PetType type) async {
  final btn = _hatchButton(type);
  await tester.ensureVisible(btn.first);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(btn.first);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  tearDown(Get.reset);

  final cheapest = kStarPetTypes.reduce(
    (a, b) => a.hatchCost <= b.hatchCost ? a : b,
  );

  group('dựng màn hình', () {
    testWidgets('render được, không ném', (tester) async {
      await _pump(tester);
      expect(find.byType(PetHabitatScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hiện đủ mọi loại pet trong bảng const', (tester) async {
      await _pump(tester);
      for (final t in kStarPetTypes) {
        expect(
          find.text(t.nameKey.tr),
          findsWidgets,
          reason: 'thiếu pet "${t.id}" trên màn hình',
        );
      }
    });

    testWidgets('hiện số Star Dust đang có', (tester) async {
      await _pump(tester, prefs: {StorageKeys.starDustCount: 777});
      expect(find.text('777'), findsWidgets);
    });
  });

  group('ấp pet', () {
    testWidgets('không đủ Star Dust -> bấm không ăn', (tester) async {
      await _pump(tester, prefs: {StorageKeys.starDustCount: 0});
      expect(gameCtrl.starOwnedPets, isEmpty);

      await _tapHatch(tester, cheapest);

      expect(
        gameCtrl.starOwnedPets,
        isEmpty,
        reason: 'nút phải bị vô hiệu khi không đủ Star Dust',
      );
      expect(gameCtrl.starDust.value, 0);
    });

    testWidgets('guard trong controller cũng chặn, không chỉ UI', (
      tester,
    ) async {
      // Test ở trên chỉ chứng minh **nút** bị vô hiệu hoá — nó không bao giờ
      // chạm tới guard trong `hatchPet`. Phát hiện qua mutation-check: gỡ
      // `if (starDust < hatchCost) return false` mà test vẫn xanh.
      //
      // Gọi thẳng controller để khoá luôn tuyến phòng thủ thứ hai: caller
      // khác (crate, thưởng, code tương lai) không đi qua UI.
      await _pump(
        tester,
        prefs: {StorageKeys.starDustCount: cheapest.hatchCost - 1},
      );

      expect(gameCtrl.hatchPet(cheapest), isFalse);
      expect(gameCtrl.starOwnedPets, isEmpty);
      expect(
        gameCtrl.starDust.value,
        cheapest.hatchCost - 1,
        reason: 'thiếu 1 Star Dust vẫn không được trừ tiền',
      );
    });

    testWidgets('đủ Star Dust -> trừ đúng giá và thêm 1 pet', (tester) async {
      await _pump(
        tester,
        prefs: {StorageKeys.starDustCount: cheapest.hatchCost + 5},
      );

      await _tapHatch(tester, cheapest);

      expect(gameCtrl.starOwnedPets.length, 1);
      expect(gameCtrl.starOwnedPets.single.typeId, cheapest.id);
      expect(gameCtrl.starDust.value, 5);
    });

    testWidgets('ấp nhiều con cùng loại được (multi-instance)', (tester) async {
      await _pump(
        tester,
        prefs: {StorageKeys.starDustCount: cheapest.hatchCost * 3},
      );

      await _tapHatch(tester, cheapest);
      await _tapHatch(tester, cheapest);

      expect(gameCtrl.starOwnedPets.length, 2);
      expect(gameCtrl.starDust.value, cheapest.hatchCost);
    });

    testWidgets('pet vừa ấp được persist, không mất khi nạp lại', (
      tester,
    ) async {
      await _pump(
        tester,
        prefs: {StorageKeys.starDustCount: cheapest.hatchCost},
      );
      await _tapHatch(tester, cheapest);

      expect(
        StorageService.to.getString(StorageKeys.starOwnedPets),
        contains(cheapest.id),
      );
    });
  });

  group('X22 — thưởng idle', () {
    testWidgets('pet vừa ấp KHÔNG cho thưởng idle ngay', (tester) async {
      // Đây chính là lỗ X22: tài khoản chưa từng collect có
      // `lastPetCollectMs = 0` (mốc 1970), nên bản cũ trả trọn trần 10 giờ
      // ngay sau khi ấp con đầu tiên.
      await _pump(
        tester,
        prefs: {StorageKeys.starDustCount: cheapest.hatchCost},
      );
      await _tapHatch(tester, cheapest);

      expect(
        gameCtrl.pendingIdlePetReward,
        0,
        reason: 'thưởng phải tính từ lúc pet tồn tại, không phải từ 1970',
      );
    });

    testWidgets('không có pet -> không có thưởng chờ, không hiện nút hốt', (
      tester,
    ) async {
      await _pump(tester);
      expect(gameCtrl.starOwnedPets, isEmpty);
      expect(gameCtrl.pendingIdlePetReward, 0);
    });

    testWidgets('hốt khi chưa có gì -> không cộng xu', (tester) async {
      await _pump(tester);
      final coinsBefore = gameCtrl.coins.value;
      expect(gameCtrl.claimIdlePetReward(), 0);
      expect(gameCtrl.coins.value, coinsBefore);
    });

    testWidgets('pet cũ (đã chờ lâu) mới sinh ra thưởng', (tester) async {
      // Gieo 1 pet ấp từ lâu + mốc collect cũ → có thưởng thật.
      const longAgo = 1000;
      await _pump(
        tester,
        prefs: {
          StorageKeys.starOwnedPets:
              '[{"typeId":"${cheapest.id}","hatchedAtMs":$longAgo}]',
          StorageKeys.lastPetCollectTimestampMs: longAgo,
        },
      );
      expect(gameCtrl.starOwnedPets.length, 1);
      expect(gameCtrl.pendingIdlePetReward, greaterThan(0));

      final coinsBefore = gameCtrl.coins.value;
      final claimed = gameCtrl.claimIdlePetReward();

      expect(claimed, greaterThan(0));
      expect(gameCtrl.coins.value, coinsBefore + claimed);
      expect(
        gameCtrl.pendingIdlePetReward,
        0,
        reason: 'hốt xong phải reset mốc, không hốt lại được ngay',
      );
    });
  });
}
