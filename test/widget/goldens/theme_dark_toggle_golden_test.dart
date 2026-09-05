import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_bg.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

// I15: chứng minh NeonTheme.dark đổi tức thì cho widget dùng token
// bgTop/bgMid/bgBot/card/ink trực tiếp. AC gợi ý "button, app bar" nhưng cả
// hai không tham chiếu token này (màu NeonButton đến từ accent truyền vào,
// NeonAppBar không có nền theo token) — dùng NeonDialog + NeonBg vì chúng
// thực sự render khác nhau giữa 2 theme.
Widget _wrap(Widget child) => MaterialApp(
  home: Material(child: Center(child: child)),
);

void main() {
  tearDown(() => NeonTheme.dark = false);

  for (final dark in [false, true]) {
    final suffix = dark ? 'dark' : 'light';

    testWidgets('NeonDialog.panel theme $suffix', (tester) async {
      NeonTheme.dark = dark;
      const key = Key('panel');
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 320,
            height: 200,
            child: KeyedSubtree(
              key: key,
              child: NeonDialog.panel(
                title: 'Theme test',
                color: NeonTheme.cyan,
                message: 'hello',
                actions: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('theme_dialog_$suffix.png'),
      );
    });

    testWidgets('NeonBg theme $suffix', (tester) async {
      NeonTheme.dark = dark;
      await tester.pumpWidget(
        _wrap(
          SizedBox(width: 120, height: 120, child: NeonBg(child: Container())),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(NeonBg),
        matchesGoldenFile('theme_bg_$suffix.png'),
      );
    });
  }
}
