import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/confetti_overlay.dart';

void main() {
  group('pure particle motion (no widget involved)', () {
    const particle = ConfettiParticle(
      startX: 0.5,
      fallSpeed: 100,
      size: 8,
      startRotation: 0,
      rotationSpeed: 2,
      swayAmplitude: 20,
      swayFrequency: 1,
      color: Colors.red,
    );

    test('confettiOffsetAt: falls linearly, sways on a sine wave', () {
      final at0 = confettiOffsetAt(particle, 0);
      expect(at0.dx, 0);
      expect(at0.dy, 0);

      final at1 = confettiOffsetAt(particle, 1);
      expect(at1.dy, 100); // fallSpeed * t
      expect(at1.dx, closeTo(sin(1) * 20, 1e-9));
    });

    test('confettiRotationAt: linear spin from startRotation', () {
      expect(confettiRotationAt(particle, 0), 0);
      expect(confettiRotationAt(particle, 2), closeTo(4, 1e-9));
    });

    test('confettiOpacityAt: full until 70% elapsed, then fades linearly', () {
      expect(confettiOpacityAt(0, 10), 1.0);
      expect(confettiOpacityAt(5, 10), 1.0); // 50% elapsed, still full
      expect(confettiOpacityAt(8.5, 10), closeTo(0.5, 1e-9)); // 85% elapsed
      expect(confettiOpacityAt(10, 10), 0.0);
      expect(confettiOpacityAt(20, 10), 0.0); // past total, clamped
    });

    test('confettiOpacityAt: zero-duration effect is instantly invisible', () {
      expect(confettiOpacityAt(0, 0), 0.0);
    });

    test(
      'generateConfettiParticles: exactly [count] particles, colors drawn '
      'from the given palette',
      () {
        const palette = [Colors.red, Colors.blue];
        final particles = generateConfettiParticles(
          12,
          palette,
          random: Random(1),
        );
        expect(particles.length, 12);
        for (final p in particles) {
          expect(palette, contains(p.color));
        }
      },
    );
  });

  group('ConfettiOverlay widget', () {
    testWidgets('paints particles, then hides itself after duration', (
      tester,
    ) async {
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ConfettiOverlay(
              particleCount: 10,
              duration: const Duration(milliseconds: 200),
              onFinished: () => finished = true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
      expect(finished, isFalse);

      // Bounded pumps well past duration — never pumpAndSettle here: the
      // ticker doesn't stop on its own until this elapses (same gotcha as
      // NeonBg documented in CLAUDE.md).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(finished, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not fire onFinished more than once', (tester) async {
      var finishedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ConfettiOverlay(
              particleCount: 5,
              duration: const Duration(milliseconds: 100),
              onFinished: () => finishedCount++,
            ),
          ),
        ),
      );

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(finishedCount, 1);
    });

    testWidgets('disposes its ticker cleanly on unmount, even mid-burst', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: ConfettiOverlay(
              particleCount: 5,
              duration: Duration(seconds: 5),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Unmount mid-animation — must not leak the Ticker.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
