import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/player_progression_service.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/presentation/widgets/common/level_up_overlay.dart';

LevelUpCelebration _celebration(
  int level, {
  List<RewardLine> rewardLines = const [],
}) => LevelUpCelebration(
  event: LevelUpEvent(level: level, rewardLines: rewardLines),
);

Widget _host(
  LevelUpOverlayController controller, {
  bool? reducedMotion,
  VoidCallback? onSkipTap,
  TextDirection textDirection = TextDirection.ltr,
  double textScaleFactor = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
    child: Directionality(
      textDirection: textDirection,
      child: MaterialApp(
        home: LevelUpOverlay(
          controller: controller,
          reducedMotion: reducedMotion,
          onSkipTap: onSkipTap,
          enableHaptics: false,
          child: const Scaffold(body: Center(child: Text('Game content'))),
        ),
      ),
    ),
  );
}

/// `LevelUpOverlayController`'s phases are driven by real `Timer`s (see
/// `_waitOrSkip`) — `AutomatedTestWidgetsFlutterBinding` fails a test that
/// leaves one pending. `skip()` + a `pump()` called from WITHIN the test
/// body cancels it correctly; the same call from `addTearDown` does not
/// (that callback runs after the widget tree is already torn down, too
/// late for `pump()` to flush the cancellation) — so every test that
/// doesn't let its sequence finish naturally must call this before
/// returning.
Future<void> _finishOrSkip(
  WidgetTester tester,
  LevelUpOverlayController controller,
) async {
  controller.skip();
  await tester.pump();
}

