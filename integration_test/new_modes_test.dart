import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/daily_challenge.dart';
import 'package:pop_star_blast/logic/mirror_draft.dart';
import 'package:pop_star_blast/logic/replay.dart';
import 'package:pop_star_blast/main.dart' as app;
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';

/// Integration cho 3 mode mới của Round 9 — **trên thiết bị thật**.
///
/// Vì sao cần: hai bug nặng nhất đợt này chỉ lộ ra ở tầng engine thật.
/// [[X29]] (buffer nuốt lần ghi thẳng) và lỗi `presetGrid` (duel hai người
/// chơi hai bàn khác nhau) đều **xanh** ở unit test — unit test chỉ kiểm
/// `puzzleLabGrid` trong controller, còn engine dựng bàn theo đường khác.
///
/// Ở đây đi qua đúng đường người chơi đi: `app.app()` → controller thật →
/// `GameScreen` thật → `PopStarGame` thật.
///
/// Chạy: `flutter test integration_test/new_modes_test.dart -d <device>`
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

/// Khởi động app thật rồi trả về controller đã đăng ký.
Future<GameController> _launch(WidgetTester tester) async {
  await app.app(withAudio: false);
  await _pumpBounded(tester, times: 15);
  return Get.find<GameController>();
}

/// Đưa vào `GameScreen` sau khi controller đã chọn mode — bỏ qua phần điều
/// hướng menu (đã có `lifecycle_test` lo), tập trung vào engine.
///
/// Dùng `Get.to` chứ KHÔNG `pumpWidget`: `app.app()` đã dựng `GetMaterialApp`
/// riêng, pump thêm một cái nữa thay cả cây và `GameWidget` không bao giờ mount
/// (bản đầu làm vậy và 4/6 ca chết ở `Bad state: No element`).
Future<PopStarGame> _openGameScreen(WidgetTester tester) async {
  unawaited(Get.to(() => const GameScreen()));
  await _pumpBounded(tester, times: 14);
  final finder = find.byType(GameWidget<PopStarGame>);
  expect(finder, findsOneWidget, reason: 'GameScreen chưa dựng xong');
  return tester.widget<GameWidget<PopStarGame>>(finder).game!;
}

