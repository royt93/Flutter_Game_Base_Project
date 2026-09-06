import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/spotlight_overlay.dart';

void main() {
  Widget harness(GlobalKey targetKey, {VoidCallback? onDismiss}) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 200, left: 40),
                child: SizedBox(
                  key: targetKey,
                  width: 120,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Target'),
                  ),
                ),
              ),
            ),
            SpotlightOverlay(
              targetKey: targetKey,
              message: 'Nhấn vào đây để bắt đầu',
              title: 'Bước 1',
              holePadding: 12,
              onDismiss: onDismiss ?? () {},
            ),
          ],
        ),
      ),
    );
  }

  testWidgets(
    'SpotlightOverlay tính hole trùng khớp RenderBox thật của target (đã +holePadding)',
    (tester) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(harness(targetKey));
      await tester.pump();

      final targetRect = tester.getRect(find.byKey(targetKey));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('spotlightOverlayPainter')),
                  )
                  .painter
              as SpotlightHolePainter;

      expect(painter.hole, targetRect.inflate(12));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SpotlightOverlay hiện title/message/nút dismiss, tap nút gọi onDismiss',
    (tester) async {
      final targetKey = GlobalKey();
      var dismissed = false;
      await tester.pumpWidget(
        harness(targetKey, onDismiss: () => dismissed = true),
      );
      await tester.pump();

      expect(find.text('Bước 1'), findsOneWidget);
      expect(find.text('Nhấn vào đây để bắt đầu'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pump();

      expect(dismissed, isTrue);
    },
  );

  testWidgets('SpotlightOverlay không crash khi targetKey chưa được mount', (
    tester,
  ) async {
    final targetKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpotlightOverlay(
            targetKey: targetKey,
            message: 'Không có target',
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('spotlightOverlayPainter')),
                )
                .painter
            as SpotlightHolePainter;
    expect(painter.hole, isNull);
    expect(tester.takeException(), isNull);
  });
}
