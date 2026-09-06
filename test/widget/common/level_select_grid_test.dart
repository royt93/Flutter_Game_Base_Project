import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/level_select_grid.dart';
import 'package:roy_casual_kit/presentation/widgets/common/star_rating.dart';

void main() {
  group('pure state logic (no widget involved)', () {
    test('levelStateTappable: locked is false, unlocked/completed are true', () {
      expect(levelStateTappable(LevelState.locked), isFalse);
      expect(levelStateTappable(LevelState.unlocked), isTrue);
      expect(levelStateTappable(LevelState.completed), isTrue);
    });

    test('levelStateIcon: only locked gets a lock glyph', () {
      expect(levelStateIcon(LevelState.locked), Icons.lock_rounded);
      expect(levelStateIcon(LevelState.unlocked), isNull);
      expect(levelStateIcon(LevelState.completed), isNull);
    });

    test('levelStateFillColor/BorderColor differ per state', () {
      expect(levelStateFillColor(LevelState.locked), NeonTheme.lockedFill);
      expect(levelStateBorderColor(LevelState.locked), NeonTheme.lockedBorder);
      expect(levelStateFillColor(LevelState.completed), NeonTheme.gold);
      expect(levelStateBorderColor(LevelState.completed), NeonTheme.gold);
      expect(levelStateFillColor(LevelState.unlocked), NeonTheme.card);
    });
  });

  group('LevelNodeButton', () {
    testWidgets('locked: shows a lock icon and blocks tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: LevelNodeButton(
              levelNumber: 3,
              state: LevelState.locked,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('3'), findsNothing);

      await tester.tap(find.byIcon(Icons.lock_rounded));
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('unlocked: shows the level number, tap fires the callback', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: LevelNodeButton(
              levelNumber: 5,
              state: LevelState.unlocked,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.byType(StarRating), findsNothing);

      await tester.tap(find.text('5'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('completed: shows the level number plus a star badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: LevelNodeButton(
              levelNumber: 2,
              state: LevelState.completed,
              starsEarned: 2,
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      final stars = tester.widget<StarRating>(find.byType(StarRating));
      expect(stars.earned, 2);
    });
  });

  group('LevelSelectGrid', () {
    testWidgets('renders exactly one node per entry in a mixed-state list', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: LevelSelectGrid(
              states: const [
                LevelState.completed,
                LevelState.completed,
                LevelState.unlocked,
                LevelState.locked,
                LevelState.locked,
              ],
              starsEarnedByLevel: const {1: 3, 2: 1},
            ),
          ),
        ),
      );

      expect(find.byType(LevelNodeButton), findsNWidgets(5));
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(2));
    });

    testWidgets('onLevelTap fires with the right 1-based level number, '
        'locked nodes never fire it', (tester) async {
      final tappedLevels = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: LevelSelectGrid(
              states: const [
                LevelState.completed,
                LevelState.unlocked,
                LevelState.locked,
              ],
              onLevelTap: tappedLevels.add,
            ),
          ),
        ),
      );

      await tester.tap(find.text('2')); // unlocked node, level 2
      await tester.pump();
      expect(tappedLevels, [2]);

      // Locked level 3 shows a lock icon instead of its number.
      await tester.tap(find.byIcon(Icons.lock_rounded));
      await tester.pump();
      expect(tappedLevels, [2]); // unchanged
    });
  });
}
