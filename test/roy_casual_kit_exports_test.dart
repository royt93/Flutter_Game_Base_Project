// BUG-65: `dlog()`/`DebugQaOverlay` were never exported from the package's
// main barrel (`lib/roy_casual_kit.dart`) — a consumer app importing
// `package:roy_casual_kit/roy_casual_kit.dart` (the documented, standard
// way per README/CLAUDE.md) couldn't reach either, despite both being
// described there as important public API. This file imports ONLY the
// barrel (never `core/debug_log.dart`/`presentation/widgets/
// debug_qa_overlay.dart` directly) — if either export is missing, this
// file fails to COMPILE, not just fails an assertion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

void main() {
  test('dlog() được truy cập được qua barrel export chính', () {
    expect(() => dlog('BUG-65 export check'), returnsNormally);
  });

  testWidgets(
    'DebugQaOverlay được truy cập được qua barrel export chính',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: SizedBox()),
        ),
      );

      expect(find.byType(DebugQaOverlay), findsOneWidget);
    },
  );
}
