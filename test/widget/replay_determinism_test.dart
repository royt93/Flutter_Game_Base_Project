import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I28 (audit fix): màn dàn sẵn để tay tạo đúng chuỗi sự kiện tiêu thụ `_rng`
/// theo thứ tự — (1) nổ cặp màu 0 ở đáy cột 0 → gift ở (1,0) rơi xuống đáy +
/// tự mở (`pickGiftReward` tiêu thụ 1 draw), (2) nổ nhóm 6 ô màu 9 ở hàng 0
/// → sinh power tile, `powerTileKindForGroupSize` gọi `_rng.nextBool()` chọn
/// lineRow/lineCol — draw này lệch pha nếu bug cũ (gift chỉ tiêu thụ rng khi
/// `!isReplay`) còn tồn tại, vì record/replay sẽ chọn kind khác nhau. (3) tap
/// lại đúng ô đó để kích hoạt power tile — lineRow/lineCol xoá 2 vùng khác
/// hẳn nhau nên khuếch đại sai lệch RNG (nếu có) thành khác biệt rõ trên
/// colorGrid cuối, không cần biết trước thứ tự draw thật của `Random`.
final PopLevel _giftPowerLevel = PopLevel(
  id: 1,
  rows: 4,
  cols: 8,
  colorCount: 10,
  targetScore: 999999,
);

List<List<int>> _giftPowerPresetGrid() => [
  [7, 9, 9, 9, 9, 9, 9, 3],
  [-1000, 4, 4, 4, 4, 4, 4, 8],
  [0, 5, 5, 5, 5, 5, 5, 2],
  [0, 6, 6, 6, 6, 6, 6, 1],
];

/// I28: regression chống RNG không xác định lọt lại — cùng 1 seed phải luôn
/// tái tạo y hệt board (bao gồm khởi tạo colorGrid, power tile, gift reward)
/// dù chạy `PopStarGame` bao nhiêu lần, vì mã ghost-replay chỉ chứa
/// (levelId, seed, taps) chứ không chứa board — nếu RNG lệch, replay ra board
/// khác lúc ghi thì vô nghĩa.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

class _Snapshot {
  _Snapshot(this.grid, this.score);
  final List<List<int?>> grid;
  final int score;
}

