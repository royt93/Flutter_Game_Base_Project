import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/boss_tile.dart';
import 'package:pop_star_blast/logic/countdown_lock_tile.dart';
import 'package:pop_star_blast/logic/gift_tile.dart';
import 'package:pop_star_blast/logic/ice_tile.dart';
import 'package:pop_star_blast/logic/magnet_tile.dart';
import 'package:pop_star_blast/logic/wildcard_tile.dart';

void main() {
  group('isIceTileId', () {
    test('2 giá trị hợp lệ trong dải (mới + đã nứt)', () {
      expect(isIceTileId(iceTileIdBase), isTrue);
      expect(isIceTileId(iceTileIdBase - iceTileDurability + 1), isTrue);
    });

    test('null, màu thường, obstacle không bị nhận nhầm', () {
      expect(isIceTileId(null), isFalse);
      expect(isIceTileId(0), isFalse);
      expect(isIceTileId(3), isFalse);
      expect(isIceTileId(-1), isFalse);
      expect(isIceTileId(-2), isFalse);
    });

    test('ID của mọi tile đặc biệt khác không bị nhận nhầm', () {
      expect(isIceTileId(giftTileValue), isFalse);
      expect(isIceTileId(wildcardTileValue), isFalse);
      expect(isIceTileId(magnetTileIdBase), isFalse);
      expect(isIceTileId(countdownLockIdBase), isFalse);
      expect(isIceTileId(bossTileIdBase), isFalse);
      expect(isIceTileId(bossTileIdBase - 5), isFalse);
    });

    test('ngoài dải hợp lệ (quá cũ hoặc chưa tới) không bị nhận nhầm', () {
      expect(isIceTileId(iceTileIdBase + 1), isFalse);
      expect(isIceTileId(iceTileIdBase - iceTileDurability), isFalse);
    });
  });

  group('iceTileRemaining', () {
    test('mới (2 lớp) và đã nứt (1 lớp) trả về đúng số lớp còn lại', () {
      expect(iceTileRemaining(iceTileIdBase - iceTileDurability + 1), 2);
      expect(iceTileRemaining(iceTileIdBase), 1);
    });
  });

  group('chipAdjacentIceTiles', () {
    test('tile đặc biệt khác liền kề không bị chip nhầm', () {
      final grid = [
        [0, giftTileValue],
      ];
      final broken = chipAdjacentIceTiles(grid, {const Point(0, 0)});
      expect(broken, isEmpty);
      expect(grid[0][1], giftTileValue);
    });

    test('chip 1 lớp: từ mới (2 lớp) thành đã nứt (1 lớp), chưa vỡ', () {
      final grid = <List<int?>>[
        [0, iceTileIdBase - iceTileDurability + 1],
      ];
      final broken = chipAdjacentIceTiles(grid, {const Point(0, 0)});
      expect(broken, isEmpty);
      expect(grid[0][1], iceTileIdBase);
    });

    test('hết lớp thì vỡ thành null và được trả về', () {
      final grid = <List<int?>>[
        [0, iceTileIdBase],
      ];
      final broken = chipAdjacentIceTiles(grid, {const Point(0, 0)});
      expect(broken, {const Point(0, 1)});
      expect(grid[0][1], isNull);
    });

    test('ice tile không liền kề ô nổ thì không bị ảnh hưởng', () {
      final grid = [
        [0, 1, iceTileIdBase],
      ];
      final broken = chipAdjacentIceTiles(grid, {const Point(0, 0)});
      expect(broken, isEmpty);
      expect(grid[0][2], iceTileIdBase);
    });

    test('1 ice tile liền kề nhiều ô nổ trong cùng đợt chỉ bị chip 1 lần', () {
      final grid = <List<int?>>[
        [0, iceTileIdBase - iceTileDurability + 1, 0],
      ];
      final broken = chipAdjacentIceTiles(grid, {
        const Point(0, 0),
        const Point(0, 2),
      });
      expect(broken, isEmpty);
      expect(grid[0][1], iceTileIdBase);
    });
  });
}
