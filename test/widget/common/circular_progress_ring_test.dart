import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/circular_progress_ring.dart';

// Helper: tìm CustomPaint có painter thuộc loại _RingPainter (private) —
// vì không import được type private từ package khác, ta lọc theo
// runtimeType.toString() để lấy đúng painter và đọc field `progress` qua
// so sánh shouldRepaint/toString là quá phức tạp, nên thay vào đó ta kiểm
// tra qua CustomPaint mà painter's runtimeType chứa "_RingPainter".
CustomPaint _ringPaint(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .firstWhere((w) => w.painter.runtimeType.toString() == '_RingPainter');

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

  testWidgets('label truyền vào được render khi không có icon', (tester) async {
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

  testWidgets(
    'ENH-30: vẽ glow layer phía sau arc khi progress > 0, không throw',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: Center(child: CircularProgressRing(progress: 0.5)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Golden-free: dựng lên 1 recorder thật và gọi paint() trực tiếp để
      // xác nhận không throw khi có glow layer (MaskFilter.blur) — cùng mức
      // rigor các test khác trong file này (kiểm hợp đồng, không pixel).
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = _ringPaint(tester).painter as CustomPainter;
      painter.paint(canvas, const Size(72, 72));
      recorder.endRecording().dispose();

      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-41: child slot', () {
    testWidgets('child truyền vào được render, ưu tiên hơn icon/label', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: Center(
              child: CircularProgressRing(
                progress: 0.5,
                icon: Icons.timer_rounded,
                label: '3:00',
                child: Text('custom'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('custom'), findsOneWidget);
      expect(find.byIcon(Icons.timer_rounded), findsNothing);
      expect(find.text('3:00'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'child null → icon/label vẫn hoạt động y hệt như trước (không phá call site cũ)',
      (tester) async {
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
      },
    );
  });

  group('ENH-59: Semantics', () {
    testWidgets('mặc định hiện đúng "Progress: N%" + value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: Center(child: CircularProgressRing(progress: 0.4)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(CircularProgressRing));
      expect(semantics.label, 'Progress: 40%');
      expect(semantics.value, '40%');
      expect(tester.takeException(), isNull);
    });

    testWidgets('progress đổi lúc runtime → Semantics cập nhật đúng %', (
      tester,
    ) async {
      var progress = 0.2;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(child: CircularProgressRing(progress: progress)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      progress = 0.9;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(child: CircularProgressRing(progress: progress)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(CircularProgressRing));
      expect(semantics.label, 'Progress: 90%');
      expect(semantics.value, '90%');
      expect(tester.takeException(), isNull);
    });

    testWidgets('progress > 1.0 clamp về 100% trong Semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: Center(child: CircularProgressRing(progress: 1.5)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(CircularProgressRing));
      expect(semantics.value, '100%');
    });

    testWidgets('semanticLabel tuỳ biến ghi đè đúng label mặc định', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: Center(
              child: CircularProgressRing(
                progress: 0.5,
                semanticLabel: 'Daily quest progress',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(CircularProgressRing));
      expect(semantics.label, 'Daily quest progress');
    });

    testWidgets(
      'label center KHÔNG bị lặp lại 2 lần trong semantics tree (excludeSemantics)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(
              child: Center(
                child: CircularProgressRing(progress: 0.4, label: '40%'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(
          find.byType(CircularProgressRing),
        );
        // Chỉ 1 node semantics duy nhất phát ra cho toàn bộ widget — nếu
        // excludeSemantics bị bỏ, label Text '40%' bên trong sẽ tạo thêm
        // 1 node semantics con, merge label thành "Progress: 40% 40%".
        expect(semantics.label, 'Progress: 40%');
      },
    );
  });
}
