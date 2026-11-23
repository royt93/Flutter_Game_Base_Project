import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/dynamic_difficulty.dart';
import 'package:roy_casual_kit/core/utils/seeded_random.dart';

DynamicDifficulty _d({
  double min = 1,
  double max = 10,
  double start = 5,
  double step = 0.5,
  int window = 4,
  double deadband = 0.1,
  double targetWinRate = 0.5,
}) => DynamicDifficulty(
  min: min,
  max: max,
  start: start,
  step: step,
  window: window,
  deadband: deadband,
  targetWinRate: targetWinRate,
);

void main() {
  group('DynamicDifficulty validation (ENH-85: ArgumentError)', () {
    test('rejects min > max and start outside [min, max]', () {
      expect(() => _d(min: 5, max: 4, start: 4), throwsArgumentError);
      expect(() => _d(start: 0.5), throwsArgumentError);
      expect(() => _d(start: 10.5), throwsArgumentError);
      expect(_d(min: 3, max: 3, start: 3).value, 3, reason: 'min == max ok');
    });

    test('rejects bad step, window, deadband, targetWinRate', () {
      expect(() => _d(step: 0), throwsArgumentError);
      expect(() => _d(step: -1), throwsArgumentError);
      expect(() => _d(window: 0), throwsArgumentError);
      expect(() => _d(deadband: -0.01), throwsArgumentError);
      expect(() => _d(targetWinRate: 0), throwsArgumentError);
      expect(() => _d(targetWinRate: 1), throwsArgumentError);
      expect(() => _d(targetWinRate: 1.2), throwsArgumentError);
    });

    test('rejects NaN and infinite numbers', () {
      for (final bad in [double.nan, double.infinity]) {
        expect(() => _d(min: bad), throwsArgumentError, reason: 'min $bad');
        expect(() => _d(max: bad), throwsArgumentError, reason: 'max $bad');
        expect(() => _d(start: bad), throwsArgumentError, reason: 'start');
        expect(() => _d(step: bad), throwsArgumentError, reason: 'step');
        expect(() => _d(deadband: bad), throwsArgumentError, reason: 'dead');
        expect(() => _d(targetWinRate: bad), throwsArgumentError);
      }
    });
  });

  group('DynamicDifficulty behaviour', () {
    test('the window must fill before anything changes', () {
      final d = _d(window: 4);
      d.record(won: true);
      d.record(won: true);
      d.record(won: true);
      expect(d.value, 5, reason: 'only 3 of 4 results recorded');
      d.record(won: true);
      expect(d.value, 5.5, reason: 'window full: 100% wins > target');
    });

    test('a winning streak raises difficulty to max and stops', () {
      final d = _d();
      for (var i = 0; i < 100; i++) {
        d.record(won: true);
      }
      expect(d.value, 10);
    });

    test('a losing streak lowers difficulty to min and stops', () {
      final d = _d();
      for (var i = 0; i < 100; i++) {
        d.record(won: false);
      }
      expect(d.value, 1);
    });

    test('alternating win/loss stays inside the deadband: no change', () {
      final d = _d(window: 4, deadband: 0.1);
      for (var i = 0; i < 200; i++) {
        d.record(won: i.isEven);
      }
      expect(d.value, 5);
    });

    test('a win rate just inside vs just outside the deadband', () {
      // window 10, target 0.5, deadband 0.1: 6/10 wins = 0.6 is NOT > 0.6.
      final inside = _d(window: 10, deadband: 0.1);
      for (var i = 0; i < 10; i++) {
        inside.record(won: i < 6);
      }
      expect(inside.value, 5);
      final outside = _d(window: 10, deadband: 0.1);
      for (var i = 0; i < 10; i++) {
        outside.record(won: i < 7);
      }
      expect(outside.value, 5.5, reason: '0.7 > 0.5 + 0.1');
    });

    test('the lower deadband edge: 4/10 wins holds, 3/10 lowers', () {
      // window 10, target 0.5, deadband 0.1: 4/10 = 0.4 is NOT < 0.4.
      final inside = _d(window: 10, deadband: 0.1);
      for (var i = 0; i < 10; i++) {
        inside.record(won: i < 4);
      }
      expect(inside.value, 5);
      final outside = _d(window: 10, deadband: 0.1);
      for (var i = 0; i < 10; i++) {
        outside.record(won: i < 3);
      }
      expect(outside.value, 4.5, reason: '0.3 < 0.5 - 0.1');
    });

    test('a non-default targetWinRate shifts both edges', () {
      // target 0.7, deadband 0.1, window 10: holds for 6..8 wins.
      for (final wins in [6, 7, 8]) {
        final d = _d(window: 10, targetWinRate: 0.7);
        for (var i = 0; i < 10; i++) {
          d.record(won: i < wins);
        }
        expect(d.value, 5, reason: '$wins/10 wins holds');
      }
      final up = _d(window: 10, targetWinRate: 0.7);
      for (var i = 0; i < 10; i++) {
        up.record(won: i < 9);
      }
      expect(up.value, 5.5);
      final down = _d(window: 10, targetWinRate: 0.7);
      for (var i = 0; i < 10; i++) {
        down.record(won: i < 5);
      }
      expect(down.value, 4.5);
    });

    test('recovery: after a losing run, wins bring difficulty back up', () {
      final d = _d(window: 4);
      for (var i = 0; i < 40; i++) {
        d.record(won: false);
      }
      final low = d.value;
      for (var i = 0; i < 40; i++) {
        d.record(won: true);
      }
      expect(d.value, greaterThan(low));
    });

    test('value is always inside [min, max] for random play (many seeds)', () {
      for (var seed = 1; seed <= 25; seed++) {
        final d = _d(window: 6, step: 0.7);
        final r = SeededRandom(seed);
        for (var i = 0; i < 2000; i++) {
          d.record(won: r.nextDouble() < 0.5 + 0.4 * sin(i / 50));
          expect(d.value, inInclusiveRange(1, 10), reason: 'seed $seed');
        }
      }
    });

    test('deterministic: same results in give the same values out', () {
      List<double> run() {
        final d = _d(window: 5);
        final r = SeededRandom(11);
        return [
          for (var i = 0; i < 300; i++)
            (() {
              d.record(won: r.nextDouble() < 0.7);
              return d.value;
            })(),
        ];
      }

      expect(run(), run());
    });

    test('toJson/restore continues the exact same trajectory', () {
      final a = _d(window: 5);
      final r = SeededRandom(3);
      for (var i = 0; i < 60; i++) {
        a.record(won: r.nextDouble() < 0.6);
      }
      final b = _d(window: 5)..restore(a.toJson());
      expect(b.value, a.value);
      for (var i = 0; i < 100; i++) {
        final w = r.nextDouble() < 0.6;
        a.record(won: w);
        b.record(won: w);
        expect(b.value, a.value, reason: 'step $i');
      }
    });

    test('restore tolerates garbage: wrong types, NaN, out of range', () {
      final d = _d(window: 4);
      d.restore({'value': 'x', 'recent': 'nope'});
      expect(d.value, 5);
      d.restore({'value': double.nan, 'recent': [true, false]});
      expect(d.value, 5);
      d.restore({'value': 99.0, 'recent': List.filled(50, true)});
      expect(d.value, 10, reason: 'clamped to max');
      d.restore({'value': -3, 'recent': [1, 'a', null, true]});
      expect(d.value, 1, reason: 'clamped to min');
      d.restore(const {});
      expect(d.value, 5, reason: 'missing -> start');
    });

    test('restore keeps only the newest window results', () {
      final d = _d(window: 3)
        ..restore({'value': 5.0, 'recent': List.filled(50, false)});
      expect(d.toJson()['recent'], hasLength(3));
    });
  });
}
