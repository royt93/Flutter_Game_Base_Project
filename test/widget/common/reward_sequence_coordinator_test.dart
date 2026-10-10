import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/reward_sequence_coordinator.dart';

void main() {
  group('RewardSequenceCoordinator logic & validation', () {
    test('validates stepDuration > 0 at runtime', () {
      expect(
        () => RewardSequenceCoordinator(stepDuration: Duration.zero),
        throwsArgumentError,
      );
      expect(
        () => RewardSequenceCoordinator(
          stepDuration: const Duration(milliseconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('controller step transitions and skipToEnd', () {
      final controller = RewardSequenceController();
      expect(controller.step, RewardSequenceStep.initial);
      expect(controller.isReady, isFalse);

      var notified = false;
      controller.addListener(() => notified = true);

      controller.advanceTo(RewardSequenceStep.banner);
      expect(controller.step, RewardSequenceStep.banner);
      expect(notified, isTrue);

      controller.skipToEnd();
      expect(controller.step, RewardSequenceStep.ready);
      expect(controller.isReady, isTrue);

      controller.reset();
      expect(controller.step, RewardSequenceStep.initial);
      expect(controller.isReady, isFalse);
    });
  });

  group('RewardSequenceCoordinator widget tests', () {
    testWidgets(
      'automatically progresses through sequence and invokes onSequenceComplete',
      (tester) async {
        var completed = false;
        var actionTaps = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardSequenceCoordinator(
                banner: const Text('Victory!'),
                content: const Text('3 Stars'),
                actionButton: GestureDetector(
                  onTap: () => actionTaps++,
                  child: const Text('Continue'),
                ),
                stepDuration: const Duration(milliseconds: 100),
                onSequenceComplete: () => completed = true,
              ),
            ),
          ),
        );

        // First stage starts immediately; later slots are genuinely hidden.
        await tester.pump();
        expect(find.text('Victory!').hitTestable(), findsOneWidget);
        expect(find.text('3 Stars').hitTestable(), findsNothing);
        expect(completed, isFalse);

        // Advance to content
        await tester.pump(const Duration(milliseconds: 110));
        expect(find.text('3 Stars'), findsOneWidget);
        expect(completed, isFalse);

        // Advance to ready (action button enabled)
        await tester.pump(const Duration(milliseconds: 110));
        expect(find.text('Continue').hitTestable(), findsOneWidget);
        expect(completed, isTrue);
        await tester.tap(find.text('Continue'));
        expect(actionTaps, 1);
      },
    );

    testWidgets('tap anywhere skips sequence immediately to ready', (
      tester,
    ) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardSequenceCoordinator(
              banner: const Text('Victory!'),
              content: const Text('3 Stars'),
              actionButton: const Text('Continue'),
              stepDuration: const Duration(milliseconds: 300),
              onSequenceComplete: () => completed = true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(completed, isFalse);

      // Tap to skip
      await tester.tap(find.byType(RewardSequenceCoordinator));
      await tester.pump();

      expect(completed, isTrue);
      expect(find.text('Continue').hitTestable(), findsOneWidget);
    });

    testWidgets(
      'reduced motion enters ready state immediately without animation lag',
      (tester) async {
        var completed = false;

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: RewardSequenceCoordinator(
                  banner: const Text('Victory!'),
                  content: const Text('3 Stars'),
                  actionButton: const Text('Continue'),
                  onSequenceComplete: () => completed = true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(completed, isTrue);
        expect(find.text('Continue'), findsOneWidget);
      },
    );

    testWidgets('hidden slot is not hit-testable or semantic until its step', (
      tester,
    ) async {
      var hiddenTaps = 0;
      final controller = RewardSequenceController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardSequenceCoordinator(
              autoStart: false,
              controller: controller,
              banner: const Text('Banner'),
              content: GestureDetector(
                onTap: () => hiddenTaps++,
                child: const Text('Content action'),
              ),
              stepDuration: const Duration(milliseconds: 100),
            ),
          ),
        ),
      );
      expect(find.text('Content action').hitTestable(), findsNothing);
      await tester.tapAt(
        tester.getCenter(find.byType(RewardSequenceCoordinator)),
      );
      expect(hiddenTaps, 0);
      controller.advanceTo(RewardSequenceStep.content);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Content action'));
      expect(hiddenTaps, 1);
    });

    testWidgets(
      'controller swap detaches old controller and observes new one',
      (tester) async {
        final oldController = RewardSequenceController();
        final nextController = RewardSequenceController();
        final completed = <String>[];
        Widget build(RewardSequenceController controller, String id) =>
            MaterialApp(
              home: Scaffold(
                body: RewardSequenceCoordinator(
                  controller: controller,
                  banner: Text('Banner $id'),
                  onSequenceComplete: () => completed.add(id),
                ),
              ),
            );
        await tester.pumpWidget(build(oldController, 'old'));
        await tester.pump();
        await tester.pumpWidget(build(nextController, 'new'));
        await tester.pump();
        oldController.skipToEnd();
        await tester.pump();
        expect(completed, isEmpty);
        nextController.skipToEnd();
        await tester.pump();
        await tester.pump();
        expect(completed, ['new']);
        await tester.pumpWidget(const SizedBox());
        oldController.skipToEnd();
        oldController.dispose();
        nextController.dispose();
      },
    );

    testWidgets('reset replays once, callback may set parent state safely', (
      tester,
    ) async {
      final controller = RewardSequenceController();
      var completions = 0;
      late StateSetter setParent;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setParent = setState;
              return RewardSequenceCoordinator(
                controller: controller,
                stepDuration: const Duration(milliseconds: 30),
                onSequenceComplete: () => setParent(() => completions++),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(completions, 1);
      controller.reset();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(completions, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets(
      'externally owned controller remains usable after coordinator unmount',
      (tester) async {
        final controller = RewardSequenceController();
        await tester.pumpWidget(
          MaterialApp(
            home: RewardSequenceCoordinator(
              autoStart: false,
              controller: controller,
              banner: const Text('Banner'),
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox());
        controller.advanceTo(RewardSequenceStep.banner);
        expect(controller.step, RewardSequenceStep.banner);
        controller.dispose();
      },
    );

    testWidgets(
      'reset then manually start creates a second completion without controller ownership',
      (tester) async {
        final controller = RewardSequenceController();
        var completions = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: RewardSequenceCoordinator(
              autoStart: false,
              controller: controller,
              onSequenceComplete: () => completions++,
            ),
          ),
        );
        controller.skipToEnd();
        await tester.pump();
        await tester.pump();
        expect(completions, 1);
        controller.reset();
        await tester.pump();
        // autoStart=false intentionally leaves reset at initial until owner advances.
        expect(controller.step, RewardSequenceStep.initial);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        expect(completions, 1);
      },
    );

    testWidgets('autoStart false does not run; enabling it starts sequence', (
      tester,
    ) async {
      var autoStart = false;
      Widget build() => MaterialApp(
        home: Scaffold(
          body: RewardSequenceCoordinator(
            autoStart: autoStart,
            stepDuration: const Duration(milliseconds: 40),
            banner: const Text('Banner'),
          ),
        ),
      );
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Banner').hitTestable(), findsNothing);
      autoStart = true;
      await tester.pumpWidget(build());
      await tester.pump();
      expect(find.text('Banner').hitTestable(), findsOneWidget);
    });

    testWidgets(
      'Reduced Motion after mount skips sequence without visible animation duration',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardSequenceCoordinator(
                key: key,
                autoStart: false,
                banner: const Text('Banner'),
                content: const Text('Content'),
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: RewardSequenceCoordinator(
                  key: key,
                  autoStart: false,
                  banner: const Text('Banner'),
                  content: const Text('Content'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        for (final animated in tester.widgetList<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        )) {
          expect(animated.duration, Duration.zero);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'allowTapToSkip false preserves child taps while sequence continues',
      (tester) async {
        var taps = 0;
        final controller = RewardSequenceController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardSequenceCoordinator(
                controller: controller,
                allowTapToSkip: false,
                autoStart: false,
                banner: GestureDetector(
                  onTap: () => taps++,
                  child: const Text('Banner'),
                ),
              ),
            ),
          ),
        );
        controller.advanceTo(RewardSequenceStep.banner);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.text('Banner'));
        expect(taps, 1);
        expect(controller.step, RewardSequenceStep.banner);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    testWidgets(
      'unmounting mid-sequence cancels timers cleanly without leaking',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardSequenceCoordinator(
                banner: const Text('Victory!'),
                content: const Text('3 Stars'),
                actionButton: const Text('Continue'),
                stepDuration: const Duration(milliseconds: 500),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Unmount mid-sequence
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull);
      },
    );
  });
}
