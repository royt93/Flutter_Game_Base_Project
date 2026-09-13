import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/wheel_spinner.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reducedMotion),
  child: MaterialApp(
    home: Material(child: Center(child: child)),
  ),
);

void main() {
  group('WheelSpinner', () {
    final segments = const [
      WheelSegment(label: '10 coins', color: Colors.red, value: 10),
      WheelSegment(label: '50 coins', color: Colors.blue, value: 50),
      WheelSegment(label: '100 coins', color: Colors.green, value: 100),
      WheelSegment(label: 'Jackpot', color: Colors.amber, value: 1000),
    ];

    test(
      'controller rejects negative resultIndex before notifying listeners',
      () {
        final controller = WheelSpinnerController();
        var notified = false;
        controller.addListener(() => notified = true);

        expect(() => controller.spin(-1), throwsRangeError);
        expect(controller.resultIndex, 0);
        expect(notified, isFalse);
      },
    );

    test('runtime configuration validation names every invalid parameter', () {
      void expectInvalid({
        List<WheelSegment>? segmentOverride,
        double size = 260,
        Duration spinDuration = const Duration(seconds: 3),
        int extraTurns = 4,
        required String parameter,
      }) {
        expect(
          () => WheelSpinner.validateConfiguration(
            segments: segmentOverride ?? segments,
            size: size,
            spinDuration: spinDuration,
            extraTurns: extraTurns,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              parameter,
            ),
          ),
        );
      }

      expectInvalid(
        segmentOverride: const [WheelSegment(label: 'Only', color: Colors.red)],
        parameter: 'segments',
      );
      expectInvalid(size: 0, parameter: 'size');
      expectInvalid(size: double.nan, parameter: 'size');
      expectInvalid(
        spinDuration: const Duration(seconds: -1),
        parameter: 'spinDuration',
      );
      expectInvalid(extraTurns: -1, parameter: 'extraTurns');
    });

    testWidgets('out-of-range resultIndex fails before list access', (
      tester,
    ) async {
      final controller = WheelSpinnerController();
      await tester.pumpWidget(
        _wrap(
          WheelSpinner(
            segments: segments,
            controller: controller,
            onSpinEnd: (_) {},
          ),
        ),
      );

      controller.spin(segments.length);
      await tester.pump();

      expect(tester.takeException(), isA<RangeError>());
    });

    testWidgets('renders exactly the segments passed in', (tester) async {
      final controller = WheelSpinnerController();
      await tester.pumpWidget(
        _wrap(
          WheelSpinner(
            segments: segments,
            controller: controller,
            onSpinEnd: (_) {},
          ),
        ),
      );

      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('wheelSpinnerPainter')),
                  )
                  .painter
              as WheelSpinnerPainter;
      expect(painter.segments, segments);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'spin(resultIndex) rồi settle animation → onSpinEnd nhận đúng segment',
      (tester) async {
        WheelSegment? result;
        final controller = WheelSpinnerController();
        await tester.pumpWidget(
          _wrap(
            WheelSpinner(
              segments: segments,
              controller: controller,
              onSpinEnd: (s) => result = s,
              spinDuration: const Duration(milliseconds: 300),
            ),
          ),
        );

        controller.spin(2);
        await tester.pump();
        expect(result, isNull);
        await tester.pumpAndSettle();

        expect(result, segments[2]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ENH-17: Reduce Motion bật → onSpinEnd fire ngay, không cần chờ animation',
      (tester) async {
        WheelSegment? result;
        final controller = WheelSpinnerController();
        await tester.pumpWidget(
          _wrap(
            WheelSpinner(
              segments: segments,
              controller: controller,
              onSpinEnd: (s) => result = s,
              spinDuration: const Duration(seconds: 5),
            ),
            reducedMotion: true,
          ),
        );

        controller.spin(1);
        await tester.pump();

        expect(result, segments[1]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('spin lần 2 trước khi lần 1 xong → chỉ kết quả mới nhất fire', (
      tester,
    ) async {
      final results = <WheelSegment>[];
      final controller = WheelSpinnerController();
      await tester.pumpWidget(
        _wrap(
          WheelSpinner(
            segments: segments,
            controller: controller,
            onSpinEnd: results.add,
            spinDuration: const Duration(milliseconds: 300),
          ),
        ),
      );

      controller.spin(0);
      await tester.pump(const Duration(milliseconds: 50));
      controller.spin(3);
      await tester.pumpAndSettle();

      expect(results, [segments[3]]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ít hơn 2 segment thì throw assert', (tester) async {
      expect(
        () => WheelSpinner(
          segments: const [WheelSegment(label: 'Only', color: Colors.red)],
          controller: WheelSpinnerController(),
          onSpinEnd: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('ENH-33: rim vẽ glow layer phía sau, không throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WheelSpinner(
            segments: segments,
            controller: WheelSpinnerController(),
            onSpinEnd: (_) {},
          ),
        ),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('wheelSpinnerPainter')),
                  )
                  .painter
              as CustomPainter;
      painter.paint(canvas, const Size(260, 260));
      recorder.endRecording().dispose();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ENH-33: pointer có glow backdrop', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WheelSpinner(
            segments: segments,
            controller: WheelSpinnerController(),
            onSpinEnd: (_) {},
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_drop_down_rounded),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.boxShadow, isNotNull);
      expect(decoration!.boxShadow!.isNotEmpty, true);
    });

    group('ENH-38: RTL', () {
      WheelSpinnerPainter painterOf(WidgetTester tester) =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('wheelSpinnerPainter')),
                  )
                  .painter
              as WheelSpinnerPainter;

      testWidgets('LTR (mặc định): painter nhận textDirection.ltr', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            WheelSpinner(
              segments: segments,
              controller: WheelSpinnerController(),
              onSpinEnd: (_) {},
            ),
          ),
        );

        expect(painterOf(tester).textDirection, TextDirection.ltr);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'RTL: painter nhận đúng textDirection.rtl từ Directionality ambient (không hardcode ltr nữa)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Material(
                child: Center(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: WheelSpinner(
                      segments: segments,
                      controller: WheelSpinnerController(),
                      onSpinEnd: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(painterOf(tester).textDirection, TextDirection.rtl);
          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}
