import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/level_goal_tracker.dart';

void main() {
  group('GoalItem', () {
    test('validates constructor parameters', () {
      expect(
        () => GoalItem(
          id: '',
          label: 'Strawberries',
          icon: const Icon(Icons.favorite),
          target: 10,
        ),
        throwsArgumentError,
      );
      expect(
        () => GoalItem(
          id: 'berries',
          label: '',
          icon: const Icon(Icons.favorite),
          target: 10,
        ),
        throwsArgumentError,
      );
      expect(
        () => GoalItem(
          id: 'berries',
          label: 'Strawberries',
          icon: const Icon(Icons.favorite),
          target: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => GoalItem(
          id: 'berries',
          label: 'Strawberries',
          icon: const Icon(Icons.favorite),
          target: 10,
          current: -1,
        ),
        throwsArgumentError,
      );
    });

    test('computes remaining and isCompleted correctly', () {
      final uncompleted = GoalItem(
        id: 'berries',
        label: 'Strawberries',
        icon: const Icon(Icons.favorite),
        target: 10,
        current: 4,
      );
      expect(uncompleted.remaining, 6);
      expect(uncompleted.isCompleted, isFalse);

      final exact = GoalItem(
        id: 'berries',
        label: 'Strawberries',
        icon: const Icon(Icons.favorite),
        target: 10,
        current: 10,
      );
      expect(exact.remaining, 0);
      expect(exact.isCompleted, isTrue);

      final exceeded = GoalItem(
        id: 'berries',
        label: 'Strawberries',
        icon: const Icon(Icons.favorite),
        target: 10,
        current: 15,
      );
      expect(exceeded.remaining, 0);
      expect(exceeded.isCompleted, isTrue);
    });
  });

  group('LevelGoalTracker validation', () {
    test('rejects empty or more than 4 goals', () {
      expect(() => LevelGoalTracker(goals: const []), throwsArgumentError);
      expect(
        () => LevelGoalTracker(
          goals: [
            for (var i = 0; i < 5; i++)
              GoalItem(
                id: 'g$i',
                label: 'Goal $i',
                icon: const Icon(Icons.star),
                target: 5,
              ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate goal IDs', () {
      expect(
        () => LevelGoalTracker(
          goals: [
            GoalItem(
              id: 'dup',
              label: 'First',
              icon: const Icon(Icons.star),
              target: 5,
            ),
            GoalItem(
              id: 'dup',
              label: 'Second',
              icon: const Icon(Icons.star),
              target: 5,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('LevelGoalTracker rendering & animation', () {
    testWidgets(
      'renders remaining count and checkmark at rest on initial mount',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LevelGoalTracker(
                goals: [
                  GoalItem(
                    id: 'berries',
                    label: 'Strawberries',
                    icon: const Icon(Icons.favorite),
                    target: 10,
                    current: 7,
                  ),
                  GoalItem(
                    id: 'ice',
                    label: 'Ice Blocks',
                    icon: const Icon(Icons.ac_unit),
                    target: 5,
                    current: 5,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('goalRemaining_berries')),
          findsOneWidget,
        );
        expect(find.text('3'), findsOneWidget);

        final checkIce = tester.widget<AnimatedScale>(
          find.ancestor(
            of: find.byKey(const ValueKey('goalCheck_ice')),
            matching: find.byType(AnimatedScale),
          ),
        );
        expect(checkIce.scale, 1.0);

        final checkBerries = tester.widget<AnimatedScale>(
          find.ancestor(
            of: find.byKey(const ValueKey('goalCheck_berries')),
            matching: find.byType(AnimatedScale),
          ),
        );
        expect(checkBerries.scale, 0.0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'transitions to complete and bounces checkmark when target reached',
      (tester) async {
        var currentBerries = 8;
        late StateSetter updateState;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  updateState = setState;
                  return LevelGoalTracker(
                    goals: [
                      GoalItem(
                        id: 'berries',
                        label: 'Strawberries',
                        icon: const Icon(Icons.favorite),
                        target: 10,
                        current: currentBerries,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        var scaleWidget = tester.widget<AnimatedScale>(
          find.ancestor(
            of: find.byKey(const ValueKey('goalCheck_berries')),
            matching: find.byType(AnimatedScale),
          ),
        );
        expect(scaleWidget.scale, 0.0);

        updateState(() => currentBerries = 10);
        await tester.pump();

        scaleWidget = tester.widget<AnimatedScale>(
          find.ancestor(
            of: find.byKey(const ValueKey('goalCheck_berries')),
            matching: find.byType(AnimatedScale),
          ),
        );
        expect(scaleWidget.scale, 1.0);

        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Reduced Motion disables transition animation', (tester) async {
      var current = 2;
      late StateSetter updateState;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  updateState = setState;
                  return LevelGoalTracker(
                    goals: [
                      GoalItem(
                        id: 'gems',
                        label: 'Gems',
                        icon: const Icon(Icons.diamond),
                        target: 5,
                        current: current,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      updateState(() => current = 5);
      await tester.pump();

      final scaleWidget = tester.widget<AnimatedScale>(
        find.ancestor(
          of: find.byKey(const ValueKey('goalCheck_gems')),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scaleWidget.duration, Duration.zero);
      expect(scaleWidget.scale, 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'exposes accessible semantics for completed and uncompleted goals',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LevelGoalTracker(
                showLabel: true,
                goals: [
                  GoalItem(
                    id: 'berries',
                    label: 'Strawberries',
                    icon: const Icon(Icons.favorite),
                    target: 10,
                    current: 3,
                  ),
                  GoalItem(
                    id: 'ice',
                    label: 'Ice Blocks',
                    icon: const Icon(Icons.ac_unit),
                    target: 4,
                    current: 4,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Strawberries'), findsOneWidget);
        expect(find.text('Ice Blocks'), findsOneWidget);

        final berriesSemantics = tester.getSemantics(
          find.byKey(const ValueKey('goalChip_berries')),
        );
        expect(berriesSemantics.label, 'Strawberries: 7 remaining');
        expect(berriesSemantics.value, '3/10');

        final iceSemantics = tester.getSemantics(
          find.byKey(const ValueKey('goalChip_ice')),
        );
        expect(iceSemantics.label, 'Ice Blocks: completed');
        expect(iceSemantics.value, '4/4');
      },
    );

    testWidgets('updating one goal does not rebuild unchanged goal content', (
      tester,
    ) async {
      var firstCurrent = 0;
      var secondBuilds = 0;
      final secondIcon = Builder(
        builder: (context) {
          secondBuilds++;
          return const Icon(Icons.diamond);
        },
      );
      late StateSetter updateState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                updateState = setState;
                return LevelGoalTracker(
                  goals: [
                    GoalItem(
                      id: 'first',
                      label: 'First',
                      icon: const Icon(Icons.star),
                      target: 3,
                      current: firstCurrent,
                    ),
                    GoalItem(
                      id: 'second',
                      label: 'Second',
                      icon: secondIcon,
                      target: 5,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final initialSecondBuilds = secondBuilds;
      updateState(() => firstCurrent = 1);
      await tester.pump();

      expect(secondBuilds, initialSecondBuilds);
      expect(tester.takeException(), isNull);
    });

    testWidgets('direction and padding apply properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelGoalTracker(
              direction: Axis.vertical,
              padding: const EdgeInsets.all(12),
              goals: [
                GoalItem(
                  id: 'g1',
                  label: 'Goal 1',
                  icon: const Icon(Icons.star),
                  target: 3,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(Column), findsWidgets);
      final paddingWidget = tester.widget<Padding>(
        find.byWidgetPredicate(
          (w) => w is Padding && w.padding == const EdgeInsets.all(12),
        ),
      );
      expect(paddingWidget, isNotNull);
    });
  });
}
