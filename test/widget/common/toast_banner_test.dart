import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/toast_banner.dart';

void main() {
  testWidgets(
    'ENH-17: Reduce Motion bật → ToastBanner.show hiện/ẩn ngay, không cần chờ transition',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                ctx = context;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );

      ToastBanner.show(
        ctx,
        message: 'Saved!',
        duration: const Duration(milliseconds: 500),
      );

      // 1 frame duy nhất — duration = 0 nên FadeTransition/SlideTransition
      // phải ở trạng thái cuối ngay, không cần chờ 220ms entrance.
      await tester.pump();
      expect(find.text('Saved!'), findsOneWidget);
      final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
      expect(fade.opacity.value, 1.0);
      expect(tester.takeException(), isNull);

      // Qua mốc duration → remove() gọi reverse() nhưng cũng duration 0 →
      // biến mất ngay, không cần chờ thêm 180ms reverse.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Saved!'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
