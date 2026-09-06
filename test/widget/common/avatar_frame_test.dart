import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/avatar_frame.dart';

void main() {
  testWidgets('render child bên trong, dùng size/color mặc định', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: AvatarFrame(child: const Text('AB'))),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('AB'), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints?.maxWidth, 64);
    expect(container.constraints?.maxHeight, 64);

    final decoration = container.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.border, Border.all(color: NeonTheme.cyan, width: 3));
  });

  testWidgets('size/color/ringWidth tuỳ chỉnh áp dụng đúng', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: AvatarFrame(
            color: NeonTheme.red,
            size: 100,
            ringWidth: 6,
            child: const Icon(Icons.person),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints?.maxWidth, 100);
    expect(container.constraints?.maxHeight, 100);

    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, Border.all(color: NeonTheme.red, width: 6));
  });
}