/// Dựng 1 `PopStarGame` với [seed] cố định (dùng `GameController` throwaway,
/// không đăng ký GetX permanent — tránh đụng singleton thật giữa 2 lần
/// chạy), tap theo đúng 1 chuỗi cố định, rồi chụp lại trạng thái cuối.
Future<_Snapshot> _runSeeded(
  WidgetTester tester,
  int seed, {
  bool isReplay = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  final gameCtrl = GameController();
  gameCtrl.currentLevelRx.value = kLevels[0];
  final game = PopStarGame(gameCtrl, seed: seed, isReplay: isReplay);

  await tester.pumpWidget(GetMaterialApp(home: GameWidget(game: game)));
  await tester.pump(const Duration(milliseconds: 100));
  await _pumpFrames(tester, frames: 20); // chờ hết intro rơi ô

  final cellSize = game.cellSize;
  final boardLeft = (game.size.x - game.cols * cellSize) / 2;
  final boardTop = (game.size.y - game.rows * cellSize) / 2;
  Vector2 centerOf(int row, int col) => Vector2(
    boardLeft + col * cellSize + cellSize / 2,
    boardTop + row * cellSize + cellSize / 2,
  );

  // Chuỗi tap cố định, không ép lưới thủ công — để RNG khởi tạo board tự
  // nhiên chịu trách nhiệm toàn bộ, đúng tinh thần seed quyết định mọi thứ.
  for (final (r, c) in const [(0, 0), (2, 1), (4, 3), (0, 5)]) {
    game.handleTap(centerOf(r, c));
    await _pumpFrames(tester);
  }

  final snapshot = _Snapshot(
    game.colorGrid.map((row) => List<int?>.of(row)).toList(),
    gameCtrl.score.value,
  );
  Get.reset();
  return snapshot;
}

/// Dựng [_giftPowerLevel]/[_giftPowerPresetGrid] với [seed] cố định, chạy
/// đúng chuỗi 3 tap mô tả ở trên (không phụ thuộc thứ tự draw thật của
/// `Random`, chỉ cần record/replay tiêu thụ `_rng` đối xứng), rồi chụp lại
/// colorGrid cuối cùng.
Future<_Snapshot> _runGiftPowerScenario(
  WidgetTester tester, {
  required int seed,
  required bool isReplay,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  final gameCtrl = GameController();
  gameCtrl.currentLevelRx.value = _giftPowerLevel;
  final game = PopStarGame(
    gameCtrl,
    seed: seed,
    isReplay: isReplay,
    presetGrid: _giftPowerPresetGrid(),
  );

  await tester.pumpWidget(GetMaterialApp(home: GameWidget(game: game)));
  await tester.pump(const Duration(milliseconds: 100));
  await _pumpFrames(tester, frames: 20);

  final cellSize = game.cellSize;
  final boardLeft = (game.size.x - game.cols * cellSize) / 2;
  final boardTop = (game.size.y - game.rows * cellSize) / 2;
  Vector2 centerOf(int row, int col) => Vector2(
    boardLeft + col * cellSize + cellSize / 2,
    boardTop + row * cellSize + cellSize / 2,
  );

  game.handleTap(centerOf(3, 0)); // (1) nổ cặp 0 → gift rơi đáy + tự mở.
  await _pumpFrames(tester);
  game.handleTap(centerOf(0, 3)); // (2) nổ nhóm 6 màu 9 → sinh power tile.
  await _pumpFrames(tester);
  game.handleTap(centerOf(0, 3)); // (3) kích hoạt power tile vừa sinh.
  await _pumpFrames(tester);

  final snapshot = _Snapshot(
    game.colorGrid.map((row) => List<int?>.of(row)).toList(),
    gameCtrl.score.value,
  );
  Get.reset();
  return snapshot;
}

void main() {
  testWidgets(
    'I28: gift reward tiêu thụ RNG đối xứng giữa ghi (isReplay=false) và '
    'phát lại (isReplay=true) cùng seed+taps → board cuối phải giống hệt '
    'nhau (regression cho bug audit: pickGiftReward từng chỉ bốc rng khi '
    '!isReplay, làm lệch pha các draw kế tiếp)',
    (tester) async {
      const seed = 777;
      final recorded = await _runGiftPowerScenario(
        tester,
        seed: seed,
        isReplay: false,
      );
      final replayed = await _runGiftPowerScenario(
        tester,
        seed: seed,
        isReplay: true,
      );

      expect(replayed.grid, recorded.grid);
    },
  );

  testWidgets(
    'I28: cùng seed chạy 2 lần qua PopStarGame → colorGrid + score cuối '
    'giống hệt nhau (chống RNG không xác định)',
    (tester) async {
      const seed = 424242;
      final a = await _runSeeded(tester, seed);
      final b = await _runSeeded(tester, seed);

      expect(a.grid, b.grid);
      expect(a.score, b.score);
    },
  );

  testWidgets(
    'I28 (audit fix): ghi (isReplay=false) và phát lại (isReplay=true) cùng '
    'seed + chuỗi tap trên board random thật (không preset, khác chuỗi tap '
    'dàn sẵn ở scenario gift/power trên) → colorGrid cuối giống hệt nhau. '
    // Không so score: isReplay=true cố tình không cộng điểm qua controller
    // (xem PopStarGame._tryPop) nên score luôn 0 ở nhánh replay — đúng thiết
    // kế "chỉ xem", không phải bug.
    'Khép gap: trước đây chỉ có regression test cho scenario gift/power dàn '
    'sẵn, chưa có test nào so record-vs-replay trên board random thật.',
    (tester) async {
      const seed = 909090;
      final recorded = await _runSeeded(tester, seed, isReplay: false);
      final replayed = await _runSeeded(tester, seed, isReplay: true);

      expect(replayed.grid, recorded.grid);
    },
  );

  testWidgets(
    'I28: seed khác nhau (xác suất cao) → board khởi tạo khác nhau, xác '
    'nhận seed thực sự chi phối kết quả chứ không phải hằng số ẩn',
    (tester) async {
      final a = await _runSeeded(tester, 1);
      final b = await _runSeeded(tester, 2);

      expect(a.grid, isNot(equals(b.grid)));
    },
  );
}
