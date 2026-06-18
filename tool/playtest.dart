// ignore_for_file: avoid_print
// (CLI dev-tool — print là output chủ đích, KHÔNG ship vào app.)
//
// Auto-playtest simulator (Wave 13) — validate đường cong độ khó Wave 12 bằng
// DỮ LIỆU. Bot greedy Monte Carlo chơi mỗi màn N lần, báo pass-rate / lượt TB.
//
// Chạy:  dart run tool/playtest.dart [runsPerLevel]
//
// LƯU Ý: đây là LOWER BOUND — bot KHÔNG dùng special gem nổ-dây (striped/bomb/
// rainbow) và KHÔNG dùng booster. Người chơi thật làm TỐT HƠN nhiều. Mục đích:
// kiểm hình DẠNG đường cong + bắt "tường" (target bất khả thi). Nếu bot pass
// tốt → người chơi chắc chắn pass.

import 'dart:math';

import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/logic/match_detector.dart';

class Sim {
  final int rows, cols, colorCount;
  final Random rnd;
  late List<List<GemColor?>> g;

  Sim(this.rows, this.cols, this.colorCount, this.rnd) {
    _fill();
  }

  GemColor _rc() => GemColor.values[rnd.nextInt(colorCount)];

  void _fill() {
    g = List.generate(rows, (_) => List.generate(cols, (_) => _rc()));
    var guard = 0;
    while (MatchDetector.hasMatch(g) && guard++ < 200) {
      for (final grp in MatchDetector.findMatches(g)) {
        for (final cell in grp.cells) {
          g[cell.row][cell.col] = _rc();
        }
      }
    }
  }

  void _gravityRefill(Set<Cell> cleared) {
    for (final cell in cleared) {
      g[cell.row][cell.col] = null;
    }
    for (int c = 0; c < cols; c++) {
      int write = rows - 1;
      for (int r = rows - 1; r >= 0; r--) {
        if (g[r][c] != null) {
          g[write][c] = g[r][c];
          if (write != r) g[r][c] = null;
          write--;
        }
      }
      for (int r = write; r >= 0; r--) {
        g[r][c] = _rc();
      }
    }
  }

  /// Giải quyết toàn bộ cascade sau 1 nước đi. Trả (score, collected màu mục tiêu).
  ({int score, int collected}) resolve(GemColor? collectColor) {
    var score = 0, collected = 0, combo = 0;
    while (true) {
      final matches = MatchDetector.findMatches(g);
      if (matches.isEmpty) break;
      combo++;
      final cells = <Cell>{};
      for (final m in matches) {
        cells.addAll(m.cells);
        // Mô hình SPECIAL (xấp xỉ người chơi tạo & dùng special):
        // match-5+ → xoá toàn bộ gem CÙNG MÀU (rainbow); match-4 → nổ cả hàng +
        // cột của 1 ô (striped/bomb). Làm bot sát thực hơn (không quá bi quan).
        final f = m.cells.first;
        if (m.cells.length >= 5) {
          final col = g[f.row][f.col];
          for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
              if (g[r][c] == col) cells.add(Cell(r, c));
            }
          }
        } else if (m.cells.length == 4) {
          for (int c = 0; c < cols; c++) {
            cells.add(Cell(f.row, c));
          }
          for (int r = 0; r < rows; r++) {
            cells.add(Cell(r, f.col));
          }
        }
      }
      for (final cell in cells) {
        if (collectColor != null && g[cell.row][cell.col] == collectColor) {
          collected++;
        }
      }
      // Công thức điểm THẬT: gems*10*(1+(combo-1)*0.5)
      score += (cells.length * 10 * (1 + (combo - 1) * 0.5)).round();
      _gravityRefill(cells);
    }
    return (score: score, collected: collected);
  }

  /// Bot greedy: tìm swap kề tạo match LỚN NHẤT. null nếu bí (→ caller xáo bàn).
  List<int>? bestMove() {
    List<int>? best;
    var bestSize = 0;
    void test(int r1, int c1, int r2, int c2) {
      final t = g[r1][c1];
      g[r1][c1] = g[r2][c2];
      g[r2][c2] = t;
      var size = 0;
      for (final grp in MatchDetector.findMatches(g)) {
        size += grp.cells.length;
      }
      final t2 = g[r1][c1];
      g[r1][c1] = g[r2][c2];
      g[r2][c2] = t2;
      if (size > bestSize) {
        bestSize = size;
        best = [r1, c1, r2, c2];
      }
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (c + 1 < cols) test(r, c, r, c + 1);
        if (r + 1 < rows) test(r, c, r + 1, c);
      }
    }
    return best;
  }

  void applyMove(List<int> mv) {
    final t = g[mv[0]][mv[1]];
    g[mv[0]][mv[1]] = g[mv[2]][mv[3]];
    g[mv[2]][mv[3]] = t;
  }

  void reshuffle() => _fill();
}

