import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/mode_select_screen.dart';
import 'package:pop_star_blast/presentation/widgets/neon_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `ModeSelectScreen` (I70) là **cửa vào duy nhất** của 14 side mode. Nó chỉ
/// gồm layout + `onTap` gọi `startSideMode(...)`, nên bug ở đây không làm
/// crash mà làm mode dẫn sai chỗ — kiểu lỗi âm thầm nhất. Trước batch này màn
/// hình 285 dòng này không có test nào.
late GameController gameCtrl;

/// Đẩy `ModeSelectScreen` thành **route con** trên một home giả, không dùng
/// làm `home` trực tiếp.
///
/// Bắt buộc: mỗi `onTap` bắt đầu bằng `Get.back()` (đóng màn chọn mode) rồi
/// mới `startSideMode(...)` + `Get.to(GameScreen)`. Nếu màn này là route gốc,
/// `Get.back()` ném và **hai dòng sau không bao giờ chạy** — test sẽ thấy mode
/// đứng nguyên ở `campaign` và trông như bug của màn hình, trong khi thật ra
/// là harness dựng sai.
Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  gameCtrl = Get.put(GameController(), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
  // Navigator của GetMaterialApp chỉ gắn sau vài frame; gọi `Get.to` quá sớm
  // thì route không được đẩy và màn hình không bao giờ xuất hiện.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  unawaited(Get.to(() => const ModeSelectScreen()));
  // Không dùng pumpAndSettle: NeonBg/StarMascot chạy animation lặp vô hạn.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Cuộn tới rồi **đưa vào viewport** [target] — danh sách mode dài hơn màn
/// hình test.
///
/// `ensureVisible` là bắt buộc, không thừa: `ListView` dựng sẵn một khoảng
/// ngoài viewport, nên `target.evaluate()` khác rỗng **không** có nghĩa widget
/// chạm được. Thiếu bước này thì `tester.tap` bắn vào toạ độ ngoài màn hình,
/// `onTap` không chạy, và test báo "mode vẫn là campaign" — trông y hệt bug
/// của màn hình.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final list = find.byType(ListView);
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -260));
    await tester.pump(const Duration(milliseconds: 60));
  }
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target.first);
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Nút chạm được của một tile.
///
/// **Không tap vào nhãn.** `_modeTile` dựng `NeonIconButton` (mang `onTap`)
/// và `Text` nhãn là hai widget **anh em** trong cùng `Column` — chữ không
/// nằm trong vùng chạm. Tap vào `find.text(...)` chạy trót lọt nhưng không
/// kích hoạt gì, và test sẽ báo "mode vẫn là campaign" như thể màn hình hỏng.
Finder _tileButton(String label) => find.descendant(
  of: find
      .ancestor(of: find.text(label), matching: find.byType(Column))
      .first,
  matching: find.byType(NeonIconButton),
);

/// Cuộn tới tile mang [label] rồi tap đúng nút của nó.
Future<void> _tapTile(WidgetTester tester, String label) async {
  await _scrollTo(tester, find.text(label));
  final button = _tileButton(label);
  expect(button, findsOneWidget, reason: 'không thấy nút của tile "$label"');
  await tester.ensureVisible(button);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  tearDown(Get.reset);

  group('dựng màn hình', () {
    testWidgets('render được, không ném', (tester) async {
      await _pump(tester);
      expect(find.byType(ModeSelectScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('có tiêu đề và danh sách cuộn được', (tester) async {
      await _pump(tester);
      expect(find.text('modes_title'.tr), findsWidgets);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('cuộn hết danh sách không ném', (tester) async {
      await _pump(tester);
      final list = find.byType(ListView);
      for (var i = 0; i < 12; i++) {
        await tester.drag(list, const Offset(0, -260));
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('mỗi tile dẫn đúng mode', () {
    // Bảng này là phần có giá trị nhất: nó khoá "nhãn nào → mode nào". Đổi
    // nhầm 2 dòng onTap cho nhau là bug không crash, không test nào khác bắt.
    const cases = <String, GameMode>{
      'mode_time_attack_label': GameMode.timeAttack,
      'mode_zen_label': GameMode.zen,
      'mode_combo_rush_label': GameMode.comboRush,
      'mode_frost_rush_label': GameMode.frostRush,
    };

    cases.forEach((labelKey, expectedMode) {
      testWidgets('$labelKey -> $expectedMode', (tester) async {
        await _pump(tester);
        await _tapTile(tester, labelKey.tr);
        expect(gameCtrl.mode.value, expectedMode);
      });
    });
  });

  group('trạng thái ván sau khi chọn mode', () {
    testWidgets('chọn mode reset điểm và cờ kết thúc của ván trước', (
      tester,
    ) async {
      await _pump(tester);
      gameCtrl.score.value = 9999;
      gameCtrl.ended.value = true;
      gameCtrl.cleared.value = true;

      await _tapTile(tester, 'mode_zen_label'.tr);

      expect(gameCtrl.score.value, 0);
      expect(gameCtrl.ended.value, isFalse);
      expect(gameCtrl.cleared.value, isFalse);
      expect(
        gameCtrl.currentLevelRx.value,
        isNotNull,
        reason: 'phải có PopLevel để GameScreen dựng bàn',
      );
    });

    testWidgets('side mode KHÔNG đụng tiến độ campaign', (tester) async {
      await _pump(tester);
      final unlockedBefore = gameCtrl.unlockedLevel.value;
      final coinsBefore = gameCtrl.coins.value;

      await _tapTile(tester, 'mode_time_attack_label'.tr);

      expect(gameCtrl.unlockedLevel.value, unlockedBefore);
      expect(gameCtrl.coins.value, coinsBefore);
    });
  });
}
