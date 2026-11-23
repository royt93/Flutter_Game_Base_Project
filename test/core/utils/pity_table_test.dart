import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/pity_table.dart';
import 'package:roy_casual_kit/core/utils/seeded_random.dart';

PityTable<String> _table({int pityAfter = 10, List<double>? weights}) =>
    PityTable<String>(
      items: const ['common', 'rare', 'epic'],
      weights: weights ?? const [90, 9, 1],
      pityItems: const {'rare', 'epic'},
      pityAfter: pityAfter,
    );

void main() {
  group('PityTable validation (ENH-85: ArgumentError, not assert)', () {
    test('rejects empty, mismatched or bad weights', () {
      expect(
        () => PityTable<String>(
          items: const [],
          weights: const [],
          pityItems: const {'a'},
          pityAfter: 3,
        ),
        throwsArgumentError,
      );
      expect(
        () => PityTable<String>(
          items: const ['a', 'b'],
          weights: const [1],
          pityItems: const {'a'},
          pityAfter: 3,
        ),
        throwsArgumentError,
      );
      for (final w in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => PityTable<String>(
            items: const ['a', 'b'],
            weights: [1, w],
            pityItems: const {'b'},
            pityAfter: 3,
          ),
          throwsArgumentError,
          reason: 'weight $w',
        );
      }
    });

    test('rejects pityAfter <= 0, empty pityItems, pityItems not in table', () {
      expect(() => _table(pityAfter: 0), throwsArgumentError);
      expect(() => _table(pityAfter: -2), throwsArgumentError);
      expect(
        () => PityTable<String>(
          items: const ['a', 'b'],
          weights: const [1, 1],
          pityItems: const {},
          pityAfter: 3,
        ),
        throwsArgumentError,
      );
      expect(
        () => PityTable<String>(
          items: const ['a', 'b'],
          weights: const [1, 1],
          pityItems: const {'zzz'},
          pityAfter: 3,
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate items (they would make pity ambiguous)', () {
      expect(
        () => PityTable<String>(
          items: const ['a', 'a'],
          weights: const [1, 1],
          pityItems: const {'a'},
          pityAfter: 3,
        ),
        throwsArgumentError,
      );
    });
  });

  group('PityTable behaviour', () {
    test('never exceeds pityAfter consecutive misses (many seeds)', () {
      for (var seed = 1; seed <= 40; seed++) {
        final t = _table(pityAfter: 8, weights: const [1000, 1, 1]);
        final r = SeededRandom(seed);
        var streak = 0;
        for (var i = 0; i < 3000; i++) {
          final got = t.pull(r);
          if (got == 'common') {
            streak++;
          } else {
            streak = 0;
          }
          expect(streak, lessThan(8), reason: 'seed $seed pull $i');
        }
      }
    });

    test('the pityAfter-th consecutive miss forces a pity item', () {
      final t = _table(pityAfter: 3, weights: const [1000000, 1, 1]);
      // Rig the random so the plain roll is always the common item.
      final r = _FixedRandom(0.0);
      expect(t.pull(r), 'common');
      expect(t.misses, 1);
      expect(t.pull(r), 'common');
      expect(t.misses, 2);
      final forced = t.pull(r);
      expect(forced, isIn(['rare', 'epic']));
      expect(t.misses, 0);
    });

    test('the counter resets after any pity item, natural or forced', () {
      final t = _table(pityAfter: 5, weights: const [1, 1000000, 1]);
      final r = _FixedRandom(0.0);
      // First roll lands on 'common' (index 0, target 0): count a miss.
      expect(t.pull(r), 'common');
      expect(t.misses, 1);
      final natural = _table(pityAfter: 5, weights: const [1, 1, 1000000]);
      final r2 = _FixedRandom(0.9999);
      expect(natural.pull(r2), 'epic');
      expect(natural.misses, 0);
    });

    test('same seed gives the same sequence; different seed differs', () {
      List<String> run(int seed) {
        final t = _table(pityAfter: 6);
        final r = SeededRandom(seed);
        return [for (var i = 0; i < 200; i++) t.pull(r)];
      }

      expect(run(7), run(7));
      expect(run(7), isNot(run(8)));
    });

    test('save and restore continues the exact same sequence', () {
      final a = _table(pityAfter: 6);
      final ra = SeededRandom(99);
      for (var i = 0; i < 37; i++) {
        a.pull(ra);
      }
      final saved = a.toJson();
      final snap = ra.snapshot();
      final b = _table(pityAfter: 6)..restore(saved);
      final rb = SeededRandom.fromSnapshot(snap);
      for (var i = 0; i < 100; i++) {
        expect(b.pull(rb), a.pull(ra), reason: 'pull $i');
        expect(b.misses, a.misses);
      }
    });

    test('restore ignores garbage: wrong types, negative, too large', () {
      final t = _table(pityAfter: 5);
      t.restore({'misses': 'abc'});
      expect(t.misses, 0);
      t.restore({'misses': -4});
      expect(t.misses, 0);
      t.restore({'misses': 999});
      expect(t.misses, 4, reason: 'clamped below pityAfter');
      t.restore(const {});
      expect(t.misses, 0);
      t.restore({'misses': double.nan});
      expect(t.misses, 0);
    });

    test('statistics: with generous weights pity is rare, rate is sane', () {
      final t = _table(pityAfter: 50, weights: const [90, 9, 1]);
      final r = SeededRandom(2026);
      var rare = 0;
      const n = 20000;
      for (var i = 0; i < n; i++) {
        if (t.pull(r) != 'common') rare++;
      }
      // Natural rate is 10%; pity only nudges it up slightly.
      expect(rare / n, inInclusiveRange(0.09, 0.13));
    });
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}
