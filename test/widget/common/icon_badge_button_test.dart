import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/icon_badge_button.dart';

void main() {
  testWidgets('IconBadgeButton dùng semanticLabel tuỳ chỉnh khi được truyền', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: IconBadgeButton(
            icon: Icons.settings,
            semanticLabel: 'Settings',
            onTap: () {},
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(IconBadgeButton));
    expect(semantics.label, 'Settings');
    handle.dispose();
  });
}