int _filled(PopStarGame g) =>
    g.colorGrid.expand((r) => r).where((v) => v != null).length;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ghost Duel: bàn engine ĐÚNG bàn từ seed', (tester) async {
    // Đây chính là lỗi đã lọt: `presetGrid` không liệt kê `GameMode.duel` nên
    // engine tự sinh bàn ngẫu nhiên — hai người chơi hai bàn khác nhau.
    final ctrl = await _launch(tester);
    const duel = DuelData(
      seed: 4242,
      taps: [(8, 0), (8, 1)],
      score: 640,
      senderName: 'Roy',
    );
    expect(ctrl.startDuel(duel), isTrue);

    final game = await _openGameScreen(tester);

    expect(
      game.colorGrid,
      equals(generateDailyChallengeGrid(4242)),
      reason: 'bàn engine phải khớp bàn sinh từ seed, từng ô một',
    );
    expect(ctrl.mode.value, GameMode.duel);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ghost Duel: điểm ghost chạy theo số nước đi', (tester) async {
    final ctrl = await _launch(tester);
    ctrl.startDuel(
      const DuelData(
        seed: 4242,
        taps: [(8, 0), (8, 1), (7, 0)],
        score: 640,
        senderName: 'Roy',
      ),
    );
    final game = await _openGameScreen(tester);

    expect(ctrl.ghostScoreNow, 0, reason: 'chưa đi nước nào');

    // Nổ một nhóm bất kỳ.
    var tapped = false;
    for (var r = 0; r < game.rows && !tapped; r++) {
      for (var c = 0; c < game.cols; c++) {
        if (findConnectedGroupSize(game.colorGrid, r, c) >= 2) {
          game.handleTap(game.cellCenterFor(r, c));
          await _pumpBounded(tester, times: 8);
          tapped = true;
          break;
        }
      }
    }
    expect(tapped, isTrue);
    expect(ctrl.movesUsed.value, greaterThan(0));
    expect(
      ctrl.ghostScoreNow,
      ctrl.ghostTimeline.isEmpty ? 0 : ctrl.ghostTimeline.first,
      reason: 'sau nước đầu tiên, điểm ghost phải là mốc đầu của timeline',
    );
  });

  testWidgets('Mirror Draft: bàn đối xứng và tap nổ cả nửa gương', (
    tester,
  ) async {
    final ctrl = await _launch(tester);
    ctrl.startMirrorDraft();
    final game = await _openGameScreen(tester);

    // Đối xứng lúc mới dựng.
    for (final row in game.colorGrid) {
      for (var c = 0; c < game.cols ~/ 2; c++) {
        expect(row[c], row[game.cols - 1 - c]);
      }
    }

    // Tìm nước nổ được cả hai nửa rồi kiểm số ô mất đi.
    ({int r, int c, int tapped, int total})? move;
    for (var r = 0; r < game.rows && move == null; r++) {
      for (var c = 0; c < game.cols ~/ 2; c++) {
        final d = mirrorDraftCells(game.colorGrid, r, c);
        if (d.isValid && d.mirroredToo) {
          move = (
            r: r,
            c: c,
            tapped: d.tappedCells.length,
            total: d.allCells.length,
          );
          break;
        }
      }
    }
    expect(move, isNotNull, reason: 'bàn gương mới sinh phải có nước gương');

    final before = _filled(game);
    game.handleTap(game.cellCenterFor(move!.r, move.c));
    await _pumpBounded(tester, times: 10);

    final removed = before - _filled(game);
    expect(
      removed,
      greaterThan(move.tapped),
      reason: 'phải nổ cả nhóm gương, không chỉ nhóm vừa tap',
    );
    // Nhóm gộp >= 5 giữ lại 1 ô làm power tile (F5).
    expect(removed, greaterThanOrEqualTo(move.total - 1));
    expect(ctrl.lastMirrorMirrored, isTrue);
  });

  testWidgets('Bàn hôm nay: cùng ngày ra cùng bàn, thưởng 1 lần', (
    tester,
  ) async {
    final ctrl = await _launch(tester);
    expect(ctrl.startPuzzleDaily(), isTrue);
    final first = ctrl.puzzleLabGrid;

    final game = await _openGameScreen(tester);
    expect(
      game.colorGrid.map((r) => r.map((v) => v ?? 0).toList()).toList(),
      equals(first),
      reason: 'engine phải dùng đúng bàn controller đã chọn',
    );

    // Chơi tới khi hết nước rồi kết thúc, kiểm thưởng chỉ ghi một lần.
    ctrl.score.value = 500;
    ctrl.checkEnd(true);
    final coinsAfterFirst = ctrl.coins.value;
    expect(ctrl.puzzleDailyScore, 500);
    expect(ctrl.canRecordPuzzleDailyScore, isFalse);

    ctrl.startPuzzleDaily();
    expect(ctrl.puzzleLabGrid, equals(first), reason: 'cùng ngày, cùng bàn');
    ctrl.score.value = 900;
    ctrl.checkEnd(true);

    expect(
      ctrl.coins.value,
      coinsAfterFirst,
      reason: 'chơi lại trong ngày không được cộng xu lần hai',
    );
  });

  testWidgets('X32: mode mới KHÔNG bị chèn ô khoá của campaign', (
    tester,
  ) async {
    // Lỗi đã lộ ra khi verify F18 trên máy: `id % 6 == 0` đúng với id âm nên
    // chain lock rò vào Mirror Mode (-6) và Bàn hôm nay (-18).
    final ctrl = await _launch(tester);
    ctrl.startPuzzleDaily();
    final game = await _openGameScreen(tester);

    var locked = 0;
    for (final row in game.lockGrid) {
      for (final v in row) {
        if (v > 0) locked++;
      }
    }
    expect(locked, 0, reason: 'bàn tự vẽ/preset không được bị sửa');
  });

  testWidgets('mode mới KHÔNG đụng tiến độ campaign', (tester) async {
    final ctrl = await _launch(tester);
    final unlockedBefore = ctrl.unlockedLevel.value;
    final starsBefore = ctrl.totalStars.value;

    ctrl.startMirrorDraft();
    ctrl.score.value = 99999;
    ctrl.checkEnd(true);

    await StorageService.to.flush();
    expect(ctrl.unlockedLevel.value, unlockedBefore);
    expect(ctrl.totalStars.value, starsBefore);
    expect(
      StorageService.to.getInt(StorageKeys.unlockedLevel, def: 1),
      unlockedBefore,
      reason: 'kiểm cả trên ĐĨA, không chỉ trong bộ nhớ ([[X29]])',
    );
  });
}

/// Kích thước nhóm liền kề tại `(r, c)` — bọc mỏng để test không phải import
/// thêm `pop_detector` chỉ vì một phép đếm.
int findConnectedGroupSize(List<List<int?>> grid, int r, int c) =>
    mirrorDraftCells(grid, r, c).tappedCells.length;
