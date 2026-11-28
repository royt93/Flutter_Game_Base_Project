import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/scratch_card.dart';

import '../../support/leak_ignores.dart';

void main() {
  group('ScratchCoverageGrid', () {
    test('rejects zero columns or rows', () {
      expect(
        () => ScratchCoverageGrid(columns: 0, rows: 1),
        throwsArgumentError,
      );
      expect(
        () => ScratchCoverageGrid(columns: 1, rows: 0),
        throwsArgumentError,
      );
    });

    test(
      'degenerate segment marks nearby cells and invalid dimensions do nothing',
      () {
        final grid = ScratchCoverageGrid(columns: 4, rows: 4);
        expect(
          grid.markSegment(
            start: const Offset(20, 20),
            end: const Offset(20, 20),
            size: const Size(40, 40),
            brushWidth: 4,
          ),
          greaterThan(0),
        );
        final covered = grid.coveredCount;
        expect(
          grid.markSegment(
            start: Offset.zero,
            end: Offset.zero,
            size: const Size(0, 40),
            brushWidth: 4,
          ),
          0,
        );
        expect(
          grid.markSegment(
            start: Offset.zero,
            end: Offset.zero,
            size: const Size(40, 40),
            brushWidth: 0,
          ),
          0,
        );
        expect(grid.coveredCount, covered);
      },
    );

    test(
      'zero-length segment uses point distance; nonzero segment clamps projection endpoints',
      () {
        final grid = ScratchCoverageGrid(columns: 4, rows: 2);
        final size = const Size(40, 20);
        final point = grid.markSegment(
          start: const Offset(5, 5),
          end: const Offset(5, 5),
          size: size,
          brushWidth: 1,
        );
        expect(point, greaterThan(0));
        final before = grid.coveredCount;
        grid.markSegment(
          start: const Offset(0, 5),
          end: const Offset(2, 5),
          size: size,
          brushWidth: 1,
        );
        expect(grid.coveredCount, greaterThanOrEqualTo(before));
        expect(grid.ratio, inInclusiveRange(0, 1));
      },
    );
  });

  group('ScratchCard validation and pointer ownership', () {
    Widget host(ScratchCard card) => MaterialApp(home: Material(child: card));
    ScratchCard card({
      Key? key,
      double threshold = 0.6,
      double brushWidth = 8,
      Size size = const Size(80, 60),
      double radius = 8,
      int columns = 4,
      int rows = 3,
    }) => ScratchCard(
      key: key,
      prize: const Text('Prize'),
      cover: const ColoredBox(color: Colors.grey),
      threshold: threshold,
      brushWidth: brushWidth,
      size: size,
      columns: columns,
      rows: rows,
      coverBorderRadius: radius,
    );

    for (final (name, build) in <(String, ScratchCard Function())>[
      ('rejects threshold zero', () => card(threshold: 0)),
      ('rejects infinite brush width', () => card(brushWidth: double.infinity)),
      (
        'rejects infinite size',
        () => card(size: const Size(double.infinity, 20)),
      ),
      ('rejects negative radius', () => card(radius: -1)),
    ]) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(host(build()));
        expect(tester.takeException(), isArgumentError);
      }, experimentalLeakTesting: ignoringFailedInitState('ScratchCardState'));
    }

    testWidgets(
      'rejects a grid with no columns',
      (tester) async {
        await tester.pumpWidget(host(card(columns: 0)));
        expect(tester.takeException(), isArgumentError);
      },
      experimentalLeakTesting: ignoringFailedInitState('ScratchCardState'),
    );

    testWidgets(
      'rejects a grid with no rows',
      (tester) async {
        await tester.pumpWidget(host(card(rows: 0)));
        expect(tester.takeException(), isArgumentError);
      },
      experimentalLeakTesting: ignoringFailedInitState('ScratchCardState'),
    );

    testWidgets(
      'ignores another pointer while first owns the scratch; cancel releases it',
      (tester) async {
        final key = GlobalKey<ScratchCardState>();
        await tester.pumpWidget(host(card(key: key, threshold: 0.99)));
        final rect = tester.getRect(find.byType(ScratchCard));
        final first = await tester.startGesture(
          rect.topLeft + const Offset(8, 8),
          pointer: 1,
        );
        final progressAfterFirst = key.currentState!.progress;
        final second = await tester.startGesture(
          rect.bottomRight - const Offset(8, 8),
          pointer: 2,
        );
        await second.moveTo(rect.center);
        await tester.pump();
        expect(
          key.currentState!.progress,
          progressAfterFirst,
          reason: 'second pointer is ignored',
        );
        await second.up();
        await first.cancel();

        final next = await tester.startGesture(
          rect.topLeft + const Offset(10, 30),
          pointer: 3,
        );
        await next.moveTo(rect.topLeft + const Offset(70, 30));
        await tester.pump();
        expect(key.currentState!.progress, greaterThan(progressAfterFirst));
        await next.up();
      },
    );

    testWidgets('updating brush width repaints existing scratch segments', (
      tester,
    ) async {
      final key = GlobalKey<ScratchCardState>();
      Widget make(double brushWidth) => MaterialApp(
        home: Material(
          child: ScratchCard(
            key: key,
            prize: const Text('Prize'),
            cover: const ColoredBox(color: Colors.grey),
            threshold: 0.99,
            brushWidth: brushWidth,
            size: const Size(80, 60),
            columns: 4,
            rows: 3,
          ),
        ),
      );

      await tester.pumpWidget(make(2));
      final rect = tester.getRect(find.byType(ScratchCard));
      final gesture = await tester.startGesture(
        rect.topLeft + const Offset(5, 5),
      );
      await gesture.moveTo(rect.topLeft + const Offset(20, 5));
      await tester.pump();
      await gesture.up();
      expect(key.currentState!.progress, greaterThan(0));

      await tester.pumpWidget(make(24));
      await tester.pump();
      expect(key.currentState!.progress, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'changing grid resolution resets reveal and allows callbacks again',
      (tester) async {
        final key = GlobalKey<ScratchCardState>();
        var revealed = 0;
        final finder = find.byType(ScratchCard);
        Widget make(int rows) => MaterialApp(
          home: Material(
            child: ScratchCard(
              key: key,
              prize: const Text('Prize'),
              cover: const ColoredBox(color: Colors.grey),
              threshold: 0.001,
              brushWidth: 32,
              size: const Size(80, 60),
              columns: 4,
              rows: rows,
              onRevealed: () => revealed++,
            ),
          ),
        );
        await tester.pumpWidget(make(3));
        final semantics = tester.ensureSemantics();
        final node = tester.getSemantics(finder);
        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          node.id,
          SemanticsAction.tap,
        );
        await tester.pump();
        semantics.dispose();
        expect(key.currentState!.isRevealed, isTrue);
        expect(revealed, 1);

        await tester.pumpWidget(make(4));
        expect(key.currentState!.isRevealed, isFalse);
        expect(key.currentState!.progress, 0);
        final semanticsAgain = tester.ensureSemantics();
        final nodeAgain = tester.getSemantics(finder);
        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          nodeAgain.id,
          SemanticsAction.tap,
        );
        await tester.pump();
        semanticsAgain.dispose();
        expect(key.currentState!.isRevealed, isTrue);
        expect(revealed, 2);
      },
    );
  });

  group('ScratchCoverageGrid', () {
    test('segment marks cells crossed between pointer events, once', () {
      final grid = ScratchCoverageGrid(columns: 10, rows: 4);
      final first = grid.markSegment(
        start: const Offset(5, 5),
        end: const Offset(95, 35),
        size: const Size(100, 40),
        brushWidth: 2,
      );
      expect(first, greaterThan(0));
      final ratioAfterFirst = grid.ratio;
      final second = grid.markSegment(
        start: const Offset(5, 5),
        end: const Offset(95, 35),
        size: const Size(100, 40),
        brushWidth: 2,
      );
      expect(second, 0);
      expect(grid.ratio, ratioAfterFirst);
    });

    test('clamps strokes at edges and coverage ratio stays bounded', () {
      final grid = ScratchCoverageGrid(columns: 8, rows: 4);
      grid.markSegment(
        start: const Offset(-10, 0),
        end: const Offset(110, 0),
        size: const Size(80, 40),
        brushWidth: 12,
      );
      expect(grid.ratio, inInclusiveRange(0, 1));
      expect(grid.coveredCount, lessThanOrEqualTo(grid.cellCount));
    });
  });

  test('threshold comparison uses strict greater-than', () {
    expect(scratchThresholdReached(0.6, threshold: 0.6), isFalse);
    expect(scratchThresholdReached(0.60001, threshold: 0.6), isTrue);
    expect(scratchThresholdReached(1, threshold: 0.6), isTrue);
  });

  testWidgets('drag clears cover and reveals once only after >60%', (
    tester,
  ) async {
    final key = GlobalKey<ScratchCardState>();
    var reached = 0;
    var revealed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ScratchCard(
            key: key,
            size: const Size(240, 160),
            columns: 12,
            rows: 8,
            brushWidth: 46,
            cover: const ColoredBox(color: Colors.grey),
            prize: const Center(child: Text('Grand prize')),
            onThresholdReached: () => reached++,
            onRevealed: () => revealed++,
          ),
        ),
      ),
    );
    expect(key.currentState!.progress, 0);
    final scratch = find.byType(ScratchCard);
    final rect = tester.getRect(scratch);
    final gesture = await tester.startGesture(
      rect.topLeft + const Offset(10, 12),
    );
    for (final lane in [12.0, 48.0, 84.0, 120.0]) {
      await gesture.moveTo(Offset(rect.left + 10, rect.top + lane));
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset(rect.left + 10 + i * 18, rect.top + lane));
      }
    }
    await tester.pump();
    expect(key.currentState!.progress, greaterThan(0.6));
    expect(key.currentState!.isRevealed, isTrue);
    expect(reached, 1);
    expect(revealed, 1);
    await gesture.up();
    await tester.pump();
    expect(reached, 1);
    expect(revealed, 1);
    expect(find.text('Grand prize'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantic tap reveals for non-drag input users', (tester) async {
    var revealed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ScratchCard(
            cover: const ColoredBox(color: Colors.grey),
            prize: const Text('Prize'),
            onRevealed: () => revealed++,
          ),
        ),
      ),
    );
    final semanticsHandle = tester.ensureSemantics();
    final semantics = tester.getSemantics(find.byType(ScratchCard));
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      semantics.id,
      SemanticsAction.tap,
    );
    await tester.pump();
    expect(revealed, 1);
    expect(find.text('Prize'), findsOneWidget);
    semanticsHandle.dispose();
  });
}
