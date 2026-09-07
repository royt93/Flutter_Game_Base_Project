import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/floating_combo_text.dart';

void main() {
  testWidgets(
    'FloatingComboText.show render trên overlay rồi tự remove khỏi tree sau duration',
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

      FloatingComboText.show(
        ctx,
        text: '+10',
        duration: const Duration(milliseconds: 300),
      );

      // 1 frame để OverlayEntry được insert + animation bắt đầu.
      await tester.pump();
      expect(find.text('+10'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Chưa hết duration → vẫn còn trong tree.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('+10'), findsOneWidget);

      // Qua mốc duration → animation hoàn tất → onDone gọi entry.remove().
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('+10'), findsNothing);
      expect(find.byType(FloatingComboText), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FloatingComboText (widget trần) gọi onDone khi animation xong và dispose sạch',
    (tester) async {
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: FloatingComboText(
              text: 'Combo x3',
              duration: const Duration(milliseconds: 200),
              onDone: () => done = true,
            ),
          ),
        ),
      );

      expect(find.text('Combo x3'), findsOneWidget);
      expect(done, isFalse);

      await tester.pump(const Duration(milliseconds: 250));
      expect(done, isTrue);
      expect(tester.takeException(), isNull);

      // Unmount ngay sau khi animation xong — controller phải dispose sạch,
      // không ném lỗi "used after being disposed".
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Unmount FloatingComboText giữa chừng animation không leak AnimationController',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: FloatingComboText(
              text: '+5',
              duration: Duration(milliseconds: 500),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('+5'), findsOneWidget);

      // Unmount giữa chừng (chưa hết duration) — dispose() phải chạy sạch,
      // không leak ticker vẫn sống sau khi widget đã rời tree.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FloatingComboText.show gọi liên tiếp nhanh (spam) không crash/leak',
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

      for (var i = 0; i < 10; i++) {
        FloatingComboText.show(
          ctx,
          text: '+$i',
          duration: const Duration(milliseconds: 150),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(tester.takeException(), isNull);

      // Đợi hết tất cả — mọi entry phải tự dọn sạch, không còn cái nào kẹt.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FloatingComboText), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ENH-17: Reduce Motion bật → rise+fade hoàn tất ngay, onDone gọi ngay',
    (tester) async {
      var done = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: FloatingComboText(
                text: 'Combo x3',
                duration: const Duration(milliseconds: 900),
                onDone: () => done = true,
              ),
            ),
          ),
        ),
      );

      // 1 frame duy nhất — duration = 0 nên animation hoàn tất ngay, không
      // cần chờ 900ms.
      await tester.pump();

      expect(find.text('Combo x3'), findsOneWidget);
      expect(done, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
