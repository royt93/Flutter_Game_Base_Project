import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/toast_banner.dart';

void main() {
  testWidgets(
    'ToastBanner.show render message trên overlay rồi tự dismiss sau duration',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      ToastBanner.show(
        ctx,
        message: 'Saved!',
        duration: const Duration(milliseconds: 500),
      );

      // 1 frame để OverlayEntry được insert + controller.forward() bắt đầu.
      await tester.pump();
      expect(find.text('Saved!'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Chưa hết duration (500ms) → toast vẫn còn hiển thị.
      // Không dùng pumpAndSettle() — Future.delayed(duration, remove) là 1
      // timer độc lập nên bounded pump() theo từng mốc là cách an toàn
      // (convention NeonBg trong CLAUDE.md).
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved!'), findsOneWidget);

      // Qua mốc 500ms → remove() được gọi → reverse() 180ms → entry.remove().
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Saved!'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ToastBanner (widget trần) render đúng message truyền vào', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: Center(child: ToastBanner(message: 'Hi'))),
      ),
    );

    expect(find.text('Hi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
