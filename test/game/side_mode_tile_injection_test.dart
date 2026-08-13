import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// X32 — side mode KHÔNG được bị chèn ô đặc biệt của campaign.
///
/// Phát hiện khi verify [[F18]] trên máy: bàn tự vẽ 9×8 hiện ra với **2 ô
/// khoá** mà người chơi không hề vẽ. Nguyên nhân:
///
/// ```dart
/// if (level.id % 6 != 0) return;   // _placeChainLocksIfNeeded
/// ```
///
/// `id % 6 == 0` đúng với cả số âm trong Dart, nên mọi side mode có id chia
/// hết cho 6 lọt qua cổng: `mirrorMode` (-6) và `puzzleDaily` (-18).
///
/// Với Mirror Mode thì nặng hơn F18: chain lock đặt ngẫu nhiên phá đúng tính
/// đối xứng vốn là toàn bộ lý do mode đó tồn tại.
late GameController ctrl;

Future<void> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

/// Dựng engine thật rồi đếm ô bị khoá.
Future<int> _lockedCells(WidgetTester tester) async {
  final game = PopStarGame(ctrl);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: GameWidget(game: game))),
  );
  await tester.pump(const Duration(milliseconds: 200));
  var n = 0;
  for (final row in game.lockGrid) {
    for (final v in row) {
      if (v > 0) n++;
    }
  }
  return n;
}

void main() {
  tearDown(Get.reset);

  testWidgets('Mirror Mode: không ô khoá nào bị chèn', (tester) async {
    await _boot();
    // Mirror Mode có hàm start riêng, KHÔNG đi qua `startSideMode` (hàm đó
    // rơi về `kZenLevel` cho mọi mode không liệt kê).
    ctrl.startMirrorMode();
    expect(ctrl.currentLevel.id, -6, reason: 'id này chia hết cho 6');

    expect(
      await _lockedCells(tester),
      0,
      reason: 'chain lock ngẫu nhiên phá tính đối xứng của Mirror Mode',
    );
  });

  testWidgets('Board of the Day: bàn tự vẽ giữ nguyên, không ô khoá', (
    tester,
  ) async {
    await _boot();
    expect(ctrl.startPuzzleDaily(), isTrue);
    expect(ctrl.currentLevel.id, -18);

    expect(
      await _lockedCells(tester),
      0,
      reason: 'bàn người chơi tự vẽ không được bị sửa',
    );
  });

  testWidgets('mọi side mode: không ô khoá nào', (tester) async {
    // Quét cả họ thay vì chỉ hai ca đã biết — id side mode mới thêm sau này
    // mà chia hết cho 6 sẽ đỏ ngay.
    final starters = <String, void Function()>{
      'timeAttack': () => ctrl.startSideMode(GameMode.timeAttack),
      'zen': () => ctrl.startSideMode(GameMode.zen),
      'comboRush': () => ctrl.startSideMode(GameMode.comboRush),
      'frostRush': () => ctrl.startSideMode(GameMode.frostRush),
      'mirrorMode': () => ctrl.startMirrorMode(),
      'dailyChallenge': () => ctrl.startDailyChallenge(),
      'puzzleDaily': () => ctrl.startPuzzleDaily(),
    };
    for (final entry in starters.entries) {
      await _boot();
      entry.value();
      expect(
        await _lockedCells(tester),
        0,
        reason:
            'mode ${entry.key} (id ${ctrl.currentLevel.id}) bị chèn ô khoá',
      );
      Get.reset();
    }
  });

  testWidgets('campaign VẪN có chain lock ở màn chia hết cho 6', (
    tester,
  ) async {
    // Chốt ngược: bản sửa không được vô hiệu hoá luôn cơ chế ở campaign.
    await _boot();
    ctrl.startLevel(6);

    expect(
      await _lockedCells(tester),
      greaterThan(0),
      reason: 'sửa quá tay thành tắt hẳn chain lock của campaign',
    );
  });

  testWidgets('campaign màn KHÔNG chia hết cho 6 -> không chain lock', (
    tester,
  ) async {
    await _boot();
    ctrl.startLevel(7);
    expect(await _lockedCells(tester), 0);
  });
}
