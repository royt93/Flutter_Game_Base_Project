import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/level_path_map_tile.dart';
import 'package:roy_casual_kit/presentation/widgets/common/level_select_grid.dart'
    show LevelState;

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

double _nodeScale(WidgetTester tester, int level) => tester
    .widget<Transform>(find.byKey(ValueKey('levelPathNodeScale_$level')))
    .transform
    .entry(0, 0);

void main() {
  group('levelPathNodeCenter', () {
    test('computes smooth alternating S-curve centers', () {
      const width = 300.0;
      final c0 = levelPathNodeCenter(0, width);
      final c1 = levelPathNodeCenter(1, width);
      final c2 = levelPathNodeCenter(2, width);
      final c3 = levelPathNodeCenter(3, width);

      expect(c0.dx, closeTo(150.0, 0.001));
      expect(c1.dx, greaterThan(150.0)); // swings right
      expect(c2.dx, closeTo(150.0, 0.001)); // returns center
      expect(c3.dx, lessThan(150.0)); // swings left

      expect(c1.dy, greaterThan(c0.dy));
      expect(c2.dy, greaterThan(c1.dy));
    });

    test('validates width and rowHeight inputs', () {
      expect(() => levelPathNodeCenter(0, 0), throwsArgumentError);
      expect(
        () => levelPathNodeCenter(0, 300, rowHeight: 0),
        throwsArgumentError,
      );
    });
  });

  group('LevelPathNode validation', () {
    test('rejects level < 1 and invalid stars', () {
      expect(
        () => LevelPathNode(level: 0, state: LevelState.unlocked),
        throwsArgumentError,
      );
      expect(
        () => LevelPathNode(
          level: 1,
          state: LevelState.unlocked,
          starsEarned: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            LevelPathNode(level: 1, state: LevelState.unlocked, starsEarned: 4),
        throwsArgumentError,
      );
    });

    test('value equality works', () {
      final a = LevelPathNode(
        level: 5,
        state: LevelState.completed,
        starsEarned: 3,
      );
      final b = LevelPathNode(
        level: 5,
        state: LevelState.completed,
        starsEarned: 3,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('LevelPathMap validation', () {
    test('rejects empty nodes or invalid dimensions', () {
      expect(() => LevelPathMap(nodes: const []), throwsArgumentError);
      expect(
        () => LevelPathMap(
          nodes: [LevelPathNode(level: 1, state: LevelState.unlocked)],
          width: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => LevelPathMap(
          nodes: [LevelPathNode(level: 1, state: LevelState.unlocked)],
          rowHeight: -10,
        ),
        throwsArgumentError,
      );
    });
  });

  group('LevelPathMapTile rendering & interactions', () {
    testWidgets('completed node shows level number and stars, invokes onTap', (
      tester,
    ) async {
      int? tapped;
      await tester.pumpWidget(
        _wrap(
          LevelPathMapTile(
            node: LevelPathNode(
              level: 1,
              state: LevelState.completed,
              starsEarned: 2,
            ),
            onTap: () => tapped = 1,
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));

      await tester.tap(find.byKey(const ValueKey('levelPathNodeTap_1')));
      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('locked node shows lock icon and ignores tap', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        _wrap(
          LevelPathMapTile(
            node: LevelPathNode(level: 4, state: LevelState.locked),
            onTap: () => tapped = 4,
          ),
        ),
      );

      expect(find.byKey(const ValueKey('levelPathLock_4')), findsOneWidget);
      expect(find.text('4'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('levelPathNodeTap_4')));
      expect(tapped, isNull);
    });

    testWidgets('current node pulses glow, disabled under Reduced Motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LevelPathMapTile(
            node: LevelPathNode(
              level: 3,
              state: LevelState.unlocked,
              isCurrent: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(_nodeScale(tester, 3), greaterThan(1.0));

      // Reduced motion test
      await tester.pumpWidget(
        _wrap(
          LevelPathMapTile(
            node: LevelPathNode(
              level: 3,
              state: LevelState.unlocked,
              isCurrent: true,
            ),
          ),
          reduced: true,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(_nodeScale(tester, 3), 1.0);
    });

    testWidgets('semantics accurately announce node details', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrap(
          LevelPathMapTile(
            node: LevelPathNode(
              level: 2,
              state: LevelState.completed,
              starsEarned: 3,
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(LevelPathMapTile));
      expect(node.label, 'Level 2, completed, 3 stars');

      handle.dispose();
    });
  });

  group('LevelPathMap layout', () {
    testWidgets('renders all nodes and connects them bottom-up by default', (
      tester,
    ) async {
      int? tappedLevel;
      final nodes = [
        LevelPathNode(level: 1, state: LevelState.completed, starsEarned: 3),
        LevelPathNode(level: 2, state: LevelState.unlocked, isCurrent: true),
        LevelPathNode(level: 3, state: LevelState.locked),
      ];

      await tester.pumpWidget(
        _wrap(
          LevelPathMap(
            nodes: nodes,
            bottomUp: true,
            rowHeight: 80,
            onLevelTap: (lvl) => tappedLevel = lvl,
          ),
        ),
      );

      expect(find.byType(LevelPathMapTile), findsNWidgets(3));
      expect(find.byKey(const ValueKey('levelPathNumber_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('levelPathNumber_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('levelPathLock_3')), findsOneWidget);

      // In bottom-up mode, level 1 has the largest Y coordinate (bottom of map)
      final pos1 = tester.getCenter(
        find.byKey(const ValueKey('levelPathNodeTap_1')),
      );
      final pos2 = tester.getCenter(
        find.byKey(const ValueKey('levelPathNodeTap_2')),
      );
      final pos3 = tester.getCenter(
        find.byKey(const ValueKey('levelPathNodeTap_3')),
      );

      expect(pos1.dy, greaterThan(pos2.dy));
      expect(pos2.dy, greaterThan(pos3.dy));

      await tester.tap(find.byKey(const ValueKey('levelPathNodeTap_2')));
      expect(tappedLevel, 2);
    });
  });
}
