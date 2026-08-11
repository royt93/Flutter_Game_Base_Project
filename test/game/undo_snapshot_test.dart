import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/power_tile.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// X17/X20/X21 — `_saveUndo()` từng snapshot theo danh sách tay và danh sách
/// đó đã trôi lại phía sau 3 lần: counter ĐỜI (X17), power tile (X20), lượt
/// Freeze (X21). Test này khoá cả 3 lại.
///
/// Bàn dùng `presetGrid` cố định (không random) để mọi case dưới đây tất định:
/// hàng 0 là 6 ô cùng màu 0 (đủ lớn để sinh power tile, xem
/// [powerTileKindForGroupSize]), phần còn lại xen kẽ để vẫn có nhóm ≥2 khác
/// để tap mà không đụng hàng 0.
const _presetGrid = <List<int>>[
  [0, 0, 0, 0, 0, 0],
  [1, 1, 2, 2, 3, 3],
  [1, 1, 2, 2, 3, 3],
  [2, 2, 3, 3, 1, 1],
  [2, 2, 3, 3, 1, 1],
  [3, 3, 1, 1, 2, 2],
  [3, 3, 1, 1, 2, 2],
  [1, 1, 2, 2, 3, 3],
];

Future<(PopStarGame, GameController)> _buildGame(
  WidgetTester tester, {
  Map<String, Object>? initialPrefs,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs ?? {});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  final gameCtrl = Get.put(GameController(), permanent: true);
  gameCtrl.startLevel(1);
  final game = PopStarGame(gameCtrl, seed: 1, presetGrid: _presetGrid);
  await tester.pumpWidget(GetMaterialApp(home: GameWidget(game: game)));
  await tester.pump(const Duration(milliseconds: 100));
  // A6: chờ hết animation intro-rơi-ô, nếu không tap/undo đầu tiên bị
  // `_animating` chặn (cùng pattern booster_test/swap_freeze_test).
  await _settle(tester);
  return (game, gameCtrl);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> _tapCell(
  WidgetTester tester,
  PopStarGame game,
  int r,
  int c,
) async {
  game.handleTap(game.cellCenterFor(r, c));
  await _settle(tester);
}

void main() {
  setUp(Get.reset);

  group('X17 counter đời phải lùi theo undo', () {
    testWidgets('nổ → undo → counter đời trở về đúng mốc trước nước đi', (
      tester,
    ) async {
      final (game, ctrl) = await _buildGame(tester);
      final gemsBefore = ctrl.totalGemsPopped.value;
      final weeklyBefore = ctrl.weeklyGoalProgress.value;
      final clanWeekBefore = ctrl.clanContribWeek.value;
      final clanTotalBefore = ctrl.clanContribTotal.value;
      final questsBefore = List<int>.from(ctrl.dailyQuestProgress);

      await _tapCell(tester, game, 1, 0); // nhóm màu 1, 4 ô
      expect(
        ctrl.totalGemsPopped.value,
        greaterThan(gemsBefore),
        reason: 'pop phải cộng counter đời, nếu không test dưới vô nghĩa',
      );

      expect(game.undo(), isTrue);
      await _settle(tester);

      expect(ctrl.totalGemsPopped.value, gemsBefore);
      expect(ctrl.weeklyGoalProgress.value, weeklyBefore);
      expect(ctrl.clanContribWeek.value, clanWeekBefore);
      expect(ctrl.clanContribTotal.value, clanTotalBefore);
      expect(ctrl.dailyQuestProgress.toList(), questsBefore);
    });

    testWidgets('vòng farm "nổ → undo → nổ lại" 20 lần = đúng 1 lần nổ', (
      tester,
    ) async {
      final (game, ctrl) = await _buildGame(tester);
      final gemsStart = ctrl.totalGemsPopped.value;

      await _tapCell(tester, game, 1, 0);
      final gemsAfterOnePop = ctrl.totalGemsPopped.value;
      expect(game.undo(), isTrue);
      await _settle(tester);

      for (var i = 0; i < 20; i++) {
        await _tapCell(tester, game, 1, 0);
        expect(game.undo(), isTrue);
        await _settle(tester);
      }
      await _tapCell(tester, game, 1, 0);

      expect(
        ctrl.totalGemsPopped.value,
        gemsAfterOnePop,
        reason:
            '20 vòng nổ-undo-nổ lại phải cho ra counter bằng đúng 1 lần nổ, '
            'không phải 21 lần (đây chính là lỗ farm X17)',
      );
      expect(ctrl.totalGemsPopped.value, greaterThan(gemsStart));
    });

    testWidgets('maxComboEver lùi theo undo', (tester) async {
      final (game, ctrl) = await _buildGame(tester);
      expect(ctrl.maxComboEver.value, 0);

      await _tapCell(tester, game, 1, 0);
      expect(ctrl.maxComboEver.value, 1);

      expect(game.undo(), isTrue);
      await _settle(tester);
      expect(ctrl.maxComboEver.value, 0);
    });

    testWidgets(
      'achievement mở khoá trong nước bị undo: giữ xu, không trao lại',
      (tester) async {
        // Gieo 496 gem: nhóm 4 ô ở (1,0) đẩy qua đúng ngưỡng `gems_500`.
        final (game, ctrl) = await _buildGame(
          tester,
          initialPrefs: {StorageKeys.totalGemsPopped: 496},
        );
        expect(ctrl.totalGemsPopped.value, 496);
        final coinsBefore = ctrl.coins.value;

        await _tapCell(tester, game, 1, 0);
        expect(ctrl.totalGemsPopped.value, 500);
        expect(ctrl.unlockedAchievementIds, contains('gems_500'));
        final coinsAfterUnlock = ctrl.coins.value;
        expect(coinsAfterUnlock, greaterThan(coinsBefore));

        expect(game.undo(), isTrue);
        await _settle(tester);
        expect(ctrl.totalGemsPopped.value, 496);
        expect(
          ctrl.coins.value,
          coinsAfterUnlock,
          reason: 'xu đã trao thì không thu hồi (achievement giữ nguyên)',
        );
        expect(ctrl.unlockedAchievementIds, contains('gems_500'));

        // Nổ lại đúng nhóm đó: vượt ngưỡng lần nữa nhưng KHÔNG được trao xu lại.
        await _tapCell(tester, game, 1, 0);
        expect(ctrl.totalGemsPopped.value, 500);
        expect(
          ctrl.coins.value,
          coinsAfterUnlock,
          reason: 'đây là đường farm xu qua achievement — phải đóng',
        );
      },
    );

    testWidgets('undo sau bomb không lùi nhầm counter của lần pop trước', (
      tester,
    ) async {
      // Bomb gọi `_saveUndo()` nhưng KHÔNG gọi `registerPop` — nếu snapshot
      // counter được chụp trong `registerPop` thay vì trong `_saveUndo`, undo
      // sau bomb sẽ khôi phục nhầm về mốc của cú pop trước đó.
      final (game, ctrl) = await _buildGame(tester);
      await _tapCell(tester, game, 1, 0);
      final gemsAfterPop = ctrl.totalGemsPopped.value;

      expect(game.triggerBomb(5, 0), isTrue);
      await _settle(tester);
      expect(game.undo(), isTrue);
      await _settle(tester);

      expect(
        ctrl.totalGemsPopped.value,
        gemsAfterPop,
        reason: 'bomb không cộng counter nên undo bomb cũng không được trừ',
      );
    });
  });

  group('X20 power tile phải sống qua undo', () {
    testWidgets(
      'tạo power tile → nổ nhóm khác → undo → power tile còn nguyên',
      (tester) async {
        final (game, _) = await _buildGame(tester);

        // Hàng 0 có 6 ô cùng màu → pop sinh power tile tại đúng ô vừa tap.
        await _tapCell(tester, game, 0, 2);
        final kind = game.powerKindAt(0, 2);
        expect(
          kind,
          isNotNull,
          reason: 'nhóm 6 ô phải sinh power tile (powerTileKindForGroupSize)',
        );

        // Nổ một nhóm khác, không liên quan tới ô power tile.
        await _tapCell(tester, game, 5, 0);
        expect(game.undo(), isTrue);
        await _settle(tester);

        expect(
          game.powerKindAt(0, 2),
          kind,
          reason: 'undo nước đi khác không được xoá power tile đã có sẵn',
        );
      },
    );

    testWidgets('undo đúng nước tạo ra power tile thì power tile biến mất', (
      tester,
    ) async {
      final (game, _) = await _buildGame(tester);

      await _tapCell(tester, game, 0, 2);
      expect(game.powerKindAt(0, 2), isNotNull);

      expect(game.undo(), isTrue);
      await _settle(tester);

      expect(
        game.powerKindAt(0, 2),
        isNull,
        reason: 'nước tạo ra nó bị hoàn tác → power tile không được tồn tại',
      );
    });
  });

  group('X21 lượt Freeze phải lùi theo undo', () {
    testWidgets('freeze 5 lượt → pop (còn 4) → undo → về lại 5', (
      tester,
    ) async {
      final (game, _) = await _buildGame(tester);
      game.applyFreeze(5);
      expect(game.freezeTurnsLeft, 5);

      await _tapCell(tester, game, 1, 0);
      expect(
        game.freezeTurnsLeft,
        4,
        reason: 'mỗi pop khi Freeze bật phải trừ 1 lượt',
      );

      expect(game.undo(), isTrue);
      await _settle(tester);
      expect(game.freezeTurnsLeft, 5);
    });

    testWidgets('freeze còn 1 → pop (hết) → undo → còn 1, vẫn bảo vệ tiếp', (
      tester,
    ) async {
      final (game, _) = await _buildGame(tester);
      game.applyFreeze(1);

      await _tapCell(tester, game, 1, 0);
      expect(game.freezeTurnsLeft, 0);

      expect(game.undo(), isTrue);
      await _settle(tester);
      expect(game.freezeTurnsLeft, 1);
    });
  });
}
