import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/staggered_animated_grid.dart';

void main() {
  group('staggerGridDelayForIndex', () {
    test('uses row plus column order at the configured interval', () {
      expect(
        staggerGridDelayForIndex(index: 0, crossAxisCount: 3).inMilliseconds,
        0,
      );
      expect(
        staggerGridDelayForIndex(index: 1, crossAxisCount: 3).inMilliseconds,
        40,
      );
      expect(
        staggerGridDelayForIndex(index: 2, crossAxisCount: 3).inMilliseconds,
        80,
      );
      expect(
        staggerGridDelayForIndex(index: 3, crossAxisCount: 3).inMilliseconds,
        40,
      );
      expect(
        staggerGridDelayForIndex(index: 5, crossAxisCount: 3).inMilliseconds,
        120,
      );
    });

    test('rejects invalid index, columns and stagger', () {
      expect(
        () => staggerGridDelayForIndex(index: -1, crossAxisCount: 3),
        throwsArgumentError,
      );
      expect(
        () => staggerGridDelayForIndex(index: 0, crossAxisCount: 0),
        throwsArgumentError,
      );
      expect(
        () => staggerGridDelayForIndex(
          index: 0,
          crossAxisCount: 2,
          stagger: const Duration(milliseconds: -1),
        ),
        throwsArgumentError,
      );
    });
  });

  testWidgets('six visible cells enter in delayed order and remain tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: StaggeredAnimatedGrid(
              itemCount: 6,
              crossAxisCount: 3,
              stagger: const Duration(milliseconds: 100),
              animationDuration: const Duration(milliseconds: 200),
              itemBuilder: (context, index) => GestureDetector(
                key: ValueKey('grid_$index'),
                onTap: () => taps++,
                child: ColoredBox(color: Colors.amber),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('grid_0')), findsOneWidget);
    final firstOpacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(const ValueKey('grid_0')),
        matching: find.byType(Opacity),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(firstOpacity.opacity, 0);
    await tester.pump(const Duration(milliseconds: 150));
    final firstNow = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(const ValueKey('grid_0')),
        matching: find.byType(Opacity),
      ),
    );
    final secondNow = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(const ValueKey('grid_1')),
        matching: find.byType(Opacity),
      ),
    );
    expect(firstNow.opacity, greaterThan(secondNow.opacity));
    await tester.pump(const Duration(seconds: 2));
    final lastTile = find.byKey(const ValueKey('grid_5'));
    await tester.ensureVisible(lastTile);
    await tester.pump();
    await tester.tap(lastTile);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offscreen item disposal cancels delayed entrance cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 120,
          child: StaggeredAnimatedGrid(
            itemCount: 60,
            crossAxisCount: 3,
            stagger: const Duration(seconds: 10),
            itemBuilder: _tile,
          ),
        ),
      ),
    );
    expect(find.text('Tile 0'), findsOneWidget);
    expect(find.text('Tile 59'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion mounts children without entrance wrappers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: SizedBox(
            height: 300,
            child: StaggeredAnimatedGrid(itemCount: 2, itemBuilder: _tile),
          ),
        ),
      ),
    );
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('Tile 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid grid configuration throws', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StaggeredAnimatedGrid(itemCount: -1, itemBuilder: _tile),
      ),
    );
    expect(tester.takeException(), isA<ArgumentError>());
  });
}

Widget _tile(BuildContext context, int index) => Text('Tile $index');
