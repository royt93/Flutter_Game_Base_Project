import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/scratch_card.dart';

void main() {
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
