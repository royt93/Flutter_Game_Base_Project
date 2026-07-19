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

    test('I2: ô đang khoá trả về rỗng, không match được', () {
      final grid = [
        [0, 0],
      ];
      final lockGrid = [
        [1, 0],
      ];
      expect(findConnectedGroup(grid, 0, 0, lockGrid: lockGrid), isEmpty);
    });

    test('I2: flood-fill không lan qua ô đang khoá dù cùng màu ô cạnh', () {
      final grid = [
        [0, 0, 0],
      ];
      final lockGrid = [
        [0, 1, 0],
      ];
      final group = findConnectedGroup(grid, 0, 0, lockGrid: lockGrid);
      expect(group, {Point(0, 0)});
    });

    test('I2: ô về lock=0 thì tham gia flood-fill lại bình thường', () {
      final grid = [
        [0, 0, 0],
      ];
      final lockGrid = [
        [0, 0, 0],
      ];
      final group = findConnectedGroup(grid, 0, 0, lockGrid: lockGrid);
      expect(group, {Point(0, 0), Point(0, 1), Point(0, 2)});
    });
  });

  group('findLargestGroup', () {
    test('I2: bỏ qua ô đang khoá, chọn nhóm lớn nhất trong ô còn lại', () {
      final grid = [
        [0, 0, 0],
        [1, 1, 2],
      ];
      final lockGrid = [
        [1, 1, 1],
        [0, 0, 0],
      ];
      expect(findLargestGroup(grid, lockGrid: lockGrid), {
        Point(1, 0),
        Point(1, 1),
      });
    });

    test('I31: chọn nhóm lớn nhất khi có nhiều nhóm kích cỡ khác nhau', () {
      final grid = [
        [0, 0, 1],
        [2, 2, 1],
        [2, 3, 1],
      ];
      expect(findLargestGroup(grid), {Point(0, 2), Point(1, 2), Point(2, 2)});
    });

    test('I31: chỉ toàn obstacle/gift/boss tile (âm) → rỗng', () {
      final grid = [
        [-1, -1000],
        [-2000, -2001],
      ];
      expect(findLargestGroup(grid), isEmpty);
    });

    test('I31: bàn trống toàn null → rỗng', () {
      final grid = [
        [null, null],
        [null, null],
      ];
      expect(findLargestGroup(grid), isEmpty);
    });

    test('I31: đúng 1 nhóm ≥2 duy nhất, phần còn lại là ô đơn lẻ', () {
      final grid = [
        [0, 1],
        [0, 2],
      ];
      expect(findLargestGroup(grid), {Point(0, 0), Point(1, 0)});
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

    test('I2: false khi nhóm ≥2 duy nhất đang bị khoá', () {
      final grid = [
        [0, 0],
        [1, 2],
      ];
      final lockGrid = [
        [1, 1],
        [0, 0],
      ];
      expect(hasAnyMovableGroup(grid, lockGrid: lockGrid), isFalse);
    });
  });
}
