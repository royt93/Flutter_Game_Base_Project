import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/neon_theme.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/pigments.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/color_alchemy_screen.dart';
import 'package:pop_star_blast/presentation/widgets/pressable_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `ColorAlchemyScreen` (I62) — chưa có test nào.
///
/// Đáng test vì đây là màn duy nhất **tiêu xu** mà không đi qua shop, và logic
/// mua nằm ngay trong `onTap` của chip chứ không phải trong controller:
///
/// ```dart
/// if (unlocked) { setGemColorOverride(...); }
/// else if (pigment.coinPrice != null && controller.buyPigment(pigment)) {
///   setGemColorOverride(...);
/// }
/// ```
///
/// Ba nhánh, ba cách hỏng khác nhau: gán màu chưa mua, trừ xu mà không gán
/// màu, hoặc gán màu khoá-bằng-achievement mà người chơi chưa đạt.
late GameController ctrl;

const _free = 'aqua'; // kPigments.first, luôn mở
const _coinLocked = 'coral'; // 180 xu
const _achLocked = 'midnight'; // mở bằng achievement 'combo_25'

Pigment _p(String id) => kPigments.firstWhere((p) => p.id == id);

Future<void> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: const ColorAlchemyScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Card của slot [slot], neo theo **nhãn** chứ không theo vị trí.
///
/// `find.byType(Card).at(slot)` sai: `ensureVisible` cuộn `ListView`, card đầu
/// rơi ra ngoài cacheExtent và bị huỷ, nên chỉ số tụt đi một. Bản đầu của test
/// này trúng bẫy đó — tap "slot 1" thật ra ghi vào slot 2, mà assertion vẫn
/// chỉ báo "null" nên rất dễ tưởng là lỗi sản phẩm.
Finder _card(int slot) => find.ancestor(
  of: find.text('alchemy_slot'.trParams({'slot': '${slot + 1}'})),
  matching: find.byType(Card),
);

/// Mỗi slot dựng đủ 5 chip pigment, nên `find.text('Coral')` trúng nhiều ô
/// trên nhiều hàng — phải giới hạn theo card của đúng slot.
Finder _chip(int slot, String pigmentId) => find.descendant(
  of: _card(slot),
  matching: find.ancestor(
    of: find.text(_p(pigmentId).nameKey.tr),
    matching: find.byType(PressableScale),
  ),
);

Finder _resetButton(int slot) =>
    find.descendant(of: _card(slot), matching: find.text('alchemy_reset'.tr));

/// `ensureVisible` không cứu được card đã bị `ListView` huỷ: finder rỗng thì
/// không có gì để cuộn tới. Kéo ngược lên cho tới khi card dựng lại.
///
/// ponytail: chỉ kéo theo chiều dương (về slot nhỏ hơn) — mọi ca ở đây đều
/// quay lại slot 0/1 sau khi trôi xuống. Cần đi xuống thì thêm chiều âm.
Future<void> _ensureCard(WidgetTester tester, int slot) async {
  if (_card(slot).evaluate().isNotEmpty) return;
  await tester.dragUntilVisible(
    _card(slot),
    find.byType(Scrollable).last,
    const Offset(0, 120),
  );
  await tester.pump(const Duration(milliseconds: 120));
}

