import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/logic/match_detector.dart';
import 'package:neon_jewels/logic/versus_board.dart';
import 'package:neon_jewels/presentation/controllers/versus_controller.dart';

/// Phủ bàn bằng pattern (r+c)%3 → KHÔNG có run 3 ngang/dọc nào.
void _fillSafe(VersusBoard b) {
  for (int r = 0; r < b.rows; r++) {
    for (int c = 0; c < b.cols; c++) {
      b.grid[r][c] = GemColor.values[(r + c) % 3];
    }
  }
}

void main() {
  group('VersusBoard (thuần)', () {
    test('bàn khởi tạo không có match sẵn', () {
      final b = VersusBoard(rnd: Random(1));
      expect(MatchDetector.hasMatch(b.grid), isFalse);
    });

    test('swap không kề → invalid', () {
      final b = VersusBoard(rnd: Random(1));
      final r = b.swap(const Cell(0, 0), const Cell(2, 2));
      expect(r.valid, isFalse);
    });

    test('swap tạo match-3 → hợp lệ, cộng điểm, combo ≥ 1', () {
      final b = VersusBoard(rnd: Random(2));
      _fillSafe(b);
      // dựng để swap (3,2)<->(2,2) tạo hàng cyan,cyan,cyan ở row 3 cols 0..2
      b.grid[3][1] = GemColor.cyan; // (3,0) đã là cyan theo pattern
      b.grid[2][2] = GemColor.cyan;
      expect(MatchDetector.hasMatch(b.grid), isFalse); // chưa swap: không match
      final r = b.swap(const Cell(3, 2), const Cell(2, 2));
      expect(r.valid, isTrue);
      expect(r.combo, greaterThanOrEqualTo(1));
      expect(b.score, greaterThan(0));
    });

    test('swap không tạo match → đảo lại, invalid, bàn không đổi', () {
      final b = VersusBoard(rnd: Random(3));
      _fillSafe(b);
      final before = b.grid[0][0];
      final r = b.swap(const Cell(0, 0), const Cell(0, 1));
      expect(r.valid, isFalse);
      expect(b.grid[0][0], before); // đã đảo lại
    });

    test('receiveJunk đẩy bàn lên + lấp đáy', () {
      final b = VersusBoard(rnd: Random(4));
      _fillSafe(b);
      final rowsN = b.rows;
      final oldRow2 = [for (int c = 0; c < b.cols; c++) b.grid[2][c]];
      b.receiveJunk(2);
      // hàng cũ index 2 nay phải ở index 0 (đẩy lên 2)
      for (int c = 0; c < b.cols; c++) {
        expect(b.grid[0][c], oldRow2[c]);
      }
      expect(b.grid.length, rowsN); // kích thước không đổi
    });

    test('match-4 tạo gem striped (specialsMade ≥ 1)', () {
      final b = VersusBoard(rnd: Random(6));
      _fillSafe(b);
      // dựng để swap (4,4)<->(3,4) tạo hàng cyan dài 4 ở row 4 cols 2..5
      b.grid[4][2] = GemColor.cyan;
      b.grid[4][3] = GemColor.cyan;
      b.grid[4][5] = GemColor.cyan;
      b.grid[4][4] = GemColor.magenta; // chắn để chưa match
      b.grid[3][4] = GemColor.cyan; // sẽ swap xuống
      expect(MatchDetector.hasMatch(b.grid), isFalse);
      final r = b.swap(const Cell(4, 4), const Cell(3, 4));
      expect(r.valid, isTrue);
      expect(r.specialsMade, greaterThanOrEqualTo(1));
    });

    test('striped bị clear → nổ cả hàng (cleared ≥ số cột)', () {
      final b = VersusBoard(rnd: Random(7));
      _fillSafe(b);
      b.grid[4][2] = GemColor.cyan;
      b.type[4][2] = GemType.stripedH; // gem striped sẵn
      b.grid[4][3] = GemColor.cyan;
      b.grid[4][4] = GemColor.magenta; // chắn
      b.grid[4][5] = GemColor.magenta; // tránh tạo run 4
      b.grid[3][4] = GemColor.cyan;
      final r = b.swap(const Cell(4, 4), const Cell(3, 4));
      expect(r.valid, isTrue);
      expect(r.cleared, greaterThanOrEqualTo(b.cols)); // striped quét cả hàng
    });

    test('wouldMatch dry-run đúng, KHÔNG đổi bàn', () {
      final b = VersusBoard(rnd: Random(8));
      _fillSafe(b);
      b.grid[3][1] = GemColor.cyan;
      b.grid[2][2] = GemColor.cyan; // swap (3,2)-(2,2) → match
      final before = b.grid[3][2];
      expect(b.wouldMatch(const Cell(3, 2), const Cell(2, 2)), isTrue);
      expect(b.grid[3][2], before); // bàn không đổi sau dry-run
      expect(b.wouldMatch(const Cell(0, 0), const Cell(0, 1)), isFalse);
      expect(b.wouldMatch(const Cell(0, 0), const Cell(3, 3)), isFalse); // không kề
    });

    test('hasMove phát hiện còn nước đi', () {
      final b = VersusBoard(rnd: Random(5));
      _fillSafe(b);
      b.grid[3][1] = GemColor.cyan;
      b.grid[2][2] = GemColor.cyan; // swap (3,2)-(2,2) tạo match
      expect(b.hasMove(), isTrue);
    });
  });

  group('VersusController', () {
    test('playerSwap hợp lệ cập nhật điểm; bơm rác sang đối thủ (versus)', () {
      final c = VersusController(VersusMode.versus,
          rnd1: Random(2), rnd2: Random(9));
      c.running.value = true; // bỏ qua Timer thật
      _fillSafe(c.p1);
      c.p1.grid[3][1] = GemColor.cyan;
      c.p1.grid[2][2] = GemColor.cyan;
      final ok = c.playerSwap(1, const Cell(3, 2), const Cell(2, 2));
      expect(ok, isTrue);
      expect(c.score1.value, greaterThan(0));
      expect(c.score2.value, 0);
    });

    test('playerSwap chặn khi chưa chạy', () {
      final c = VersusController(VersusMode.versus);
      expect(c.playerSwap(1, const Cell(0, 0), const Cell(0, 1)), isFalse);
    });

    test('finish versus chọn người điểm cao', () {
      final c = VersusController(VersusMode.versus);
      c.running.value = true;
      c.score1.value = 120;
      c.score2.value = 80;
      c.finish();
      expect(c.outcome.value, VersusOutcome.p1);
      expect(c.finished.value, isTrue);
    });

    test('finish versus hoà khi bằng điểm', () {
      final c = VersusController(VersusMode.versus);
      c.running.value = true;
      c.score1.value = 50;
      c.score2.value = 50;
      c.finish();
      expect(c.outcome.value, VersusOutcome.draw);
    });

    test('coop đạt mục tiêu chung → coopWin', () {
      final c = VersusController(VersusMode.coop);
      c.running.value = true;
      c.score1.value = VersusController.coopGoal - 10;
      c.score2.value = 0;
      // mô phỏng góp điểm vượt ngưỡng qua finish
      c.score2.value = 20;
      c.finish();
      expect(c.outcome.value, VersusOutcome.coopWin);
    });

    test('coop thiếu điểm khi hết giờ → coopLose', () {
      final c = VersusController(VersusMode.coop);
      c.running.value = true;
      c.score1.value = 100;
      c.finish();
      expect(c.outcome.value, VersusOutcome.coopLose);
    });

    test('tickSecond đếm ngược, hết giờ → finish', () {
      final c = VersusController(VersusMode.versus);
      c.running.value = true;
      c.timeLeft.value = 2;
      c.tickSecond();
      expect(c.timeLeft.value, 1);
      c.tickSecond();
      expect(c.timeLeft.value, 0);
      expect(c.finished.value, isTrue);
    });
  });
}
