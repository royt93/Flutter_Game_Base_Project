import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:pop_star_blast/presentation/widgets/star_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

/// I41: mirror kỹ thuật dồn combo của `combo_milestone_fx_test.dart` — mỗi
/// cột (trừ cột cuối) có 1 cặp dọc cùng màu riêng biệt ở 2 hàng đáy, cột
/// rỗng dồn trái sau mỗi lần nổ nên tap lặp lại đúng (rows-1, 0) luôn trúng
/// cặp kế tiếp còn sống.
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

void main() {
  testWidgets('mascot đổi mood đúng theo comboCount qua các mốc biên 2/4/5', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(21); // world 2: đủ cột cho 5 tap

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await _pumpFrames(tester, frames: 20); // chờ hết intro rơi ô

    final gsc = Get.find<GameScreenController>();
    final game = gsc.game;
    _fillComboColumns(game);

    StarMood moodOf() =>
        tester.widget<StarMascot>(find.byType(StarMascot)).mood;

    // combo 0 -> idle trước khi tap.
    expect(moodOf(), StarMood.idle);

    // Tap 1: combo 1 -> vẫn idle.
    game.handleTap(game.cellCenterFor(game.rows - 1, 0));
    await _pumpFrames(tester);
    expect(gameCtrl.comboCount.value, 1);
    expect(moodOf(), StarMood.idle);

    // Tap 2: combo 2 -> happy.
    game.handleTap(game.cellCenterFor(game.rows - 1, 0));
    await _pumpFrames(tester);
    expect(gameCtrl.comboCount.value, 2);
    expect(moodOf(), StarMood.happy);

    // Tap 3, 4: combo 4 -> vẫn happy.
    game.handleTap(game.cellCenterFor(game.rows - 1, 0));
    await _pumpFrames(tester);
    game.handleTap(game.cellCenterFor(game.rows - 1, 0));
    await _pumpFrames(tester);
    expect(gameCtrl.comboCount.value, 4);
    expect(moodOf(), StarMood.happy);

    // Tap 5: combo 5 -> cheer.
    game.handleTap(game.cellCenterFor(game.rows - 1, 0));
    await _pumpFrames(tester);
    expect(gameCtrl.comboCount.value, 5);
    expect(moodOf(), StarMood.cheer);

    Get.reset();
  });
}
