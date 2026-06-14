import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/logic/versus_board.dart';
import 'package:neon_jewels/presentation/widgets/versus_board_view.dart';

void _fillSafe(VersusBoard b) {
  for (int r = 0; r < b.rows; r++) {
    for (int c = 0; c < b.cols; c++) {
      b.grid[r][c] = GemColor.values[(r + c) % 3];
    }
  }
}

void main() {
  testWidgets('vuốt tạo match HỢP LỆ → onSwap được gọi (sau animation)',
      (tester) async {
    final board = VersusBoard(rnd: Random(2));
    _fillSafe(board);
    board.grid[3][1] = GemColor.cyan; // swap (3,2)<->(2,2) tạo match cyan
    board.grid[2][2] = GemColor.cyan;

    Cell? gotA, gotB;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 350, // 7 cột → cell 50px, board ở góc (0,0)
            height: 350,
            child: VersusBoardView(
              board: board,
              accent: Colors.cyan,
              repaint: 0,
              onSwap: (a, b) {
                gotA = a;
                gotB = b;
              },
            ),
          ),
        ),
      ),
    ));

    // cell (3,2) center = (2*50+25, 3*50+25) = (125,175); vuốt LÊN 1 ô → (2,2)
    await tester.dragFrom(const Offset(125, 175), const Offset(0, -50));
    await tester.pump(); // bắt đầu animation
    await tester.pump(const Duration(milliseconds: 250)); // animation xong

    expect(gotA, const Cell(3, 2));
    expect(gotB, const Cell(2, 2));
  });

  testWidgets('vuốt KHÔNG match → onSwap KHÔNG gọi (nhún rồi trả lại)',
      (tester) async {
    final board = VersusBoard(rnd: Random(3));
    _fillSafe(board); // pattern (r+c)%3 → vuốt kề bất kỳ không tạo match

    var called = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 350,
            height: 350,
            child: VersusBoardView(
              board: board,
              accent: Colors.cyan,
              repaint: 0,
              onSwap: (_, __) => called = true,
            ),
          ),
        ),
      ),
    ));

    await tester.dragFrom(const Offset(125, 175), const Offset(50, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(called, isFalse);
  });
}
