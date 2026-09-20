import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/progress_bar_stars.dart';

void main() {
  testWidgets(
    'progress giữa 2 threshold: đúng số sao đã sáng (star_rounded) và chưa sáng (star_outline)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                width: 300,
                child: ProgressBarStars(progress: 0.5),
              ),
            ),
          ),
        ),
      );

      // Chờ TweenAnimationBuilder chạy xong (400ms fill animation) — không
      // ảnh hưởng tới star icon (chỉ phụ thuộc progress, không animate) nhưng
      // pumpAndSettle an toàn ở đây vì không có ticker vĩnh viễn nào.
      await tester.pumpAndSettle();

      // Ngưỡng mặc định [0.33, 0.66, 1.0]; progress 0.5 >= 0.33 (sáng) nhưng
      // < 0.66 và < 1.0 (chưa sáng) → 1 sao sáng, 2 sao mờ.
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('progress = 1.0: cả 3 sao đều sáng', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(width: 300, child: ProgressBarStars(progress: 1.0)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress = 0.0: cả 3 sao đều mờ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(width: 300, child: ProgressBarStars(progress: 0.0)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fill bar sau animation phản ánh đúng progress (widthFactor)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(width: 300, child: ProgressBarStars(progress: 0.4)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fractionally = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fractionally.widthFactor, closeTo(0.4, 0.001));
  });

  testWidgets(
    'ENH-17: Reduce Motion bật → fill nhảy thẳng tới progress, không cần chờ 400ms',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: Center(
                child: SizedBox(
                  width: 300,
                  child: ProgressBarStars(progress: 0.4),
                ),
              ),
            ),
          ),
        ),
      );
      // 1 frame duy nhất — không chờ 400ms fill animation.
      await tester.pump();

      final fractionally = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fractionally.widthFactor, closeTo(0.4, 0.001));
      expect(tester.takeException(), isNull);
    },
  );

  // x-scale (m11) của ma trận — không dùng `getMaxScaleOnAxis()` (đã verify
  // qua debug script: trả sai giá trị cho ma trận scale thuần trong bản
  // Flutter này), đọc trực tiếp phần tử ma trận thay thế.
  double starScaleOf(WidgetTester tester, IconData icon) {
    final transform = tester.widget<Transform>(
      find.ancestor(
        of: find.byIcon(icon).first,
        matching: find.byType(Transform),
      ),
    );
    return transform.transform.storage[0];
  }

  testWidgets(
    'ENH-32: mount lần đầu đã đạt sẵn 1 sao → không pop (scale = 1.0 ngay)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                width: 300,
                child: ProgressBarStars(progress: 0.5),
              ),
            ),
          ),
        ),
      );

      expect(starScaleOf(tester, Icons.star_rounded), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ENH-32: vượt ngưỡng mới (progress tăng qua 1 threshold) → sao đó pop',
    (tester) async {
      var progress = 0.5; // đã qua 0.33, chưa qua 0.66
      late StateSetter setProgress;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                width: 300,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setProgress = setState;
                    return ProgressBarStars(progress: progress);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      setProgress(() => progress = 0.7); // vượt ngưỡng 0.66
      await tester.pump();

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      // Sao vừa đạt (ngưỡng 0.66) đang giữa chừng pop — không phải cả 2 sao
      // đều ở scale 1.0 cùng lúc.
      final scales = tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.byIcon(Icons.star_rounded),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.storage[0])
          .toList();
      expect(scales.any((s) => s != 1.0), isTrue);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ENH-32: Reduce Motion bật → không animate khi vượt ngưỡng', (
    tester,
  ) async {
    var progress = 0.5;
    late StateSetter setProgress;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                width: 300,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setProgress = setState;
                    return ProgressBarStars(progress: progress);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    setProgress(() => progress = 0.7);
    await tester.pump();

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  group('ENH-37: Semantics', () {
    testWidgets('label/value phản ánh đúng progress ở 2 mốc khác nhau', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: SizedBox(width: 300, child: ProgressBarStars(progress: 0.3)),
          ),
        ),
      );
      await tester.pump();

      var data = tester.getSemantics(find.byType(ProgressBarStars));
      expect(data.label, 'Progress: 30%');
      expect(data.value, '30%');

      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: SizedBox(width: 300, child: ProgressBarStars(progress: 0.9)),
          ),
        ),
      );
      await tester.pump();

      data = tester.getSemantics(find.byType(ProgressBarStars));
      expect(data.label, 'Progress: 90%');
      expect(data.value, '90%');
      handle.dispose();
    });

    testWidgets('semanticLabel tuỳ chỉnh ghi đè đúng label mặc định', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: SizedBox(
              width: 300,
              child: ProgressBarStars(
                progress: 0.5,
                semanticLabel: 'World progress',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(ProgressBarStars)).label,
        'World progress',
      );
      handle.dispose();
    });
  });

  group('ENH-38: RTL', () {
    testWidgets('LTR: sao ở threshold 0.2 nằm gần mép trái của thanh', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: SizedBox(
              width: 300,
              child: ProgressBarStars(
                progress: 1.0,
                starThresholds: const [0.2],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final barRect = tester.getRect(find.byType(ProgressBarStars));
      final starRect = tester.getRect(find.byIcon(Icons.star_rounded));
      expect(starRect.center.dx - barRect.left, lessThan(barRect.width / 2));
    });

    testWidgets(
      'RTL: cùng threshold 0.2 → sao nằm gần mép PHẢI (đảo ngược so với LTR)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SizedBox(
                  width: 300,
                  child: ProgressBarStars(
                    progress: 1.0,
                    starThresholds: const [0.2],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final barRect = tester.getRect(find.byType(ProgressBarStars));
        final starRect = tester.getRect(find.byIcon(Icons.star_rounded));
        expect(barRect.right - starRect.center.dx, lessThan(barRect.width / 2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'RTL: fill vẫn tô đúng widthFactor=progress, chỉ đổi hướng phát triển (từ phải sang trái)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SizedBox(
                  width: 300,
                  child: ProgressBarStars(progress: 0.5),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fittedBox = tester.widget<FractionallySizedBox>(
          find.byType(FractionallySizedBox),
        );
        expect(fittedBox.widthFactor, 0.5);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
