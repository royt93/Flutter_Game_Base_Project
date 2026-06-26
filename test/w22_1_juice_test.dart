import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/logic/juice.dart';

void main() {
  group('juiceTierFor — thang cường độ leo dần', () {
    test('<3 combo: không shake/flash', () {
      for (final c in [0, 1, 2]) {
        final t = juiceTierFor(c);
        expect(t.shake, 0);
        expect(t.flash, 0);
        expect(t.slowmo, isFalse);
      }
    });

    test('combo 3: shake nhẹ + flash mờ, chưa slow-mo', () {
      final t = juiceTierFor(3);
      expect(t.shake, greaterThan(0));
      expect(t.slowmo, isFalse);
    });

    test('combo 4-5: mạnh hơn combo 3, chưa slow-mo', () {
      expect(juiceTierFor(4).shake, greaterThan(juiceTierFor(3).shake));
      expect(juiceTierFor(5).slowmo, isFalse);
      expect(juiceTierFor(4).haptic, JuiceHaptic.medium);
    });

    test('wombo (>=6): slow-mo + shake mạnh nhất + haptic heavy', () {
      final t = juiceTierFor(kWomboCombo);
      expect(t.slowmo, isTrue);
      expect(t.haptic, JuiceHaptic.heavy);
      expect(t.shake, greaterThanOrEqualTo(juiceTierFor(5).shake));
    });

    test('đơn điệu không giảm theo combo', () {
      for (var c = 0; c < 12; c++) {
        expect(
          juiceTierFor(c + 1).shake,
          greaterThanOrEqualTo(juiceTierFor(c).shake),
        );
      }
    });
  });

  group('trailParticlesFor — gem fall trail', () {
    const cell = 60.0;
    test('rơi chậm (<0.6 ô) → 0 hạt', () {
      expect(trailParticlesFor(cell * 0.5, cell, reduced: false), 0);
      expect(trailParticlesFor(0, cell, reduced: false), 0);
    });
    test('rơi vừa (>=0.6 ô) → 1 hạt; rơi nhanh (>1.5 ô) → 2 hạt (cap)', () {
      expect(trailParticlesFor(cell * 0.8, cell, reduced: false), 1);
      expect(trailParticlesFor(cell * 2.0, cell, reduced: false), 2);
      expect(trailParticlesFor(cell * 9.0, cell, reduced: false), 2); // cap
    });
    test('reduced=true → luôn 0 (accessibility)', () {
      expect(trailParticlesFor(cell * 5, cell, reduced: true), 0);
    });
    test('cellSize<=0 → 0 (an toàn)', () {
      expect(trailParticlesFor(100, 0, reduced: false), 0);
    });
  });

  group('dampenJuice — accessibility', () {
    test('reduced=false: giữ nguyên', () {
      final t = juiceTierFor(6);
      expect(identical(dampenJuice(t, reduced: false), t), isTrue);
    });

    test('reduced=true: tắt slow-mo, shake giảm 50%, flash giảm', () {
      final t = juiceTierFor(6);
      final d = dampenJuice(t, reduced: true);
      expect(d.slowmo, isFalse);
      expect(d.shake, t.shake * 0.5);
      expect(d.flash, lessThan(t.flash));
      expect(d.haptic, t.haptic); // haptic giữ nguyên
    });
  });
}
