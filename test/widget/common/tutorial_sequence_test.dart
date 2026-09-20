import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/analytics_provider.dart';
import 'package:roy_casual_kit/presentation/widgets/common/spotlight_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tutorial_sequence.dart';

class _FakeAnalyticsProvider implements AnalyticsProvider {
  // (event name, stepId) — a plain record of primitives instead of the
  // raw params Map: Dart's default Map `==` is reference (not value)
  // equality, so comparing a record that embeds 2 separately-built Maps
  // via `expect(..., [...])` would never match even for identical
  // contents. Extracting just `stepId` sidesteps that entirely.
  final List<(String, Object?)> events = [];

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    events.add((name, params?['stepId']));
  }
}

void main() {
  tearDown(Get.reset);

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

  group('IDEA-35: TutorialStep.listFromJson', () {
    test('parse đúng JSON hợp lệ, ánh xạ đúng GlobalKey qua registry', () {
      final keyA = GlobalKey();
      final keyB = GlobalKey();

      final steps = TutorialStep.listFromJson(
        '[{"id":"s1","targetKey":"a","message":"Msg A","title":"Title A",'
        '"buttonLabel":"Next"},'
        '{"id":"s2","targetKey":"b","message":"Msg B"}]',
        keyRegistry: {'a': keyA, 'b': keyB},
      );

      expect(steps, hasLength(2));
      expect(steps[0].id, 's1');
      expect(steps[0].targetKey, keyA);
      expect(steps[0].message, 'Msg A');
      expect(steps[0].title, 'Title A');
      expect(steps[0].buttonLabel, 'Next');
      expect(steps[1].id, 's2');
      expect(steps[1].targetKey, keyB);
      expect(steps[1].title, isNull);
      expect(steps[1].buttonLabel, 'Got it');
    });

    test('targetKey không có trong registry: skip bước đó, không crash', () {
      final keyA = GlobalKey();

      final steps = TutorialStep.listFromJson(
        '[{"id":"s1","targetKey":"unknown_key","message":"Msg"},'
        '{"id":"s2","targetKey":"a","message":"Msg A"}]',
        keyRegistry: {'a': keyA},
      );

      expect(steps, hasLength(1));
      expect(steps.single.id, 's2');
    });

    test('JSON không phải mảng hợp lệ: trả về danh sách rỗng, không throw', () {
      expect(
        () => TutorialStep.listFromJson('not json {{{', keyRegistry: {}),
        returnsNormally,
      );
      expect(
        TutorialStep.listFromJson('not json {{{', keyRegistry: {}),
        isEmpty,
      );
      expect(
        TutorialStep.listFromJson('{"not":"a list"}', keyRegistry: {}),
        isEmpty,
      );
    });

    test(
      'bỏ qua từng bước thiếu field bắt buộc hoặc sai kiểu, giữ lại bước hợp lệ',
      () {
        final keyA = GlobalKey();

        final steps = TutorialStep.listFromJson(
          '['
          '{"targetKey":"a","message":"missing id"},'
          '{"id":"","targetKey":"a","message":"blank id"},'
          '{"id":"s3","message":"missing targetKey"},'
          '{"id":"s4","targetKey":"a","message":123},'
          '{"id":"s5","targetKey":123,"message":"wrong targetKey type"},'
          '{"id":"s6","targetKey":"a","message":"wrong title type","title":42},'
          '{"id":"s7","targetKey":"a","message":"wrong buttonLabel type","buttonLabel":42},'
          '"not a map",'
          '{"id":"good","targetKey":"a","message":"OK"}'
          ']',
          keyRegistry: {'a': keyA},
        );

        expect(steps, hasLength(1));
        expect(steps.single.id, 'good');
      },
    );

    test('danh sách rỗng ([]) trả về danh sách rỗng, không throw', () {
      expect(TutorialStep.listFromJson('[]', keyRegistry: {}), isEmpty);
    });
  });

  group('IDEA-35: analytics shown/dismissed logging', () {
    late _FakeAnalyticsProvider analytics;

    setUp(() {
      analytics = _FakeAnalyticsProvider();
      Get.put<AnalyticsProvider>(analytics);
    });

    test('start() log đúng "tutorial_step_shown" cho step có id', () {
      final controller = TutorialSequenceController();
      final key = GlobalKey();

      controller.start([
        TutorialStep(id: 'step1', targetKey: key, message: 'Msg'),
      ]);

      expect(analytics.events, [('tutorial_step_shown', 'step1')]);
    });

    test('next() log "dismissed" cho step cũ rồi "shown" cho step mới', () {
      final controller = TutorialSequenceController();
      final keyA = GlobalKey();
      final keyB = GlobalKey();

      controller.start([
        TutorialStep(id: 'step1', targetKey: keyA, message: 'A'),
        TutorialStep(id: 'step2', targetKey: keyB, message: 'B'),
      ]);
      analytics.events.clear();

      controller.next();

      expect(analytics.events, [
        ('tutorial_step_dismissed', 'step1'),
        ('tutorial_step_shown', 'step2'),
      ]);
    });

    test(
      'next() ở bước cuối chỉ log "dismissed" đúng 1 lần, không log "shown" thừa',
      () {
        final controller = TutorialSequenceController();
        final key = GlobalKey();

        controller.start([
          TutorialStep(id: 'only', targetKey: key, message: 'Msg'),
        ]);
        analytics.events.clear();

        controller.next();

        expect(analytics.events, [('tutorial_step_dismissed', 'only')]);
        expect(controller.isActive, isFalse);
      },
    );

    test('skip() log đúng "dismissed" cho step đang hiện tại', () {
      final controller = TutorialSequenceController();
      final keyA = GlobalKey();
      final keyB = GlobalKey();

      controller.start([
        TutorialStep(id: 'step1', targetKey: keyA, message: 'A'),
        TutorialStep(id: 'step2', targetKey: keyB, message: 'B'),
      ]);
      analytics.events.clear();

      controller.skip();

      expect(analytics.events, [('tutorial_step_dismissed', 'step1')]);
    });

    test(
      'step KHÔNG có id (authored kiểu imperative cũ) không log gì cả — không phá hành vi cũ',
      () {
        final controller = TutorialSequenceController();
        final key = GlobalKey();

        controller.start([TutorialStep(targetKey: key, message: 'Msg')]);
        controller.next();

        expect(analytics.events, isEmpty);
      },
    );

    test('không có AnalyticsProvider nào đăng ký: không throw', () {
      Get.reset();
      final controller = TutorialSequenceController();
      final key = GlobalKey();

      expect(
        () => controller.start([
          TutorialStep(id: 'step1', targetKey: key, message: 'Msg'),
        ]),
        returnsNormally,
      );
    });
  });
}
