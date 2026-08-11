import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T2 — `GameScreenController` là controller rủi ro nhất trong repo: 534 dòng,
/// dựng `PopStarGame` thật, và **kết thúc màn đến bất đồng bộ** (phát qua
/// `ever(gameCtrl.ended, …)` sau khi animation Flame xong, rồi còn
/// `Future.delayed(350ms)` nữa trước khi đổi `GameUi`). Đúng loại code mà bug
/// hồi quy trốn được, và trước batch này không có test nào.
///
/// Dùng `testWidgets` + `GetMaterialApp` vì `quit()` gọi `Get.back()` (cần
/// navigator) và vì các `Timer` của Time Attack/Combo Rush phải được pump.
late GameController gameCtrl;
late GameScreenController ctrl;

/// Dựng controller trong một app thật. [start] chọn mode trước khi `onInit`
/// chạy — `onInit` gọi thẳng `_newGame()` nên mode phải đúng từ trước.
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
    GetMaterialApp(home: const Scaffold(body: SizedBox.shrink())),
  );
  ctrl = Get.put(GameScreenController(gameCtrl));
  await tester.pump();
}

/// Kết thúc màn rồi chờ qua mốc `Future.delayed(350ms)` của `_onEndChanged`.
Future<void> _finish(WidgetTester tester, {required bool cleared}) async {
  gameCtrl.checkEnd(cleared);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  tearDown(Get.reset);

  group('chuyển GameUi qua ever(ended) — bất đồng bộ', () {
    testWidgets('thắng (>=1 sao) → win, và chỉ SAU 350ms', (tester) async {
      await _boot(tester);
      expect(ctrl.ui.value, GameUi.playing);

      gameCtrl.score.value = kLevels[0].targetScore * 2;
      gameCtrl.checkEnd(true);
      expect(
        ctrl.ui.value,
        GameUi.playing,
        reason: 'chưa hết delay thì overlay chưa được hiện',
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(ctrl.ui.value, GameUi.win);
    });

    testWidgets('0 sao → lose', (tester) async {
      await _boot(tester);
      gameCtrl.score.value = 0;
      await _finish(tester, cleared: false);
      expect(ctrl.ui.value, GameUi.lose);
    });

    testWidgets('đang ở overlay quit thì ended KHÔNG ghi đè', (tester) async {
      await _boot(tester);
      ctrl.confirmQuit();
      expect(ctrl.ui.value, GameUi.quit);

      gameCtrl.score.value = kLevels[0].targetScore * 2;
      await _finish(tester, cleared: true);
      expect(
        ctrl.ui.value,
        GameUi.quit,
        reason: 'chỉ đổi khi đang playing — nếu không sẽ nuốt mất dialog quit',
      );
    });

    testWidgets('passAndPlay: GameScreenController KHÔNG tự hiện win/lose', (
      tester,
    ) async {
      await _boot(
        tester,
        start: (c) {
          c.startPassAndPlayDuel();
        },
      );
      gameCtrl.score.value = 500;
      await _finish(tester, cleared: false);
      expect(
        ctrl.ui.value,
        GameUi.playing,
        reason:
            'PassAndPlayController mới là chỗ quyết định overlay chuyển máy',
      );
    });
  });

  group('overlay quit', () {
    testWidgets('confirmQuit rồi closeOverlay quay lại playing', (
      tester,
    ) async {
      await _boot(tester);
      ctrl.confirmQuit();
      expect(ctrl.ui.value, GameUi.quit);
      ctrl.closeOverlay();
      expect(ctrl.ui.value, GameUi.playing);
    });

    testWidgets('confirmQuit khi đã ở overlay khác → no-op', (tester) async {
      await _boot(tester);
      gameCtrl.score.value = 0;
      await _finish(tester, cleared: false);
      expect(ctrl.ui.value, GameUi.lose);

      ctrl.confirmQuit();
      expect(ctrl.ui.value, GameUi.lose);
    });

    testWidgets('closeOverlay khi không ở quit → no-op', (tester) async {
      await _boot(tester);
      gameCtrl.score.value = 0;
      await _finish(tester, cleared: false);
      ctrl.closeOverlay();
      expect(ctrl.ui.value, GameUi.lose);
    });
  });

  group('FTUE — chỉ lần đầu, campaign level 1', () {
    testWidgets('cài mới + level 1 → hiện FTUE', (tester) async {
      await _boot(tester);
      expect(ctrl.showFtue.value, isTrue);
    });

    testWidgets('đã xem rồi → không hiện lại', (tester) async {
      await _boot(tester, prefs: {StorageKeys.hasSeenFtue: true});
      expect(ctrl.showFtue.value, isFalse);
    });

    testWidgets('level khác 1 → không hiện dù chưa từng xem', (tester) async {
      await _boot(tester, start: (c) => c.startLevel(3));
      expect(ctrl.showFtue.value, isFalse);
    });

    testWidgets('side-mode → không hiện', (tester) async {
      await _boot(tester, start: (c) => c.startSideMode(GameMode.zen));
      expect(ctrl.showFtue.value, isFalse);
    });

    testWidgets('coach-mark booster KHÔNG chồng lên FTUE', (tester) async {
      await _boot(tester);
      expect(ctrl.showFtue.value, isTrue);
      expect(
        ctrl.showBoosterTutorial.value,
        isFalse,
        reason: 'hai overlay cùng lúc là lỗi trình bày',
      );
    });

    testWidgets('FTUE xong + còn bomb → mới hiện coach-mark booster', (
      tester,
    ) async {
      await _boot(tester, prefs: {StorageKeys.hasSeenFtue: true});
      expect(ctrl.showBoosterTutorial.value, isTrue);
    });

    testWidgets('hết bomb → không hiện coach-mark booster', (tester) async {
      await _boot(
        tester,
        prefs: {StorageKeys.hasSeenFtue: true, StorageKeys.bombCount: 0},
      );
      expect(
        ctrl.showBoosterTutorial.value,
        isFalse,
        reason: 'chỉ dạy khi người chơi thật sự có booster để dùng',
      );
    });

    testWidgets('thao tác booster bất kỳ tắt coach-mark vĩnh viễn', (
      tester,
    ) async {
      await _boot(tester, prefs: {StorageKeys.hasSeenFtue: true});
      expect(ctrl.showBoosterTutorial.value, isTrue);

      ctrl.toggleBombArm();
      expect(ctrl.showBoosterTutorial.value, isFalse);
      expect(
        StorageService.to.getBool(StorageKeys.hasSeenBoosterTutorial),
        isTrue,
      );
    });
  });

  group('arm booster', () {
    testWidgets('toggle bomb bật rồi tắt', (tester) async {
      await _boot(tester);
      ctrl.toggleBombArm();
      expect(ctrl.armed.value, BoosterMode.bomb);
      ctrl.toggleBombArm();
      expect(ctrl.armed.value, BoosterMode.none);
    });

    testWidgets('arm booster khác thay thế cái đang arm', (tester) async {
      await _boot(tester);
      ctrl.toggleBombArm();
      ctrl.toggleRainbowArm();
      expect(ctrl.armed.value, BoosterMode.rainbow);
      ctrl.toggleSwapArm();
      expect(ctrl.armed.value, BoosterMode.swap);
    });
  });

  group('again() — chơi lại', () {
    testWidgets('campaign: reset về đúng level cũ, dọn overlay + arm', (
      tester,
    ) async {
      await _boot(tester, start: (c) => c.startLevel(4));
      ctrl.toggleBombArm();
      gameCtrl.score.value = 0;
      await _finish(tester, cleared: false);
      expect(ctrl.ui.value, GameUi.lose);

      final versionBefore = ctrl.gameVersion.value;
      ctrl.again();
      await tester.pump();

      expect(ctrl.ui.value, GameUi.playing);
      expect(ctrl.armed.value, BoosterMode.none);
      expect(gameCtrl.currentLevel.id, 4);
      expect(gameCtrl.score.value, 0);
      expect(gameCtrl.ended.value, isFalse);
      expect(
        ctrl.gameVersion.value,
        greaterThan(versionBefore),
        reason: 'phải dựng lại GameWidget, không tái dùng bàn cũ',
      );
    });

    testWidgets('endless: quay về bàn đầu, không rơi vào nhánh zen', (
      tester,
    ) async {
      await _boot(tester, start: (c) => c.startEndless());
      gameCtrl.score.value = 0;
      await _finish(tester, cleared: false);

      ctrl.again();
      await tester.pump();
      expect(gameCtrl.mode.value, GameMode.endless);
      expect(gameCtrl.score.value, 0);
    });

    testWidgets('zen: giữ nguyên mode side', (tester) async {
      await _boot(tester, start: (c) => c.startSideMode(GameMode.zen));
      await _finish(tester, cleared: false);
      ctrl.again();
      await tester.pump();
      expect(gameCtrl.mode.value, GameMode.zen);
    });

    testWidgets('dailyChallenge: cùng ngày sinh lại đúng bàn cũ', (
      tester,
    ) async {
      await _boot(tester, start: (c) => c.startDailyChallenge());
      final board = gameCtrl.dailyChallengeGrid!
          .map((r) => List<int>.from(r))
          .toList();

      await _finish(tester, cleared: false);
      ctrl.again();
      await tester.pump();

      expect(gameCtrl.dailyChallengeGrid, equals(board));
    });
  });

  group('next() — sang level kế', () {
    testWidgets('campaign: sang đúng level +1, dọn overlay', (tester) async {
      await _boot(tester, start: (c) => c.startLevel(5));
      gameCtrl.score.value = kLevels[4].targetScore * 2;
      await _finish(tester, cleared: true);
      expect(ctrl.ui.value, GameUi.win);

      ctrl.next();
      await tester.pump();

      expect(gameCtrl.currentLevel.id, 6);
      expect(ctrl.ui.value, GameUi.playing);
      expect(ctrl.armed.value, BoosterMode.none);
    });
  });

  group('canShareReplay', () {
    testWidgets('không bật ghi replay → false', (tester) async {
      await _boot(tester);
      expect(ctrl.canShareReplay, isFalse);
    });

    testWidgets('bật ghi nhưng chưa tap lần nào → false', (tester) async {
      await _boot(tester, prefs: {StorageKeys.recordReplay: true});
      expect(
        ctrl.canShareReplay,
        isFalse,
        reason: 'replay rỗng thì không có gì để chia sẻ',
      );
    });
  });

  group('vòng đời timer', () {
    testWidgets('timeAttack: đếm ngược chạy và kết thúc màn khi hết giờ', (
      tester,
    ) async {
      await _boot(tester, start: (c) => c.startSideMode(GameMode.timeAttack));
      expect(
        ctrl.remainingSeconds.value,
        GameScreenController.timeAttackSeconds,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(
        ctrl.remainingSeconds.value,
        GameScreenController.timeAttackSeconds - 1,
      );

      // Chạy hết giờ.
      for (var i = 0; i < GameScreenController.timeAttackSeconds; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(ctrl.remainingSeconds.value, lessThanOrEqualTo(0));
      expect(gameCtrl.ended.value, isTrue);

      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('onClose huỷ timer — không rò sang test sau', (tester) async {
      await _boot(tester, start: (c) => c.startSideMode(GameMode.timeAttack));
      ctrl.onClose();
      // Nếu timer còn sống, pump dưới đây sẽ làm scheduler báo pending timer.
      await tester.pump(const Duration(seconds: 5));
      expect(
        ctrl.remainingSeconds.value,
        GameScreenController.timeAttackSeconds,
      );
    });
  });
}