Future<void> _tapAt(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(f.first);
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _tapChip(WidgetTester tester, int slot, String pigmentId) async {
  await _ensureCard(tester, slot);
  await _tapAt(tester, _chip(slot, pigmentId));
}

Future<void> _tapReset(WidgetTester tester, int slot) async {
  await _ensureCard(tester, slot);
  await _tapAt(tester, _resetButton(slot));
}

void main() {
  tearDown(Get.reset);

  group('dựng màn hình', () {
    testWidgets('render được, không ném', (tester) async {
      await _pump(tester);
      expect(find.byType(ColorAlchemyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('có đúng 1 hàng cho mỗi slot màu gem', (tester) async {
      await _pump(tester);
      // ListView lazy nên chỉ dựng phần nhìn thấy — kiểm cận trên thay vì
      // đếm chính xác, và kiểm hàng đầu tồn tại.
      expect(find.byType(Card), findsWidgets);
      expect(
        tester.widgetList(find.byType(Card)).length,
        lessThanOrEqualTo(NeonTheme.gemColors.length),
      );
      expect(find.text('alchemy_slot'.trParams({'slot': '1'})), findsOneWidget);
    });

    testWidgets('liệt kê đủ mọi pigment, kể cả chưa mở', (tester) async {
      await _pump(tester);
      for (final p in kPigments) {
        expect(
          _chip(0, p.id),
          findsOneWidget,
          reason: 'thiếu pigment "${p.id}" ở slot 0',
        );
      }
    });
  });

  group('pigment miễn phí', () {
    testWidgets('bấm là gán được ngay, không tốn xu', (tester) async {
      await _pump(tester, prefs: {StorageKeys.coins: 500});

      await _tapChip(tester, 0, _free);

      expect(ctrl.gemColorOverrides[0], _free);
      expect(ctrl.coins.value, 500);
    });

    testWidgets('override đổi màu render của đúng slot đó', (tester) async {
      await _pump(tester);
      final before = resolvedGemColor(0);

      await _tapChip(tester, 0, _free);

      expect(resolvedGemColor(0), _p(_free).color);
      expect(
        resolvedGemColor(1),
        isNot(_p(_free).color),
        reason: 'gán slot 0 không được đổi lây màu slot khác',
      );
      // Không assert `before != after`: pigment free trùng màu mặc định của
      // slot 0 là hoàn toàn có thể, và điều đó không phải lỗi.
      expect(before, isA<Color>());
    });

    testWidgets('override được persist', (tester) async {
      await _pump(tester);
      await _tapChip(tester, 0, _free);

      expect(
        StorageService.to.getString(StorageKeys.gemColorOverrides),
        contains('0:$_free'),
      );
    });
  });

  group('pigment khoá bằng xu', () {
    testWidgets('không đủ xu -> không gán màu, không trừ xu', (tester) async {
      final price = _p(_coinLocked).coinPrice!;
      await _pump(tester, prefs: {StorageKeys.coins: price - 1});

      await _tapChip(tester, 0, _coinLocked);

      expect(
        ctrl.gemColorOverrides[0],
        isNull,
        reason: 'thiếu 1 xu vẫn không được dùng màu',
      );
      expect(ctrl.coins.value, price - 1);
      expect(ctrl.unlockedPigmentIds, isNot(contains(_coinLocked)));
    });

    testWidgets('đủ xu -> trừ đúng giá, mở khoá VÀ gán luôn', (tester) async {
      final price = _p(_coinLocked).coinPrice!;
      await _pump(tester, prefs: {StorageKeys.coins: price + 20});

      await _tapChip(tester, 0, _coinLocked);

      expect(ctrl.coins.value, 20);
      expect(ctrl.unlockedPigmentIds, contains(_coinLocked));
      expect(
        ctrl.gemColorOverrides[0],
        _coinLocked,
        reason: 'mua xong mà không gán thì người chơi trả tiền lấy hư không',
      );
    });

    testWidgets('mua rồi thì lần bấm sau không trừ xu nữa', (tester) async {
      final price = _p(_coinLocked).coinPrice!;
      await _pump(tester, prefs: {StorageKeys.coins: price + 20});

      await _tapChip(tester, 0, _coinLocked);
      await _tapChip(tester, 1, _coinLocked);

      expect(
        ctrl.coins.value,
        20,
        reason: 'bị tính tiền hai lần cho 1 pigment',
      );
      expect(ctrl.gemColorOverrides[1], _coinLocked);
    });

    testWidgets('mua xong được persist cả xu lẫn danh sách mở khoá', (
      tester,
    ) async {
      final price = _p(_coinLocked).coinPrice!;
      await _pump(tester, prefs: {StorageKeys.coins: price});

      await _tapChip(tester, 0, _coinLocked);

      final store = StorageService.to;
      expect(store.getInt(StorageKeys.coins), 0);
      expect(
        store.getString(StorageKeys.unlockedPigments),
        contains(_coinLocked),
      );
    });
  });

  group('pigment khoá bằng achievement', () {
    testWidgets('chưa đạt -> bấm trơ, và KHÔNG được mua bằng xu', (
      tester,
    ) async {
      await _pump(tester, prefs: {StorageKeys.coins: 999999});

      await _tapChip(tester, 0, _achLocked);

      expect(
        ctrl.gemColorOverrides[0],
        isNull,
        reason: 'màu phần thưởng mà mua được bằng xu thì thành tựu vô nghĩa',
      );
      expect(ctrl.coins.value, 999999);
      expect(ctrl.unlockedPigmentIds, isNot(contains(_achLocked)));
    });

    testWidgets('đã đạt achievement -> gán được, miễn phí', (tester) async {
      final achId = _p(_achLocked).unlockAchievementId!;
      await _pump(
        tester,
        prefs: {
          StorageKeys.coins: 500,
          StorageKeys.unlockedAchievements: achId,
        },
      );
      expect(ctrl.unlockedAchievementIds, contains(achId));

      await _tapChip(tester, 0, _achLocked);

      expect(ctrl.gemColorOverrides[0], _achLocked);
      expect(ctrl.coins.value, 500);
      expect(
        ctrl.unlockedPigmentIds,
        isNot(contains(_achLocked)),
        reason: 'suy từ achievement, không cần ghi vào danh sách đã mua',
      );
    });

    testWidgets('setGemColorOverride cũng chặn, không chỉ UI', (tester) async {
      // Chip chưa mở khoá có `onTap` không rỗng (nó còn phải thử mua), nên
      // test bấm ở trên không chạm tới guard trong controller. Gọi thẳng để
      // khoá luôn tuyến thứ hai — caller khác không đi qua màn này.
      await _pump(tester);
      expect(ctrl.setGemColorOverride(0, _achLocked), isFalse);
      expect(ctrl.setGemColorOverride(0, 'khong_ton_tai'), isFalse);
      expect(ctrl.gemColorOverrides, isEmpty);
    });
  });

  group('nút đặt lại', () {
    testWidgets('chỉ hiện khi slot đó đang có override', (tester) async {
      await _pump(tester);
      expect(_resetButton(0), findsNothing);

      await _tapChip(tester, 0, _free);

      expect(_resetButton(0), findsOneWidget);
      expect(_resetButton(1), findsNothing);
    });

    testWidgets('bấm là xoá override và trả màu về mặc định', (tester) async {
      await _pump(tester);
      await _tapChip(tester, 0, _free);

      await _tapReset(tester, 0);

      expect(ctrl.gemColorOverrides[0], isNull);
      expect(resolvedGemColor(0), NeonTheme.gemColors[0]);
      expect(
        StorageService.to.getString(StorageKeys.gemColorOverrides) ?? '',
        isNot(contains('0:')),
      );
    });

    testWidgets('xoá slot này không đụng slot kia', (tester) async {
      await _pump(tester);
      await _tapChip(tester, 0, _free);
      await _tapChip(tester, 1, _free);

      await _tapReset(tester, 0);

      expect(ctrl.gemColorOverrides[0], isNull);
      expect(ctrl.gemColorOverrides[1], _free);
    });
  });

  group('save hỏng', () {
    testWidgets('override trỏ pigment không tồn tại -> về màu mặc định', (
      tester,
    ) async {
      // Bảng `kPigments` là const: xoá một entry ở round sau không được làm
      // màn hình vỡ hay render màu rác.
      await _pump(
        tester,
        prefs: {StorageKeys.gemColorOverrides: '0:pigment_da_bi_xoa'},
      );

      expect(find.byType(ColorAlchemyScreen), findsOneWidget);
      expect(resolvedGemColor(0), NeonTheme.gemColors[0]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chuỗi override rác -> bỏ qua, không ném', (tester) async {
      await _pump(tester, prefs: {StorageKeys.gemColorOverrides: ':::,,abc,9'});

      expect(find.byType(ColorAlchemyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
