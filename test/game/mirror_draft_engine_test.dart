import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/mirror_draft.dart';
import 'package:pop_star_blast/logic/replay.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F21 — luật gương **trong engine**, không chỉ ở hàm thuần.
///
/// Mutation-check phát hiện lỗ: gỡ dòng mở rộng nhóm trong `_tryPop` mà mọi
/// test vẫn xanh, vì test thuần chỉ kiểm `mirrorDraftCells` còn test controller
/// không chạm engine. Ca ở đây tap thật trên `PopStarGame`.
late GameController ctrl;

Future<PopStarGame> _game(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
  ctrl.startMirrorDraft();

  // Dùng ĐÚNG hàm mà `GameScreenController` dùng — nếu mode thiếu ở đó thì
  // test này đỏ, thay vì im lặng dựng bàn ngẫu nhiên.
  final game = PopStarGame(ctrl, presetGrid: presetGridForMode(ctrl));
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: GameWidget(game: game))),
  );
  await tester.pump(const Duration(milliseconds: 100));
  // Chờ hết animation intro-rơi-ô, nếu không tap đầu bị `_animating` chặn —
  // cùng khuôn `undo_snapshot_test`.
  await _settle(tester);
  return game;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

int _filled(PopStarGame g) =>
    g.colorGrid.expand((r) => r).where((v) => v != null).length;

void main() {
  tearDown(Get.reset);

  testWidgets('bàn trong engine đối xứng lúc mới dựng', (tester) async {
    final g = await _game(tester);
    final cols = g.cols;
    for (final row in g.colorGrid) {
      for (var c = 0; c < cols ~/ 2; c++) {
        expect(row[c], row[cols - 1 - c]);
      }
    }
  });

  testWidgets('tap nổ CẢ nhóm gương -> mất gấp đôi số ô', (tester) async {
    final g = await _game(tester);

    // Tìm nước đi mà luật gương nói là nổ được cả hai nửa.
    ({int r, int c, int total, int tapped})? move;
    for (var r = 0; r < g.rows && move == null; r++) {
      for (var c = 0; c < g.cols ~/ 2; c++) {
        final d = mirrorDraftCells(g.colorGrid, r, c);
        if (d.isValid && d.mirroredToo) {
          move = (
            r: r,
            c: c,
            total: d.allCells.length,
            tapped: d.tappedCells.length,
          );
          break;
        }
      }
    }
    expect(move, isNotNull, reason: 'bàn gương mới sinh phải có nước đi gương');

    final before = _filled(g);
    g.handleTap(g.cellCenterFor(move!.r, move.c));
    await _settle(tester);

    final removed = before - _filled(g);
    // Nhóm gộp >= 5 sinh power tile (F5) và GIỮ LẠI 1 ô, nên không so bằng
    // đúng `total` được — ca này từng đỏ 2/3 lần vì đúng chuyện đó. Điều thật
    // sự cần chốt: nổ NHIỀU HƠN nhóm vừa tap, tức nhóm gương cũng đã nổ.
    expect(
      removed,
      greaterThan(move.tapped),
      reason: 'engine phải nổ cả nhóm gương, không chỉ nhóm vừa tap',
    );
    expect(removed, greaterThanOrEqualTo(move.total - 1));
    expect(removed, lessThanOrEqualTo(move.total));
    expect(ctrl.lastMirrorMirrored, isTrue);
  });

  testWidgets('mode khác KHÔNG bị áp luật gương', (tester) async {
    // Chốt ngược: luật chỉ được chạy ở mirrorDraft.
    SharedPreferences.setMockInitialValues({});
    final store = await SharedPreferences.getInstance();
    Get.put(StorageService(store), permanent: true);
    ctrl = Get.put(GameController(), permanent: true);
    ctrl.startLevel(1);

    final game = PopStarGame(ctrl, presetGrid: presetGridForMode(ctrl));
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GameWidget(game: game))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await _settle(tester);

    // Chỉ chọn nhóm NHỎ (2..4): nhóm >= 5 sinh power tile (F5) và giữ lại 1 ô,
    // nên "số ô mất đi" không còn bằng kích thước nhóm. Phát hiện khi ca này
    // đỏ với 7/8 — không phải flaky, mà là luật khác của campaign.
    for (var r = 0; r < game.rows; r++) {
      for (var c = 0; c < game.cols; c++) {
        final grp = mirrorDraftCells(game.colorGrid, r, c);
        if (!grp.isValid) continue;
        if (grp.tappedCells.length > 4) continue;
        final before = _filled(game);
        game.handleTap(game.cellCenterFor(r, c));
        await _settle(tester);
        expect(
          before - _filled(game),
          grp.tappedCells.length,
          reason: 'campaign không được nổ thêm nhóm gương',
        );
        return;
      }
    }
    fail('không tìm được nước đi hợp lệ');
  });

  group('presetGridForMode', () {
    Future<void> boot() async {
      SharedPreferences.setMockInitialValues({});
      final store = await SharedPreferences.getInstance();
      Get.put(StorageService(store), permanent: true);
      ctrl = Get.put(GameController(), permanent: true);
    }

    testWidgets('mirrorDraft trả về bàn ĐÃ dựng, không phải null', (
      tester,
    ) async {
      await boot();
      ctrl.startMirrorDraft();
      expect(
        presetGridForMode(ctrl),
        same(ctrl.puzzleLabGrid),
        reason: 'null ở đây = engine tự sinh bàn ngẫu nhiên, mất đối xứng',
      );
    });

    testWidgets('duel trả về bàn từ seed, không phải null', (tester) async {
      await boot();
      ctrl.startDuel(
        const DuelData(
          seed: 4242,
          taps: [(0, 0)],
          score: 100,
          senderName: 'A',
        ),
      );
      expect(
        presetGridForMode(ctrl),
        same(ctrl.puzzleLabGrid),
        reason: 'null ở đây = hai người chơi HAI bàn khác nhau',
      );
    });

    testWidgets('campaign vẫn là null (engine tự sinh)', (tester) async {
      await boot();
      ctrl.startLevel(1);
      expect(presetGridForMode(ctrl), isNull);
    });
  });
}
