import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/badge_dot.dart';

void main() {
  testWidgets('BadgeDot dùng size/color mặc định (NeonTheme.red, 10)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Material(child: BadgeDot())),
    );

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints?.maxWidth, 10);
    expect(container.constraints?.maxHeight, 10);

    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, NeonTheme.red);
    expect(decoration.shape, BoxShape.circle);

    expect(tester.takeException(), isNull);
  });

  testWidgets('BadgeDot dùng size/color tuỳ chỉnh khi được truyền', (
    tester,
  ) async {
    const customColor = Colors.blue;
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: BadgeDot(size: 20, color: customColor)),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints?.maxWidth, 20);
    expect(container.constraints?.maxHeight, 20);

    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, customColor);
  });
}
