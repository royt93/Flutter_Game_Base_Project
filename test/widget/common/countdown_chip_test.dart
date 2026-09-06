import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/format.dart';
import 'package:roy_casual_kit/presentation/widgets/common/countdown_chip.dart';

void main() {
  testWidgets('counts down every second, formatted via fmtDur', (
    tester,
  ) async {
    final target = DateTime.now().add(const Duration(seconds: 3));
    await tester.pumpWidget(
      MaterialApp(home: Material(child: CountdownChip(target: target))),
    );

    expect(find.text(fmtDur(const Duration(seconds: 3))), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(fmtDur(const Duration(seconds: 2))), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(fmtDur(const Duration(seconds: 1))), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('calls onDone exactly once on reaching zero, never again', (
    tester,
  ) async {
    var doneCount = 0;
    final target = DateTime.now().add(const Duration(seconds: 2));
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CountdownChip(target: target, onDone: () => doneCount++),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(doneCount, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(doneCount, 1);
    expect(find.text(fmtDur(Duration.zero)), findsOneWidget);

    // Further ticks must not re-fire onDone (timer is cancelled once done).
    await tester.pump(const Duration(seconds: 3));
    expect(doneCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancels its timer on unmount (no leaked Timer, no throw)', (
    tester,
  ) async {
    final target = DateTime.now().add(const Duration(seconds: 5));
    await tester.pumpWidget(
      MaterialApp(home: Material(child: CountdownChip(target: target))),
    );
    await tester.pump(const Duration(seconds: 1));

    // Unmount mid-countdown.
    await tester.pumpWidget(
      const MaterialApp(home: Material(child: SizedBox())),
    );

    // Advance time further: a leaked periodic Timer would either fail this
    // test at teardown ("A Timer is still pending") or throw via a
    // setState-after-dispose call.
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
