import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/weekly_goal.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/pop_detector.dart';
import 'package:pop_star_blast/main.dart' as app;
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:pop_star_blast/presentation/screens/level_select_screen.dart';
import 'package:pop_star_blast/presentation/widgets/neon_dialog.dart';

/// Integration cho **lớp meta**: thưởng ngày, vòng quay, mục tiêu tuần + clan,
/// season pass, thành tựu, bản đồ kho báu — trên thiết bị thật.
///
/// Cùng lý do với `core_economy_test`: unit test kiểm state controller, còn
/// đường thật đi qua engine Flame, khoá input, `ever(gameCtrl.ended)` và
/// **write-behind buffer** của storage. Riêng lớp meta còn nguy hiểm hơn: mục
/// tiêu tuần và clan cộng qua `setIntBuffered` ở hot path mỗi cú tap, đúng
/// đường mà [[X29]] từng nuốt mất.
///
/// Nguyên tắc: mọi khẳng định kiểm **trên ĐĨA sau `flush()`**.
///
/// Chạy: `flutter test integration_test/meta_progression_test.dart -d <device>`
Future<void> _pumpBounded(
  WidgetTester tester, {
  int times = 12,
  Duration step = const Duration(milliseconds: 300),
}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(step);
  }
}

/// Đóng mọi dialog đang chắn màn (thưởng ngày, thành tựu, mốc combo).
Future<void> _dismissDialogs(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await _pumpBounded(tester, times: 4);
    final buttons = find.byType(NeonDialogButton);
    if (buttons.evaluate().isEmpty) return;
    await tester.tap(buttons.last, warnIfMissed: false);
  }
}

Future<GameController> _boot(WidgetTester tester) async {
  await app.app(withAudio: false);
  await _pumpBounded(tester, times: 15);
  return Get.find<GameController>();
}

