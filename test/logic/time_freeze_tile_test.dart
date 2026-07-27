import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/time_freeze_tile.dart';

void main() {
  group('shouldTagTimeFreezeTile', () {
    test('không gắn tag khi không phải Time Attack', () {
      final rng = Random(1);
      for (var i = 0; i < 50; i++) {
        expect(
          shouldTagTimeFreezeTile(
            isTimeAttack: false,
            alreadyTagged: false,
            rng: rng,
            chance: 1,
          ),
          isFalse,
        );
      }
    });

    test('không gắn tag khi đã có 1 ô đang tag (tối đa 1 ô/bàn)', () {
      final rng = Random(2);
      for (var i = 0; i < 50; i++) {
        expect(
          shouldTagTimeFreezeTile(
            isTimeAttack: true,
            alreadyTagged: true,
            rng: rng,
            chance: 1,
          ),
          isFalse,
        );
      }
    });

    test('chance = 0 không bao giờ gắn tag dù đủ điều kiện', () {
      final rng = Random(3);
      for (var i = 0; i < 50; i++) {
        expect(
          shouldTagTimeFreezeTile(
            isTimeAttack: true,
            alreadyTagged: false,
            rng: rng,
            chance: 0,
          ),
          isFalse,
        );
      }
    });

    test('chance = 1 luôn gắn tag khi Time Attack và chưa có ô nào tag', () {
      final rng = Random(4);
      for (var i = 0; i < 50; i++) {
        expect(
          shouldTagTimeFreezeTile(
            isTimeAttack: true,
            alreadyTagged: false,
            rng: rng,
            chance: 1,
          ),
          isTrue,
        );
      }
    });

    test('tần suất mặc định (~10%) hợp lý trên nhiều lần thử', () {
      final rng = Random(5);
      var tagged = 0;
      const trials = 5000;
      for (var i = 0; i < trials; i++) {
        if (shouldTagTimeFreezeTile(
          isTimeAttack: true,
          alreadyTagged: false,
          rng: rng,
        )) {
          tagged++;
        }
      }
      final ratio = tagged / trials;
      expect(ratio, greaterThan(0.05));
      expect(ratio, lessThan(0.15));
    });
  });
}
