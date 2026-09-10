import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/wheel_spinner.dart';

Widget _wrap(Widget child, {bool reducedMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reducedMotion),
  child: MaterialApp(home: Material(child: Center(child: child))),
);

void main() {
  group('WheelSpinner', () {
    final segments = const [
      WheelSegment(label: '10 coins', color: Colors.red, value: 10),
      WheelSegment(label: '50 coins', color: Colors.blue, value: 50),
      WheelSegment(label: '100 coins', color: Colors.green, value: 100),
      WheelSegment(label: 'Jackpot', color: Colors.amber, value: 1000),
    ];

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
  });
}
