import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget home) => GetMaterialApp(
  translations: AppTranslations(),
  locale: const Locale('en', 'US'),
  home: home,
);

// I27 Prestige/New Game+: badge/entry-point ở app bar Level Select.
void main() {
  late GameController ctrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    ctrl = Get.put(GameController(), permanent: true);
  });

  tearDown(Get.reset);

  void winLevel(int id) {
    ctrl.startLevel(id);
    ctrl.addScore(
      prestigeTargetScore(kLevels[id - 1], ctrl.prestigeTier.value),
    );
    ctrl.checkEnd(false);
  }

  testWidgets('tier 0, chưa đủ điều kiện → không hiện badge prestige', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('prestige_badge')), findsNothing);
  });

  testWidgets('đủ điều kiện prestige → hiện badge tappable, mở dialog xác '
      'nhận', (tester) async {
    winLevel(kLevelCount);
    await tester.pumpWidget(_wrap(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('prestige_badge')), findsOneWidget);

    await tester.tap(find.byKey(const Key('prestige_badge')));
    await tester.pump();

    expect(find.text('Prestige'), findsWidgets);
  });

  testWidgets('tap Cancel trong dialog → không gọi prestige(), tier giữ '
      'nguyên', (tester) async {
    winLevel(kLevelCount);
    await tester.pumpWidget(_wrap(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('prestige_badge')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(ctrl.prestigeTier.value, 0);
    expect(ctrl.canPrestige, isTrue);
  });

  testWidgets('tap Prestige trong dialog → gọi prestige(), tăng tier, badge '
      'ẩn lại (chưa đủ điều kiện tier mới)', (tester) async {
    winLevel(kLevelCount);
    await tester.pumpWidget(_wrap(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('prestige_badge')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Prestige').last);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(ctrl.prestigeTier.value, 1);
    expect(ctrl.canPrestige, isFalse);
    // Badge vẫn hiện (đã prestige ít nhất 1 lần) nhưng không tappable —
    // hiển thị "P1" tĩnh thay vì icon call-to-action.
    expect(find.text('P1'), findsOneWidget);
  });

  testWidgets('badge không tappable khi tier>0 nhưng chưa đủ điều kiện lần '
      'kế (double-tap không mở dialog thêm)', (tester) async {
    winLevel(kLevelCount);
    await tester.pumpWidget(_wrap(const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('prestige_badge')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Prestige').last);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    // Sau prestige, tap vào badge "P1" không mở dialog (onTap: null khi
    // !ready) — chống double-tap mở nhầm dialog trong lúc chưa đủ điều kiện.
    await tester.tap(find.text('P1'));
    await tester.pump();
    expect(find.text('Restart from level 1'), findsNothing);
  });
}
