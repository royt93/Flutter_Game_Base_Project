import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

/// I39: đặt mỗi cột (trừ cột cuối) 1 cặp dọc cùng màu riêng biệt ở 2 hàng đáy
/// — cột nào cũng khác màu cột kề nên không gộp nhóm ngang. Sau mỗi lần nổ,
/// cột rỗng dồn trái ([applyGravityAndCollapse]) nên tap lặp lại đúng
/// (rows-1, 0) luôn trúng cặp kế tiếp còn sống, không cần tính lại toạ độ.
void _fillComboColumns(PopStarGame game) {
  final rows = game.rows;
  final cols = game.cols;
  final grid = List.generate(rows, (_) => List<int?>.filled(cols, null));
  for (var c = 0; c < cols; c++) {
    grid[rows - 2][c] = c;
    grid[rows - 1][c] = c;
  }
  game.colorGrid = grid;
  game.onGameResize(game.size);
}

Future<GameController> _setUpGame(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  await StorageService.to.setBool(StorageKeys.reduceMotion, reduceMotion);
  final gameCtrl = Get.put(GameController(), permanent: true);
  gameCtrl.startLevel(21); // world 2: rows 9, cols 8 (đủ cột cho 6 lần tap)

  await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
  await tester.pump(const Duration(milliseconds: 100));
  await _pumpFrames(tester, frames: 20); // chờ hết intro rơi ô

  final gsc = Get.find<GameScreenController>();
  final game = gsc.game;
  _fillComboColumns(game);

  // Tap cột 0 lặp lại 6 lần: mốc 5 chạm ở lần 5, lần 6 (không phải mốc) xác
  // nhận không trigger thêm. Còn 2 cột chưa tap → bàn không sạch, tránh
  // side-effect win/checkEnd xen vào giữa chuỗi combo.
  for (var i = 0; i < 6; i++) {
    game.handleTap(game.cellCenterFor(game.rows - 1, 0));
    await _pumpFrames(tester);
  }

  return gameCtrl;
}

void main() {
  testWidgets('combo chạm mốc 5 trigger đúng 1 lần, mốc 6 (ngoài danh sách) '
      'không trigger thêm', (tester) async {
    final gameCtrl = await _setUpGame(tester);

    expect(gameCtrl.comboCount.value, 6);
    expect(gameCtrl.comboMilestoneTick.value, 1);
    expect(gameCtrl.comboMilestoneValue, 5);

    Get.reset();
  });

  testWidgets(
    'reduce-motion bật: overlay không hiện text COMBO nhưng tick milestone '
    'vẫn trigger độc lập (haptic tách khỏi animation)',
    (tester) async {
      final gameCtrl = await _setUpGame(tester, reduceMotion: true);

      // Trigger nằm ở pop_star_game.dart, không phụ thuộc _reduceMotion —
      // đây là điểm gọi fireHaptic độc lập với việc overlay UI có vẽ hay
      // không.
      expect(gameCtrl.comboMilestoneTick.value, 1);
      expect(gameCtrl.comboMilestoneValue, 5);

      // Overlay UI phải tự tắt animation khi reduce-motion bật.
      expect(find.textContaining('COMBO'), findsNothing);

      Get.reset();
    },
  );
}
