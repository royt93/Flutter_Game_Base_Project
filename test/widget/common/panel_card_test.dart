import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/panel_card.dart';

void main() {
  testWidgets('PanelCard mặc định dùng NeonTheme.card, không viền', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: PanelCard(child: Text('content'))),
      ),
    );

    expect(find.text('content'), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, NeonTheme.card);
    expect(decoration.border, isNull);
    expect(
      (decoration.borderRadius as BorderRadius).topLeft,
      const Radius.circular(22),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('PanelCard alt:true dùng NeonTheme.cardAlt', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: PanelCard(alt: true, child: Text('content'))),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, NeonTheme.cardAlt);
  });

  testWidgets('PanelCard hiển thị viền màu khi truyền borderColor', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: PanelCard(
            borderColor: Colors.green,
            borderRadius: 10,
            child: Text('content'),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    final border = decoration.border as Border;
    expect(border.top.color, Colors.green);
    expect(border.top.width, 2);
    expect(
      (decoration.borderRadius as BorderRadius).topLeft,
      const Radius.circular(10),
    );
  });
}
