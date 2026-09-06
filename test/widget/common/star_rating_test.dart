import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/star_rating.dart';

void main() {
  testWidgets('StarRating (animate: false) hiển thị đúng số sao earned/dim', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: StarRating(earned: 2, total: 3)),
      ),
    );

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(1));

    final filled = tester.widgetList<Icon>(find.byIcon(Icons.star_rounded));
    for (final icon in filled) {
      expect(icon.color, NeonTheme.gold);
    }
    final dim = tester.widgetList<Icon>(
      find.byIcon(Icons.star_outline_rounded),
    );
    for (final icon in dim) {
      expect(icon.color, NeonTheme.muted);
    }

    // Không có ScaleTransition khi animate: false.
    expect(find.byType(ScaleTransition), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StarRating (animate: true) pop-in staggered, không throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: StarRating(earned: 3, total: 3, animate: true),
        ),
      ),
    );

    // Ngay sau frame đầu, các ScaleTransition đã được gắn (animation đang
    // chạy). AnimationController này tự settle (không phải ticker vô hạn)
    // nhưng vẫn dùng bounded pump theo convention của repo thay vì
    // pumpAndSettle.
    expect(find.byType(ScaleTransition), findsNWidgets(3));

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('StarRating earned=0 thì tất cả sao đều là outline (dim)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: StarRating(earned: 0, total: 3)),
      ),
    );

    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(3));
  });
}
