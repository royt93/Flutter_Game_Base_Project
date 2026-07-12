import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/power_tile.dart';

void main() {
  group('powerTileKindForGroupSize', () {
    test('nhóm < 5 ô không sinh tile', () {
      final rng = Random(1);
      expect(powerTileKindForGroupSize(2, rng), isNull);
      expect(powerTileKindForGroupSize(4, rng), isNull);
    });

    test('nhóm 5-6 ô sinh line-clear (hàng hoặc cột), không bao giờ null', () {
      final rng = Random(42);
      final kinds = List.generate(30, (_) => powerTileKindForGroupSize(5, rng));
      expect(kinds, everyElement(isNotNull));
      expect(kinds.toSet(), {PowerTileKind.lineRow, PowerTileKind.lineCol});
    });

    test('nhóm 7-8 ô luôn sinh bomb', () {
      final rng = Random(7);
      final kinds = List.generate(30, (_) => powerTileKindForGroupSize(7, rng));
      expect(kinds, everyElement(PowerTileKind.bomb));
    });

    test('nhóm >= 9 ô luôn sinh rainbow', () {
      final rng = Random(9);
      final kinds = List.generate(30, (_) => powerTileKindForGroupSize(9, rng));
      expect(kinds, everyElement(PowerTileKind.rainbow));
    });
  });
}
