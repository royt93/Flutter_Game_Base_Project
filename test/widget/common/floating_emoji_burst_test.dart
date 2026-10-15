import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/floating_emoji_burst.dart';

void main() {
  const particle = FloatingEmojiParticle(
    emoji: '❤️',
    origin: Offset(0.5, 0.8),
    durationSeconds: 2,
    amplitude: 20,
    frequency: 1,
    phase: 0,
  );

  test('zigzag position is deterministic and rises upward', () {
    final start = floatingEmojiOffsetAt(
      particle,
      const Size(200, 300),
      0,
      riseDistance: 120,
    );
    final wave = floatingEmojiOffsetAt(
      particle,
      const Size(200, 300),
      pi / 2,
      riseDistance: 120,
    );
    final end = floatingEmojiOffsetAt(
      particle,
      const Size(200, 300),
      2,
      riseDistance: 120,
    );
    expect(start, const Offset(100, 240));
    expect(wave.dx, closeTo(120, 0.001));
    expect(wave.dy, lessThan(start.dy));
    expect(end.dy, closeTo(120, 0.001));
  });

  test('opacity fades to zero at duration and clamps outside interval', () {
    expect(floatingEmojiOpacityAt(particle, 0), 1);
    expect(floatingEmojiOpacityAt(particle, 1), 1);
    expect(floatingEmojiOpacityAt(particle, 1.55), closeTo(0.5, 0.001));
    expect(floatingEmojiOpacityAt(particle, 2), 0);
    expect(floatingEmojiOpacityAt(particle, 3), 0);
  });

  testWidgets('validates burst configuration and rejects empty emoji', (
    tester,
  ) async {
    expect(
      () => FloatingEmojiBurst(duration: Duration.zero),
      throwsArgumentError,
    );
    expect(
      () => FloatingEmojiBurst(origin: const Offset(1.1, 0.5)),
      throwsArgumentError,
    );
    final key = GlobalKey<FloatingEmojiBurstState>();
    await tester.pumpWidget(MaterialApp(home: FloatingEmojiBurst(key: key)));
    expect(() => key.currentState!.burst(''), throwsArgumentError);
  });

  testWidgets('five triggers render then automatically clean themselves up', (
    tester,
  ) async {
    var finished = 0;
    final key = GlobalKey<FloatingEmojiBurstState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 300,
            child: FloatingEmojiBurst(
              key: key,
              duration: const Duration(seconds: 2),
              random: Random(7),
              onFinished: () => finished++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (var i = 0; i < 5; i++) {
      key.currentState!.burst('❤️');
    }
    await tester.pump();
    expect(key.currentState!.activeCount, 5);
    expect(find.text('❤️'), findsNWidgets(5));

    await tester.pump(const Duration(seconds: 2));
    expect(key.currentState!.activeCount, 0);
    expect(find.text('❤️'), findsNothing);
    expect(finished, 1);
    expect(key.currentState!.isAnimating, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drops new emojis after concurrency cap', (tester) async {
    final key = GlobalKey<FloatingEmojiBurstState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 300,
            child: FloatingEmojiBurst(key: key, random: Random(3)),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 25; i++) {
      key.currentState!.burst('👏');
    }
    await tester.pump();
    expect(key.currentState!.activeCount, 20);
    expect(find.text('👏'), findsNWidgets(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion skips the burst and releases active emojis', (
    tester,
  ) async {
    final key = GlobalKey<FloatingEmojiBurstState>();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: FloatingEmojiBurst(key: key, random: Random(3)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    key.currentState!.burst('😂');
    await tester.pump();
    expect(key.currentState!.activeCount, 0);
    expect(key.currentState!.isAnimating, isFalse);
    expect(find.text('😂'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
