import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/boss_tile.dart';
import 'package:pop_star_blast/logic/gift_tile.dart';

void main() {
  group('isBossTileId', () {
    test('id <= bossTileIdBase được nhận diện là boss tile', () {
      expect(isBossTileId(bossTileIdBase), isTrue);
      expect(isBossTileId(bossTileIdBase - 5), isTrue);
    });

    test('null, màu thường, obstacle không bị nhận nhầm là boss tile', () {
      expect(isBossTileId(null), isFalse);
      expect(isBossTileId(0), isFalse);
      expect(isBossTileId(3), isFalse);
      // obstacle dùng số âm nhỏ (-1, -2, ...) — dải hoàn toàn khác boss.
      expect(isBossTileId(-1), isFalse);
      expect(isBossTileId(-1999), isFalse);
    });

    test('giftTileValue (-1000) không bị nhận nhầm là boss tile', () {
      expect(isBossTileId(giftTileValue), isFalse);
    });
  });

  group('BossTileSpec', () {
    test('cells liệt kê đúng toạ độ khối chữ nhật', () {
      const spec = BossTileSpec(
        row: 1,
        col: 2,
        height: 2,
        width: 3,
        startHp: 5,
      );
      expect(spec.cells.toSet(), {
        const Point(1, 2),
        const Point(1, 3),
        const Point(1, 4),
        const Point(2, 2),
        const Point(2, 3),
        const Point(2, 4),
      });
    });

    test('fitsBoard: khối nằm gọn trong bàn thì true', () {
      const spec = BossTileSpec(
        row: 0,
        col: 0,
        height: 2,
        width: 2,
        startHp: 5,
      );
      expect(spec.fitsBoard(8, 6), isTrue);
    });

    test('fitsBoard: khối tràn ra ngoài bàn (dưới/phải) thì false', () {
      const spec = BossTileSpec(
        row: 7,
        col: 5,
        height: 2,
        width: 2,
        startHp: 5,
      );
      expect(spec.fitsBoard(8, 6), isFalse);
    });

    test('fitsBoard: toạ độ âm thì false', () {
      const spec = BossTileSpec(
        row: -1,
        col: 0,
        height: 2,
        width: 2,
        startHp: 5,
      );
      expect(spec.fitsBoard(8, 6), isFalse);
    });
  });

  group('placeBossTile', () {
    test('gán cùng 1 id lên mọi cell của khối, trả về startHp', () {
      final grid = List.generate(3, (_) => List<int?>.filled(3, 0));
      const spec = BossTileSpec(
        row: 0,
        col: 0,
        height: 2,
        width: 2,
        startHp: 7,
      );
      final hp = placeBossTile(grid, spec, bossTileIdBase);
      expect(hp, 7);
      expect(grid[0][0], bossTileIdBase);
      expect(grid[0][1], bossTileIdBase);
      expect(grid[1][0], bossTileIdBase);
      expect(grid[1][1], bossTileIdBase);
      // Cell ngoài khối không bị đụng.
      expect(grid[0][2], 0);
      expect(grid[2][2], 0);
    });
  });

  group('chipAdjacentBossTiles', () {
    test('pop gem liền kề 1 cạnh boss tile → trừ 1 HP, chưa vỡ', () {
      final grid = <List<int?>>[
        [0, bossTileIdBase],
      ];
      final bossHp = {bossTileIdBase: 3};
      final broken = chipAdjacentBossTiles(grid, {const Point(0, 0)}, bossHp);
      expect(broken, isEmpty);
      expect(bossHp[bossTileIdBase], 2);
      expect(grid[0][1], bossTileIdBase);
    });

    test('nhóm nổ chạm boss tile từ nhiều cạnh cùng lúc chỉ trừ 1 HP (chung '
        'pool, không phải 1 HP/cell tiếp giáp)', () {
      final grid = <List<int?>>[
        [0, bossTileIdBase, bossTileIdBase],
        [0, bossTileIdBase, bossTileIdBase],
      ];
      final bossHp = {bossTileIdBase: 5};
      // (0,0) và (1,0) đều liền kề khối boss (chạm 2 cell khác nhau của
      // cùng 1 id) — vẫn chỉ trừ 1 HP/lệnh gọi.
      final broken = chipAdjacentBossTiles(grid, {
        const Point(0, 0),
        const Point(1, 0),
      }, bossHp);
      expect(broken, isEmpty);
      expect(bossHp[bossTileIdBase], 4);
    });

    test('HP về 0 → toàn bộ cell của boss thành null, bị xoá khỏi bossHp', () {
      final grid = <List<int?>>[
        [0, bossTileIdBase, bossTileIdBase],
      ];
      final bossHp = {bossTileIdBase: 1};
      final broken = chipAdjacentBossTiles(grid, {const Point(0, 0)}, bossHp);
      expect(broken, {const Point(0, 1), const Point(0, 2)});
      expect(grid[0][1], isNull);
      expect(grid[0][2], isNull);
      expect(bossHp.containsKey(bossTileIdBase), isFalse);
    });

    test('pop không liền kề boss tile thì không ảnh hưởng', () {
      final grid = <List<int?>>[
        [0, 0, bossTileIdBase],
      ];
      final bossHp = {bossTileIdBase: 3};
      final broken = chipAdjacentBossTiles(grid, {const Point(0, 0)}, bossHp);
      expect(broken, isEmpty);
      expect(bossHp[bossTileIdBase], 3);
    });

    test('2 boss tile khác id, chỉ 1 cái liền kề → chỉ id đó bị trừ', () {
      const otherId = bossTileIdBase - 1;
      final grid = <List<int?>>[
        [0, bossTileIdBase, 0, otherId],
      ];
      final bossHp = {bossTileIdBase: 3, otherId: 3};
      final broken = chipAdjacentBossTiles(grid, {const Point(0, 0)}, bossHp);
      expect(broken, isEmpty);
      expect(bossHp[bossTileIdBase], 2);
      expect(bossHp[otherId], 3);
    });

    test('boss tile nằm ở mép bàn (out-of-bounds neighbor) không gây lỗi', () {
      final grid = <List<int?>>[
        [bossTileIdBase, 0],
      ];
      final bossHp = {bossTileIdBase: 3};
      final broken = chipAdjacentBossTiles(grid, {const Point(0, 1)}, bossHp);
      expect(broken, isEmpty);
      expect(bossHp[bossTileIdBase], 2);
    });

    test('id lạ trong poppedCells không có trong bossHp (an toàn, bỏ qua)', () {
      final grid = <List<int?>>[
        [0, bossTileIdBase - 99],
      ];
      final bossHp = <int, int>{};
      final broken = chipAdjacentBossTiles(grid, {const Point(0, 0)}, bossHp);
      expect(broken, isEmpty);
      expect(bossHp, isEmpty);
    });

    test('không có boss tile nào trên bàn → không crash, trả về rỗng', () {
      final grid = <List<int?>>[
        [0, 1, 2],
      ];
      final bossHp = <int, int>{};
      final broken = chipAdjacentBossTiles(grid, {const Point(0, 0)}, bossHp);
      expect(broken, isEmpty);
    });
  });

  group('decayBossTilesOnStuck', () {
    test('bàn kẹt tự giảm 1 HP mọi boss tile hiện có', () {
      const otherId = bossTileIdBase - 1;
      final grid = <List<int?>>[
        [bossTileIdBase, otherId],
      ];
      final bossHp = {bossTileIdBase: 2, otherId: 1};
      final broken = decayBossTilesOnStuck(grid, bossHp);
      expect(bossHp[bossTileIdBase], 1);
      // otherId về 0 nên vỡ.
      expect(bossHp.containsKey(otherId), isFalse);
      expect(broken, {const Point(0, 1)});
      expect(grid[0][1], isNull);
      expect(grid[0][0], bossTileIdBase);
    });

    test('bossHp rỗng thì không làm gì, không crash', () {
      final grid = <List<int?>>[
        [0, 1],
      ];
      final broken = decayBossTilesOnStuck(grid, <int, int>{});
      expect(broken, isEmpty);
    });

    test('HP khởi đầu 1 → decay 1 lần là vỡ ngay', () {
      final grid = <List<int?>>[
        [bossTileIdBase, bossTileIdBase],
      ];
      final bossHp = {bossTileIdBase: 1};
      final broken = decayBossTilesOnStuck(grid, bossHp);
      expect(broken, {const Point(0, 0), const Point(0, 1)});
      expect(grid[0][0], isNull);
      expect(grid[0][1], isNull);
      expect(bossHp, isEmpty);
    });
  });
}
