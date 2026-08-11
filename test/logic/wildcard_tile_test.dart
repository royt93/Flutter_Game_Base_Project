import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/boss_tile.dart';
import 'package:pop_star_blast/logic/countdown_lock_tile.dart';
import 'package:pop_star_blast/logic/gift_tile.dart';
import 'package:pop_star_blast/logic/pop_detector.dart';
import 'package:pop_star_blast/logic/wildcard_tile.dart';

/// T3 — Wildcard (I46) là special tile duy nhất có quy tắc flood-fill **tinh
/// tế**: khớp mọi màu khi lan tiếp, nhưng **không** được làm cầu nối 2 nhóm
/// khác màu thành một. Quy tắc đó sống trong `pop_detector.findConnectedGroup`
/// và rất dễ vỡ khi ai đó sửa flood-fill — mà trước batch này không có test nào.
void main() {
  group('sentinel', () {
    test('nhận đúng giá trị wildcard', () {
      expect(isWildcardTileValue(wildcardTileValue), isTrue);
    });

    test('không nhận null, màu thường, hay special tile khác', () {
      expect(isWildcardTileValue(null), isFalse);
      expect(isWildcardTileValue(0), isFalse);
      expect(isWildcardTileValue(6), isFalse);
      expect(isWildcardTileValue(-1), isFalse, reason: 'obstacle');
      expect(isWildcardTileValue(giftTileValue), isFalse);
      expect(isWildcardTileValue(countdownLockIdBase), isFalse);
      expect(isWildcardTileValue(bossTileIdBase), isFalse);
    });

    test('dải riêng, không đụng dải của special tile khác', () {
      // Bảng negative-ID trong CLAUDE.md: obstacle -1..-9, wildcard -500,
      // gift -1000, countdown -1500.., boss <= -2000.
      expect(wildcardTileValue, lessThan(-9));
      expect(wildcardTileValue, greaterThan(giftTileValue));
      expect(wildcardTileValue, greaterThan(countdownLockIdBase));
      expect(wildcardTileValue, greaterThan(bossTileIdBase));
    });
  });

  group('flood-fill: wildcard khớp mọi màu', () {
    test('nối vào nhóm màu 0 khi tap ô màu 0', () {
      final grid = <List<int?>>[
        [0, wildcardTileValue, 1],
        [1, 1, 1],
      ];
      final group = findConnectedGroup(grid, 0, 0);
      expect(group.length, 2, reason: 'ô màu 0 + wildcard liền kề');
    });

    test('nối vào nhóm màu KHÁC cũng được (không kén màu)', () {
      final grid = <List<int?>>[
        [2, wildcardTileValue, 5],
        [5, 5, 5],
      ];
      final group = findConnectedGroup(grid, 0, 0);
      expect(group.length, 2);
    });

    test('nhiều wildcard liên tiếp cùng nối vào một nhóm', () {
      final grid = <List<int?>>[
        [3, wildcardTileValue, wildcardTileValue],
        [9, 9, 9],
      ];
      final group = findConnectedGroup(grid, 0, 0);
      expect(group.length, 3);
    });
  });

  group('flood-fill: wildcard KHÔNG bắc cầu 2 nhóm khác màu', () {
    test('màu 0 | wildcard | màu 1 → tap màu 0 không lấy được màu 1', () {
      final grid = <List<int?>>[
        [0, wildcardTileValue, 1],
      ];
      final group = findConnectedGroup(grid, 0, 0);
      expect(
        group.length,
        2,
        reason: 'chỉ gồm ô màu 0 và wildcard — KHÔNG gồm ô màu 1',
      );
      expect(group.contains(const Point(0, 2)), isFalse);
    });

    test('tap từ phía màu 1 cũng chỉ lấy được phía của nó', () {
      final grid = <List<int?>>[
        [0, wildcardTileValue, 1],
      ];
      final group = findConnectedGroup(grid, 0, 2);
      expect(group.length, 2);
      expect(group.contains(const Point(0, 0)), isFalse);
    });

    test('hai nhóm lớn hai bên wildcard vẫn không hợp nhất', () {
      final grid = <List<int?>>[
        [4, 4, wildcardTileValue, 7, 7],
        [4, 4, 8, 7, 7],
      ];
      final left = findConnectedGroup(grid, 0, 0);
      final right = findConnectedGroup(grid, 0, 4);
      expect(left.length, 5, reason: '4 ô màu 4 + wildcard');
      expect(right.length, 5, reason: '4 ô màu 7 + wildcard');
      // Cùng dùng chung wildcard nhưng KHÔNG hợp thành 1 nhóm 9 ô.
      expect(left.contains(const Point(0, 4)), isFalse);
      expect(right.contains(const Point(0, 0)), isFalse);
    });
  });

  group('tap thẳng vào wildcard: mượn màu hàng xóm', () {
    test('mượn màu của ô màu thường liền kề', () {
      final grid = <List<int?>>[
        [wildcardTileValue, 2, 2],
      ];
      final group = findConnectedGroup(grid, 0, 0);
      expect(group.length, 3, reason: 'wildcard + 2 ô màu 2');
    });

    // Hợp đồng của `findConnectedGroup` (doc ngay trên hàm): wildcard không
    // mượn được màu thì trả nhóm **kích thước 1** — không phải rỗng. Vô hại vì
    // `PopStarGame._tryPop` bỏ qua mọi nhóm < 2, nhưng phải khoá lại cho đúng:
    // đổi sang rỗng cũng không sai về gameplay, nên nếu không có test thì
    // người sau đổi tự do mà không biết mình đang đổi hợp đồng.
    test('wildcard cô lập (không hàng xóm màu thường) → nhóm đúng 1 ô', () {
      final grid = <List<int?>>[
        [null, -1, null],
        [-1, wildcardTileValue, -1],
        [null, -1, null],
      ];
      final group = findConnectedGroup(grid, 1, 1);
      expect(group, {const Point(1, 1)});
      expect(
        group.length,
        lessThan(2),
        reason: 'dưới ngưỡng pop nên không nổ được — đó là điều quan trọng',
      );
    });

    test('wildcard chỉ giáp wildcard khác → nhóm đúng 1 ô', () {
      final grid = <List<int?>>[
        [wildcardTileValue, wildcardTileValue],
      ];
      final group = findConnectedGroup(grid, 0, 0);
      expect(
        group,
        {const Point(0, 0)},
        reason: 'không có màu thật nào để mượn → không lan sang wildcard kia',
      );
    });
  });

  group('không tương tác với special tile khác', () {
    test('không nối qua obstacle', () {
      final grid = <List<int?>>[
        [1, -1, wildcardTileValue],
      ];
      expect(findConnectedGroup(grid, 0, 0).length, 1);
    });

    test('không nối qua ô rỗng', () {
      final grid = <List<int?>>[
        [1, null, wildcardTileValue],
      ];
      expect(findConnectedGroup(grid, 0, 0).length, 1);
    });

    test(
      'tap vào gift/boss/countdown vẫn trả nhóm rỗng (không phải wildcard)',
      () {
        for (final v in [giftTileValue, bossTileIdBase, countdownLockIdBase]) {
          final grid = <List<int?>>[
            [v, 1, 1],
          ];
          expect(
            findConnectedGroup(grid, 0, 0),
            isEmpty,
            reason: 'chỉ wildcard mới được mượn màu, giá trị $v thì không',
          );
        }
      },
    );
  });
}
