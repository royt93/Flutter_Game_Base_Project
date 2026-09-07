import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/circular_progress_ring.dart';

// Helper: tìm CustomPaint có painter thuộc loại _RingPainter (private) —
// vì không import được type private từ package khác, ta lọc theo
// runtimeType.toString() để lấy đúng painter và đọc field `progress` qua
// so sánh shouldRepaint/toString là quá phức tạp, nên thay vào đó ta kiểm
// tra qua CustomPaint mà painter's runtimeType chứa "_RingPainter".
CustomPaint _ringPaint(WidgetTester tester) => tester.widgetList<CustomPaint>(
  find.byType(CustomPaint),
).firstWhere((w) => w.painter.runtimeType.toString() == '_RingPainter');

void main() {
  testWidgets(
    'sau khi animation settle, painter.progress khớp progress truyền vào (đã clamp)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: Center(child: CircularProgressRing(progress: 0.7)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final painter = _ringPaint(tester).painter as dynamic;
      expect(painter.progress, closeTo(0.7, 0.001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('progress > 1.0 bị clamp về 1.0', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Center(child: CircularProgressRing(progress: 1.5)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final painter = _ringPaint(tester).painter as dynamic;
    expect(painter.progress, closeTo(1.0, 0.001));
  });

  testWidgets('progress < 0 bị clamp về 0.0', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Center(child: CircularProgressRing(progress: -0.5)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final painter = _ringPaint(tester).painter as dynamic;
    expect(painter.progress, closeTo(0.0, 0.001));
  });

  testWidgets('icon truyền vào được render ở giữa ring', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Center(
            child: CircularProgressRing(
              progress: 0.5,
              icon: Icons.timer_rounded,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.timer_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('label truyền vào được render khi không có icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Center(
            child: CircularProgressRing(progress: 0.5, label: '3:00'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ENH-17: Reduce Motion bật → arc nhảy thẳng tới progress đích, không cần chờ 400ms',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: Center(child: CircularProgressRing(progress: 0.7)),
            ),
          ),
        ),
      );

      // 1 frame duy nhất — không pumpAndSettle/pump(400ms), vì duration = 0
      // phải khiến TweenAnimationBuilder nhảy thẳng tới giá trị cuối.
      await tester.pump();

      final painter = _ringPaint(tester).painter as dynamic;
      expect(painter.progress, closeTo(0.7, 0.001));
      expect(tester.takeException(), isNull);
    },
  );
}
