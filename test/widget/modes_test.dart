import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bơm nhiều frame nhỏ để game loop chạy hết effect + TimerComponent animation.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets(
    'F8 Time-attack: HUD hiện đếm ngược, hết giờ → overlay "Time\'s Up!"',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startSideMode(GameMode.timeAttack);

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          home: const GameScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final gsc = Get.find<GameScreenController>();
      expect(find.textContaining('Time 60s'), findsOneWidget);

      // Giả lập hết giờ mà không chờ Timer thật 60s.
      gameCtrl.checkEnd(false);
      await _pumpFrames(tester);

      expect(gsc.ui.value, GameUi.lose);
      expect(find.text("Time's Up!"), findsOneWidget);
      // Side-mode: không đụng campaign.
      expect(gameCtrl.unlockedLevel.value, 1);
      expect(gameCtrl.coins.value, 0);

      // Get.reset() không tự gọi onClose() → Timer đếm ngược còn treo, phải
      // huỷ thủ công để tránh lỗi "Timer is still pending" của test framework.
      gsc.onClose();
      Get.reset();
    },
  );

  testWidgets('F8 Zen: bàn dọn sạch thì refill thay vì kết thúc ván', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startSideMode(GameMode.zen);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: const GameScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final gsc = Get.find<GameScreenController>();
    // Cả bàn cùng màu → 1 tap nổ hết → lẽ ra sẽ "kết thúc ván" nếu không refill.
    gsc.game.colorGrid = List.generate(
      gsc.game.rows,
      (_) => List.generate(gsc.game.cols, (_) => 0),
    );

    await tester.tapAt(tester.getCenter(find.byType(GameWidget<PopStarGame>)));
    await _pumpFrames(tester);

    expect(gameCtrl.ended.value, isFalse);
    expect(gsc.ui.value, GameUi.playing);
    // Bàn được dựng lại mới, không còn rỗng hoàn toàn.
    expect(gsc.game.colorGrid.any((row) => row.any((c) => c != null)), isTrue);

    Get.reset();
  });

  testWidgets('F12 Endless: bàn dọn sạch thì sang bàn kế, không kết thúc ván', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startEndless();

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        home: const GameScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final gsc = Get.find<GameScreenController>();
    // Cả bàn cùng màu → 1 tap nổ hết → lẽ ra "kết thúc ván" nếu không sang bàn.
    gsc.game.colorGrid = List.generate(
      gsc.game.rows,
      (_) => List.generate(gsc.game.cols, (_) => 0),
    );

    await tester.tapAt(tester.getCenter(find.byType(GameWidget<PopStarGame>)));
    await _pumpFrames(tester);

    expect(gameCtrl.ended.value, isFalse);
    expect(gsc.ui.value, GameUi.playing);
    // Bàn được dựng lại mới, không còn rỗng hoàn toàn.
    expect(gsc.game.colorGrid.any((row) => row.any((c) => c != null)), isTrue);

    Get.reset();
  });

  test(
    'F12 Endless: kẹt thì kết thúc ván + lưu best (không đụng campaign)',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startEndless();
      gameCtrl.score.value = 777;

      gameCtrl.checkEnd(false);

      expect(gameCtrl.ended.value, isTrue);
      expect(gameCtrl.endlessBest.value, 777);
      expect(gameCtrl.unlockedLevel.value, 1);
      expect(gameCtrl.coins.value, 0);

      Get.reset();
    },
  );
}
