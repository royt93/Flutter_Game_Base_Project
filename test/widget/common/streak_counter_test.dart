import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/streak_counter.dart';

void main() {
  testWidgets('StreakCounter hiển thị đúng số ngày và icon lửa mặc định', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Material(child: StreakCounter(days: 7))),
    );

    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);

    final icon = tester.widget<Icon>(
      find.byIcon(Icons.local_fire_department),
    );
    expect(icon.color, NeonTheme.orange);

    expect(tester.takeException(), isNull);
  });

  testWidgets('StreakCounter dùng icon/color tuỳ chỉnh khi được truyền', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: StreakCounter(
            days: 30,
            icon: Icons.whatshot,
            color: Colors.purple,
          ),
        ),
      ),
    );

    expect(find.text('30'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
    expect(find.byIcon(Icons.whatshot), findsOneWidget);

    final icon = tester.widget<Icon>(find.byIcon(Icons.whatshot));
    expect(icon.color, Colors.purple);
  });

  Transform scaleTransformOf(WidgetTester tester) => tester.widget<Transform>(
    find.ancestor(
      of: find.byType(Row),
      matching: find.byType(Transform),
    ),
  );

  // `Matrix4.getMaxScaleOnAxis()` không phản ánh đúng hệ số scale thuần
  // (đã verify bằng debug script: storage[0] đúng 0.7 nhưng
  // getMaxScaleOnAxis() vẫn trả 1.0) — đọc trực tiếp phần tử m11 (x-scale)
  // của ma trận thay vì dùng hàm đó.
  double xScaleOf(Transform t) => t.transform.storage[0];

  testWidgets(
    'ENH-31: mount lần đầu không pop (scale = 1.0 ngay), tăng days thì pop (scale bounce)',
    (tester) async {
      var days = 5;
      late StateSetter setDays;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                setDays = setState;
                return StreakCounter(days: days);
              },
            ),
          ),
        ),
      );

      // Mount lần đầu: không animate, scale ổn định = 1.0 ngay.
      expect(xScaleOf(scaleTransformOf(tester)), 1.0);

      setDays(() => days = 6);
      await tester.pump();
      // Ngay khi vừa tăng — giữa chừng animation (chưa settle) scale phải
      // khác 1.0 (đang trong pha bounce).
      expect(xScaleOf(scaleTransformOf(tester)), isNot(1.0));

      await tester.pumpAndSettle();
      expect(find.text('6'), findsOneWidget);
      expect(xScaleOf(scaleTransformOf(tester)), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ENH-31: Reduce Motion bật → không animate, số vẫn cập nhật đúng',
    (tester) async {
      var days = 5;
      late StateSetter setDays;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setDays = setState;
                  return StreakCounter(days: days);
                },
              ),
            ),
          ),
        ),
      );

      setDays(() => days = 6);
      await tester.pump();

      expect(find.text('6'), findsOneWidget);
      expect(xScaleOf(scaleTransformOf(tester)), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ENH-40: textScaleFactor lớn + số ngày dài không gây RenderFlex overflow',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
          child: MaterialApp(
            home: Material(
              child: SizedBox(
                width: 80,
                child: StreakCounter(days: 999999),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FittedBox), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