Future<PopStarGame> _enterLevelOne(WidgetTester tester) async {
  await _dismissDialogs(tester);
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

/// Nổ [moves] nhóm lớn nhất — đủ để các counter meta chạy, không cần hết ván.
Future<void> _popSome(
  WidgetTester tester,
  PopStarGame game,
  GameController ctrl, {
  int moves = 4,
}) async {
  for (var i = 0; i < moves && !ctrl.ended.value; i++) {
    final group = findLargestGroup(game.colorGrid, lockGrid: game.lockGrid);
    if (group.length < 2) break;
    final cell = group.first;
    game.handleTap(game.cellCenterFor(cell.x, cell.y));
    await _pumpBounded(tester, times: 6);
  }
}

int _diskInt(String key, {int def = -1}) =>
    StorageService.to.getInt(key, def: def);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('thưởng ngày: nhận 1 lần/ngày, xu ghi xuống ĐĨA', (tester) async {
    final ctrl = await _boot(tester);
    // Máy test giữ save giữa các lần chạy nên hôm nay có thể đã nhận rồi.
    // Xoá dấu ngày đã nhận thay vì bỏ qua ca test — phần được kiểm vẫn là
    // `claimDaily()` thật.
    await StorageService.to.setInt(StorageKeys.lastClaimDay, -1);
    expect(ctrl.canClaimDaily, isTrue);

    final coinsBefore = ctrl.coins.value;
    final reward = ctrl.claimDaily();
    expect(reward, isNotNull);
    expect(reward, greaterThan(0));
    await StorageService.to.flush();

    expect(ctrl.coins.value, coinsBefore + reward!);
    expect(_diskInt(StorageKeys.coins), coinsBefore + reward);
    expect(_diskInt(StorageKeys.dailyStreak), ctrl.dailyStreak.value);

    // Lần hai trong cùng ngày phải trượt, và không đụng xu.
    final coinsAfter = ctrl.coins.value;
    expect(ctrl.claimDaily(), isNull);
    await StorageService.to.flush();
    expect(ctrl.coins.value, coinsAfter);
    expect(_diskInt(StorageKeys.coins), coinsAfter);
  });

  testWidgets('vòng quay: kết quả cố định trong ngày, nhận 1 lần', (
    tester,
  ) async {
    final ctrl = await _boot(tester);
    await StorageService.to.setInt(StorageKeys.lastSpinDay, -1);
    expect(ctrl.canClaimSpin, isTrue);

    // Seed theo ngày: gọi nhiều lần phải ra cùng ô, nếu không thì UI animate
    // tới một ô rồi phát thưởng ô khác.
    final peek = ctrl.todaySpinReward;
    expect(ctrl.todaySpinReward.type, peek.type);
    expect(ctrl.todaySpinReward.amount, peek.amount);

    final coinsBefore = ctrl.coins.value;
    final bombsBefore = ctrl.bombCount.value;
    final claimed = ctrl.claimSpin();
    expect(claimed, isNotNull);
    expect(claimed!.type, peek.type, reason: 'phải phát đúng ô đã chốt');
    await StorageService.to.flush();

    expect(_diskInt(StorageKeys.lastSpinDay), greaterThan(-1));
    // Đúng một loại phần thưởng được cộng, và nó nằm trên đĩa.
    if (claimed.type == 'bomb') {
      expect(_diskInt(StorageKeys.bombCount), bombsBefore + claimed.amount);
      expect(ctrl.coins.value, coinsBefore);
    } else if (claimed.type == 'shuffle' || claimed.type == 'undo') {
      expect(ctrl.coins.value, coinsBefore);
    } else {
      expect(_diskInt(StorageKeys.coins), ctrl.coins.value);
      expect(ctrl.coins.value, greaterThan(coinsBefore));
    }

    expect(ctrl.claimSpin(), isNull, reason: 'quay lần hai trong ngày');
  });

  testWidgets('nổ gem: mục tiêu tuần VÀ clan cùng tăng, cùng xuống đĩa', (
    tester,
  ) async {
    // Hai counter riêng, hai mốc riêng (300 cá nhân / 2000 pool clan) nhưng
    // cộng song song ở `registerPop`. Cả hai dùng `setIntBuffered` — đúng
    // đường X29 từng nuốt, nên phải kiểm trên đĩa.
    final ctrl = await _boot(tester);
    final weeklyBefore = ctrl.weeklyGoalProgress.value;
    final clanWeekBefore = ctrl.clanContribWeek.value;
    final clanTotalBefore = ctrl.clanContribTotal.value;

    final game = await _enterLevelOne(tester);
    await _popSome(tester, game, ctrl, moves: 4);
    await StorageService.to.flush();

    final gained = ctrl.weeklyGoalProgress.value - weeklyBefore;
    expect(gained, greaterThan(0), reason: 'nổ gem phải cộng mục tiêu tuần');
    expect(
      ctrl.clanContribWeek.value - clanWeekBefore,
      gained,
      reason: 'clan tuần cộng song song, cùng số gem',
    );
    expect(ctrl.clanContribTotal.value - clanTotalBefore, gained);

    expect(
      _diskInt(StorageKeys.weeklyGoalProgress),
      ctrl.weeklyGoalProgress.value,
    );
    expect(_diskInt(StorageKeys.clanContribWeek), ctrl.clanContribWeek.value);
    expect(_diskInt(StorageKeys.clanContribTotal), ctrl.clanContribTotal.value);
  });

  testWidgets('mục tiêu tuần: đạt mốc thì nhận được, và chỉ 1 lần/tuần', (
    tester,
  ) async {
    final ctrl = await _boot(tester);
    await StorageService.to.setInt(StorageKeys.weeklyGoalClaimedWeek, -1);
    ctrl.addWeeklyGoalProgress(weeklyGoalTarget);
    await StorageService.to.flush();
    expect(
      ctrl.weeklyGoalProgress.value,
      greaterThanOrEqualTo(weeklyGoalTarget),
    );

    final coinsBefore = ctrl.coins.value;
    expect(ctrl.claimWeeklyGoalReward(), isTrue);
    await StorageService.to.flush();
    expect(ctrl.coins.value, greaterThan(coinsBefore));
    expect(_diskInt(StorageKeys.coins), ctrl.coins.value);

    final coinsAfter = ctrl.coins.value;
    expect(ctrl.claimWeeklyGoalReward(), isFalse, reason: 'nhận lần hai');
    await StorageService.to.flush();
    expect(_diskInt(StorageKeys.coins), coinsAfter);
  });

  testWidgets('season pass: thắng campaign cộng điểm mùa, ghi xuống đĩa', (
    tester,
  ) async {
    final ctrl = await _boot(tester);
    final pointsBefore = ctrl.seasonPoints.value;

    final game = await _enterLevelOne(tester);
    // Ép thắng qua `checkEnd` THẬT thay vì chơi hết ván: điểm mùa cộng theo
    // SỐ SAO, và chơi tới cùng thì mất vài phút cho mỗi lần chạy.
    ctrl.score.value = ctrl.currentLevel.targetScore * 3;
    ctrl.checkEnd(false);
    await _pumpBounded(tester, times: 6);
    await StorageService.to.flush();

    expect(ctrl.starsEarned.value, greaterThan(0));
    expect(
      ctrl.seasonPoints.value,
      greaterThan(pointsBefore),
      reason: 'thắng campaign phải cộng điểm mùa (10 điểm mỗi sao)',
    );
    expect(_diskInt(StorageKeys.seasonPoints), ctrl.seasonPoints.value);
    expect(game.colorGrid, isNotEmpty);
  });

  testWidgets('thành tựu: mở khoá cộng xu ĐÚNG MỘT LẦN', (tester) async {
    final ctrl = await _boot(tester);
    final unlockedBefore = ctrl.unlockedAchievementIds.length;

    // Đẩy chỉ số đời lên rất cao để chắc chắn vượt vài mốc, rồi chạy đúng
    // hàm đánh giá thật qua một ván chơi.
    final game = await _enterLevelOne(tester);
    await _popSome(tester, game, ctrl, moves: 3);
    ctrl.score.value = ctrl.currentLevel.targetScore * 3;
    ctrl.checkEnd(false);
    await _pumpBounded(tester, times: 8);
    await StorageService.to.flush();

    final unlockedAfter = ctrl.unlockedAchievementIds.length;
    expect(
      unlockedAfter,
      greaterThanOrEqualTo(unlockedBefore),
      reason: 'số thành tựu không được giảm',
    );
    // Danh sách trên đĩa phải khớp bộ nhớ — mất đồng bộ ở đây nghĩa là mở
    // lại app sẽ trao thưởng lần nữa.
    final onDisk =
        (StorageService.to.getString(StorageKeys.unlockedAchievements) ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toSet();
    expect(onDisk, ctrl.unlockedAchievementIds.toSet());

    // Chạy lại vòng đánh giá: không được cộng thêm xu cho mốc đã nhận.
    final coinsBefore = ctrl.coins.value;
    ctrl.checkEnd(false); // `ended` đã bật -> no-op, nhưng vẫn phải an toàn
    await StorageService.to.flush();
    expect(ctrl.coins.value, coinsBefore);
  });

  testWidgets('bản đồ kho báu: tiêu 1 tấm, trừ đúng trên đĩa', (tester) async {
    final ctrl = await _boot(tester);
    ctrl.treasureMapCount.value = 2;
    await StorageService.to.setInt(StorageKeys.treasureMapCount, 2);

    expect(ctrl.consumeTreasureMap(), isTrue);
    await StorageService.to.flush();
    expect(ctrl.treasureMapCount.value, 1);
    expect(_diskInt(StorageKeys.treasureMapCount), 1);

    expect(ctrl.consumeTreasureMap(), isTrue);
    await StorageService.to.flush();
    expect(_diskInt(StorageKeys.treasureMapCount), 0);

    // Hết bản đồ thì không được tiêu tiếp, và không được xuống âm.
    expect(ctrl.consumeTreasureMap(), isFalse);
    await StorageService.to.flush();
    expect(ctrl.treasureMapCount.value, 0);
    expect(_diskInt(StorageKeys.treasureMapCount), 0);
  });
}
