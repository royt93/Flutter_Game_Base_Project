import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/logic/settle.dart';

/// Tiện ích: dựng lưới kind + occupancy từ bản đồ ký tự.
/// - '#' = wall, 'o' = noDrop, 'g' = play CÓ gem, '.'/' ' = play TRỐNG.
({
  int rows,
  int cols,
  CellKind Function(int, int) kindAt,
  bool Function(int, int) occupied,
}) _grid(List<String> map) {
  final rows = map.length, cols = map[0].length;
  final kind = [
    for (final line in map)
      [
        for (final ch in line.split(''))
          ch == '#' ? CellKind.wall : (ch == 'o' ? CellKind.noDrop : CellKind.play),
      ],
  ];
  final occ = [
    for (final line in map) [for (final ch in line.split('')) ch == 'g' || ch == 'o'],
  ];
  return (
    rows: rows,
    cols: cols,
    kindAt: (r, c) => kind[r][c],
    occupied: (r, c) => occ[r][c],
  );
}

void main() {
  group('Wave 15 — parseLayout / cellKindFromChar', () {
    test('ký tự → CellKind', () {
      expect(cellKindFromChar('#'), CellKind.wall);
      expect(cellKindFromChar('X'), CellKind.wall);
      expect(cellKindFromChar('o'), CellKind.noDrop);
      expect(cellKindFromChar('.'), CellKind.play);
      expect(cellKindFromChar(' '), CellKind.play);
    });

    test('parse bản đồ thành lưới đúng kích thước', () {
      final g = parseLayout(['#..', '..#']);
      expect(g.length, 2);
      expect(g[0].length, 3);
      expect(g[0][0], CellKind.wall);
      expect(g[1][2], CellKind.wall);
      expect(g[0][1], CellKind.play);
    });
  });

  group('Wave 15 — settleColumnsDown (lỗ-cắt-cột)', () {
    test('cột đặc không wall: gem dồn xuống, spawn lấp đỉnh', () {
      // 1 cột 4 hàng: gem ở hàng 0 và 2 (g), trống hàng 1,3.
      final s = _grid(['g', '.', 'g', '.']);
      final r = settleColumnsDown(s.rows, s.cols, s.kindAt, s.occupied);
      // 2 gem dồn xuống hàng 2,3. Gem hàng 0→3? hàng 2→3, hàng 0→2.
      // Quét đáy lên: rr=3 trống; rr=2 gem→write3 (move 2→3), write=2; rr=1 trống;
      //   rr=0 gem→write2 (move 0→2), write=1. Trống top..1 = hàng 0,1 → 2 spawn.
      expect(r.moves, contains(const SettleMove(2, 0, 3, 0)));
      expect(r.moves, contains(const SettleMove(0, 0, 2, 0)));
      expect(r.spawns.length, 2);
      expect(r.spawns.map((s) => s.r).toSet(), {0, 1});
    });

    test('wall giữa cột chia 2 đoạn dồn độc lập', () {
      // hàng: 0=g 1=. 2=# 3=. 4=g  (wall ở hàng 2)
      // Đoạn trên [0..1]: gem hàng0 → dồn xuống hàng1 (move 0→1); spawn hàng0.
      // Đoạn dưới [3..4]: gem hàng4 đã ở đáy; trống hàng3 → spawn hàng3.
      final s = _grid(['g', '.', '#', '.', 'g']);
      final r = settleColumnsDown(s.rows, s.cols, s.kindAt, s.occupied);
      expect(r.moves, contains(const SettleMove(0, 0, 1, 0)));
      // KHÔNG có gem nào nhảy QUA wall (không move tới/từ hàng 2, không vượt đoạn).
      expect(r.moves.every((m) => (m.fromR < 2) == (m.toR < 2)), isTrue);
      expect(r.spawns.map((s) => s.r).toSet(), {0, 3});
    });

    test('đoạn đầy không sinh spawn, không move thừa', () {
      final s = _grid(['g', 'g', '#', 'g']);
      final r = settleColumnsDown(s.rows, s.cols, s.kindAt, s.occupied);
      expect(r.moves, isEmpty);
      expect(r.spawns, isEmpty);
    });

    test('refillCapped=false: đoạn bị wall chặn đỉnh KHÔNG refill', () {
      // hàng0=# (wall đỉnh), hàng1=. trống, hàng2=g
      final s = _grid(['#', '.', 'g']);
      final capped = settleColumnsDown(s.rows, s.cols, s.kindAt, s.occupied,
          refillCapped: false);
      // Đoạn [1..2] bị wall chặn đỉnh (top=1≠0) → không spawn.
      expect(capped.spawns, isEmpty);
      final filled = settleColumnsDown(s.rows, s.cols, s.kindAt, s.occupied);
      expect(filled.spawns.length, 1); // mặc định refill
    });
  });

  group('Wave 15 — settleBoard (trượt chéo + refill đầy)', () {
    // Tái dựng tập ô CÓ GEM sau settle = gem không-đổi-ô + gem đã dời + gem mới.
    Set<String> finalFilled(List<String> map) {
      final s = _grid(map);
      final res = settleBoard(s.rows, s.cols, s.kindAt, s.occupied);
      final movedFrom = {for (final m in res.moves) '${m.fromR},${m.fromC}'};
      final occ = <String>{};
      for (int r = 0; r < s.rows; r++) {
        for (int c = 0; c < s.cols; c++) {
          if (s.occupied(r, c) && !movedFrom.contains('$r,$c')) occ.add('$r,$c');
        }
      }
      for (final m in res.moves) {
        occ.add('${m.toR},${m.toC}');
      }
      for (final sp in res.spawns) {
        occ.add('${sp.r},${sp.c}');
      }
      return occ;
    }

    Set<String> playCells(List<String> map) {
      final s = _grid(map);
      final out = <String>{};
      for (int r = 0; r < s.rows; r++) {
        for (int c = 0; c < s.cols; c++) {
          if (s.kindAt(r, c) != CellKind.wall) out.add('$r,$c');
        }
      }
      return out;
    }

    test('bàn rỗng → refill ĐẦY mọi ô chơi, KHÔNG gem trong tường', () {
      // hốc cột phải bị wall chặn đỉnh → chỉ lấp được nhờ TRƯỢT CHÉO từ cột trái.
      const map = ['.#', '..', '..'];
      expect(finalFilled(map), equals(playCells(map)));
    });

    test('hình thoi rỗng → đầy hết ô chơi (trượt chéo lấp 4 góc hốc)', () {
      const map = [
        '##....##',
        '#......#',
        '........',
        '........',
        '#......#',
        '##....##',
      ];
      expect(finalFilled(map), equals(playCells(map)));
    });

    test('không có tường: cột nén xuống + refill đầy như thường', () {
      const map = ['g.', '.g', '..'];
      expect(finalFilled(map), equals(playCells(map)));
    });

    test('tất định: cùng input → cùng kết quả', () {
      final s = _grid(const ['.#', '..', '..']);
      final a = settleBoard(s.rows, s.cols, s.kindAt, s.occupied);
      final b = settleBoard(s.rows, s.cols, s.kindAt, s.occupied);
      expect(a.moves, equals(b.moves));
      expect(a.spawns, equals(b.spawns));
    });

    test('gem giữ nguyên nếu đã ở đáy (không move thừa)', () {
      // cột đầy gem, không tường → 0 move, 0 spawn.
      const map = ['gg', 'gg'];
      final s = _grid(map);
      final res = settleBoard(s.rows, s.cols, s.kindAt, s.occupied);
      expect(res.moves, isEmpty);
      expect(res.spawns, isEmpty);
    });
  });

  group('Wave 15 — settleBoardFlow (Gravity Streams)', () {
    // map: kind+occupancy; flowMap: hướng mỗi ô (v/^/</>).
    Set<String> filledAfter(List<String> map, List<String> flowMap) {
      final s = _grid(map);
      final flow = parseFlow(flowMap);
      final res = settleBoardFlow(
          s.rows, s.cols, s.kindAt, (r, c) => flow[r][c], s.occupied);
      final movedFrom = {for (final m in res.moves) '${m.fromR},${m.fromC}'};
      final occ = <String>{};
      for (int r = 0; r < s.rows; r++) {
        for (int c = 0; c < s.cols; c++) {
          if (s.occupied(r, c) && !movedFrom.contains('$r,$c')) occ.add('$r,$c');
        }
      }
      for (final m in res.moves) {
        occ.add('${m.toR},${m.toC}');
      }
      for (final sp in res.spawns) {
        occ.add('${sp.r},${sp.c}');
      }
      return occ;
    }

    Set<String> playOf(List<String> map) {
      final s = _grid(map);
      final out = <String>{};
      for (int r = 0; r < s.rows; r++) {
        for (int c = 0; c < s.cols; c++) {
          if (s.kindAt(r, c) != CellKind.wall) out.add('$r,$c');
        }
      }
      return out;
    }

    test('flow toàn down = settleBoard: bàn rỗng refill đầy', () {
      const map = ['....', '....', '....'];
      const flow = ['vvvv', 'vvvv', 'vvvv'];
      expect(filledAfter(map, flow), equals(playOf(map)));
    });

    test('1 hàng flow PHẢI: spawn ở mép trái, chảy phải, lấp đầy', () {
      const map = ['....'];
      const flow = ['>>>>'];
      expect(filledAfter(map, flow), equals(playOf(map)));
    });

    test('1 cột flow LÊN: spawn ở đáy, chảy lên, lấp đầy', () {
      const map = ['.', '.', '.'];
      const flow = ['^', '^', '^'];
      expect(filledAfter(map, flow), equals(playOf(map)));
    });

    test('dòng chảy chữ S (down→phải→down) lấp đầy mọi ô chơi', () {
      // cột trái chảy xuống, hàng giữa chảy phải, cột phải chảy xuống.
      const map = ['....', '....', '....', '....'];
      const flow = [
        'v..v',
        'v..v',
        '>>>v',
        'v..v',
      ];
      expect(filledAfter(map, flow), equals(playOf(map)));
    });

    test('tất định: cùng input → cùng kết quả', () {
      const map = ['....', '....'];
      const flow = ['>>>v', 'vvvv'];
      final s = _grid(map);
      final f = parseFlow(flow);
      final a =
          settleBoardFlow(s.rows, s.cols, s.kindAt, (r, c) => f[r][c], s.occupied);
      final b =
          settleBoardFlow(s.rows, s.cols, s.kindAt, (r, c) => f[r][c], s.occupied);
      expect(a.moves, equals(b.moves));
      expect(a.spawns, equals(b.spawns));
    });

    test('parseFlow + flowDirFromChar đúng', () {
      expect(flowDirFromChar('^'), FlowDir.up);
      expect(flowDirFromChar('<'), FlowDir.left);
      expect(flowDirFromChar('>'), FlowDir.right);
      expect(flowDirFromChar('.'), FlowDir.down);
      expect(flowDelta(FlowDir.right), const [0, 1]);
    });
  });

  group('Wave 15 — no-drop (gem bất động)', () {
    // gem ở ô no-drop ('o') KHÔNG rơi; chặn gem trên rơi qua; ô dưới tự refill.
    test('noDrop chặn rơi + giữ nguyên, ô dưới tự refill', () {
      // row0 gem, row1 noDrop gem, row2 trống (cô lập dưới đảo nổi).
      final s = _grid(const ['g', 'o', '.']);
      final flow = parseFlow(const ['v', 'v', 'v']);
      final res =
          settleBoardFlow(s.rows, s.cols, s.kindAt, (r, c) => flow[r][c], s.occupied);
      // gem row0 KHÔNG rơi (bị noDrop chặn) → không move.
      expect(res.moves, isEmpty);
      // row2 (dưới đảo) tự refill (source vì noDrop không cấp gem).
      expect(res.spawns.map((sp) => '${sp.r},${sp.c}'), contains('2,0'));
    });

    test('ô no-drop TRỐNG tự refill tại chỗ', () {
      // dùng lưới thủ công: 1 ô no-drop trống.
      CellKind kind(int r, int c) => CellKind.noDrop;
      bool occ(int r, int c) => false; // trống
      final res = settleBoardFlow(1, 1, kind, (r, c) => FlowDir.down, occ);
      expect(res.spawns.length, 1);
      expect(res.spawns.first.r, 0);
    });
  });
}
