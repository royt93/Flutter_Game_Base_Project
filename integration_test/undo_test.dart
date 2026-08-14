import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/pop_detector.dart';
import 'package:pop_star_blast/main.dart' as app;
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:pop_star_blast/presentation/screens/level_select_screen.dart';

/// Integration cho [X17]/[X20]/[X21] — **Undo trên thiết bị thật**.
///
/// Unit test gọi thẳng `game.undo()` với `PopStarGame` dựng trong widget
/// harness. Đường thật còn có: animation Flame chạy tới nơi, `_animating`
/// khoá input, `GameScreenController` nối nút Undo, và `ever(gameCtrl.ended)`
/// có thể xen vào giữa. Bug ở tầng đó unit test không thấy.
///
/// Chạy: `flutter test integration_test/undo_test.dart -d <device>`
Future<void> _pumpBounded(
  WidgetTester tester, {
  int times = 12,
  Duration step = const Duration(milliseconds: 300),
}) async {
  // Không pumpAndSettle: StarMascot chạy animation lặp vô hạn.
  for (var i = 0; i < times; i++) {
    await tester.pump(step);
  }
}

Future<void> _dismissDialogIfShown(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    final dialog = find.byType(Dialog);
    if (dialog.evaluate().isEmpty) continue;
    final claim = find.descendant(
      of: dialog,
      matching: find.text('daily_claim'.tr),
    );
    if (claim.evaluate().isNotEmpty) {
      await tester.tap(claim.first);
      await _pumpBounded(tester, times: 4);
      return;
    }
  }
}

/// Vào màn 1 qua đúng luồng người chơi: Home -> PLAY -> level 1.
Future<PopStarGame> _enterLevelOne(WidgetTester tester) async {
  await app.app(withAudio: false);
  await _pumpBounded(tester, times: 15);
  await _dismissDialogIfShown(tester);

  // Home cuộn được từ I84 (NextUpBar đẩy nội dung xuống), nên trên máy màn
  // ngắn nút PLAY nằm dưới mép — tap thẳng sẽ trượt hit-test.
  // Nhãn nút đi qua i18n (trước đây hardcode 'PLAY') — tra bảng dịch, đừng
  // gõ chuỗi tiếng Anh.
  final play = find.text('play_now'.tr.toUpperCase()).first;
  await tester.ensureVisible(play);
  await _pumpBounded(tester, times: 3);
  await tester.tap(play);
  await _pumpBounded(tester, times: 6);
  expect(find.byType(LevelSelectScreen), findsOneWidget);

  await tester.tap(find.byKey(const Key('level_tile_1')));
  await _pumpBounded(tester, times: 8);
  expect(find.byType(GameScreen), findsOneWidget);

  return tester
      .widget<GameWidget<PopStarGame>>(find.byType(GameWidget<PopStarGame>))
      .game!;
}

/// Tap một ô có nhóm >= 2 để chắc chắn nổ được. Trả `null` nếu không tìm ra.
Future<Point<int>?> _tapAnyPoppableCell(
  WidgetTester tester,
  PopStarGame game,
) async {
  for (var r = 0; r < game.rows; r++) {
    for (var c = 0; c < game.cols; c++) {
      final group = findConnectedGroup(game.colorGrid, r, c);
      if (group.length >= 2) {
        game.handleTap(game.cellCenterFor(r, c));
        await _pumpBounded(tester, times: 6);
        return Point(r, c);
      }
    }
  }
  return null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('undo khôi phục bàn và điểm về đúng trước nước đi', (
    tester,
  ) async {
    final game = await _enterLevelOne(tester);
    final gameCtrl = Get.find<GameController>();

    final boardBefore = game.colorGrid.map((r) => List<int?>.from(r)).toList();
    final scoreBefore = gameCtrl.score.value;

    final tapped = await _tapAnyPoppableCell(tester, game);
    expect(tapped, isNotNull, reason: 'bàn mới phải có ít nhất 1 nhóm nổ được');
    expect(
      gameCtrl.score.value,
      greaterThan(scoreBefore),
      reason: 'pop phải cộng điểm, nếu không phần undo bên dưới vô nghĩa',
    );

    expect(game.undo(), isTrue);
    await _pumpBounded(tester, times: 8);

    expect(gameCtrl.score.value, scoreBefore);
    expect(
      game.colorGrid,
      equals(boardBefore),
      reason: 'bàn phải trở lại y hệt, từng ô một',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('X17: counter đời lùi theo undo, không farm được', (
    tester,
  ) async {
    final game = await _enterLevelOne(tester);
    final gameCtrl = Get.find<GameController>();

    final gemsBefore = gameCtrl.totalGemsPopped.value;
    final weeklyBefore = gameCtrl.weeklyGoalProgress.value;
    final clanBefore = gameCtrl.clanContribTotal.value;

    await _tapAnyPoppableCell(tester, game);
    expect(gameCtrl.totalGemsPopped.value, greaterThan(gemsBefore));

    expect(game.undo(), isTrue);
    await _pumpBounded(tester, times: 8);

    expect(
      gameCtrl.totalGemsPopped.value,
      gemsBefore,
      reason: 'vòng nổ-undo-nổ lại từng bơm được achievement/quest/clan',
    );
    expect(gameCtrl.weeklyGoalProgress.value, weeklyBefore);
    expect(gameCtrl.clanContribTotal.value, clanBefore);

    // Và giá trị đã lùi phải xuống ĐĨA, không chỉ trong bộ nhớ.
    await StorageService.to.flush();
    expect(StorageService.to.getInt(StorageKeys.totalGemsPopped), gemsBefore);
  });

  testWidgets('X21: undo trả lại lượt Freeze đã tiêu', (tester) async {
    final game = await _enterLevelOne(tester);

    game.applyFreeze(5);
    expect(game.freezeTurnsLeft, 5);

    await _tapAnyPoppableCell(tester, game);
    expect(
      game.freezeTurnsLeft,
      lessThan(5),
      reason: 'mỗi pop khi Freeze bật phải trừ 1 lượt',
    );

    expect(game.undo(), isTrue);
    await _pumpBounded(tester, times: 8);
    expect(game.freezeTurnsLeft, 5);
  });

  testWidgets('lặp nổ-undo nhiều lần vẫn ổn định, không rò state', (
    tester,
  ) async {
    final game = await _enterLevelOne(tester);
    final gameCtrl = Get.find<GameController>();

    final boardBefore = game.colorGrid.map((r) => List<int?>.from(r)).toList();
    final gemsBefore = gameCtrl.totalGemsPopped.value;

    for (var i = 0; i < 5; i++) {
      await _tapAnyPoppableCell(tester, game);
      expect(game.undo(), isTrue);
      await _pumpBounded(tester, times: 6);
    }

    expect(game.colorGrid, equals(boardBefore));
    expect(gameCtrl.score.value, 0);
    expect(gameCtrl.totalGemsPopped.value, gemsBefore);
    expect(tester.takeException(), isNull);
  });
}
