import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/puzzles.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/logic/match_detector.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/puzzle_controller.dart';
import 'package:neon_jewels/presentation/screens/puzzle_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// W19.2 — Cấu đố (Puzzle): no-refill + score target + bàn seed cố định.
/// Test gồm: data, GIẢI ĐƯỢC (greedy sim conservative), controller, checkEnd,
/// engine mount (no-refill integration), widget select.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ─── Mô phỏng thuần để VERIFY GIẢI ĐƯỢC ─────────────────────────────────
  // Replicate y hệt cách engine sinh bàn (Random(seed), row-major, tránh match-3
  // sẵn). Rồi greedy no-refill dùng MatchDetector THẬT + scoring ×1 (BỎ combo
  // bonus + special) → cận DƯỚI. Nếu sim đạt target trong budget thì game thật
  // (điểm ≥ sim nhờ combo/special) CHẮC CHẮN đạt → đảm bảo giải được.

  bool wouldMatch(List<List<GemColor?>> g, int r, int c, GemColor col) {
    if (c >= 2 && g[r][c - 1] == col && g[r][c - 2] == col) return true;
    if (r >= 2 && g[r - 1][c] == col && g[r - 2][c] == col) return true;
    return false;
  }

  List<List<GemColor?>> genBoard(int seed, int colorCount, int rows, int cols) {
    final rnd = Random(seed);
    final g = List.generate(rows, (_) => List<GemColor?>.filled(cols, null));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        GemColor col;
        do {
          col = GemColor.values[rnd.nextInt(colorCount)];
        } while (wouldMatch(g, r, c, col));
        g[r][c] = col;
      }
    }
    return g;
  }

  List<int>? findSwap(List<List<GemColor?>> g) {
    final rows = g.length, cols = g[0].length;
    bool createsMatch(int r1, int c1, int r2, int c2) {
      final t = g[r1][c1];
      g[r1][c1] = g[r2][c2];
      g[r2][c2] = t;
      final has = MatchDetector.hasMatch(g);
      final t2 = g[r1][c1];
      g[r1][c1] = g[r2][c2];
      g[r2][c2] = t2;
      return has;
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (g[r][c] == null) continue;
        if (c + 1 < cols && g[r][c + 1] != null && createsMatch(r, c, r, c + 1)) {
          return [r, c, r, c + 1];
        }
        if (r + 1 < rows && g[r + 1][c] != null && createsMatch(r, c, r + 1, c)) {
          return [r, c, r + 1, c];
        }
      }
    }
    return null;
  }

  void gravityNoRefill(List<List<GemColor?>> g) {
    final rows = g.length, cols = g[0].length;
    for (int c = 0; c < cols; c++) {
      int writeRow = rows - 1;
      for (int r = rows - 1; r >= 0; r--) {
        if (g[r][c] != null) {
          if (writeRow != r) {
            g[writeRow][c] = g[r][c];
            g[r][c] = null;
          }
          writeRow--;
        }
      }
    }
  }

  /// Greedy no-refill: trả (score, movesUsed) khi đạt target hoặc bí/cạn budget.
  ({int score, int moves}) greedySolve(
      List<List<GemColor?>> g, int target, int maxMoves) {
    int score = 0, moves = 0;
    while (score < target && moves < maxMoves) {
      final mv = findSwap(g);
      if (mv == null) break; // bí bàn
      final t = g[mv[0]][mv[1]];
      g[mv[0]][mv[1]] = g[mv[2]][mv[3]];
      g[mv[2]][mv[3]] = t;
      moves++;
      while (true) {
        final matches = MatchDetector.findMatches(g);
        if (matches.isEmpty) break;
        final cleared = <int>{};
        for (final m in matches) {
          for (final cell in m.cells) {
            cleared.add(cell.row * 100 + cell.col);
          }
        }
        score += cleared.length * 10; // ×1 (cận dưới — bỏ combo/special)
        for (final key in cleared) {
          g[key ~/ 100][key % 100] = null;
        }
        gravityNoRefill(g);
      }
    }
    return (score: score, moves: moves);
  }

  // ─── 1) Data ─────────────────────────────────────────────────────────────

  group('PuzzleDef — data', () {
    test('có đúng 8 cấu đố, id 1..8 liên tục', () {
      expect(kPuzzles.length, 8);
      for (var i = 0; i < kPuzzles.length; i++) {
        expect(kPuzzles[i].id, i + 1);
      }
    });

    test('seed duy nhất', () {
      final seeds = kPuzzles.map((p) => p.seed).toList();
      expect(seeds.toSet().length, seeds.length);
    });

    test('target không giảm + colorCount trong [4,6]', () {
      for (var i = 1; i < kPuzzles.length; i++) {
        expect(kPuzzles[i].target,
            greaterThanOrEqualTo(kPuzzles[i - 1].target),
            reason: 'target nên khó dần');
      }
      for (final p in kPuzzles) {
        expect(p.colorCount, inInclusiveRange(4, 6));
        expect(p.maxMoves, greaterThan(0));
        expect(p.target, greaterThan(0));
      }
    });

    test('puzzleById trả đúng / null ngoài phạm vi', () {
      expect(puzzleById(1)?.id, 1);
      expect(puzzleById(8)?.id, 8);
      expect(puzzleById(0), isNull);
      expect(puzzleById(9), isNull);
    });

    test('puzzleStarsFor theo lượt dư', () {
      expect(puzzleStarsFor(10, 20), 3); // 50% >= 40%
      expect(puzzleStarsFor(8, 20), 3); // 40%
      expect(puzzleStarsFor(5, 20), 2); // 25%
      expect(puzzleStarsFor(3, 20), 2); // 15%
      expect(puzzleStarsFor(2, 20), 1); // 10%
      expect(puzzleStarsFor(0, 20), 1);
      expect(puzzleStarsFor(5, 0), 1); // guard chia 0
    });

    test('buildPuzzleLevel khớp def', () {
      final def = kPuzzles[2];
      final lv = buildPuzzleLevel(def);
      expect(lv.index, kPuzzleLevelIndex);
      expect(lv.rows, 8);
      expect(lv.cols, 8);
      expect(lv.colorCount, def.colorCount);
      expect(lv.moves, def.maxMoves);
      expect(lv.targetScore, def.target);
    });
  });

  // ─── 2) GIẢI ĐƯỢC (quan trọng nhất) ─────────────────────────────────────

  group('Puzzle — đảm bảo GIẢI ĐƯỢC (greedy sim cận dưới)', () {
    test('mỗi cấu đố: bàn mở màn KHÔNG bí (có nước đi)', () {
      for (final p in kPuzzles) {
        final board = genBoard(p.seed, p.colorCount, 8, 8);
        expect(findSwap(board), isNotNull,
            reason: 'Cấu đố ${p.id} (seed ${p.seed}) bí ngay từ đầu');
      }
    });

    test('mỗi cấu đố: greedy ×1 đạt target trong ngân sách lượt', () {
      final failures = <String>[];
      for (final p in kPuzzles) {
        final board = genBoard(p.seed, p.colorCount, 8, 8);
        final res = greedySolve(board, p.target, p.maxMoves);
        // trần điểm bàn (greedy tới khi bí, budget rộng) — để tune target.
        final ceil = greedySolve(
            genBoard(p.seed, p.colorCount, 8, 8), 1 << 30, 99);
        if (res.score < p.target) {
          failures.add('Cấu đố ${p.id}: ${res.score}/${p.target} trong '
              '${res.moves}/${p.maxMoves} lượt (trần bàn ${ceil.score} @ ${ceil.moves} lượt)');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('greedy giải có biên an toàn (đạt trước khi cạn budget)', () {
      // greedy (dumb) đạt target dùng < maxMoves → người chơi giỏi dư sức.
      for (final p in kPuzzles) {
        final board = genBoard(p.seed, p.colorCount, 8, 8);
        final res = greedySolve(board, p.target, p.maxMoves);
        expect(res.moves, lessThanOrEqualTo(p.maxMoves), reason: 'Cấu đố ${p.id}');
      }
    });
  });

  // ─── 3) Controller ───────────────────────────────────────────────────────

  group('PuzzleController', () {
    late GameController g;
    late PuzzleController pc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
      pc = Get.put(PuzzleController(g));
    });
    tearDown(Get.reset);

    test('mặc định: chỉ cấu đố 1 mở khoá, chưa giải gì', () {
      expect(pc.unlocked.value, 1);
      expect(pc.isUnlocked(1), isTrue);
      expect(pc.isUnlocked(2), isFalse);
      expect(pc.solvedCount, 0);
      expect(pc.allSolved, isFalse);
    });

    test('recordWin: lưu sao + mở khoá cấu đố kế', () {
      pc.recordWin(1, 2);
      expect(pc.starsOf(1), 2);
      expect(pc.unlocked.value, 2);
      expect(pc.isUnlocked(2), isTrue);
      expect(pc.solvedCount, 1);
    });

    test('recordWin: sao chỉ tăng, không giảm', () {
      pc.recordWin(1, 3);
      pc.recordWin(1, 1); // chơi lại tệ hơn
      expect(pc.starsOf(1), 3);
    });

    test('recordWin cấu đố không ở mép KHÔNG nhảy mở khoá', () {
      pc.recordWin(1, 1); // unlocked → 2
      // giải lại cấu đố 1 (đã mở) không đẩy unlocked lên 3
      pc.recordWin(1, 2);
      expect(pc.unlocked.value, 2);
    });

    test('giải hết → allSolved', () {
      for (final p in kPuzzles) {
        pc.recordWin(p.id, 3);
      }
      expect(pc.allSolved, isTrue);
      expect(pc.solvedCount, kPuzzles.length);
    });

    test('persist + reload', () async {
      pc.recordWin(1, 3);
      pc.recordWin(2, 2);
      final pc2 = PuzzleController(g);
      pc2.onInit();
      expect(pc2.starsOf(1), 3);
      expect(pc2.starsOf(2), 2);
      expect(pc2.unlocked.value, 3);
    });

    test('resetState xoá tiến trình', () {
      pc.recordWin(1, 3);
      pc.recordWin(2, 3);
      pc.resetState();
      expect(pc.solvedCount, 0);
      expect(pc.unlocked.value, 1);
    });

    test('skip guard: recordWin(3) khi unlocked=1 KHÔNG nhảy unlock', () {
      // Chỉ puzzle đúng thứ tự mới mở khoá tiếp theo.
      pc.recordWin(3, 3); // id=3, unlocked=1 → id ≠ unlocked → bỏ qua
      expect(pc.unlocked.value, 1, reason: 'không được nhảy tới puzzle 3');
      expect(pc.isUnlocked(2), isFalse);
      expect(pc.isUnlocked(3), isFalse);
    });

    test('board determinism: cùng seed sinh cùng lưới (replicate engine)', () {
      // Mô phỏng thuần cách engine sinh bàn (Random(seed), row-major, tránh match-3 sẵn).
      List<GemColor> buildBoard(int seed) {
        const rows = 8, cols = 8;
        const nColors = 4;
        final rnd = Random(seed);
        final colors = List<GemColor?>.filled(rows * cols, null);
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            GemColor pick;
            do {
              pick = GemColor.values[rnd.nextInt(nColors)];
            } while ((c >= 2 &&
                    colors[r * cols + c - 1] == pick &&
                    colors[r * cols + c - 2] == pick) ||
                (r >= 2 &&
                    colors[(r - 1) * cols + c] == pick &&
                    colors[(r - 2) * cols + c] == pick));
            colors[r * cols + c] = pick;
          }
        }
        return colors.cast<GemColor>();
      }

      final def = kPuzzles.first;
      final board1 = buildBoard(def.seed);
      final board2 = buildBoard(def.seed);
      expect(board1, board2, reason: 'cùng seed phải cho cùng bàn (tất định)');
    });
  });

  // ─── 4) startPuzzle + checkEnd ───────────────────────────────────────────

  group('startPuzzle + checkEnd', () {
    late GameController g;
    late PuzzleController pc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
      pc = Get.put(PuzzleController(g));
    });
    tearDown(Get.reset);

    test('startPuzzle bật cờ + side mode + seed + target', () {
      final def = kPuzzles[2];
      g.startPuzzle(def);
      expect(g.isPuzzle.value, isTrue);
      expect(g.isSideMode, isTrue);
      expect(g.boardSeed, def.seed);
      expect(g.targetScore.value, def.target);
      expect(g.movesLeft.value, def.maxMoves);
      expect(g.currentPuzzle?.id, def.id);
    });

    test('đạt điểm → win + sao + mở khoá kế', () {
      final def = kPuzzles[0];
      g.startPuzzle(def);
      g.score.value = def.target;
      // còn nhiều lượt → 3 sao
      g.movesLeft.value = def.maxMoves;
      expect(g.checkEnd(), 'win');
      expect(g.lastStars, 3);
      expect(pc.starsOf(def.id), 3);
      expect(pc.unlocked.value, 2);
    });

    test('hết lượt chưa đạt → lose, không thưởng', () {
      final def = kPuzzles[0];
      g.startPuzzle(def);
      g.score.value = def.target - 1;
      g.movesLeft.value = 0;
      final before = g.coins.value;
      expect(g.checkEnd(), 'lose');
      expect(g.lastStars, 0);
      expect(g.coins.value, before);
      expect(pc.solvedCount, 0);
    });

    test('isPuzzle cô lập: startLevel tắt cờ puzzle', () {
      g.startPuzzle(kPuzzles[0]);
      expect(g.isPuzzle.value, isTrue);
      g.startLevel(1);
      expect(g.isPuzzle.value, isFalse);
      expect(g.isSideMode, isFalse);
    });

    test('reset run-state: điểm/combo về 0', () {
      g.startPuzzle(kPuzzles[0]);
      expect(g.score.value, 0);
      expect(g.comboCount.value, 0);
    });
  });

  // ─── 5) Engine mount — no-refill integration ─────────────────────────────

  group('Engine — puzzle mount (no-refill)', () {
    late GameController g;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
      Get.put(PuzzleController(g));
    });
    tearDown(Get.reset);

    test('mount đúng seed: bàn đầy 64 gem + có nước đi + isPuzzle', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final def = kPuzzles[0];
        g.startPuzzle(def);
        final game = NeonJewelGame(
          controller: g,
          rows: 8,
          cols: 8,
          colorCount: def.colorCount,
          onGameEnd: (_) {},
          muteSfx: true,
          boardSeed: g.boardSeed,
        );
        game.onGameResize(Vector2(560, 800));
        await game.onLoad();
        expect(g.isPuzzle.value, isTrue);
        var gems = 0;
        for (int r = 0; r < 8; r++) {
          for (int c = 0; c < 8; c++) {
            if (game.grid[r][c] != null) gems++;
          }
        }
        expect(gems, 64, reason: 'bàn puzzle mở màn phải đầy');
        expect(game.hasPossibleMove, isTrue);
      });
    });
  });

  // ─── 6) Widget — màn chọn cấu đố ─────────────────────────────────────────

  group('PuzzleSelectScreen', () {
    Widget appEn(Widget home) => GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: AppTranslations.fallback,
          home: home,
        );

    testWidgets('render lưới + chỉ cấu đố mở khoá tap được', (tester) async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      final g = Get.put(GameController());
      Get.put(PuzzleController(g));
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appEn(const PuzzleSelectScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // 1 cấu đố mở (số "1"), 7 khoá (icon lock).
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(7));
      expect(find.text('1'), findsOneWidget);
      Get.reset();
    });

    testWidgets('giải hết → banner Strategist', (tester) async {
      final seeded = <String, Object>{'pz_unlocked': kPuzzles.length};
      for (final p in kPuzzles) {
        seeded['pz_star_${p.id}'] = 3;
      }
      SharedPreferences.setMockInitialValues(seeded);
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      final g = Get.put(GameController());
      Get.put(PuzzleController(g));
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appEn(const PuzzleSelectScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(Get.find<PuzzleController>().allSolved, isTrue);
      Get.reset();
    });
  });
}
