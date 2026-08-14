import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/pop_detector.dart';
import 'package:pop_star_blast/logic/second_chance.dart';
import 'package:pop_star_blast/main.dart' as app;
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:pop_star_blast/presentation/screens/level_select_screen.dart';
import 'package:pop_star_blast/presentation/widgets/neon_dialog.dart';

/// Integration cho **luồng lõi kiếm/tiêu**: thắng màn, mua booster, dùng
/// booster, second chance, prestige — trên thiết bị thật.
///
/// Vì sao cần dù đã có 1666 unit test: hai bug nặng nhất session này ([[X29]]
/// buffer nuốt lần ghi thẳng, và `presetGrid` bỏ sót mode làm hai người chơi
/// hai bàn khác nhau) đều **xanh** dưới unit test. Unit test kiểm state trong
/// controller; đường thật còn có engine Flame, `_animating` khoá input,
/// `ever(gameCtrl.ended)` xen vào, và write-behind buffer của storage.
///
/// Nguyên tắc chung của file: **kiểm trên ĐĨA sau `flush()`**, không chỉ kiểm
/// biến trong bộ nhớ. Đó chính là chỗ X29 lọt.
///
/// Chạy: `flutter test integration_test/core_economy_test.dart -d <device>`
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

/// Đóng MỌI hộp thoại đang chắn màn, không riêng thưởng ngày.
///
/// Bản đầu chỉ đóng dialog thưởng ngày và đỏ ngẫu nhiên: các ca sau ca thắng
/// còn gặp dialog "mở khoá thành tựu" và mốc combo. Chúng dựng một
/// `AbsorbPointer` phủ toàn màn, nên `tap` vào nút PLAY trượt hit-test với
/// thông báo "another widget is obscuring it" — trông như lỗi layout chứ
/// không như lỗi test.
///
/// Đóng tối đa [rounds] lớp: một lần thắng có thể xếp chồng vài dialog.
Future<void> _dismissDialogs(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await _pumpBounded(tester, times: 4);
    final buttons = find.byType(NeonDialogButton);
    if (buttons.evaluate().isEmpty) return;
    // Nút cuối là nút đóng/xác nhận ở mọi dialog của app.
    await tester.tap(buttons.last, warnIfMissed: false);
  }
}

Future<GameController> _boot(WidgetTester tester) async {
  await app.app(withAudio: false);
  await _pumpBounded(tester, times: 15);
  await _dismissDialogs(tester);
  return Get.find<GameController>();
}

