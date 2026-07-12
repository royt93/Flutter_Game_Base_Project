import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/pop_detector.dart';

void main() {
  group('findConnectedGroup', () {
    test('gom nhóm liền kề 4 hướng cùng màu', () {
      final grid = [
        [0, 0, 1],
        [0, 1, 1],
        [1, 1, 1],
      ];
      final group = findConnectedGroup(grid, 0, 0);
      expect(group, {Point(0, 0), Point(0, 1), Point(1, 0)});
    });

    test('không lan sang màu khác hoặc ô null', () {
      final grid = [
        [0, 1],
        [null, 1],
      ];
      final group = findConnectedGroup(grid, 0, 1);
      expect(group, {Point(0, 1), Point(1, 1)});
    });

    test('ô null trả về rỗng', () {
      final grid = [
        [null],
      ];
      expect(findConnectedGroup(grid, 0, 0), isEmpty);
    });

    test('nhóm kích thước 1 vẫn được trả về (caller tự lọc ≥2)', () {
      final grid = [
        [0, 1],
        [1, 1],
      ];
      expect(findConnectedGroup(grid, 0, 0), {Point(0, 0)});
    });

    test('F6a: ô obstacle (giá trị âm) trả về rỗng, không nổ trực tiếp', () {
      final grid = [
        [-2, 0],
        [0, 0],
      ];
      expect(findConnectedGroup(grid, 0, 0), isEmpty);
    });

    test('F6a: flood-fill không lan qua ô obstacle dù cùng cạnh ô màu', () {
      final grid = [
        [0, -1, 0],
      ];
      final group = findConnectedGroup(grid, 0, 0);
      expect(group, {Point(0, 0)});
    });
  });

  group('hasAnyMovableGroup', () {
    test('true khi còn ít nhất 1 nhóm ≥2', () {
      final grid = [
        [0, 0],
        [1, 2],
      ];
      expect(hasAnyMovableGroup(grid), isTrue);
    });

    test('false khi bàn kẹt — mọi ô là nhóm đơn lẻ', () {
      final grid = [
        [0, 1],
        [2, 0],
      ];
      expect(hasAnyMovableGroup(grid), isFalse);
    });

    test('false khi bàn trống', () {
      final grid = [
        [null, null],
        [null, null],
      ];
      expect(hasAnyMovableGroup(grid), isFalse);
    });

    test(
      'F6a: 2 obstacle cùng độ bền cạnh nhau không tính là nhóm nổ được',
      () {
        final grid = [
          [-1, -1],
          [0, 1],
        ];
        expect(hasAnyMovableGroup(grid), isFalse);
      },
    );
  });
}
