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
            child: SizedBox(
              width: 300,
              child: ProgressBarStars(progress: 1.0),
            ),
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
            child: SizedBox(
              width: 300,
              child: ProgressBarStars(progress: 0.0),
            ),
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
            child: SizedBox(
              width: 300,
              child: ProgressBarStars(progress: 0.4),
            ),
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
}