int startMovesOf(LevelConfig lv) => lv.objective == ObjectiveType.timeAttack
    ? (lv.timeLimit / 2.5).round() // ~2.5s/nước đi
    : lv.moves;

/// Mô phỏng 1 ván → (won, movesUsed, finalScore).
({bool won, int moves, int score}) playGame(LevelConfig lv, Random rnd) {
  final sim = Sim(lv.rows, lv.cols, lv.colorCount, rnd);
  final start = startMovesOf(lv);
  var moves = start, score = 0, collected = 0, dry = 0;
  while (moves > 0) {
    final mv = sim.bestMove();
    if (mv == null) {
      sim.reshuffle();
      if (++dry > 5) break;
      continue;
    }
    dry = 0;
    sim.applyMove(mv);
    final r = sim.resolve(lv.collectColor);
    score += r.score;
    collected += r.collected;
    moves--;
    final won = lv.objective == ObjectiveType.collect
        ? collected >= lv.collectTarget
        : score >= lv.targetScore;
    if (won) return (won: true, moves: start - moves, score: score);
  }
  return (won: false, moves: start - moves, score: score);
}

void main(List<String> args) {
  final runs = args.isNotEmpty ? int.parse(args[0]) : 120;
  const validated = {
    ObjectiveType.score,
    ObjectiveType.collect,
    ObjectiveType.timeAttack,
  };

  print('Auto-playtest (bot greedy, $runs runs/màn, LOWER BOUND — không special/booster)');
  print('=' * 74);
  print('Màn | mục tiêu     | lượt | target | pass% | điểm TB | nhãn');
  print('-' * 74);

  final hard = <int>[];
  var trivialCount = 0;
  for (final lv in kLevels) {
    if (!validated.contains(lv.objective)) continue;
    var wins = 0;
    var sumScore = 0.0;
    for (int i = 0; i < runs; i++) {
      final res = playGame(lv, Random(lv.index * 100000 + i));
      if (res.won) wins++;
      sumScore += res.score;
    }
    final pass = wins / runs * 100;
    final tgt = lv.objective == ObjectiveType.collect
        ? lv.collectTarget
        : lv.targetScore;
    var tag = '';
    if (pass < 25) {
      tag = '⚠ QUÁ KHÓ';
      hard.add(lv.index);
    } else if (pass > 98 && lv.index > 10) {
      tag = '· dễ';
      trivialCount++;
    }
    print('${lv.index.toString().padLeft(3)} | '
        '${lv.objective.name.padRight(12)} | '
        '${startMovesOf(lv).toString().padLeft(4)} | '
        '${tgt.toString().padLeft(6)} | '
        '${pass.toStringAsFixed(0).padLeft(4)}% | '
        '${(sumScore / runs).toStringAsFixed(0).padLeft(7)} | $tag');
  }
  print('=' * 74);
  print('Màn QUÁ KHÓ với bot (pass<25%): ${hard.isEmpty ? "KHÔNG ✓" : hard.join(", ")}');
  print('Màn dễ (pass>98%): $trivialCount màn');
  print('\nLƯU Ý: bot KHÔNG dùng special gem nổ-dây + booster → pass-rate THẬT của');
  print('người chơi CAO HƠN. Màn "quá khó" với bot vẫn có thể ổn cho người chơi.');
}
