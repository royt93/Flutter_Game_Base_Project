import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/logic/ftue_tips.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I85 — phần nối dây của các mẩu hướng dẫn.
///
/// Luật "khi nào hiện" đã có test thuần (`test/logic/ftue_tips_test.dart`).
/// Ở đây chỉ kiểm thứ hàm thuần không tự bảo vệ được: controller có đọc đúng
/// cờ đã-xem không, và **có ghi lại sau khi hiện** không — thiếu bước ghi thì
/// mẩu hướng dẫn lặp lại mỗi lần thua, đúng kiểu phiền nhất.
late GameController gameCtrl;
late GameScreenController gsc;

Future<void> _boot(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  void Function(GameController)? start,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  gameCtrl = Get.put(GameController(), permanent: true);
  (start ?? (c) => c.startLevel(1))(gameCtrl);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
  gsc = Get.put(GameScreenController(gameCtrl));
  await tester.pump();
}

void main() {
  tearDown(Get.reset);

  group('mẩu "nhóm lớn hơn"', () {
    testWidgets('campaign level 1, cài mới -> bật', (tester) async {
      await _boot(tester);
      expect(gsc.showBigGroupTip.value, isTrue);
    });

    testWidgets('đã xem -> không bật lại', (tester) async {
      await _boot(tester, prefs: {StorageKeys.hasSeenBigGroupTip: true});
      expect(gsc.showBigGroupTip.value, isFalse);
    });

    testWidgets('level khác 1 -> không bật', (tester) async {
      await _boot(tester, start: (c) => c.startLevel(4));
      expect(gsc.showBigGroupTip.value, isFalse);
    });

    testWidgets('side-mode -> không bật', (tester) async {
      await _boot(tester, start: (c) => c.startSideMode(GameMode.zen));
      expect(gsc.showBigGroupTip.value, isFalse);
    });

    testWidgets('công tắc bỏ qua hướng dẫn -> không bật', (tester) async {
      await _boot(tester, prefs: {StorageKeys.skipTips: true});
      expect(gsc.showBigGroupTip.value, isFalse);
    });

    testWidgets('tap bàn tắt vĩnh viễn, có ghi lại', (tester) async {
      await _boot(tester);
      expect(gsc.showBigGroupTip.value, isTrue);

      // Trigger thật là tap BÀN CỜ (`handleBoardTap`), không phải arm booster
      // — mẩu này sống cùng bong bóng FTUE nên tắt cùng nhịp với nó.
      //
      // Phải mount GameWidget thật: `handleBoardTap` gọi `game.cellAt`, mà
      // `colorGrid`/`rows` chỉ có sau `onLoad()`. Không mount thì ném
      // LateInitializationError chứ không phải "test đỏ vì logic sai".
      await tester.pumpWidget(
        GetMaterialApp(home: GameWidget(game: gsc.game)),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      gsc.handleBoardTap(gsc.game.cellCenterFor(0, 0));
      await tester.pump();

      expect(gsc.showBigGroupTip.value, isFalse);
      expect(
        StorageService.to.getBool(StorageKeys.hasSeenBigGroupTip),
        isTrue,
        reason: 'không ghi lại thì mẩu này hiện lại mỗi ván',
      );
    });
  });

  group('mẩu "bàn không refill"', () {
    testWidgets('thua campaign lần đầu -> có lời khuyên', (tester) async {
      await _boot(tester);
      gameCtrl.starsEarned.value = 0;
      gameCtrl.score.value = 10;

      expect(gsc.takeNoRefillAdvice(), isNotNull);
    });

    testWidgets('gọi lần 2 -> null (chỉ dạy đúng một lần)', (tester) async {
      await _boot(tester);
      gameCtrl.starsEarned.value = 0;

      expect(gsc.takeNoRefillAdvice(), isNotNull);
      expect(
        gsc.takeNoRefillAdvice(),
        isNull,
        reason: 'thua lần sau không được nhắc lại',
      );
      expect(StorageService.to.getBool(StorageKeys.hasSeenNoRefillTip), isTrue);
    });

    testWidgets('thắng -> không có lời khuyên', (tester) async {
      await _boot(tester);
      gameCtrl.starsEarned.value = 2;
      expect(gsc.takeNoRefillAdvice(), isNull);
    });

    testWidgets('side-mode thua -> không có (Zen có refill)', (tester) async {
      await _boot(tester, start: (c) => c.startSideMode(GameMode.zen));
      gameCtrl.starsEarned.value = 0;
      expect(gsc.takeNoRefillAdvice(), isNull);
    });

    testWidgets('công tắc bỏ qua -> không có, và KHÔNG đánh dấu đã xem', (
      tester,
    ) async {
      await _boot(tester, prefs: {StorageKeys.skipTips: true});
      gameCtrl.starsEarned.value = 0;

      expect(gsc.takeNoRefillAdvice(), isNull);
      expect(
        StorageService.to.getBool(StorageKeys.hasSeenNoRefillTip),
        isFalse,
        reason:
            'tắt hướng dẫn rồi bật lại thì vẫn phải được dạy — không "đốt" mất '
            'lần hiện duy nhất',
      );
    });

    testWidgets('lời khuyên đổi theo mức hụt điểm', (tester) async {
      await _boot(tester);
      gameCtrl.starsEarned.value = 0;
      gameCtrl.score.value = gameCtrl.currentLevel.targetScore; // sát nút
      expect(gsc.takeNoRefillAdvice(), FtueLossAdvice.soClose);
    });
  });
}
