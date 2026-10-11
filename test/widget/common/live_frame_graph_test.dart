import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/live_frame_graph.dart';

void main() {
  group('frame classification', () {
    test('normal <= 16.667ms, slow <= 33ms, jank > 33ms', () {
      expect(
        classifyFrameDuration(const Duration(milliseconds: 16)),
        FrameTimingClass.normal,
      );
      expect(
        classifyFrameDuration(const Duration(microseconds: 16667)),
        FrameTimingClass.normal,
      );
      expect(
        classifyFrameDuration(const Duration(milliseconds: 20)),
        FrameTimingClass.slow,
      );
      expect(
        classifyFrameDuration(const Duration(milliseconds: 33)),
        FrameTimingClass.slow,
      );
      expect(
        classifyFrameDuration(const Duration(microseconds: 33001)),
        FrameTimingClass.jank,
      );
    });

    test('bounded samples retain newest capacity values', () {
      final samples = BoundedFrameSamples(3)
        ..add(const Duration(milliseconds: 10))
        ..add(const Duration(milliseconds: 20))
        ..add(const Duration(milliseconds: 40))
        ..add(const Duration(milliseconds: 17));
      expect(samples.values, [
        const Duration(milliseconds: 20),
        const Duration(milliseconds: 40),
        const Duration(milliseconds: 17),
      ]);
    });

    test('bounded samples reject non-positive capacity', () {
      expect(() => BoundedFrameSamples(0), throwsArgumentError);
    });
  });

  testWidgets('graph renders with bounded sample capacity label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LiveFrameGraph(capacity: 3))),
    );
    expect(find.text('0/3 frames'), findsOneWidget);
    expect(find.text('Frame time · 0 FPS · Jank: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'injected frame samples update jank summary and stop on unmount',
    (tester) async {
      final timings = StreamController<Duration>.broadcast(sync: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveFrameGraph(
              capacity: 3,
              sampleFrameTimings: timings.stream,
            ),
          ),
        ),
      );

      timings.add(const Duration(milliseconds: 10));
      timings.add(const Duration(milliseconds: 20));
      timings.add(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('3/3 frames'), findsOneWidget);
      expect(find.text('Frame time · 25 FPS · Jank: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      timings.add(const Duration(milliseconds: 5));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await timings.close();
    },
  );
}
