import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_icon.dart';

Widget _wrap(Widget child) => MaterialApp(home: Material(child: child));

void main() {
  group('NeonBackButton', () {
    testWidgets('không truyền color thì dùng NeonTheme.cyan hiện hành', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const NeonBackButton()));

      final iconButton = tester.widget<NeonIconButton>(
        find.byType(NeonIconButton),
      );
      expect(iconButton.color, NeonTheme.cyan);
    });

    testWidgets('truyền color tuỳ chỉnh thì ưu tiên dùng color đó', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const NeonBackButton(color: Colors.red)));

      final iconButton = tester.widget<NeonIconButton>(
        find.byType(NeonIconButton),
      );
      expect(iconButton.color, Colors.red);
    });
  });
}