void main() {
  group('LevelUpOverlay: render cơ bản', () {
    testWidgets('idle: chỉ hiện child, không có overlay', (tester) async {
      final controller = LevelUpOverlayController();
      await tester.pumpWidget(_host(controller));

      expect(find.text('Game content'), findsOneWidget);
      expect(find.textContaining('Level'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('active: hiện đúng "Level N!" và chặn tương tác với child', (
      tester,
    ) async {
      final controller = LevelUpOverlayController(
        xpFillDuration: const Duration(milliseconds: 5),
        levelPopDuration: const Duration(milliseconds: 5),
        rewardRevealDuration: const Duration(milliseconds: 5),
      );
      await tester.pumpWidget(_host(controller, reducedMotion: true));

      unawaited(controller.show([_celebration(5)]));
      await tester.pump();

      expect(find.text('Level 5!'), findsOneWidget);

      final ignorePointers = tester.widgetList<IgnorePointer>(
        find.byType(IgnorePointer),
      );
      expect(ignorePointers, isNotEmpty);
      expect(ignorePointers.any((w) => w.ignoring), isTrue);

      await _finishOrSkip(tester, controller);
    });

    testWidgets('hiện đúng reward line ở phase rewardReveal', (tester) async {
      final controller = LevelUpOverlayController(
        xpFillDuration: const Duration(milliseconds: 5),
        levelPopDuration: const Duration(milliseconds: 5),
        rewardRevealDuration: const Duration(milliseconds: 200),
      );
      await tester.pumpWidget(_host(controller, reducedMotion: true));

      unawaited(
        controller.show([
          _celebration(
            3,
            rewardLines: const [RewardLine(currency: 'gem', amount: 25)],
          ),
        ]),
      );
      await tester.pump(); // xpFill
      await tester.pump(const Duration(milliseconds: 10)); // levelPop
      await tester.pump(const Duration(milliseconds: 10)); // rewardReveal

      expect(find.text('+25 gem'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _finishOrSkip(tester, controller);
    });
  });

  group('LevelUpOverlay: skip', () {
    testWidgets('bấm Skip: overlay tắt ngay, onComplete gọi đúng 1 lần', (
      tester,
    ) async {
      final controller = LevelUpOverlayController(
        xpFillDuration: const Duration(seconds: 10),
        levelPopDuration: const Duration(seconds: 10),
        rewardRevealDuration: const Duration(seconds: 10),
      );
      var completeCount = 0;

      await tester.pumpWidget(
        _host(controller, reducedMotion: true, onSkipTap: controller.skip),
      );

      unawaited(
        controller.show([_celebration(2)], onComplete: () => completeCount++),
      );
      await tester.pump();
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(find.text('Game content'), findsOneWidget);
      expect(completeCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('không truyền onSkipTap: không có nút Skip nào', (
      tester,
    ) async {
      final controller = LevelUpOverlayController(
        xpFillDuration: const Duration(milliseconds: 5),
        levelPopDuration: const Duration(milliseconds: 5),
        rewardRevealDuration: const Duration(milliseconds: 5),
      );
      await tester.pumpWidget(_host(controller, reducedMotion: true));

      unawaited(controller.show([_celebration(2)]));
      await tester.pump();

      expect(find.text('Skip'), findsNothing);

      await _finishOrSkip(tester, controller);
    });
  });

  group('LevelUpOverlay: reduced motion', () {
    testWidgets(
      'reducedMotion=true: mọi animation duration co về 0, vẫn hiện đúng nội dung',
      (tester) async {
        final controller = LevelUpOverlayController(
          xpFillDuration: const Duration(milliseconds: 5),
          levelPopDuration: const Duration(milliseconds: 5),
          rewardRevealDuration: const Duration(milliseconds: 5),
        );
        await tester.pumpWidget(_host(controller, reducedMotion: true));

        unawaited(controller.show([_celebration(7)]));
        await tester.pump();

        final tweenBuilders = tester.widgetList<TweenAnimationBuilder<double>>(
          find.byType(TweenAnimationBuilder<double>),
        );
        for (final builder in tweenBuilders) {
          expect(builder.duration, Duration.zero);
        }
        expect(tester.takeException(), isNull);

        await _finishOrSkip(tester, controller);
      },
    );
  });

  group('LevelUpOverlay: text scale/RTL không overflow', () {
    testWidgets(
      'textScaleFactor lớn (2.5) + reward line dài: không throw overflow',
      (tester) async {
        final controller = LevelUpOverlayController(
          xpFillDuration: const Duration(milliseconds: 5),
          levelPopDuration: const Duration(milliseconds: 5),
          rewardRevealDuration: const Duration(milliseconds: 200),
        );
        await tester.pumpWidget(
          _host(controller, reducedMotion: true, textScaleFactor: 2.5),
        );

        unawaited(
          controller.show([
            _celebration(
              9,
              rewardLines: const [
                RewardLine(
                  currency: 'super_rare_legendary_gem_currency',
                  amount: 999999,
                ),
              ],
            ),
          ]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 10));

        expect(tester.takeException(), isNull);

        await _finishOrSkip(tester, controller);
      },
    );

    testWidgets('RTL: overlay vẫn render đúng, không throw', (tester) async {
      final controller = LevelUpOverlayController(
        xpFillDuration: const Duration(milliseconds: 5),
        levelPopDuration: const Duration(milliseconds: 5),
        rewardRevealDuration: const Duration(milliseconds: 5),
      );
      await tester.pumpWidget(
        _host(
          controller,
          reducedMotion: true,
          textDirection: TextDirection.rtl,
        ),
      );

      unawaited(controller.show([_celebration(4)]));
      await tester.pump();

      expect(find.text('Level 4!'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _finishOrSkip(tester, controller);
    });
  });

  group('LevelUpOverlay: nhiều reward line không overflow list', () {
    testWidgets('10 reward line trong 1 event: render hết, không throw', (
      tester,
    ) async {
      final controller = LevelUpOverlayController(
        xpFillDuration: const Duration(milliseconds: 5),
        levelPopDuration: const Duration(milliseconds: 5),
        rewardRevealDuration: const Duration(milliseconds: 200),
      );
      await tester.pumpWidget(_host(controller, reducedMotion: true));

      unawaited(
        controller.show([
          _celebration(
            6,
            rewardLines: List.generate(
              10,
              (i) => RewardLine(currency: 'currency_$i', amount: i + 1),
            ),
          ),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text('+1 currency_0'), findsOneWidget);
      expect(find.text('+10 currency_9'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _finishOrSkip(tester, controller);
    });
  });

  group('LevelUpOverlay: không tự grant reward', () {
    test(
      'source code không gọi grantXp/commit/RewardTransactionPipeline nào — chỉ nhận LevelUpEvent/RewardLine làm dữ liệu hiển thị',
      () {
        final source = File(
          'lib/presentation/widgets/common/level_up_overlay.dart',
        ).readAsStringSync();

        // Kiểm tra LỜI GỌI thật (cú pháp gọi hàm/khởi tạo), không phải chỉ
        // tên xuất hiện trong doc comment giải thích kiến trúc (ví dụ
        // "...obtained from PlayerProgressionService.grantXp" là prose hợp
        // lệ, không phải code thật gọi nó).
        expect(source.contains('.grantXp('), isFalse);
        expect(source.contains('RewardTransactionPipeline('), isFalse);
        expect(source.contains('.commit('), isFalse);
        expect(source.contains('PlayerProgressionService('), isFalse);
        expect(
          source.contains(
            "import '../../../core/reward_transaction_pipeline.dart'",
          ),
          isFalse,
        );
      },
    );
  });
}
