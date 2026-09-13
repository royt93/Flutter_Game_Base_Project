import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/spotlight_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tutorial_sequence.dart';

void main() {
  group('TutorialSequenceController', () {
    test('start() với list rỗng thì không kích hoạt', () {
      final controller = TutorialSequenceController();
      controller.start(const []);
      expect(controller.isActive, false);
      expect(controller.currentStep, isNull);
    });

    test('start() rồi next() đi tới đúng bước, hết bước cuối thì tự đóng', () {
      final controller = TutorialSequenceController();
      final keyA = GlobalKey();
      final keyB = GlobalKey();
      controller.start([
        TutorialStep(targetKey: keyA, message: 'Step A'),
        TutorialStep(targetKey: keyB, message: 'Step B'),
      ]);

      expect(controller.isActive, true);
      expect(controller.currentStep!.message, 'Step A');

      controller.next();
      expect(controller.isActive, true);
      expect(controller.currentStep!.message, 'Step B');

      controller.next();
      expect(controller.isActive, false);
      expect(controller.currentStep, isNull);
    });

    test('skip() đóng ngay bất kể đang ở bước nào', () {
      final controller = TutorialSequenceController();
      controller.start([
        TutorialStep(targetKey: GlobalKey(), message: 'Step A'),
        TutorialStep(targetKey: GlobalKey(), message: 'Step B'),
      ]);
      controller.skip();
      expect(controller.isActive, false);
    });

    group('ENH-48: currentIndex/stepCount', () {
      test('chưa start() → currentIndex âm, stepCount = 0', () {
        final controller = TutorialSequenceController();
        expect(controller.currentIndex, lessThan(0));
        expect(controller.stepCount, 0);
      });

      test('start() rồi next() → currentIndex/stepCount đúng ở mỗi bước', () {
        final controller = TutorialSequenceController();
        controller.start([
          TutorialStep(targetKey: GlobalKey(), message: 'A'),
          TutorialStep(targetKey: GlobalKey(), message: 'B'),
          TutorialStep(targetKey: GlobalKey(), message: 'C'),
        ]);
        expect(controller.currentIndex, 0);
        expect(controller.stepCount, 3);

        controller.next();
        expect(controller.currentIndex, 1);
        expect(controller.stepCount, 3);

        controller.next();
        expect(controller.currentIndex, 2);
        expect(controller.stepCount, 3);
      });

      test('skip() → stepCount về 0 (không active nữa)', () {
        final controller = TutorialSequenceController();
        controller.start([TutorialStep(targetKey: GlobalKey(), message: 'A')]);
        controller.skip();
        expect(controller.stepCount, 0);
      });
    });
  });

  group('TutorialSequence widget', () {
    testWidgets(
      'chưa start() thì chỉ render child, không có SpotlightOverlay',
      (tester) async {
        final controller = TutorialSequenceController();
        final targetKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: TutorialSequence(
              controller: controller,
              child: Material(child: Text('target', key: targetKey)),
            ),
          ),
        );

        expect(find.byType(SpotlightOverlay), findsNothing);
        expect(find.text('target'), findsOneWidget);
      },
    );

    testWidgets(
      'start() → hiện SpotlightOverlay cho bước hiện tại, dismiss (Got it) tự next()',
      (tester) async {
        final controller = TutorialSequenceController();
        final keyA = GlobalKey();
        final keyB = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: TutorialSequence(
              controller: controller,
              child: Material(
                child: Column(
                  children: [
                    Text('A', key: keyA),
                    Text('B', key: keyB),
                  ],
                ),
              ),
            ),
          ),
        );

        controller.start([
          TutorialStep(targetKey: keyA, message: 'Message A'),
          TutorialStep(targetKey: keyB, message: 'Message B'),
        ]);
        await tester.pump();
        await tester.pump();

        expect(find.byType(SpotlightOverlay), findsOneWidget);
        expect(find.text('Message A'), findsOneWidget);

        await tester.tap(find.text('Got it'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Message B'), findsOneWidget);
      },
    );

    testWidgets('onComplete được gọi khi hết chuỗi bước', (tester) async {
      final controller = TutorialSequenceController();
      final key = GlobalKey();
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TutorialSequence(
            controller: controller,
            onComplete: () => completed = true,
            child: Material(child: Text('A', key: key)),
          ),
        ),
      );

      controller.start([TutorialStep(targetKey: key, message: 'Only step')]);
      await tester.pump();
      await tester.pump();

      expect(completed, false);
      await tester.tap(find.text('Got it'));
      await tester.pump();

      expect(completed, true);
      expect(find.byType(SpotlightOverlay), findsNothing);
    });
  });

  group('ENH-48: step indicator + Skip button', () {
    testWidgets('hiển thị đúng "Step X/Y" ở từng bước', (tester) async {
      final controller = TutorialSequenceController();
      final keyA = GlobalKey();
      final keyB = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: TutorialSequence(
            controller: controller,
            child: Material(
              child: Column(
                children: [
                  Text('A', key: keyA),
                  Text('B', key: keyB),
                ],
              ),
            ),
          ),
        ),
      );

      controller.start([
        TutorialStep(targetKey: keyA, message: 'Message A'),
        TutorialStep(targetKey: keyB, message: 'Message B'),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Step 1/2'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pump();

      expect(find.text('Step 1/2'), findsNothing);
      expect(find.text('Step 2/2'), findsOneWidget);
    });

    testWidgets(
      'showSkip mặc định true → có nút Skip, tap Skip kết thúc ngay dù chưa hết bước',
      (tester) async {
        final controller = TutorialSequenceController();
        final keyA = GlobalKey();
        final keyB = GlobalKey();
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: TutorialSequence(
              controller: controller,
              onComplete: () => completed = true,
              child: Material(
                child: Column(
                  children: [
                    Text('A', key: keyA),
                    Text('B', key: keyB),
                  ],
                ),
              ),
            ),
          ),
        );

        controller.start([
          TutorialStep(targetKey: keyA, message: 'Message A'),
          TutorialStep(targetKey: keyB, message: 'Message B'),
        ]);
        await tester.pump();
        await tester.pump();

        expect(find.text('Skip'), findsOneWidget);

        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(controller.isActive, isFalse);
        expect(completed, isTrue);
        expect(find.byType(SpotlightOverlay), findsNothing);
      },
    );

    testWidgets('showSkip: false → không có nút Skip nào', (tester) async {
      final controller = TutorialSequenceController();
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: TutorialSequence(
            controller: controller,
            showSkip: false,
            child: Material(child: Text('A', key: key)),
          ),
        ),
      );

      controller.start([TutorialStep(targetKey: key, message: 'Message A')]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Step 1/1'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('skipLabel tuỳ chỉnh → hiện đúng chuỗi đó thay vì "Skip"', (
      tester,
    ) async {
      final controller = TutorialSequenceController();
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: TutorialSequence(
            controller: controller,
            skipLabel: 'Bỏ qua',
            child: Material(child: Text('A', key: key)),
          ),
        ),
      );

      controller.start([TutorialStep(targetKey: key, message: 'Message A')]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Skip'), findsNothing);
      expect(find.text('Bỏ qua'), findsOneWidget);
    });
  });
}
