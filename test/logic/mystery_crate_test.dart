import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/mystery_crate.dart';

void main() {
  group('Mystery Crate Pure Logic', () {
    final sampleItems = [
      const CosmeticEntry(
        id: 'ruby',
        kind: CosmeticKind.mascotSkin,
        nameKey: 'skin_ruby_name',
        color: Colors.red,
        originalItem: 'ruby_skin',
      ),
      const CosmeticEntry(
        id: 'neon_cyan',
        kind: CosmeticKind.boardFrame,
        nameKey: 'board_frame_neon_cyan',
        color: Colors.cyan,
        originalItem: 'neon_cyan_frame',
      ),
    ];

    test('rollCrate trả về item trong pool truyền vào', () {
      final rng = Random(42);
      final rolled = rollCrate(eligiblePool: sampleItems, rng: rng);
      expect(rolled, isNotNull);
      expect(sampleItems.contains(rolled), isTrue);
    });

    test('rollCrate trả về null khi pool rỗng (không crash)', () {
      final rng = Random(42);
      final rolled = rollCrate(eligiblePool: [], rng: rng);
      expect(rolled, isNull);
    });

    test('rollCrate deterministic với Random seed cố định', () {
      final rng1 = Random(12345);
      final rolled1 = rollCrate(eligiblePool: sampleItems, rng: rng1);

      final rng2 = Random(12345);
      final rolled2 = rollCrate(eligiblePool: sampleItems, rng: rng2);

      expect(rolled1!.id, equals(rolled2!.id));
    });
  });
}
