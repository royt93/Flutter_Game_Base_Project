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
}