/// Vào màn 1 qua đúng luồng người chơi: Home -> PLAY -> ô màn 1.
Future<PopStarGame> _enterLevelOne(WidgetTester tester) async {
  // Ván trước có thể để lại dialog thành tựu/mốc combo phủ Home.
  await _dismissDialogs(tester);
  // Nhãn nút đi qua i18n (trước đây hardcode 'PLAY') — tra bảng dịch, đừng gõ
  // chuỗi tiếng Anh, máy test có thể đặt ngôn ngữ bất kỳ.
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

/// Chơi tham lam: mỗi nước nổ nhóm LỚN NHẤT còn lại, tới khi ván kết thúc.
///
/// Cùng chiến thuật mà `test/data/levels_achievability_test.dart` dùng để
/// chứng minh mọi màn đạt được `targetScore` — nên màn 1 phải thắng. Nếu ca
/// test dưới đỏ vì thua, đó là tín hiệu thật: hoặc target đã bị chỉnh, hoặc
/// engine không khớp mô hình thuần.
Future<void> _playGreedilyUntilEnd(
  WidgetTester tester,
  PopStarGame game,
  GameController ctrl, {
  int maxMoves = 120,
}) async {
  for (var i = 0; i < maxMoves && !ctrl.ended.value; i++) {
    final group = findLargestGroup(game.colorGrid, lockGrid: game.lockGrid);
    if (group.isNotEmpty && group.length >= 2) {
      final cell = group.first;
      game.handleTap(game.cellCenterFor(cell.x, cell.y));
      await _pumpBounded(tester, times: 6);
      continue;
    }
    // Hết nhóm >= 2 KHÔNG có nghĩa là hết nước. Power tile (F5a) kích hoạt
    // được dù đứng một mình, và `_checkEnd` của engine coi bàn còn power tile
    // là chưa kẹt — nên dừng ở đây thì ván không bao giờ kết thúc.
    //
    // Không đọc `_blocks` (private) để biết ô nào là power tile: cứ gõ lần
    // lượt mọi ô còn lại, ô thường sẽ không phản ứng.
    if (!await _tapEveryRemainingCell(tester, game)) break;
  }
  // Bàn hết nước mà `ended` chưa bật thì engine chưa kịp gọi `_checkEnd`.
  await _pumpBounded(tester, times: 10);
}

/// Gõ lần lượt mọi ô còn lại. Trả `true` nếu bàn có đổi (tức là còn nước đi).
Future<bool> _tapEveryRemainingCell(
  WidgetTester tester,
  PopStarGame game,
) async {
  int filled() =>
      game.colorGrid.expand((r) => r).where((v) => v != null).length;
  final before = filled();
  for (var r = 0; r < game.rows; r++) {
    for (var c = 0; c < game.cols; c++) {
      if (game.colorGrid[r][c] == null) continue;
      game.handleTap(game.cellCenterFor(r, c));
      await _pumpBounded(tester, times: 4);
      if (filled() < before) return true;
    }
  }
  return false;
}

int _diskInt(String key, {int def = -1}) =>
    StorageService.to.getInt(key, def: def);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('thắng màn 1 qua engine thật: xu/sao/unlock ghi xuống ĐĨA', (
    tester,
  ) async {
    final ctrl = await _boot(tester);
    final coinsBefore = ctrl.coins.value;
    final game = await _enterLevelOne(tester);

    await _playGreedilyUntilEnd(tester, game, ctrl);

    expect(ctrl.ended.value, isTrue, reason: 'ván phải kết thúc');
    expect(
      ctrl.starsEarned.value,
      greaterThan(0),
      reason:
          'chiến thuật tham lam phải thắng màn 1 — nếu thua thì '
          'targetScore đã bị chỉnh quá tay, xem levels_achievability_test',
    );

    await StorageService.to.flush();
    expect(
      _diskInt(StorageKeys.star(1)),
      ctrl.starsEarned.value,
      reason: 'sao phải nằm trên đĩa, không chỉ trong bộ nhớ ([[X29]])',
    );
    expect(
      _diskInt(StorageKeys.unlockedLevel),
      greaterThanOrEqualTo(2),
      // Không so bằng 2: máy test giữ save giữa các lần chạy, tiến độ có thể
      // đã xa hơn. Điều cần khẳng định là thắng màn 1 thì màn 2 phải mở.
    );
    expect(
      _diskInt(StorageKeys.coins),
      ctrl.coins.value,
      reason: 'xu trong bộ nhớ và trên đĩa phải khớp',
    );
    expect(
      ctrl.coins.value,
      greaterThan(coinsBefore),
      reason: 'thắng campaign phải được thưởng xu',
    );
    expect(
      _diskInt(StorageKeys.highScore(1)),
      greaterThanOrEqualTo(ctrl.score.value),
      // Cũng vì save cũ: lần chạy trước có thể đã đạt điểm cao hơn.
      reason: 'điểm cao của màn 1 phải được ghi',
    );
  });

  testWidgets('mua booster: trừ đúng giá, cộng đúng 1, cả hai xuống đĩa', (
    tester,
  ) async {
    final ctrl = await _boot(tester);
    // Đủ tiền để phép trừ có ý nghĩa; đây là setup save, không phải bỏ qua
    // đường mua — `buyBomb()` bên dưới vẫn là hàm thật.
    ctrl.coins.value = 5000;
    await StorageService.to.setInt(StorageKeys.coins, 5000);

    final price = ctrl.discountedPrice(GameController.bombPrice);
    final bombsBefore = ctrl.bombCount.value;

    expect(ctrl.buyBomb(), isTrue);
    await StorageService.to.flush();

    expect(ctrl.bombCount.value, bombsBefore + 1);
    expect(ctrl.coins.value, 5000 - price);
    expect(_diskInt(StorageKeys.bombCount), bombsBefore + 1);
    expect(_diskInt(StorageKeys.coins), 5000 - price);
  });

  testWidgets('hết xu thì không mua được, và không đụng gì cả', (tester) async {
    final ctrl = await _boot(tester);
    ctrl.coins.value = 0;
    await StorageService.to.setInt(StorageKeys.coins, 0);
    final bombsBefore = ctrl.bombCount.value;

    expect(ctrl.buyBomb(), isFalse);
    await StorageService.to.flush();

    // Mua hụt mà vẫn cộng booster (hoặc trừ xu âm) là lỗi kinh điển.
    expect(ctrl.bombCount.value, bombsBefore);
    expect(ctrl.coins.value, 0);
    expect(_diskInt(StorageKeys.bombCount), bombsBefore);
    expect(_diskInt(StorageKeys.coins), 0);
  });

  testWidgets('dùng bomb: trừ 1 trên đĩa VÀ thật sự xoá ô trên bàn', (
    tester,
  ) async {
    final ctrl = await _boot(tester);
    ctrl.coins.value = 5000;
    expect(ctrl.buyBomb(), isTrue);
    final bombsBefore = ctrl.bombCount.value;

    final game = await _enterLevelOne(tester);
    final filledBefore = game.colorGrid
        .expand((r) => r)
        .where((v) => v != null)
        .length;

    // Nổ giữa bàn để vùng 3x3 chắc chắn nằm trong lưới.
    ctrl.useBomb(game.rows ~/ 2, game.cols ~/ 2);
    await _pumpBounded(tester, times: 10);
    await StorageService.to.flush();

    expect(ctrl.bombCount.value, bombsBefore - 1);
    expect(_diskInt(StorageKeys.bombCount), bombsBefore - 1);
    final filledAfter = game.colorGrid
        .expand((r) => r)
        .where((v) => v != null)
        .length;
    expect(
      filledAfter,
      lessThan(filledBefore),
      reason: 'trừ booster mà bàn không đổi = người chơi mất tiền vô ích',
    );
  });

  testWidgets('second chance tính bằng XU — không quảng cáo, không IAP', (
    tester,
  ) async {
    final ctrl = await _boot(tester);
    ctrl.coins.value = 5000;
    final game = await _enterLevelOne(tester);

    // Chơi vài nước cho bàn vơi đi. Cần thật: `refillForSecondChance()` bồi
    // vào ô trống, bàn còn đầy 48 ô thì không bồi được gì và phần kiểm "bàn
    // phải dày lên" vô nghĩa — bản đầu của ca này vấp đúng chỗ đó.
    await _playGreedilyUntilEnd(tester, game, ctrl, maxMoves: 5);

    // Không chơi cho tới lúc thua: màn 1 quá dễ để thua thật. Bản đầu thử
    // "chơi phá" (chỉ nổ nhóm 2 ô) và vẫn ăn 3 sao — power tile sinh ra trong
    // lúc chơi tự cộng điểm. Thay vào đó ép đúng trạng thái thua rồi chạy
    // `_checkEnd` THẬT: đặt điểm trên ngưỡng chào cứu (kSecondChanceMinRatio
    // = 0.7 target) nhưng dưới target.
    final target = ctrl.currentLevel.targetScore;
    ctrl.score.value = (target * 0.8).round();
    ctrl.checkEnd(false);

    expect(ctrl.ended.value, isTrue);
    expect(ctrl.starsEarned.value, 0, reason: 'dưới target thì 0 sao');

    final filledBefore = game.colorGrid
        .expand((r) => r)
        .where((v) => v != null)
        .length;
    final coinsBefore = ctrl.coins.value;

    expect(ctrl.canBuySecondChance, isTrue);
    expect(ctrl.buySecondChance(), isTrue);
    await _pumpBounded(tester, times: 10);
    await StorageService.to.flush();

    // Không quảng cáo, không IAP: giá là XU, đúng kSecondChanceCost.
    expect(ctrl.coins.value, coinsBefore - kSecondChanceCost);
    expect(_diskInt(StorageKeys.coins), coinsBefore - kSecondChanceCost);
    expect(ctrl.ended.value, isFalse, reason: 'ván phải mở lại');
    expect(
      game.colorGrid.expand((r) => r).where((v) => v != null).length,
      greaterThan(filledBefore),
      reason: 'trả xu mà bàn không được bồi thì người chơi mất tiền vô ích',
    );
    // Mua lần hai trong cùng màn phải bị chặn.
    expect(ctrl.buySecondChance(), isFalse);
  });

  testWidgets('prestige: reset tiến độ, thưởng xu, GIỮ lịch sử màn cũ', (
    tester,
  ) async {
    final ctrl = await _boot(tester);
    final game = await _enterLevelOne(tester);
    await _playGreedilyUntilEnd(tester, game, ctrl);
    await StorageService.to.flush();

    final starBefore = _diskInt(StorageKeys.star(1));
    final highScoreBefore = _diskInt(StorageKeys.highScore(1));
    final tierBefore = ctrl.prestigeTier.value;
    final coinsBefore = ctrl.coins.value;

    expect(
      ctrl.canPrestige,
      isFalse,
      reason: 'chưa thắng màn cuối thì không được prestige',
    );
    ctrl.prestige();
    expect(
      ctrl.prestigeTier.value,
      tierBefore,
      reason: 'gọi prestige khi chưa đủ điều kiện phải là no-op',
    );

    // Bật cờ "đã phá đảo" thẳng trên controller: chơi hết 260 màn trong một
    // ca integration là bất khả thi. Phần được kiểm vẫn là `prestige()` thật.
    ctrl.allLevelsCompletedOnce.value = true;
    expect(ctrl.canPrestige, isTrue);

    ctrl.prestige();
    await StorageService.to.flush();

    expect(ctrl.prestigeTier.value, tierBefore + 1);
    expect(_diskInt(StorageKeys.prestigeTier), tierBefore + 1);
    expect(_diskInt(StorageKeys.unlockedLevel), 1);
    expect(ctrl.coins.value, coinsBefore + GameController.prestigeRewardCoins);
    expect(
      _diskInt(StorageKeys.coins),
      coinsBefore + GameController.prestigeRewardCoins,
    );
    // Prestige reset tiến độ, KHÔNG phạt lịch sử — sao và điểm cao giữ nguyên.
    expect(_diskInt(StorageKeys.star(1)), starBefore);
    expect(_diskInt(StorageKeys.highScore(1)), highScoreBefore);
  });
}
