import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/review_prompt_trigger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  testWidgets('render child bình thường, không crash khi chưa có event nào', (
    tester,
  ) async {
    final controller = StreamController<int>.broadcast();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPromptTrigger(
          winStreakEvents: controller.stream,
          showReview: () async {},
          child: const Text('game content'),
        ),
      ),
    );

    expect(find.text('game content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'winStreak đủ ngưỡng, chưa từng hỏi -> gọi showReview đúng 1 lần, '
    'onRequested fire',
    (tester) async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);
      var showReviewCalls = 0;
      var onRequestedCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewPromptTrigger(
            winStreakEvents: controller.stream,
            showReview: () async => showReviewCalls++,
            onRequested: () => onRequestedCalls++,
            minWinStreak: 3,
            child: const Text('game content'),
          ),
        ),
      );

      controller.add(3);
      await tester.pump();

      expect(showReviewCalls, 1);
      expect(onRequestedCalls, 1);
    },
  );

  testWidgets(
    'winStreak chưa đủ ngưỡng -> KHÔNG gọi showReview, KHÔNG fire onRequested',
    (tester) async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);
      var showReviewCalls = 0;
      var onRequestedCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewPromptTrigger(
            winStreakEvents: controller.stream,
            showReview: () async => showReviewCalls++,
            onRequested: () => onRequestedCalls++,
            minWinStreak: 3,
            child: const Text('game content'),
          ),
        ),
      );

      controller.add(2);
      await tester.pump();

      expect(showReviewCalls, 0);
      expect(onRequestedCalls, 0);
    },
  );

  testWidgets(
    'everDeclined: true -> KHÔNG bao giờ gọi showReview dù winStreak đủ',
    (tester) async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);
      var showReviewCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewPromptTrigger(
            winStreakEvents: controller.stream,
            showReview: () async => showReviewCalls++,
            everDeclined: true,
            minWinStreak: 3,
            child: const Text('game content'),
          ),
        ),
      );

      controller.add(10);
      await tester.pump();

      expect(showReviewCalls, 0);
    },
  );

  testWidgets(
    'đã hỏi rồi, event thứ 2 trong cooldown -> KHÔNG hỏi lại (không '
    'double-prompt)',
    (tester) async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);
      var showReviewCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewPromptTrigger(
            winStreakEvents: controller.stream,
            showReview: () async => showReviewCalls++,
            minWinStreak: 3,
            cooldown: const Duration(days: 30),
            child: const Text('game content'),
          ),
        ),
      );

      controller.add(3);
      await tester.pump();
      expect(showReviewCalls, 1);

      controller.add(5);
      await tester.pump();
      expect(showReviewCalls, 1);
    },
  );

  testWidgets('showReview throw -> không crash, nuốt lỗi im lặng', (
    tester,
  ) async {
    final controller = StreamController<int>.broadcast();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPromptTrigger(
          winStreakEvents: controller.stream,
          showReview: () async => throw Exception('platform lỗi'),
          minWinStreak: 3,
          child: const Text('game content'),
        ),
      ),
    );

    controller.add(3);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('game content'), findsOneWidget);
  });

  testWidgets('dispose widget trong lúc chưa có event nào không crash', (
    tester,
  ) async {
    final controller = StreamController<int>.broadcast();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewPromptTrigger(
          winStreakEvents: controller.stream,
          showReview: () async {},
          child: const Text('game content'),
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: Text('other screen')));
    controller.add(3);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
