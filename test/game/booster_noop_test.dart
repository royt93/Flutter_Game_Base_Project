import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// X23 — hợp đồng giữa [GameController] và [PopStarGame]: caller chỉ trừ
/// booster khi trigger trả `true`. `triggerSwap`/`shuffleBoard` từng trả `true`
/// cả khi bàn không đổi, nên booster bị nuốt cho thao tác vô hiệu.
Future<(PopStarGame, GameController)> _build(
  WidgetTester tester, {
  List<List<int>>? grid,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  final ctrl = Get.put(GameController(), permanent: true);
  // Bàn tự vẽ phải đi qua `startPuzzleLevel` để `currentLevel.rows/cols` khớp
  // kích thước grid — `startLevel(1)` giữ nguyên 8x6 của campaign và engine sẽ
  // đọc ngoài biên grid.
  if (grid == null) {
    ctrl.startLevel(1);
  } else {
    ctrl.startPuzzleLevel(grid);
  }
  final game = PopStarGame(ctrl, seed: 1, presetGrid: grid);
  await tester.pumpWidget(GetMaterialApp(home: GameWidget(game: game)));
  await tester.pump(const Duration(milliseconds: 100));
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  return (game, ctrl);
}

void main() {
  setUp(Get.reset);

  group('X23 swap cùng một ô', () {
    testWidgets('trả false, không tiêu booster, không tăng totalBoostersUsed', (
      tester,
    ) async {
      final (game, ctrl) = await _build(tester);
      ctrl.swapCount.value = 3;
      final usedBefore = ctrl.totalBoostersUsed.value;

      expect(game.triggerSwap(0, 0, 0, 0), isFalse);

      ctrl.useSwap(0, 0, 0, 0);
      expect(ctrl.swapCount.value, 3);
      expect(ctrl.totalBoostersUsed.value, usedBefore);
    });

    testWidgets('swap 2 ô khác nhau vẫn hoạt động bình thường', (tester) async {
      final (game, ctrl) = await _build(tester);
      ctrl.swapCount.value = 3;

      expect(game.triggerSwap(0, 0, 1, 1), isTrue);
      // Trigger trực tiếp ở trên không đi qua controller nên chưa trừ lượt;
      // xác nhận đường qua controller cũng trừ đúng 1.
      await tester.pump(const Duration(milliseconds: 400));
      ctrl.useSwap(2, 0, 3, 1);
      expect(ctrl.swapCount.value, 2);
    });
  });

  group('X23 shuffle không có gì để xáo', () {
    testWidgets('bàn chỉ còn 1 ô xáo được -> false, không tiêu booster', (
      tester,
    ) async {
      // Bàn 2x2: 1 ô màu thật, phần còn lại là obstacle (giá trị âm) nên
      // không nằm trong danh sách `movable`.
      final (game, ctrl) = await _build(
        tester,
        grid: const [
          [0, -1],
          [-1, -1],
        ],
      );
      ctrl.shuffleCount.value = 2;
      final usedBefore = ctrl.totalBoostersUsed.value;

      expect(game.shuffleBoard(), isFalse);

      ctrl.useShuffle();
      expect(ctrl.shuffleCount.value, 2);
      expect(ctrl.totalBoostersUsed.value, usedBefore);
    });

    testWidgets('mọi ô xáo được đều cùng màu -> false (bàn không thể đổi)', (
      tester,
    ) async {
      final (game, ctrl) = await _build(
        tester,
        grid: const [
          [0, 0],
          [0, 0],
        ],
      );
      ctrl.shuffleCount.value = 2;

      expect(
        game.shuffleBoard(),
        isFalse,
        reason:
            'mọi hoán vị đều cho ra bàn y hệt -> không được tính là đã dùng',
      );
      ctrl.useShuffle();
      expect(ctrl.shuffleCount.value, 2);
    });

    testWidgets('bàn bình thường -> shuffle vẫn chạy và trừ đúng 1 lượt', (
      tester,
    ) async {
      final (_, ctrl) = await _build(tester);
      ctrl.shuffleCount.value = 2;

      ctrl.useShuffle();
      expect(ctrl.shuffleCount.value, 1);
    });
  });

  group('X27 guard phòng thủ', () {
    testWidgets('mystery crate không đủ điều kiện -> không trừ xu', (
      tester,
    ) async {
      final (_, ctrl) = await _build(tester);
      // Chưa mở khoá cosmetic nào ngoài mặc định -> pool rỗng.
      ctrl.coins.value = 1000;

      final item = ctrl.rollMysteryCrate();

      if (item == null) {
        expect(
          ctrl.coins.value,
          1000,
          reason: 'roll thất bại thì không được trừ xu',
        );
      } else {
        expect(ctrl.coins.value, 1000 - GameController.mysteryCrateCost);
      }
    });

    testWidgets('unlockedLevel = 0 trong storage -> không crash, kẹp về 1', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({StorageKeys.unlockedLevel: 0});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final ctrl = Get.put(GameController(), permanent: true);

      expect(ctrl.unlockedLevel.value, 1);
      // Bản cũ: `currentWeekIndex % 0` -> ném IntegerDivisionByZeroException
      // ngay ở màn Home.
      expect(ctrl.featuredLevelId, greaterThanOrEqualTo(1));
      expect(() => ctrl.startWeeklyFeatured(), returnsNormally);
    });
  });
}
